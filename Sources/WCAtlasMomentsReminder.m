#import "WCAtlasMomentsReminder.h"
#import "WCAtlasAccount.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInAppNotification.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasRuntimeFeatures.h"
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

static NSString *const WCAtlasMomentsReminderSeenItemsKey = @"com.qiu7c.wcatlas.moments.reminder.seen-items";

static id WCAtlasMomentsReminderService(const char *className) {
    Class contextClass = objc_getClass("MMContext");
    Class serviceClass = objc_getClass(className);
    SEL activeSelector = sel_registerName("activeUserContext");
    SEL serviceSelector = sel_registerName("getService:");
    if (!contextClass || !serviceClass || ![contextClass respondsToSelector:activeSelector]) return nil;
    id context = ((id (*)(id, SEL))objc_msgSend)(contextClass, activeSelector);
    if (!context || ![context respondsToSelector:serviceSelector]) return nil;
    return ((id (*)(id, SEL, Class))objc_msgSend)(context, serviceSelector, serviceClass);
}

static NSString *WCAtlasMomentsReminderLocalUsername(void) {
    Class settingClass = objc_getClass("SettingUtil");
    SEL selector = sel_registerName("getLocalUsrName:");
    if (settingClass && [settingClass respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL, unsigned int))objc_msgSend)(settingClass, selector, 0);
        if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
    }
    return WCAtlasCurrentUserWXID();
}

static NSString *WCAtlasMomentsReminderForwardTarget(void) {
    return [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasMomentsReminderForwardTargetKey] == 1
        ? @"filehelper" : WCAtlasMomentsReminderLocalUsername();
}

static void WCAtlasMomentsReminderSendText(NSString *target, NSString *content) {
    if (target.length == 0 || content.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasPrivateSendTextMessage(target, content); });
}

static void WCAtlasMomentsReminderSendImage(NSString *target, UIImage *image) {
    if (target.length == 0 || !image) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData *data = UIImagePNGRepresentation(image);
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"wcatlas-moments-%@.png", NSUUID.UUID.UUIDString]];
        if (![data writeToFile:path atomically:YES]) return;
        WCAtlasPrivateSendImageMessage(target, path);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        });
    });
}

static void WCAtlasMomentsReminderSendVideo(NSString *target, NSString *path) {
    if (target.length == 0 || path.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:path]) return;
    dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasPrivateSendVideoMessage(target, path); });
}

NSArray<NSString *> *WCAtlasMomentsReminderUsers(void) {
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSet];
    for (id value in [NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasMomentsReminderUsersKey] ?: @[]) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![value hasSuffix:@"@chatroom"]) {
            [users addObject:value];
        }
    }
    return users.array;
}

void WCAtlasMomentsReminderSetUserSelected(NSString *username, BOOL selected) {
    if (username.length == 0 || [username hasSuffix:@"@chatroom"]) return;
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSetWithArray:WCAtlasMomentsReminderUsers()];
    if (selected) [users addObject:username]; else [users removeObject:username];
    [NSUserDefaults.standardUserDefaults setObject:users.array forKey:WCAtlasMomentsReminderUsersKey];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                       object:WCAtlasMomentsReminderUsersKey];
}

static id WCAtlasMomentsReminderObjectValue(id object, const char *selectorName) {
    if (!object || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    Method method = class_getInstanceMethod([object class], selector);
    if (!method || method_getNumberOfArguments(method) != 2) return nil;
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] != '@') return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static uint64_t WCAtlasMomentsReminderIntegerValue(id object, const char *selectorName) {
    if (!object || !selectorName) return 0;
    SEL selector = sel_registerName(selectorName);
    Method method = class_getInstanceMethod([object class], selector);
    if (!method || method_getNumberOfArguments(method) != 2) return 0;
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] == '@') {
        id value = WCAtlasMomentsReminderObjectValue(object, selectorName);
        return [value respondsToSelector:@selector(unsignedLongLongValue)] ? [value unsignedLongLongValue] : 0;
    }
    @try { return ((uint64_t (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return 0; }
}

static NSString *WCAtlasMomentsReminderString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return text.length > 0 ? text : nil;
    }
    return [value respondsToSelector:@selector(stringValue)] ? [value stringValue] : nil;
}

