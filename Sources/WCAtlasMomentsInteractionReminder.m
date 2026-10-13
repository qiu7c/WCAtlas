#import "WCAtlasMomentsInteractionReminder.h"
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
#import <stdlib.h>
#import <string.h>

static NSString *const WCAtlasMomentsInteractionStateKey = @"com.qiu7c.wcatlas.moments.interaction-reminder.state";

static const char *WCAtlasMomentsInteractionSkipQualifiers(const char *type) {
    while (type && strchr("rnNoORV", *type)) type++;
    return type ?: "";
}

static BOOL WCAtlasMomentsInteractionMethodMatches(id object, SEL selector, char returnType) {
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return NO;
    char *type = method_copyReturnType(method);
    BOOL matches = WCAtlasMomentsInteractionSkipQualifiers(type)[0] == returnType;
    free(type);
    return matches;
}

static BOOL WCAtlasMomentsInteractionMethodHasEncoding(id object, SEL selector, const char *encoding) {
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    const char *actual = method ? method_getTypeEncoding(method) : NULL;
    return actual && encoding && strcmp(actual, encoding) == 0;
}

static id WCAtlasMomentsInteractionObjectGetter(id object, const char *selectorName) {
    if (!object || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    if (!WCAtlasMomentsInteractionMethodHasEncoding(object, selector, "@16@0:8")) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static NSString *WCAtlasMomentsInteractionStringGetter(id object, const char *selectorName) {
    SEL selector = sel_registerName(selectorName);
    if (!WCAtlasMomentsInteractionMethodMatches(object, selector, '@')) return nil;
    id value = nil;
    @try { value = ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *string = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return string.length > 0 ? string : nil;
}

static NSString *WCAtlasMomentsInteractionMessageKey(id message) {
    if (!message) return nil;
    NSString *msgID = WCAtlasMomentsInteractionStringGetter(message, "msgID");
    if (msgID.length > 0) return [@"msg:" stringByAppendingString:msgID];
    NSString *clientID = WCAtlasMomentsInteractionStringGetter(message, "clientId");
    if (clientID.length > 0) return [@"client:" stringByAppendingString:clientID];
    NSString *objectID = WCAtlasMomentsInteractionStringGetter(message, "objID");
    NSString *parentID = WCAtlasMomentsInteractionStringGetter(message, "parentObjID");
    if (objectID.length > 0 || parentID.length > 0) {
        return [NSString stringWithFormat:@"object:%@:%@", objectID ?: @"", parentID ?: @""];
    }
    return [NSString stringWithFormat:@"pointer:%p", (__bridge void *)message];
}

static long long WCAtlasMomentsInteractionMessageType(id message) {
    SEL selector = sel_registerName("msgTypeFromClientId");
    Method method = message ? class_getInstanceMethod([message class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return 0;
    char *returnType = method_copyReturnType(method);
    BOOL matches = WCAtlasMomentsInteractionSkipQualifiers(returnType)[0] == 'q';
    free(returnType);
    if (!matches) return 0;
    @try { return ((long long (*)(id, SEL))objc_msgSend)(message, selector); }
    @catch (__unused NSException *exception) { return 0; }
}

static void WCAtlasMomentsInteractionNotify(NSUInteger count, NSString *messageKey,
                                           long long messageType, id message) {
    NSString *typeName = messageType == 1 ? @"点赞" : (messageType == 2 ? @"评论" : @"互动");
    BOOL showsDetails = [NSUserDefaults.standardUserDefaults
        boolForKey:WCAtlasMomentsInteractionReminderDetailsEnabledKey];
    id comment = WCAtlasMomentsInteractionObjectGetter(message, "comment");
    NSString *username = WCAtlasMomentsInteractionStringGetter(comment, "username");
    NSString *nickname = WCAtlasMomentsInteractionStringGetter(comment, "nickname");
    NSString *author = WCAtlasPrivateNotificationDisplayName(username, nickname);
    NSString *commentContent = WCAtlasMomentsInteractionStringGetter(comment, "content");
    if (commentContent.length > 100) {
        commentContent = [[commentContent substringToIndex:97] stringByAppendingString:@"…"];
    }
    NSString *title = showsDetails && author.length > 0 ? author : @"朋友圈互动";
    NSString *detail = nil;
    if (showsDetails && messageType == 1) {
        detail = @"点赞了你的朋友圈";
    } else if (showsDetails && messageType == 2 && commentContent.length > 0) {
        detail = [NSString stringWithFormat:@"评论：%@", commentContent];
    } else if (showsDetails && messageType == 2) {
        detail = @"评论了你的朋友圈";
    } else {
        detail = [NSString stringWithFormat:@"朋友圈收到新的%@", typeName];
    }
    NSString *body = nil;
    if (!showsDetails) {
        body = count > 1
            ? [NSString stringWithFormat:@"朋友圈收到 %lu 条新互动", (unsigned long)count]
            : detail;
    } else {
        body = count > 1
            ? [NSString stringWithFormat:@"收到 %lu 条新互动，最新：%@", (unsigned long)count, detail]
            : detail;
    }
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        NSString *symbolName = messageType == 1 ? @"heart.fill" :
                               (messageType == 2 ? @"bubble.left.fill" : @"bell.fill");
        NSString *identifier = [@"moments-interaction:" stringByAppendingString:messageKey ?: @"unknown"];
        WCAtlasShowInAppNotification(title, body, identifier, symbolName, ^{
            WCAtlasOpenMomentsTimeline();
        });
        return;
    }
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.sound = UNNotificationSound.defaultSound;
    content.threadIdentifier = @"wcatlas.moments.interaction";
    content.userInfo = @{ @"wcatlas": @"moments-interaction" };
    NSString *identifier = [NSString stringWithFormat:@"wcatlas.moments.interaction.%lu.%lu",
                              (unsigned long)messageKey.hash, (unsigned long)count];
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0 repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error) WCAtlasLog(@"发送朋友圈互动提醒失败：%@", error.localizedDescription ?: @"未知错误");
    }];
}

@interface WCAtlasMomentsInteractionReminderManager : NSObject
@property (nonatomic, weak) id notificationManager;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *lastMessageKey;
@property (nonatomic, assign) unsigned int lastUnreadCount;
@property (nonatomic, assign) NSUInteger pendingIncrease;
@property (nonatomic, assign) BOOL baselineReady;
@property (nonatomic, assign) BOOL lastMessageReadScheduled;
+ (instancetype)sharedManager;
- (void)observeManager:(id)manager unreadCount:(unsigned int)count;
- (void)observeManager:(id)manager lastUnreadMessage:(id)message;
- (void)tick;
- (void)settingsDidChange;
@end

@implementation WCAtlasMomentsInteractionReminderManager

+ (instancetype)sharedManager {
    static WCAtlasMomentsInteractionReminderManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WCAtlasMomentsInteractionReminderManager new]; });
    return manager;
}

