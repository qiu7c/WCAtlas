#import "WCAtlasPluginManager.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasSettingsViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>

NSString *const WCAtlasPluginManagerEnabledKey = @"com.qiu7c.wcatlas.plugin-manager.enabled";

static NSString *const WCPCategoriesKey = @"com.qiu7c.wcatlas.plugin-manager.categories";
static NSString *const WCPCustomCategoriesKey = @"com.qiu7c.wcatlas.plugin-manager.custom-categories";
static NSString *const WCPNamesKey = @"com.qiu7c.wcatlas.plugin-manager.display-names";
static NSString *const WCPVersionsKey = @"com.qiu7c.wcatlas.plugin-manager.display-versions";
static NSString *const WCPOrdersKey = @"com.qiu7c.wcatlas.plugin-manager.order-indexes";
static NSString *const WCPHiddenKey = @"com.qiu7c.wcatlas.plugin-manager.hidden-plugins";
static NSString *const WCPPerPageKey = @"com.qiu7c.wcatlas.plugin-manager.plugins-per-page";
static NSString *const WCPHeaderTitleKey = @"com.qiu7c.wcatlas.plugin-manager.header-title";
static NSString *const WCPHeaderSubtitleKey = @"com.qiu7c.wcatlas.plugin-manager.header-subtitle";
static NSString *const WCPHeaderIconKey = @"com.qiu7c.wcatlas.plugin-manager.header-icon-data";
static NSString *const WCPHeaderIconStyleKey = @"com.qiu7c.wcatlas.plugin-manager.header-icon-style";
static NSString *const WCPHeaderRadiusKey = @"com.qiu7c.wcatlas.plugin-manager.header-icon-radius";
static NSString *const WCPEntryIconStyleKey = @"com.qiu7c.wcatlas.plugin-manager.entry-icon-style";
static NSString *const WCPDidChangeNotification = @"WCAtlasPluginsMgr.RegistryDidChange";
static NSString *const WCPWCAtlasQuickSwitchesKey = @"com.qiu7c.wcatlas.plugin-manager.quick-switches";
static Class WCPRuntimeRegistryClass;
static WCAtlasPluginsMgr *WCPRuntimeRegistryInstance;

static NSArray<NSString *> *WCPPluginIconStyleNames(void) {
    return @[@"微信原生", @"灯泡", @"拼图", @"印章", @"宫格"];
}

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

static NSInteger WCPCurrentHeaderIconStyle(NSUserDefaults *defaults) {
    return [defaults objectForKey:WCPHeaderIconStyleKey]
        ? [defaults integerForKey:WCPHeaderIconStyleKey]
        : 4;
}

static UIImage *WCPHeaderBuiltinPluginIcon(NSInteger style) {
    UIImage *image = WCPBuiltinPluginIcon(style);
    if (style != 0 || !image) return image;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(72.0, 72.0)
                                                                                format:format];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(18.0, 18.0, 36.0, 36.0)];
    }];
}

static UIFont *WCPScaledFont(UIFontTextStyle textStyle, CGFloat size, UIFontWeight weight) {
    UIFont *font = [UIFont systemFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

static UIColor *WCPPluginCardColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? UIColor.secondarySystemGroupedBackgroundColor
                : UIColor.whiteColor;
        }];
    }
    return UIColor.whiteColor;
}

static NSDictionary *WCPDictionary(NSString *key) {
    NSDictionary *value = [NSUserDefaults.standardUserDefaults dictionaryForKey:key];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}
static NSMutableDictionary *WCPMutableDictionary(NSString *key) { return [NSMutableDictionary dictionaryWithDictionary:WCPDictionary(key)]; }
static NSArray *WCPArray(NSString *key) {
    NSArray *value = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSString *WCPIdentifierForModel(WCAtlasPluginModel *model) {
    if (model.isController && model.controller.length) return [@"controller:" stringByAppendingString:model.controller];
    if (!model.isController && model.key.length) return [@"switch:" stringByAppendingString:model.key];
    return [@"title:" stringByAppendingString:model.title ?: @""];
}

static void WCPShow(UIViewController *controller, UIAlertController *alert) {
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) { popover.sourceView = controller.view; popover.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMaxY(controller.view.bounds) - 1.0, 1.0, 1.0); }
    [controller presentViewController:alert animated:YES completion:nil];
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

@class WCAtlasPluginsViewController;

@interface WCPCategoryPillControl : UIControl
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, assign) NSInteger selectedSegmentIndex;
@end

@interface WCPCategoryPillControl ()
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, strong) UIView *selectionView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, copy) NSArray<UIButton *> *buttons;
@property (nonatomic, strong, nullable) NSLayoutConstraint *selectionCenterConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *selectionWidthConstraint;
@end

@implementation WCPCategoryPillControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 20.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;

    self.backdropView = [UIView new];
    self.backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropView.userInteractionEnabled = NO;
    self.backdropView.layer.cornerRadius = 20.0;
    self.backdropView.layer.cornerCurve = kCACornerCurveContinuous;
    self.backdropView.layer.masksToBounds = YES;
    [self addSubview:self.backdropView];

    self.selectionView = [UIView new];
    self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionView.userInteractionEnabled = NO;
    self.selectionView.layer.cornerRadius = 17.0;
    self.selectionView.layer.cornerCurve = kCACornerCurveContinuous;
    self.selectionView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.selectionView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    self.selectionView.layer.shadowRadius = 5.0;
    [self addSubview:self.selectionView];

    self.stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisHorizontal;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.distribution = UIStackViewDistributionFill;
    self.stackView.spacing = 0.0;
    [self addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.backdropView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.backdropView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.backdropView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.backdropView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:3.0],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-3.0],
        [self.stackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:3.0],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3.0],
        [self.selectionView.centerYAnchor constraintEqualToAnchor:self.stackView.centerYAnchor],
        [self.selectionView.heightAnchor constraintEqualToAnchor:self.stackView.heightAnchor],
    ]];
    [self updateColors];
    return self;
}