static NSArray *WCAtlasMomentsReminderMediaList(id dataItem) {
    id contentObject = WCAtlasMomentsReminderObjectValue(dataItem, "contentObj");
    id mediaList = WCAtlasMomentsReminderObjectValue(contentObject, "mediaList");
    return [mediaList isKindOfClass:NSArray.class] ? mediaList : @[];
}

static id WCAtlasMomentsReminderFacade(void) {
    return WCAtlasMomentsReminderService("WCFacade");
}

static void WCAtlasMomentsReminderDownloadImage(id mediaItem, NSString *target) {
    id facade = WCAtlasMomentsReminderFacade();
    if (!facade || !mediaItem || target.length == 0) return;
    id manager = nil;
    SEL primarySelector = sel_registerName("downloadImageCdnMgr");
    SEL fallbackSelector = sel_registerName("imageDownloadCdnMgrForCategory:");
    if ([facade respondsToSelector:primarySelector]) {
        manager = ((id (*)(id, SEL))objc_msgSend)(facade, primarySelector);
    } else if ([facade respondsToSelector:fallbackSelector]) {
        manager = ((id (*)(id, SEL, unsigned int))objc_msgSend)(facade, fallbackSelector, 0);
    }
    SEL downloadSelector = sel_registerName("StartDownloadImage:downloadType:needNotify:force:");
    if (!manager || ![manager respondsToSelector:downloadSelector]) return;
    ((void (*)(id, SEL, id, unsigned int, BOOL, BOOL))objc_msgSend)(manager, downloadSelector,
                                                                   mediaItem, 2, NO, YES);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        SEL imageSelector = sel_registerName("imageOfSize:");
        UIImage *image = nil;
        for (NSUInteger attempt = 0; attempt < 180 && !image; attempt++) {
            if ([mediaItem respondsToSelector:imageSelector]) {
                id value = ((id (*)(id, SEL, unsigned int))objc_msgSend)(mediaItem, imageSelector, 2);
                if ([value isKindOfClass:UIImage.class]) image = value;
            }
            if (!image) [NSThread sleepForTimeInterval:1.0];
        }
        if (image) WCAtlasMomentsReminderSendImage(target, image);
        else WCAtlasLog(@"朋友圈图片下载超时");
    });
}

static void WCAtlasMomentsReminderDownloadVideo(id mediaItem, NSString *target) {
    id facade = WCAtlasMomentsReminderFacade();
    if (!facade || !mediaItem || target.length == 0) return;
    id manager = nil;
    SEL primarySelector = sel_registerName("videoDownloadCdnMgrForCategory:");
    SEL fallbackManagerSelector = sel_registerName("downloadCDNMgr");
    if ([facade respondsToSelector:primarySelector]) {
        manager = ((id (*)(id, SEL, unsigned int))objc_msgSend)(facade, primarySelector,
                                                                arc4random_uniform(10));
    } else if ([facade respondsToSelector:fallbackManagerSelector]) {
        manager = ((id (*)(id, SEL))objc_msgSend)(facade, fallbackManagerSelector);
    }
    SEL modeSelector = sel_registerName("StartDownloadVideo:DownloadMode:");
    SEL fallbackSelector = sel_registerName("StartDownloadVideo:");
    if ([manager respondsToSelector:modeSelector]) {
        ((void (*)(id, SEL, id, unsigned int))objc_msgSend)(manager, modeSelector, mediaItem, 1);
    } else if ([manager respondsToSelector:fallbackSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(manager, fallbackSelector, mediaItem);
    } else {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        SEL pathSelector = sel_registerName("getFormatVideoPath");
        NSString *path = nil;
        for (NSUInteger attempt = 0; attempt < 301; attempt++) {
            id value = [mediaItem respondsToSelector:pathSelector]
                ? ((id (*)(id, SEL))objc_msgSend)(mediaItem, pathSelector) : nil;
            if ([value isKindOfClass:NSString.class] && [NSFileManager.defaultManager fileExistsAtPath:value]) {
                path = value;
                break;
            }
            [NSThread sleepForTimeInterval:1.0];
        }
        if (path.length > 0) WCAtlasMomentsReminderSendVideo(target, path);
        else WCAtlasLog(@"朋友圈视频下载超时");
    });
}