- (NSString *)currentAccount {
    return WCAtlasCurrentUserWXID() ?: @"default";
}

- (NSMutableDictionary *)stateRoot {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCAtlasMomentsInteractionStateKey];
    return saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)prepareAccountIfNeeded {
    NSString *account = [self currentAccount];
    if ([self.account isEqualToString:account]) return;
    self.account = account;
    NSMutableDictionary *root = [self stateRoot];
    id savedState = root[account];
    NSDictionary *state = [savedState isKindOfClass:NSDictionary.class] ? savedState : nil;
    self.baselineReady = state != nil;
    self.lastUnreadCount = [state[@"count"] unsignedIntValue];
    self.lastMessageKey = [state[@"messageKey"] isKindOfClass:NSString.class] ? state[@"messageKey"] : nil;
    self.pendingIncrease = [state[@"pending"] unsignedIntegerValue];
    self.lastMessageReadScheduled = NO;
}

- (void)saveState {
    if (self.account.length == 0) return;
    NSMutableDictionary *root = [self stateRoot];
    root[self.account] = @{ @"count": @(self.lastUnreadCount),
                            @"messageKey": self.lastMessageKey ?: @"",
                            @"pending": @(self.pendingIncrease) };
    [NSUserDefaults.standardUserDefaults setObject:root forKey:WCAtlasMomentsInteractionStateKey];
}