- (void)setCategories:(NSArray<NSString *> *)categories {
    NSArray<NSString *> *normalized = [categories copy] ?: @[];
    if ([_categories isEqualToArray:normalized]) return;
    _categories = normalized;
    for (UIButton *button in self.buttons) {
        [self.stackView removeArrangedSubview:button];
        [button removeFromSuperview];
    }

    NSMutableArray<UIButton *> *buttons = [NSMutableArray arrayWithCapacity:_categories.count];
    [_categories enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, __unused BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = (NSInteger)index;
        button.titleLabel.font = WCPScaledFont(UIFontTextStyleSubheadline, 14.0, UIFontWeightRegular);
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.72;
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 22.0, 0.0, 22.0);
        [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [button setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                               forAxis:UILayoutConstraintAxisHorizontal];
        button.accessibilityLabel = title;
        [button setTitle:title forState:UIControlStateNormal];
        [button addTarget:self action:@selector(categoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:button];
        [buttons addObject:button];
    }];
    self.buttons = buttons;
    if (_categories.count == 0) {
        _selectedSegmentIndex = UISegmentedControlNoSegment;
    } else if (_selectedSegmentIndex < 0 || _selectedSegmentIndex >= (NSInteger)_categories.count) {
        _selectedSegmentIndex = 0;
    }
    [self updateSelectionAnimated:NO];
}

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex {
    if (self.categories.count == 0) {
        _selectedSegmentIndex = UISegmentedControlNoSegment;
    } else {
        _selectedSegmentIndex = MAX(0, MIN(selectedSegmentIndex, (NSInteger)self.categories.count - 1));
    }
    [self updateSelectionAnimated:NO];
}

- (void)categoryButtonTapped:(UIButton *)button {
    if (button.tag == self.selectedSegmentIndex) return;
    _selectedSegmentIndex = button.tag;
    [self updateSelectionAnimated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)updateSelectionAnimated:(BOOL)animated {
    BOOL hasSelection = self.selectedSegmentIndex >= 0 &&
                        self.selectedSegmentIndex < (NSInteger)self.buttons.count;
    self.selectionView.hidden = !hasSelection;
    if (!hasSelection) return;

    UIButton *selectedButton = self.buttons[(NSUInteger)self.selectedSegmentIndex];
    [self layoutIfNeeded];
    [self.selectionCenterConstraint setActive:NO];
    [self.selectionWidthConstraint setActive:NO];
    self.selectionCenterConstraint = [self.selectionView.centerXAnchor constraintEqualToAnchor:selectedButton.centerXAnchor];
    self.selectionWidthConstraint = [self.selectionView.widthAnchor constraintEqualToAnchor:selectedButton.widthAnchor];
    [NSLayoutConstraint activateConstraints:@[self.selectionCenterConstraint, self.selectionWidthConstraint]];

    void (^changes)(void) = ^{
        [self layoutIfNeeded];
        [self updateButtonAppearance];
    };
    if (animated) {
        [UIView animateWithDuration:0.30
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.25
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)updateButtonAppearance {
    [self.buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, __unused BOOL *stop) {
        BOOL selected = index == (NSUInteger)self.selectedSegmentIndex;
        [button setTitleColor:selected ? UIColor.labelColor : UIColor.secondaryLabelColor
                    forState:UIControlStateNormal];
        button.titleLabel.font = WCPScaledFont(UIFontTextStyleSubheadline,
                                               14.0,
                                               selected ? UIFontWeightSemibold : UIFontWeightRegular);
        button.accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected
                                              : UIAccessibilityTraitButton;
    }];
}

- (void)updateColors {
    self.backdropView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.09]
            : [UIColor colorWithWhite:0.48 alpha:0.10];
    }];
    self.selectionView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIColor.tertiarySystemGroupedBackgroundColor
            : UIColor.whiteColor;
    }];
    self.selectionView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.28 : 0.12;
    [self updateButtonAppearance];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateColors];
        }
    }
}

@end

@interface WCPCategoryOrderEditorController : WCAtlasCardTableViewController
- (instancetype)initWithOwner:(WCAtlasPluginsViewController *)owner;
@end

@interface WCAtlasPluginsViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSArray<WCAtlasPluginModel *> *allVisibleModels;
@property (nonatomic, copy) NSArray<WCAtlasPluginModel *> *pageModels;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *currentCategory;
@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, strong) UIImageView *heroIcon;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;
@property (nonatomic, strong) WCPCategoryPillControl *categoryControl;
- (NSString *)identifierForModel:(WCAtlasPluginModel *)model;
- (NSString *)displayNameForModel:(WCAtlasPluginModel *)model;
- (NSString *)displayVersionForModel:(WCAtlasPluginModel *)model;
- (NSString *)categoryForModel:(WCAtlasPluginModel *)model;
- (BOOL)isPluginHidden:(WCAtlasPluginModel *)model;
- (void)setPluginHidden:(BOOL)hidden forModel:(WCAtlasPluginModel *)model;
- (void)reloadTableData;
- (void)buildHeader;
- (void)registryChanged:(NSNotification *)note;
- (void)reloadCategories;
- (void)categoryChanged:(WCPCategoryPillControl *)sender;
- (void)switchChanged:(UISwitch *)sender;
- (void)rowLongPressed:(UILongPressGestureRecognizer *)gesture;
- (void)headerLongPressed:(UILongPressGestureRecognizer *)gesture;
- (void)presentSettingsMenu;
- (void)previousPage;
- (void)nextPage;
- (void)updateHeader;
- (void)manageCategories;
- (void)editCategoryOrder;
- (void)editCategory:(nullable NSString *)oldName;
- (void)deleteCurrentCategory;
- (void)editPerPage;
- (void)editHeaderText;
- (void)editHeaderIcon;
- (void)editHeaderRadius;
- (void)confirmReset;
- (void)editModel:(WCAtlasPluginModel *)model;
- (void)editOrderForModel:(WCAtlasPluginModel *)model;
- (void)chooseCategory:(WCAtlasPluginModel *)model;
- (void)editEntryIcon;
- (void)updatePaginationFooter;
@end