static NSString *WCAtlasMomentsReminderContentTypeName(id dataItem) {
    id contentObject = WCAtlasMomentsReminderObjectValue(dataItem, "contentObj");
    uint64_t type = WCAtlasMomentsReminderIntegerValue(contentObject, "type");
    if (type == 1 || type == 54) return @"图片";
    if (type == 15) return @"视频";
    return @"文字";
}

static void WCAtlasMomentsReminderForwardItem(id dataItem, NSString *username, NSString *nickname,
                                            NSString *content, uint64_t createdAt) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsReminderForwardEnabledKey) || !dataItem) return;
    NSString *target = WCAtlasMomentsReminderForwardTarget();
    if (target.length == 0) return;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *name = WCAtlasPrivateNotificationDisplayName(username, nickname);
    NSString *copyText = content.length > 0 ? [NSString stringWithFormat:@"文案: %@", content] : @"";
    NSString *message = [NSString stringWithFormat:@"【朋友圈特别关注】\n好友: %@\n类型: %@\n时间: %@\n%@",
                         name ?: @"", WCAtlasMomentsReminderContentTypeName(dataItem),
                         [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:createdAt]], copyText];
    WCAtlasMomentsReminderSendText(target, message);

    id contentObject = WCAtlasMomentsReminderObjectValue(dataItem, "contentObj");
    uint64_t type = WCAtlasMomentsReminderIntegerValue(contentObject, "type");
    NSArray *mediaList = WCAtlasMomentsReminderMediaList(dataItem);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:WCAtlasMomentsReminderForwardImagesKey] && (type == 1 || type == 54)) {
        for (id mediaItem in mediaList) WCAtlasMomentsReminderDownloadImage(mediaItem, target);
    }
    if ([defaults boolForKey:WCAtlasMomentsReminderForwardVideosKey]) {
        if (type == 15 && mediaList.count > 0) {
            WCAtlasMomentsReminderDownloadVideo(mediaList.firstObject, target);
        } else if (type == 54) {
            for (id mediaItem in mediaList) {
                id liveMedia = WCAtlasMomentsReminderObjectValue(mediaItem, "livePhotoMediaItem");
                if (liveMedia) WCAtlasMomentsReminderDownloadVideo(liveMedia, target);
            }
        }
    }
}

static id WCAtlasMomentsReminderContact(NSString *username) {
    return WCAtlasPrivateContact(username);
}

static void WCAtlasMomentsReminderNotify(NSString *username, NSString *nickname, NSString *content, uint64_t createdAt, NSString *tid) {
    NSString *name = WCAtlasPrivateNotificationDisplayName(username, nickname);
    if (name.length == 0) name = @"好友";
    NSString *body = content.length > 0 ? content : @"发布了新朋友圈";
    if (body.length > 180) body = [[body substringToIndex:177] stringByAppendingString:@"…"];
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        NSString *identifier = [NSString stringWithFormat:@"moments-reminder:%@:%@",
                                  username ?: @"unknown", tid ?: @"unknown"];
        WCAtlasShowInAppNotification(name, body, identifier, @"circle.grid.3x3", ^{
            WCAtlasOpenMomentsTimeline();
        });
        return;
    }
    UNMutableNotificationContent *notification = [UNMutableNotificationContent new];
    notification.title = name;
    notification.body = body;
    notification.sound = UNNotificationSound.defaultSound;
    notification.threadIdentifier = @"wcatlas.moments.reminder";
    notification.userInfo = @{ @"wcatlas": @"moments-reminder", @"username": username ?: @"", @"tid": tid ?: @"" };
    NSString *identifier = [NSString stringWithFormat:@"wcatlas.moments.%@.%@.%llu", username ?: @"unknown", tid ?: @"unknown", createdAt];
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0 repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:notification trigger:trigger];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error) WCAtlasLog(@"发送朋友圈提醒失败：%@", error.localizedDescription ?: @"未知错误");
    }];
}

