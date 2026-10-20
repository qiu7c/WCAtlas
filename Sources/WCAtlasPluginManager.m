#import "WCAtlasPluginManager.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasSettingsTheme.h"
#import "WCAtlasSettingsViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>

NSString *const WCAtlasPluginManagerEnabledKey = @"com.qiu7c.wcatlas.plugin-manager.enabled";

static NSString *const WCPEntryIconStyleKey = @"com.qiu7c.wcatlas.plugin-manager.entry-icon-style";
static NSString *const WCPDidChangeNotification = @"WCAtlasPluginsMgr.RegistryDidChange";
static NSString *const WCPWCAtlasQuickSwitchesKey = @"com.qiu7c.wcatlas.plugin-manager.quick-switches";
static Class WCPRuntimeRegistryClass;
static WCAtlasPluginsMgr *WCPRuntimeRegistryInstance;


static UIImage *WCPBuiltinPluginIcon(NSInteger style) {
    if (style <= 0) {
        UIImage *native = [UIImage imageNamed:@"WeChat_Lab_Logo_light_small"] ?:
                          [UIImage imageNamed:@"WeChat_Lab_Logo_light_small@3x.png"];
        if (native) return native;
    }
    NSArray<NSString *> *symbols = @[@"app.badge", @"lightbulb", @"puzzlepiece.extension", @"seal", @"square.grid.2x2"];
    NSUInteger index = MIN((NSUInteger)MAX(style, 0), symbols.count - 1);
    return [UIImage systemImageNamed:symbols[index]];
}





static NSDictionary *WCPDictionary(NSString *key) {
    NSDictionary *value = [NSUserDefaults.standardUserDefaults dictionaryForKey:key];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}
static NSMutableDictionary *WCPMutableDictionary(NSString *key) { return [NSMutableDictionary dictionaryWithDictionary:WCPDictionary(key)]; }

static NSString *WCPIdentifierForModel(WCAtlasPluginModel *model) {
    if (model.isController && model.controller.length) return [@"controller:" stringByAppendingString:model.controller];
    if (!model.isController && model.key.length) return [@"switch:" stringByAppendingString:model.key];
    return [@"title:" stringByAppendingString:model.title ?: @""];
}


static BOOL WCPPushViewController(UINavigationController *navigation,
                                  UIViewController *controller,
                                  BOOL animated) {
    if (!navigation || !controller) return NO;
    SEL wechatPush = NSSelectorFromString(@"PushViewController:animated:");
    if ([navigation respondsToSelector:wechatPush]) {
        ((void (*)(id, SEL, UIViewController *, BOOL))objc_msgSend)(navigation, wechatPush, controller, animated);
        return YES;
    }
    [navigation pushViewController:controller animated:animated];
    return YES;
}

@implementation WCAtlasPluginModel
@end

@implementation WCAtlasPluginsMgr
+ (instancetype)sharedInstance {
    if (WCPRuntimeRegistryClass) {
        return (id)[WCPRuntimeRegistryClass sharedInstance];
    }
    static WCAtlasPluginsMgr *manager; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WCAtlasPluginsMgr new]; manager.plugins = [NSMutableArray array]; });
    return manager;
}
- (NSString *)identifier:(WCAtlasPluginModel *)model {
    return WCPIdentifierForModel(model);
}
- (void)addModel:(WCAtlasPluginModel *)model {
    if (!model.title.length) return;
    NSString *identifier = [self identifier:model];
    @synchronized (self) {
        NSUInteger index = [self.plugins indexOfObjectPassingTest:^BOOL(WCAtlasPluginModel *candidate, NSUInteger idx, BOOL *stop) { return [[self identifier:candidate] isEqualToString:identifier]; }];
        if (index == NSNotFound) [self.plugins addObject:model]; else self.plugins[index] = model;
    }
    [NSNotificationCenter.defaultCenter postNotificationName:WCPDidChangeNotification object:self];
    WCAtlasLog(@"检测到插件注册：%@ (%@)", model.title, model.isController ? model.controller : model.key);
}
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller {
    if (!title.length || !controller.length) return;
    WCAtlasPluginModel *model = [WCAtlasPluginModel new]; model.isController = YES; model.title = title; model.version = version ?: @""; model.controller = controller; model.key = @""; [self addModel:model];
}
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key {
    if (!title.length || !key.length) return;
    WCAtlasPluginModel *model = [WCAtlasPluginModel new]; model.isController = NO; model.title = title; model.version = @""; model.controller = @""; model.key = key; [self addModel:model];
}
- (void)removeSwitchWithKey:(NSString *)key {
    if (!key.length) return;
    NSString *identifier = [@"switch:" stringByAppendingString:key];
    @synchronized (self) {
        NSIndexSet *indexes = [self.plugins indexesOfObjectsPassingTest:^BOOL(WCAtlasPluginModel *model, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop;
            return [[self identifier:model] isEqualToString:identifier];
        }];
        if (indexes.count) [self.plugins removeObjectsAtIndexes:indexes];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:WCPDidChangeNotification object:self];
}
@end