- (void)scheduleLastMessageReadFromManager:(id)manager {
    if (self.lastMessageReadScheduled || !manager) return;
    self.lastMessageReadScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        strongSelf.lastMessageReadScheduled = NO;
        if (!strongSelf || strongSelf.pendingIncrease == 0 ||
            !WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey)) return;
        SEL lastSelector = sel_registerName("getLastUnReadMessage");
        if (!WCAtlasMomentsInteractionMethodHasEncoding(manager, lastSelector, "@16@0:8")) return;
        @try { ((id (*)(id, SEL))objc_msgSend)(manager, lastSelector); }
        @catch (NSException *exception) {
            WCAtlasLog(@"读取朋友圈最后未读互动失败：%@", exception.reason ?: @"未知异常");
        }
    });
}

- (void)observeManager:(id)manager unreadCount:(unsigned int)count {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self observeManager:manager unreadCount:count]; });
        return;
    }
    if (manager) self.notificationManager = manager;
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey)) return;
    [self prepareAccountIfNeeded];
    if (!self.baselineReady) {
        self.baselineReady = YES;
        self.lastUnreadCount = count;
        [self saveState];
        return;
    }
    if (count > self.lastUnreadCount) {
        self.pendingIncrease += count - self.lastUnreadCount;
        self.lastUnreadCount = count;
        [self saveState];
        [self scheduleLastMessageReadFromManager:manager ?: self.notificationManager];
    } else if (count < self.lastUnreadCount) {
        self.lastUnreadCount = count;
        self.pendingIncrease = 0;
        [self saveState];
    }
}

- (void)observeManager:(id)manager lastUnreadMessage:(id)message {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self observeManager:manager lastUnreadMessage:message]; });
        return;
    }
    if (manager) self.notificationManager = manager;
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey) || self.pendingIncrease == 0 || !message) return;
    [self prepareAccountIfNeeded];
    NSString *messageKey = WCAtlasMomentsInteractionMessageKey(message);
    if (messageKey.length == 0) return;
    NSUInteger increase = self.pendingIncrease;
    self.pendingIncrease = 0;
    BOOL duplicate = [self.lastMessageKey isEqualToString:messageKey];
    long long messageType = WCAtlasMomentsInteractionMessageType(message);
    self.lastMessageKey = messageKey;
    [self saveState];
    if (!duplicate) WCAtlasMomentsInteractionNotify(increase, messageKey, messageType, message);
}

- (void)tick {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self tick]; });
        return;
    }
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey)) return;
    id manager = self.notificationManager;
    SEL selector = sel_registerName("getUnReadMessageCount");
    if (!WCAtlasMomentsInteractionMethodHasEncoding(manager, selector, "I16@0:8")) return;
    @try { ((unsigned int (*)(id, SEL))objc_msgSend)(manager, selector); }
    @catch (NSException *exception) { WCAtlasLog(@"读取朋友圈互动未读数失败：%@", exception.reason ?: @"未知异常"); }
}

- (void)settingsDidChange {
    if (self.account.length > 0) {
        self.pendingIncrease = 0;
        [self saveState];
    }
    self.account = nil;
    self.baselineReady = NO;
    self.lastMessageReadScheduled = NO;
    if (WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey)) [self tick];
}

@end

void WCAtlasMomentsInteractionObserveUnreadCount(id manager, unsigned int count) {
    [[WCAtlasMomentsInteractionReminderManager sharedManager] observeManager:manager unreadCount:count];
}

void WCAtlasMomentsInteractionObserveLastUnreadMessage(id manager, id message) {
    [[WCAtlasMomentsInteractionReminderManager sharedManager] observeManager:manager lastUnreadMessage:message];
}

void WCAtlasMomentsInteractionReminderTick(void) {
    [[WCAtlasMomentsInteractionReminderManager sharedManager] tick];
}

void WCAtlasMomentsInteractionReminderSettingsDidChange(void) {
    [[WCAtlasMomentsInteractionReminderManager sharedManager] settingsDidChange];
}