@implementation WCAtlasPluginsViewController
- (instancetype)init { return [self initWithStyle:UITableViewStyleInsetGrouped]; }
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.hidesBottomBarWhenPushed = YES;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"插件"; self.currentPage = 0;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(presentSettingsMenu)];
    self.tableView.rowHeight = 56.0; self.tableView.estimatedRowHeight = 56.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self buildHeader];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(registryChanged:) name:WCPDidChangeNotification object:nil];
    [self reloadTableData];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadTableData]; }
- (void)registryChanged:(NSNotification *)note { dispatch_async(dispatch_get_main_queue(), ^{ [self reloadTableData]; }); }

- (void)buildHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 270.0)]; header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.heroIcon = [UIImageView new]; self.heroIcon.translatesAutoresizingMaskIntoConstraints = NO; self.heroIcon.contentMode = UIViewContentModeScaleAspectFill; self.heroIcon.clipsToBounds = YES; [header addSubview:self.heroIcon];
    self.heroTitle = [UILabel new]; self.heroTitle.translatesAutoresizingMaskIntoConstraints = NO; self.heroTitle.font = WCPScaledFont(UIFontTextStyleHeadline, 19.0, UIFontWeightSemibold); self.heroTitle.adjustsFontForContentSizeCategory = YES; self.heroTitle.textAlignment = NSTextAlignmentCenter; [header addSubview:self.heroTitle];
    self.heroSubtitle = [UILabel new]; self.heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO; self.heroSubtitle.font = WCPScaledFont(UIFontTextStyleSubheadline, 14.0, UIFontWeightRegular); self.heroSubtitle.adjustsFontForContentSizeCategory = YES; self.heroSubtitle.textColor = UIColor.secondaryLabelColor; self.heroSubtitle.textAlignment = NSTextAlignmentCenter; [header addSubview:self.heroSubtitle];
    self.categoryControl = [WCPCategoryPillControl new]; [self.categoryControl addTarget:self action:@selector(categoryChanged:) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.categoryControl];
    [header addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(headerLongPressed:)]];
    [NSLayoutConstraint activateConstraints:@[
        [self.heroIcon.centerXAnchor constraintEqualToAnchor:header.centerXAnchor], [self.heroIcon.topAnchor constraintEqualToAnchor:header.topAnchor constant:24], [self.heroIcon.widthAnchor constraintEqualToConstant:72], [self.heroIcon.heightAnchor constraintEqualToConstant:72],
        [self.heroTitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:header.leadingAnchor constant:24], [self.heroTitle.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-24], [self.heroTitle.centerXAnchor constraintEqualToAnchor:header.centerXAnchor], [self.heroTitle.topAnchor constraintEqualToAnchor:self.heroIcon.bottomAnchor constant:12],
        [self.heroSubtitle.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:28], [self.heroSubtitle.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-28], [self.heroSubtitle.topAnchor constraintEqualToAnchor:self.heroTitle.bottomAnchor constant:8],
        [self.categoryControl.centerXAnchor constraintEqualToAnchor:header.centerXAnchor], [self.categoryControl.leadingAnchor constraintGreaterThanOrEqualToAnchor:header.leadingAnchor constant:20], [self.categoryControl.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-20], [self.categoryControl.topAnchor constraintEqualToAnchor:self.heroSubtitle.bottomAnchor constant:24], [self.categoryControl.heightAnchor constraintEqualToConstant:40]
    ]];
    self.tableView.tableHeaderView = header; [self updateHeader];
}
- (void)updateHeader {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.heroTitle.text = [defaults stringForKey:WCPHeaderTitleKey] ?: @"Plug-in";
    self.heroSubtitle.text = [defaults stringForKey:WCPHeaderSubtitleKey] ?: @"万事皆有可能";
    NSData *data = [defaults dataForKey:WCPHeaderIconKey];
    NSInteger iconStyle = WCPCurrentHeaderIconStyle(defaults);
    self.heroIcon.image = data.length ? [UIImage imageWithData:data] : WCPHeaderBuiltinPluginIcon(iconStyle);
    self.heroIcon.contentMode = data.length ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleAspectFit;
    self.heroIcon.tintColor = UIColor.systemGreenColor;
    CGFloat radius = [defaults objectForKey:WCPHeaderRadiusKey] ? [defaults doubleForKey:WCPHeaderRadiusKey] : 12; self.heroIcon.layer.cornerRadius = MIN(44, MAX(0, radius));
}
- (NSString *)identifierForModel:(WCAtlasPluginModel *)model {
    if (model.isController && model.controller.length) return [@"controller:" stringByAppendingString:model.controller];
    if (!model.isController && model.key.length) return [@"switch:" stringByAppendingString:model.key];
    return [@"title:" stringByAppendingString:model.title ?: @""];
}
- (NSString *)displayNameForModel:(WCAtlasPluginModel *)model { return WCPDictionary(WCPNamesKey)[[self identifierForModel:model]] ?: model.title ?: @"插件"; }
- (NSString *)displayVersionForModel:(WCAtlasPluginModel *)model { return WCPDictionary(WCPVersionsKey)[[self identifierForModel:model]] ?: model.version ?: @""; }
- (NSString *)categoryForModel:(WCAtlasPluginModel *)model {
    NSString *stored = WCPDictionary(WCPCategoriesKey)[[self identifierForModel:model]];
    if ([self.categories containsObject:stored]) return stored;
    BOOL isWCAtlas = (model.isController && [model.controller isEqualToString:@"WCAtlasSettingsViewController"]) ||
                   (!model.isController && [model.key hasPrefix:@"com.qiu7c.wcatlas."]);
    NSString *preferred = isWCAtlas ? @"定制" : @"功能";
    if ([self.categories containsObject:preferred]) return preferred;
    return self.categories.firstObject ?: preferred;
}
- (BOOL)isPluginHidden:(WCAtlasPluginModel *)model { return [WCPArray(WCPHiddenKey) containsObject:[self identifierForModel:model]]; }
- (void)setPluginHidden:(BOOL)hidden forModel:(WCAtlasPluginModel *)model {
    NSMutableArray *items = [NSMutableArray arrayWithArray:WCPArray(WCPHiddenKey)]; NSString *identifier = [self identifierForModel:model]; [items removeObject:identifier]; if (hidden) [items addObject:identifier]; [NSUserDefaults.standardUserDefaults setObject:items forKey:WCPHiddenKey]; [self reloadTableData];
}
- (void)reloadCategories {
    NSArray *defaults = @[@"定制", @"功能"]; NSMutableArray *saved = [NSMutableArray array];
    for (id category in WCPArray(WCPCustomCategoriesKey)) if ([category isKindOfClass:NSString.class] && [category length] && ![saved containsObject:category]) [saved addObject:category];
    NSArray *categories = saved.count > 0 ? saved : defaults; self.categories = categories; if (![categories containsObject:self.currentCategory]) self.currentCategory = categories.firstObject;
    if (self.categoryControl) {
        self.categoryControl.categories = categories;
        NSInteger selectedIndex = [categories indexOfObject:self.currentCategory];
        if (self.categoryControl.selectedSegmentIndex != selectedIndex) {
            self.categoryControl.selectedSegmentIndex = selectedIndex;
        }
    }
}
- (void)reloadTableData {
    [self reloadCategories]; NSArray *models; @synchronized (WCAtlasPluginsMgr.sharedInstance) { models = [WCAtlasPluginsMgr.sharedInstance.plugins copy]; }
    NSMutableArray *filtered = [NSMutableArray array]; for (WCAtlasPluginModel *model in models) if (![self isPluginHidden:model] && [[self categoryForModel:model] isEqualToString:self.currentCategory]) [filtered addObject:model];
    NSDictionary *orders = WCPDictionary(WCPOrdersKey); [filtered sortUsingComparator:^NSComparisonResult(WCAtlasPluginModel *left, WCAtlasPluginModel *right) { NSNumber *l = orders[[self identifierForModel:left]], *r = orders[[self identifierForModel:right]]; if (l && r && l.integerValue != r.integerValue) return l.integerValue < r.integerValue ? NSOrderedAscending : NSOrderedDescending; if (l) return NSOrderedAscending; if (r) return NSOrderedDescending; return [[self displayNameForModel:left] localizedCompare:[self displayNameForModel:right]]; }];
    self.allVisibleModels = filtered; NSUInteger perPage = MAX(1, [NSUserDefaults.standardUserDefaults integerForKey:WCPPerPageKey] ?: 10); NSUInteger pages = MAX((NSUInteger)1, (filtered.count + perPage - 1) / perPage); if (self.currentPage >= pages) self.currentPage = pages - 1; NSUInteger start = MIN(self.currentPage * perPage, filtered.count); NSUInteger length = MIN(perPage, filtered.count - start); self.pageModels = length ? [filtered subarrayWithRange:NSMakeRange(start, length)] : @[]; [self updateHeader]; [self updatePaginationFooter]; [self.tableView reloadData];
}
- (void)categoryChanged:(WCPCategoryPillControl *)sender { if (sender.selectedSegmentIndex < 0 || sender.selectedSegmentIndex >= (NSInteger)self.categories.count) return; self.currentCategory = self.categories[sender.selectedSegmentIndex]; self.currentPage = 0; [self reloadTableData]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.pageModels.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return self.allVisibleModels.count ? nil : @"暂无已注册的插件"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PluginValueCell"]; if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PluginValueCell"];
    WCAtlasPluginModel *model = self.pageModels[indexPath.row]; cell.textLabel.text = [self displayNameForModel:model]; cell.textLabel.font = WCPScaledFont(UIFontTextStyleBody, 16.0, UIFontWeightRegular); cell.textLabel.adjustsFontForContentSizeCategory = YES; NSString *version = [self displayVersionForModel:model]; cell.detailTextLabel.text = version.length ? version : nil; cell.detailTextLabel.font = WCPScaledFont(UIFontTextStyleSubheadline, 15.0, UIFontWeightRegular); cell.detailTextLabel.adjustsFontForContentSizeCategory = YES; cell.imageView.image = nil;
    BOOL firstRow = indexPath.row == 0;
    BOOL lastRow = indexPath.row + 1 == (NSInteger)self.pageModels.count;
    CACornerMask corners = 0;
    if (firstRow) corners |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (lastRow) corners |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    UIView *cardBackground = [UIView new];
    cardBackground.backgroundColor = WCPPluginCardColor();
    cardBackground.layer.cornerRadius = (firstRow || lastRow) ? 16.0 : 0.0;
    cardBackground.layer.cornerCurve = kCACornerCurveContinuous;
    cardBackground.layer.maskedCorners = corners;
    cell.backgroundColor = UIColor.clearColor;
    cell.backgroundView = cardBackground;
    UIView *selectedBackground = [UIView new];
    selectedBackground.backgroundColor = UIColor.secondarySystemFillColor;
    selectedBackground.layer.cornerRadius = cardBackground.layer.cornerRadius;
    selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    selectedBackground.layer.maskedCorners = corners;
    cell.selectedBackgroundView = selectedBackground;
    if (model.isController) { cell.accessoryView = nil; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; } else { UISwitch *toggle = [UISwitch new]; toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:model.key]; toggle.tag = indexPath.row; [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle; cell.accessoryType = UITableViewCellAccessoryNone; }
    if (!cell.gestureRecognizers.count) [cell addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rowLongPressed:)]]; return cell;
}
- (void)switchChanged:(UISwitch *)sender { if (sender.tag < 0 || sender.tag >= (NSInteger)self.pageModels.count) return; WCAtlasPluginModel *model = self.pageModels[sender.tag]; if (!model.isController && model.key.length) { [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:model.key]; WCAtlasSettingsHandleSwitchChange(model.key, sender.on); } }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.pageModels.count) return;
    WCAtlasPluginModel *model = self.pageModels[indexPath.row];
    if (!model.isController) return;
    Class cls = NSClassFromString(model.controller);
    if (!cls || ![cls isSubclassOfClass:UIViewController.class]) {
        WCAtlasLog(@"插件管理：控制器不可用，controller=%@", model.controller ?: @"");
        return;
    }
    UIViewController *controller = [cls new];
    controller.hidesBottomBarWhenPushed = YES;
    WCAtlasLog(@"插件管理：打开 %@，controller=%@ navigation=%@",
             [self displayNameForModel:model], model.controller, NSStringFromClass(self.navigationController.class));
    if (!WCPPushViewController(self.navigationController, controller, YES)) {
        WCAtlasLog(@"插件管理：页面入栈失败，controller=%@", model.controller);
    }
}
- (void)headerLongPressed:(UILongPressGestureRecognizer *)gesture { if (gesture.state == UIGestureRecognizerStateBegan) [self presentSettingsMenu]; }
- (void)rowLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return; NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]]; if (!path) return; WCAtlasPluginModel *model = self.pageModels[path.row]; UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[self displayNameForModel:model] message:nil preferredStyle:UIAlertControllerStyleActionSheet]; __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"修改插件信息" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editModel:model]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:@"修改排序序号" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editOrderForModel:model]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:@"选择收纳位置" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf chooseCategory:model]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:@"隐藏此项目" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [weakSelf setPluginHidden:YES forModel:model]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}
- (void)editModel:(WCAtlasPluginModel *)model {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改插件信息" message:nil preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"插件名字"; field.text = [self displayNameForModel:model]; }]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"版本号"; field.text = [self displayVersionForModel:model]; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { NSString *identifier = [weakSelf identifierForModel:model]; NSMutableDictionary *names = WCPMutableDictionary(WCPNamesKey), *versions = WCPMutableDictionary(WCPVersionsKey); NSString *name = [alert.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet], *version = [alert.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (name.length) names[identifier] = name; else [names removeObjectForKey:identifier]; if (version.length) versions[identifier] = version; else [versions removeObjectForKey:identifier]; [NSUserDefaults.standardUserDefaults setObject:names forKey:WCPNamesKey]; [NSUserDefaults.standardUserDefaults setObject:versions forKey:WCPVersionsKey]; [weakSelf reloadTableData]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)editOrderForModel:(WCAtlasPluginModel *)model {
    NSUInteger count = self.allVisibleModels.count; NSDictionary *orders = WCPDictionary(WCPOrdersKey); NSInteger current = [orders[[self identifierForModel:model]] integerValue] + 1; if (current <= 0) current = [self.allVisibleModels indexOfObject:model] + 1; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改排序序号" message:[NSString stringWithFormat:@"当前分类共 %lu 个插件", (unsigned long)count] preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"序号"; field.keyboardType = UIKeyboardTypeNumberPad; field.text = [NSString stringWithFormat:@"%ld", (long)current]; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self; [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { NSInteger value = MIN((NSInteger)MAX(count, (NSUInteger)1), MAX(1, alert.textFields.firstObject.text.integerValue)); NSMutableDictionary *updated = WCPMutableDictionary(WCPOrdersKey); updated[[weakSelf identifierForModel:model]] = @(value - 1); [NSUserDefaults.standardUserDefaults setObject:updated forKey:WCPOrdersKey]; [weakSelf reloadTableData]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)chooseCategory:(WCAtlasPluginModel *)model {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择收纳位置" message:nil preferredStyle:UIAlertControllerStyleActionSheet]; __weak typeof(self) weakSelf = self; for (NSString *category in self.categories) [sheet addAction:[UIAlertAction actionWithTitle:category style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { NSMutableDictionary *mapping = WCPMutableDictionary(WCPCategoriesKey); mapping[[weakSelf identifierForModel:model]] = category; [NSUserDefaults.standardUserDefaults setObject:mapping forKey:WCPCategoriesKey]; [weakSelf reloadTableData]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}

- (void)updatePaginationFooter {
    NSUInteger perPage = MAX(1, [NSUserDefaults.standardUserDefaults integerForKey:WCPPerPageKey] ?: 10);
    NSUInteger pages = MAX((NSUInteger)1, (self.allVisibleModels.count + perPage - 1) / perPage);
    if (pages <= 1) { self.tableView.tableFooterView = nil; return; }
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 52)]; footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIButton *previous = [UIButton buttonWithType:UIButtonTypeSystem]; previous.frame = CGRectMake(18, 6, 88, 40); previous.autoresizingMask = UIViewAutoresizingFlexibleRightMargin; [previous setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal]; [previous setTitle:@" 上一页" forState:UIControlStateNormal]; previous.enabled = self.currentPage > 0; [previous addTarget:self action:@selector(previousPage) forControlEvents:UIControlEventTouchUpInside]; [footer addSubview:previous];
    UIButton *next = [UIButton buttonWithType:UIButtonTypeSystem]; next.frame = CGRectMake(footer.bounds.size.width - 106, 6, 88, 40); next.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin; [next setTitle:@"下一页 " forState:UIControlStateNormal]; [next setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal]; next.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft; next.enabled = self.currentPage + 1 < pages; [next addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside]; [footer addSubview:next]; self.tableView.tableFooterView = footer;
}
- (void)previousPage { if (self.currentPage == 0) return; self.currentPage--; [self reloadTableData]; }
- (void)nextPage { NSUInteger perPage = MAX(1, [NSUserDefaults.standardUserDefaults integerForKey:WCPPerPageKey] ?: 10); NSUInteger pages = MAX((NSUInteger)1, (self.allVisibleModels.count + perPage - 1) / perPage); if (self.currentPage + 1 >= pages) return; self.currentPage++; [self reloadTableData]; }