@interface WCAtlasMomentsReminderManager : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *controllers;
@property (nonatomic, assign) NSTimeInterval lastCheckTime;
@property (nonatomic, assign) BOOL checking;
+ (instancetype)sharedManager;
- (void)tick;
- (void)performCheck;
- (void)settingsDidChange;
@end

@implementation WCAtlasMomentsReminderManager

+ (instancetype)sharedManager {
    static WCAtlasMomentsReminderManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [WCAtlasMomentsReminderManager new];
        manager.controllers = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (NSTimeInterval)checkInterval {
    NSTimeInterval interval = [NSUserDefaults.standardUserDefaults doubleForKey:WCAtlasMomentsReminderIntervalKey];
    return MIN(3600.0, MAX(30.0, interval > 0.0 ? interval : 60.0));
}

- (id)controllerForUsername:(NSString *)username {
    id controller = self.controllers[username];
    if (controller) return controller;
    Class controllerClass = objc_getClass("WCListViewController");
    id contact = WCAtlasMomentsReminderContact(username);
    if (!controllerClass || !contact) return nil;
    controller = [[controllerClass alloc] init];
    SEL setContactSelector = sel_registerName("setM_contact:");
    if (![controller respondsToSelector:setContactSelector]) return nil;
    ((void (*)(id, SEL, id))objc_msgSend)(controller, setContactSelector, contact);
    self.controllers[username] = controller;
    return controller;
}

- (NSArray *)loadItemsForUsername:(NSString *)username success:(BOOL *)success {
    if (success) *success = NO;
    id controller = [self controllerForUsername:username];
    SEL initDataSelector = sel_registerName("initData:");
    Method initDataMethod = controller ? class_getInstanceMethod([controller class], initDataSelector) : NULL;
    const char *initDataEncoding = initDataMethod ? method_getTypeEncoding(initDataMethod) : NULL;
    if (!initDataEncoding || strcmp(initDataEncoding, "v20@0:8B16") != 0) {
        WCAtlasLog(@"读取 %@ 的朋友圈数据失败：initData: ABI 不匹配", username);
        return @[];
    }
    @try {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, initDataSelector, YES);
        id value = [controller valueForKey:@"m_arrPhotoDatas"];
        if (![value isKindOfClass:NSArray.class]) return @[];
        if (success) *success = YES;
        return [value copy];
    } @catch (NSException *exception) {
        WCAtlasLog(@"读取 %@ 的朋友圈数据失败：%@", username, exception.reason ?: @"未知异常");
        return @[];
    }
}