static id WCPRuntimeRegistrySharedInstance(id receiver, SEL selector) {
    (void)selector;
    @synchronized ((id)receiver) {
        if (!WCPRuntimeRegistryInstance) {
            WCPRuntimeRegistryInstance = [[receiver alloc] init];
            WCPRuntimeRegistryInstance.plugins = [NSMutableArray array];
        }
        return WCPRuntimeRegistryInstance;
    }
}

BOOL WCAtlasInstallPluginRegistry(void) {
    if (![NSUserDefaults.standardUserDefaults boolForKey:WCAtlasPluginManagerEnabledKey]) return NO;
    Class existingClass = objc_getClass("WCPluginsMgr");
    if (existingClass) return existingClass == WCPRuntimeRegistryClass;

    Class registryClass = objc_allocateClassPair(WCAtlasPluginsMgr.class, "WCPluginsMgr", 0);
    if (!registryClass) return NO;
    Class metaClass = object_getClass(registryClass);
    if (!class_addMethod(metaClass, @selector(sharedInstance),
                         (IMP)WCPRuntimeRegistrySharedInstance, "@@:")) {
        objc_disposeClassPair(registryClass);
        return NO;
    }
    objc_registerClassPair(registryClass);
    WCPRuntimeRegistryClass = registryClass;
    WCAtlasLog(@"已注册 WCPluginsMgr 内置插件管理中心");
    return YES;
}

static WCAtlasPluginsMgr *WCPExternalManager(void) {
    Class managerClass = NSClassFromString(@"WCPluginsMgr");
    if (!managerClass || managerClass == WCPRuntimeRegistryClass ||
        managerClass == WCAtlasPluginsMgr.class ||
        ![managerClass respondsToSelector:@selector(sharedInstance)]) return nil;
    return [managerClass sharedInstance];
}

BOOL WCAtlasExternalPluginManagerAvailable(void) {
    WCAtlasPluginsMgr *manager = WCPExternalManager();
    return manager && [manager respondsToSelector:
        @selector(registerControllerWithTitle:version:controller:)];
}

static id WCPRegistrationManager(void) {
    WCAtlasPluginsMgr *external = WCPExternalManager();
    if (external) return external;
    if (![NSUserDefaults.standardUserDefaults boolForKey:WCAtlasPluginManagerEnabledKey] ||
        !WCAtlasInstallPluginRegistry()) return nil;
    return [WCPRuntimeRegistryClass sharedInstance];
}

BOOL WCAtlasPluginManagerIsQuickSwitchRegistered(NSString *key) {
    if (key.length == 0) return NO;
    return [WCPDictionary(WCPWCAtlasQuickSwitchesKey)[key] isKindOfClass:NSString.class];
}

void WCAtlasPluginManagerSetQuickSwitchRegistered(NSString *key, NSString *title, BOOL registered) {
    if (key.length == 0) return;
    NSMutableDictionary *saved = WCPMutableDictionary(WCPWCAtlasQuickSwitchesKey);
    id manager = WCPRegistrationManager();
    if (registered) {
        NSString *displayTitle = title.length ? title : key;
        saved[key] = displayTitle;
        if ([manager respondsToSelector:@selector(registerSwitchWithTitle:key:)]) {
            [manager registerSwitchWithTitle:displayTitle key:key];
        }
    } else {
        [saved removeObjectForKey:key];
        if ([manager respondsToSelector:@selector(removeSwitchWithKey:)]) {
            [manager removeSwitchWithKey:key];
        }
    }
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:WCPWCAtlasQuickSwitchesKey];
}

void WCAtlasPluginManagerRegisterSavedQuickSwitches(void) {
    NSDictionary *saved = WCPDictionary(WCPWCAtlasQuickSwitchesKey);
    id manager = WCPRegistrationManager();
    if (!manager) return;
    [saved enumerateKeysAndObjectsUsingBlock:^(id key, id title, BOOL *stop) {
        (void)stop;
        if ([key isKindOfClass:NSString.class] && [title isKindOfClass:NSString.class] &&
            [key length] > 0 && [title length] > 0) {
            [manager registerSwitchWithTitle:title key:key];
        }
    }];
}


static UIImage *WCPEntryIcon(void) { return WCPBuiltinPluginIcon([NSUserDefaults.standardUserDefaults integerForKey:WCPEntryIconStyleKey]); }