- (void)presentSettingsMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"设置" message:@"管理插件分类、顺序与页面外观" preferredStyle:UIAlertControllerStyleActionSheet]; __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"管理分类" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf manageCategories]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"编辑插件顺序" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf.navigationController pushViewController:[[WCPPluginOrderEditorController alloc] initWithOwner:weakSelf] animated:YES]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"每页插件数量" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editPerPage]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"顶部文字" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editHeaderText]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"顶部图标" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editHeaderIcon]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"入口图标" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editEntryIcon]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"清空配置" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [weakSelf confirmReset]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}
- (void)manageCategories {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"管理分类" message:nil preferredStyle:UIAlertControllerStyleActionSheet]; __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"新增分类" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editCategory:nil]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"修改当前名称" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editCategory:weakSelf.currentCategory]; }]];
    if (self.categories.count > 1) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"调整分类顺序" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editCategoryOrder]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"删除当前分类" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [weakSelf deleteCurrentCategory]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}
- (void)editCategoryOrder {
    WCPCategoryOrderEditorController *controller = [[WCPCategoryOrderEditorController alloc] initWithOwner:self];
    [self.navigationController pushViewController:controller animated:YES];
}
- (void)editCategory:(nullable NSString *)oldName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:oldName ? @"修改分类名称" : @"新增分类" message:nil preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"分类名称"; field.text = oldName; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:oldName ? @"保存" : @"新增" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length) return;
        NSMutableArray *categories = [weakSelf.categories mutableCopy] ?: [NSMutableArray array];
        NSUInteger oldIndex = oldName ? [categories indexOfObject:oldName] : NSNotFound;
        NSUInteger existingIndex = [categories indexOfObject:name];
        if (existingIndex != NSNotFound && existingIndex != oldIndex) {
            UIAlertController *duplicate = [UIAlertController alertControllerWithTitle:@"名称已存在" message:@"请换一个分类名称。" preferredStyle:UIAlertControllerStyleAlert];
            [duplicate addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentViewController:duplicate animated:YES completion:nil]; });
            return;
        }
        NSMutableDictionary *mapping = WCPMutableDictionary(WCPCategoriesKey);
        if (oldIndex != NSNotFound) {
            NSArray *models = [WCAtlasPluginsMgr.sharedInstance.plugins copy];
            for (WCAtlasPluginModel *model in models) {
                if ([[weakSelf categoryForModel:model] isEqualToString:oldName]) mapping[[weakSelf identifierForModel:model]] = name;
            }
            categories[oldIndex] = name;
        } else {
            [categories addObject:name];
        }
        [NSUserDefaults.standardUserDefaults setObject:categories forKey:WCPCustomCategoriesKey];
        [NSUserDefaults.standardUserDefaults setObject:mapping forKey:WCPCategoriesKey];
        weakSelf.currentCategory = name;
        [weakSelf reloadTableData];
    }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)deleteCurrentCategory {
    if (self.categories.count <= 1) return;
    NSString *deleted = self.currentCategory;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"删除当前分类？" message:@"分类中的插件会移动到相邻分类。" preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSMutableArray *categories = [weakSelf.categories mutableCopy];
        NSUInteger deletedIndex = [categories indexOfObject:deleted];
        if (deletedIndex == NSNotFound || categories.count <= 1) return;
        [categories removeObjectAtIndex:deletedIndex];
        NSString *destination = categories[MIN(deletedIndex, categories.count - 1)];
        NSMutableDictionary *mapping = WCPMutableDictionary(WCPCategoriesKey);
        NSArray *models = [WCAtlasPluginsMgr.sharedInstance.plugins copy];
        for (WCAtlasPluginModel *model in models) {
            if ([[weakSelf categoryForModel:model] isEqualToString:deleted]) mapping[[weakSelf identifierForModel:model]] = destination;
        }
        [NSUserDefaults.standardUserDefaults setObject:categories forKey:WCPCustomCategoriesKey];
        [NSUserDefaults.standardUserDefaults setObject:mapping forKey:WCPCategoriesKey];
        weakSelf.currentCategory = destination;
        weakSelf.currentPage = 0;
        [weakSelf reloadTableData];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
- (void)editPerPage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"每页插件数量" message:@"超过数量后在底部翻页" preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.keyboardType = UIKeyboardTypeNumberPad; field.placeholder = @"10"; field.text = [NSString stringWithFormat:@"%ld", (long)([NSUserDefaults.standardUserDefaults integerForKey:WCPPerPageKey] ?: 10)]; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self; [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { NSInteger value = MIN(100, MAX(1, alert.textFields.firstObject.text.integerValue)); [NSUserDefaults.standardUserDefaults setInteger:value forKey:WCPPerPageKey]; weakSelf.currentPage = 0; [weakSelf reloadTableData]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)editHeaderText {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"顶部文字" message:nil preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Plug-in"; field.text = self.heroTitle.text; }]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"万事皆有可能"; field.text = self.heroSubtitle.text; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self; [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [NSUserDefaults.standardUserDefaults setObject:alert.textFields[0].text ?: @"" forKey:WCPHeaderTitleKey]; [NSUserDefaults.standardUserDefaults setObject:alert.textFields[1].text ?: @"" forKey:WCPHeaderSubtitleKey]; [weakSelf updateHeader]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)editHeaderIcon {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"顶部图标" message:nil preferredStyle:UIAlertControllerStyleActionSheet]; __weak typeof(self) weakSelf = self;
    BOOL hasCustomImage = [NSUserDefaults.standardUserDefaults dataForKey:WCPHeaderIconKey].length > 0;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        NSString *customTitle = hasCustomImage ? @"✓  从相册自定义" : @"从相册自定义";
        [sheet addAction:[UIAlertAction actionWithTitle:customTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { UIImagePickerController *picker = [UIImagePickerController new]; picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary; picker.delegate = weakSelf; [weakSelf presentViewController:picker animated:YES completion:nil]; }]];
    }
    NSArray<NSString *> *names = WCPPluginIconStyleNames();
    NSInteger current = WCPCurrentHeaderIconStyle(NSUserDefaults.standardUserDefaults);
    for (NSUInteger index = 0; index < names.count; index++) {
        NSString *title = !hasCustomImage && index == (NSUInteger)MAX(current, 0)
            ? [@"✓  " stringByAppendingString:names[index]] : names[index];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:WCPHeaderIconKey];
            [NSUserDefaults.standardUserDefaults setInteger:index forKey:WCPHeaderIconStyleKey];
            [weakSelf updateHeader];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"圆角度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf editHeaderRadius]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}
- (void)editEntryIcon {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"入口图标" message:@"更改后重新进入“我”页生效" preferredStyle:UIAlertControllerStyleActionSheet]; NSArray *names = WCPPluginIconStyleNames(); NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:WCPEntryIconStyleKey]; for (NSUInteger index = 0; index < names.count; index++) { NSString *title = index == (NSUInteger)MAX(current, 0) ? [@"✓  " stringByAppendingString:names[index]] : names[index]; [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [NSUserDefaults.standardUserDefaults setInteger:index forKey:WCPEntryIconStyleKey]; }]]; } [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; WCPShow(self, sheet);
}
- (void)editHeaderRadius {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"图标圆角度" message:@"范围 0 - 20" preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.keyboardType = UIKeyboardTypeDecimalPad; field.text = [NSString stringWithFormat:@"%.0f", self.heroIcon.layer.cornerRadius]; }]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self; [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [NSUserDefaults.standardUserDefaults setDouble:MIN(20, MAX(0, alert.textFields.firstObject.text.doubleValue)) forKey:WCPHeaderRadiusKey]; [weakSelf updateHeader]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info { UIImage *image = info[UIImagePickerControllerOriginalImage]; NSData *data = image ? UIImageJPEGRepresentation(image, 0.86) : nil; if (data) [NSUserDefaults.standardUserDefaults setObject:data forKey:WCPHeaderIconKey]; [picker dismissViewControllerAnimated:YES completion:^{ [self updateHeader]; }]; }
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }
- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空配置" message:@"恢复顶部文案、图标、分类、排序和分页设置" preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; __weak typeof(self) weakSelf = self; [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { for (NSString *key in @[WCPCategoriesKey, WCPCustomCategoriesKey, WCPNamesKey, WCPVersionsKey, WCPOrdersKey, WCPHiddenKey, WCPPerPageKey, WCPHeaderTitleKey, WCPHeaderSubtitleKey, WCPHeaderIconKey, WCPHeaderIconStyleKey, WCPHeaderRadiusKey, WCPEntryIconStyleKey]) [NSUserDefaults.standardUserDefaults removeObjectForKey:key]; weakSelf.currentCategory = @"定制"; weakSelf.currentPage = 0; [weakSelf reloadTableData]; }]]; [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface WCPCategoryOrderEditorController ()
@property (nonatomic, weak) WCAtlasPluginsViewController *owner;
@property (nonatomic, strong) NSMutableArray<NSString *> *items;
@end