- (void)processItems:(NSArray *)items username:(NSString *)username seenRoot:(NSMutableDictionary *)seenRoot account:(NSString *)account {
    if (username.length == 0) return;
    NSMutableDictionary *accountSeen = [seenRoot[account] isKindOfClass:NSDictionary.class]
        ? [seenRoot[account] mutableCopy] : [NSMutableDictionary dictionary];
    BOOL hasBaseline = [accountSeen[username] isKindOfClass:NSArray.class];
    NSArray<NSString *> *previouslySeen = hasBaseline ? accountSeen[username] : @[];
    NSSet<NSString *> *previouslySeenSet = [NSSet setWithArray:previouslySeen];
    NSMutableOrderedSet<NSString *> *currentTids = [NSMutableOrderedSet orderedSet];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSMutableArray<NSDictionary *> *newItems = [NSMutableArray array];

    for (id item in items) {
        NSString *tid = WCAtlasMomentsReminderString(WCAtlasMomentsReminderObjectValue(item, "tid"));
        if (tid.length == 0) continue;
        BOOL alreadySeen = [previouslySeenSet containsObject:tid];
        [currentTids addObject:tid];
        if (!hasBaseline || alreadySeen) continue;
        uint64_t createdAt = WCAtlasMomentsReminderIntegerValue(item, "createtime");
        if (createdAt == 0 || now - (NSTimeInterval)createdAt > 86400.0) continue;
        NSString *nickname = WCAtlasMomentsReminderString(WCAtlasMomentsReminderObjectValue(item, "nickname"));
        NSString *content = WCAtlasMomentsReminderString(WCAtlasMomentsReminderObjectValue(item, "contentDesc"));
        [newItems addObject:@{ @"tid": tid,
                               @"createdAt": @(createdAt),
                               @"nickname": nickname ?: @"",
                               @"content": content ?: @"",
                               @"dataItem": item }];
    }

    NSMutableOrderedSet<NSString *> *mergedSeen = [NSMutableOrderedSet orderedSetWithOrderedSet:currentTids];
    [mergedSeen addObjectsFromArray:previouslySeen];
    while (mergedSeen.count > 200) [mergedSeen removeObjectAtIndex:mergedSeen.count - 1];
    accountSeen[username] = mergedSeen.array;
    seenRoot[account] = accountSeen;
    for (NSDictionary *item in [newItems sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"createdAt"] compare:right[@"createdAt"]];
    }]) {
        WCAtlasMomentsReminderNotify(username, item[@"nickname"], item[@"content"],
                                   [item[@"createdAt"] unsignedLongLongValue], item[@"tid"]);
        WCAtlasMomentsReminderForwardItem(item[@"dataItem"], username, item[@"nickname"], item[@"content"],
                                        [item[@"createdAt"] unsignedLongLongValue]);
    }
}

- (void)tick {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self tick]; });
        return;
    }
    if (self.checking || !WCAtlasEnhancementEnabled(WCAtlasMomentsReminderEnabledKey)) return;
    NSArray<NSString *> *users = WCAtlasMomentsReminderUsers();
    if (users.count == 0) return;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (self.lastCheckTime > 0.0 && now - self.lastCheckTime < [self checkInterval]) return;
    self.lastCheckTime = now;
    self.checking = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performCheck];
    });
}

- (void)performCheck {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsReminderEnabledKey)) {
        self.checking = NO;
        return;
    }
    NSArray<NSString *> *users = WCAtlasMomentsReminderUsers();
    if (users.count == 0) {
        self.checking = NO;
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *seenRoot = [[defaults dictionaryForKey:WCAtlasMomentsReminderSeenItemsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *account = WCAtlasCurrentUserWXID() ?: @"default";
    for (NSString *username in users) {
        BOOL loaded = NO;
        NSArray *items = [self loadItemsForUsername:username success:&loaded];
        if (loaded) {
            [self processItems:items username:username seenRoot:seenRoot account:account];
        }
    }
    [defaults setObject:seenRoot forKey:WCAtlasMomentsReminderSeenItemsKey];
    self.checking = NO;
}

- (void)settingsDidChange {
    self.lastCheckTime = 0.0;
    NSSet *selected = [NSSet setWithArray:WCAtlasMomentsReminderUsers()];
    for (NSString *username in self.controllers.allKeys.copy) {
        if (![selected containsObject:username]) [self.controllers removeObjectForKey:username];
    }
    if (WCAtlasEnhancementEnabled(WCAtlasMomentsReminderEnabledKey)) [self tick];
}

@end

void WCAtlasMomentsReminderTick(void) {
    [[WCAtlasMomentsReminderManager sharedManager] tick];
}

void WCAtlasMomentsReminderSettingsDidChange(void) {
    [[WCAtlasMomentsReminderManager sharedManager] settingsDidChange];
}