void WCAtlasInstallPluginManagerEntry(id moreViewController) {
    if (!moreViewController) return;
    if (WCAtlasExternalPluginManagerAvailable()) {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
        return;
    }
    if (![NSUserDefaults.standardUserDefaults boolForKey:WCAtlasPluginManagerEnabledKey]) return; id tableManager = nil; @try { tableManager = [moreViewController valueForKey:@"m_tableViewMgr"]; } @catch (__unused NSException *exception) {} if (!tableManager || ![tableManager respondsToSelector:NSSelectorFromString(@"getSectionAt:")]) return; Class cellClass = NSClassFromString(@"WCTableViewCellManager"); UIImage *icon = WCPEntryIcon(); id cell = nil; SEL factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:WithDisclosureIndicator:"); if ([cellClass respondsToSelector:factory]) cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, BOOL))objc_msgSend)(cellClass, factory, @selector(pushPluginController), moreViewController, icon, @"插件", YES); else { factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:pathKey:"); if ([cellClass respondsToSelector:factory]) cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, NSString *))objc_msgSend)(cellClass, factory, @selector(pushPluginController), moreViewController, icon, @"插件", nil); } if (!cell) return; id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(tableManager, NSSelectorFromString(@"getSectionAt:"), 2); if (section && [section respondsToSelector:NSSelectorFromString(@"addCell:")]) ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"addCell:"), cell); id tableView = nil; if ([tableManager respondsToSelector:NSSelectorFromString(@"getTableView")]) tableView = ((id (*)(id, SEL))objc_msgSend)(tableManager, NSSelectorFromString(@"getTableView")); if ([tableView respondsToSelector:@selector(reloadData)]) [tableView reloadData];
}

static char WCPSettingsFallbackAddedKey;

static id WCPSettingsTableManager(id controller) {
    if (!controller) return nil;
    for (NSString *name in @[@"m_tableViewMgr", @"_tableViewMgr", @"m_tableMgr", @"_tableMgr"]) {
        Ivar ivar = NULL;
        for (Class cls = [controller class]; cls && !ivar; cls = class_getSuperclass(cls)) {
            ivar = class_getInstanceVariable(cls, name.UTF8String);
        }
        if (ivar) {
            id manager = object_getIvar(controller, ivar);
            if (manager) return manager;
        }
    }
    for (NSString *key in @[@"m_tableViewMgr", @"tableViewMgr", @"m_tableMgr", @"tableMgr"]) {
        @try {
            id manager = [controller valueForKey:key];
            if (manager) return manager;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

void WCAtlasInstallSettingsFallbackEntry(id settingsController) {
    if (!settingsController || WCAtlasExternalPluginManagerAvailable() ||
        WCAtlasInstallPluginRegistry()) return;

    id tableManager = WCPSettingsTableManager(settingsController);
    SEL sectionSelector = NSSelectorFromString(@"getSectionAt:");
    if (!tableManager || ![tableManager respondsToSelector:sectionSelector]) return;
    id section = ((id (*)(id, SEL, NSInteger))objc_msgSend)(tableManager, sectionSelector, 0);
    SEL addSelector = NSSelectorFromString(@"addCell:");
    if (!section || ![section respondsToSelector:addSelector]) return;
    // Native reloads rebuild their section objects, so comparing against the section that was
    // used last time never matched and the row was injected again into the new section. That is
    // how the same entry ended up in two different categories. A plain flag on the controller is
    // enough: once this page carries our row, no later rebuild needs another one.
    if (objc_getAssociatedObject(settingsController, &WCPSettingsFallbackAddedKey)) return;

    Class cellClass = NSClassFromString(@"WCTableViewNormalCellManager");
    if (!cellClass) cellClass = NSClassFromString(@"WCTableViewCellManager");
    SEL factory = NSSelectorFromString(@"normalCellForSel:target:title:rightValue:accessoryType:");
    id cell = nil;
    if ([cellClass respondsToSelector:factory]) {
        cell = ((id (*)(id, SEL, SEL, id, NSString *, NSString *, int))objc_msgSend)(
            cellClass, factory, NSSelectorFromString(@"wcatlas_openSettings"),
            settingsController, @"WCAtlas", WCAtlasDisplayVersion, 1);
    }
    if (!cell) return;

    ((void (*)(id, SEL, id))objc_msgSend)(section, addSelector, cell);
    objc_setAssociatedObject(settingsController, &WCPSettingsFallbackAddedKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasLog(@"懒猫插件管理不可用，已注入微信设置页备用入口");
}

void WCAtlasPushSettingsController(id sender) {
    WCAtlasSettingsViewController *controller = [WCAtlasSettingsViewController new];
    controller.hidesBottomBarWhenPushed = YES;
    UINavigationController *navigation = nil;
    Class managerClass = NSClassFromString(@"CAppViewControllerManager");
    SEL currentSelector = NSSelectorFromString(@"getCurrentNavigationController");
    if ([managerClass respondsToSelector:currentSelector]) {
        navigation = ((id (*)(id, SEL))objc_msgSend)(managerClass, currentSelector);
    }
    if (!navigation && [sender isKindOfClass:UIViewController.class]) {
        navigation = [(UIViewController *)sender navigationController];
    }
    WCPPushViewController(navigation, controller, YES);
}