@implementation WCPCategoryOrderEditorController

- (instancetype)initWithOwner:(WCAtlasPluginsViewController *)owner {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _owner = owner;
        _items = [owner.categories mutableCopy] ?: [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"分类顺序";
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self setEditing:YES animated:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSUserDefaults.standardUserDefaults setObject:self.items forKey:WCPCustomCategoriesKey];
    [self.owner reloadTableData];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.items.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    return @"拖动右侧手柄调整分类显示顺序。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryOrderCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CategoryOrderCell"];
    cell.textLabel.text = self.items[indexPath.row];
    cell.showsReorderControl = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (BOOL)tableView:(__unused UITableView *)tableView canMoveRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(__unused UITableView *)tableView canEditRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(__unused UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.row == destinationIndexPath.row) return;
    NSString *item = self.items[sourceIndexPath.row];
    [self.items removeObjectAtIndex:sourceIndexPath.row];
    [self.items insertObject:item atIndex:destinationIndexPath.row];
    [NSUserDefaults.standardUserDefaults setObject:self.items forKey:WCPCustomCategoriesKey];
}

@end

@interface WCPPluginOrderEditorController ()
@property (nonatomic, weak) WCAtlasPluginsViewController *owner;
@property (nonatomic, strong) NSMutableArray<WCAtlasPluginModel *> *shown;
@property (nonatomic, strong) NSMutableArray<WCAtlasPluginModel *> *hidden;
- (void)reloadModels;
@end

@implementation WCPPluginOrderEditorController
- (instancetype)initWithOwner:(WCAtlasPluginsViewController *)owner { self = [super initWithStyle:UITableViewStyleInsetGrouped]; if (self) _owner = owner; return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"编辑插件顺序"; self.navigationItem.rightBarButtonItem = self.editButtonItem; self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; [self reloadModels]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.owner reloadTableData]; }
- (void)reloadModels { self.shown = [NSMutableArray array]; self.hidden = [NSMutableArray array]; NSArray *models = [WCAtlasPluginsMgr.sharedInstance.plugins copy]; NSDictionary *orders = WCPDictionary(WCPOrdersKey); models = [models sortedArrayUsingComparator:^NSComparisonResult(WCAtlasPluginModel *left, WCAtlasPluginModel *right) { NSNumber *l = orders[[self.owner identifierForModel:left]], *r = orders[[self.owner identifierForModel:right]]; if (l && r && l.integerValue != r.integerValue) return l.integerValue < r.integerValue ? NSOrderedAscending : NSOrderedDescending; if (l) return NSOrderedAscending; if (r) return NSOrderedDescending; return [[self.owner displayNameForModel:left] localizedCompare:[self.owner displayNameForModel:right]]; }]; for (WCAtlasPluginModel *model in models) { if (![[self.owner categoryForModel:model] isEqualToString:self.owner.currentCategory]) continue; if ([self.owner isPluginHidden:model]) [self.hidden addObject:model]; else [self.shown addObject:model]; } [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? self.shown.count : self.hidden.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"当前显示" : @"已隐藏的插件"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path { UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OrderCell"]; if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"OrderCell"]; WCAtlasPluginModel *model = path.section == 0 ? self.shown[path.row] : self.hidden[path.row]; cell.textLabel.text = [self.owner displayNameForModel:model]; cell.detailTextLabel.text = [self.owner displayVersionForModel:model]; cell.showsReorderControl = path.section == 0; cell.accessoryType = path.section == 1 ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone; return cell; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return path.section == 0; }
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination { if (source.section || destination.section) return; WCAtlasPluginModel *model = self.shown[source.row]; [self.shown removeObjectAtIndex:source.row]; [self.shown insertObject:model atIndex:destination.row]; NSMutableDictionary *orders = WCPMutableDictionary(WCPOrdersKey); [self.shown enumerateObjectsUsingBlock:^(WCAtlasPluginModel *item, NSUInteger idx, BOOL *stop) { orders[[self.owner identifierForModel:item]] = @(idx); }]; [NSUserDefaults.standardUserDefaults setObject:orders forKey:WCPOrdersKey]; }
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path { return path.section == 0; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path { if (style != UITableViewCellEditingStyleDelete || path.section) return; [self.owner setPluginHidden:YES forModel:self.shown[path.row]]; [self reloadModels]; }
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)path { if (path.section != 1) return; [self.owner setPluginHidden:NO forModel:self.hidden[path.row]]; [self reloadModels]; }
@end

static UIImage *WCPEntryIcon(void) { return WCPBuiltinPluginIcon([NSUserDefaults.standardUserDefaults integerForKey:WCPEntryIconStyleKey]); }

void WCAtlasInstallPluginManagerEntry(id moreViewController) {
    if (!moreViewController) return;
    if (WCAtlasExternalPluginManagerAvailable()) {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
        return;
    }
    if (![NSUserDefaults.standardUserDefaults boolForKey:WCAtlasPluginManagerEnabledKey]) return; id tableManager = nil; @try { tableManager = [moreViewController valueForKey:@"m_tableViewMgr"]; } @catch (__unused NSException *exception) {} if (!tableManager || ![tableManager respondsToSelector:NSSelectorFromString(@"getSectionAt:")]) return; Class cellClass = NSClassFromString(@"WCTableViewCellManager"); UIImage *icon = WCPEntryIcon(); id cell = nil; SEL factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:WithDisclosureIndicator:"); if ([cellClass respondsToSelector:factory]) cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, BOOL))objc_msgSend)(cellClass, factory, @selector(pushPluginController), moreViewController, icon, @"插件", YES); else { factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:pathKey:"); if ([cellClass respondsToSelector:factory]) cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, NSString *))objc_msgSend)(cellClass, factory, @selector(pushPluginController), moreViewController, icon, @"插件", nil); } if (!cell) return; id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(tableManager, NSSelectorFromString(@"getSectionAt:"), 2); if (section && [section respondsToSelector:NSSelectorFromString(@"addCell:")]) ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"addCell:"), cell); id tableView = nil; if ([tableManager respondsToSelector:NSSelectorFromString(@"getTableView")]) tableView = ((id (*)(id, SEL))objc_msgSend)(tableManager, NSSelectorFromString(@"getTableView")); if ([tableView respondsToSelector:@selector(reloadData)]) [tableView reloadData];
}

void WCAtlasPushPluginManager(id sender) {
    WCAtlasPluginsViewController *controller = [WCAtlasPluginsViewController new]; controller.hidesBottomBarWhenPushed = YES; UINavigationController *navigation = nil; Class managerClass = NSClassFromString(@"CAppViewControllerManager"); SEL current = NSSelectorFromString(@"getCurrentNavigationController"); if ([managerClass respondsToSelector:current]) navigation = ((id (*)(id, SEL))objc_msgSend)(managerClass, current); if (!navigation && [sender isKindOfClass:UIViewController.class]) navigation = [(UIViewController *)sender navigationController]; WCPPushViewController(navigation, controller, YES);
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
    // Native reloads normally rebuild their section objects. Remember that exact generation so
    // repeated lifecycle callbacks do not duplicate the row, while a rebuilt model is injectable.
    if (objc_getAssociatedObject(settingsController, &WCPSettingsFallbackAddedKey) == section) return;

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
                             section, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
