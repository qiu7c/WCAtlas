#import "WCAtlasRuntimeFeatures.h"
#import "WCAtlasMessageBlock.h"

#import "WCAtlasAccount.h"
#import "WCAtlasCompatibility.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasPrivateAPI.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

static char WCAtlasMenuOriginalTitleKey;

static id WCAtlasRuntimeSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void WCAtlasRuntimeSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {
    }
}

static NSString *WCAtlasRuntimeStringValue(id object, NSString *key) {
    id value = WCAtlasRuntimeSafeValue(object, key);
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length > 0 ? text : nil;
}

static NSArray<NSString *> *WCAtlasRuntimeStringList(NSString *key) {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    if (![stored isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:stored.count];
    for (id item in stored) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *value = [(NSString *)item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) [values addObject:value];
    }
    return values;
}

static BOOL WCAtlasRuntimeStringMatchesAny(NSString *value, NSArray<NSString *> *candidates) {
    if (value.length == 0) return NO;
    for (NSString *candidate in candidates) {
        if ([value caseInsensitiveCompare:candidate] == NSOrderedSame) return YES;
    }
    return NO;
}

static NSString *WCAtlasRuntimeMatchedTerm(NSString *text, NSString *defaultsKey) {
    if (text.length == 0) return nil;
    for (NSString *term in WCAtlasRuntimeStringList(defaultsKey)) {
        if ([text rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound) return term;
    }
    return nil;
}

static NSString *WCAtlasMenuSourceTitle(id item) {
    NSString *stored = objc_getAssociatedObject(item, &WCAtlasMenuOriginalTitleKey);
    if (stored.length > 0) return stored;
    SEL titleSelector = sel_registerName("title");
    id value = nil;
    if ([item respondsToSelector:titleSelector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(item, titleSelector);
    } else {
        value = WCAtlasRuntimeSafeValue(item, @"title");
    }
    if (![value isKindOfClass:[NSString class]] || [value length] == 0) return nil;
    stored = [value copy];
    objc_setAssociatedObject(item, &WCAtlasMenuOriginalTitleKey, stored, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return stored;
}

static void WCAtlasSetMenuTitle(id item, NSString *title) {
    if (!item || title.length == 0) return;
    SEL selector = sel_registerName("setTitle:");
    if ([item respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSString *))objc_msgSend)(item, selector, title);
    } else {
        WCAtlasRuntimeSetValue(item, @"title", title);
    }
}

NSArray *WCAtlasManagedLongPressMenuItems(NSArray *items) {
    if (![items isKindOfClass:[NSArray class]]) return items;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *knownTitles = [[defaults arrayForKey:WCAtlasLongPressMenuKnownTitlesKey] mutableCopy] ?: [NSMutableArray array];
    BOOL discoveredNewTitle = NO;
    for (id item in items) {
        NSString *sourceTitle = WCAtlasMenuSourceTitle(item);
        if (sourceTitle.length > 0 && ![knownTitles containsObject:sourceTitle]) {
            [knownTitles addObject:sourceTitle];
            discoveredNewTitle = YES;
        }
    }
    if (discoveredNewTitle) {
        [defaults setObject:knownTitles forKey:WCAtlasLongPressMenuKnownTitlesKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                            object:WCAtlasLongPressMenuKnownTitlesKey];
    }
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasLongPressMenuEnabledKey);
    for (id item in items) {
        NSString *sourceTitle = WCAtlasMenuSourceTitle(item);
        if (!enabled && sourceTitle.length > 0) WCAtlasSetMenuTitle(item, sourceTitle);
    }
    if (!enabled) return items;

    NSSet *hiddenTitles = [NSSet setWithArray:WCAtlasRuntimeStringList(WCAtlasLongPressMenuHiddenTitlesKey)];
    NSMutableArray *remaining = [NSMutableArray array];
    for (id item in items) {
        NSString *sourceTitle = WCAtlasMenuSourceTitle(item);
        if (sourceTitle.length == 0 || ![hiddenTitles containsObject:sourceTitle]) [remaining addObject:item];
    }

    NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:remaining.count];
    for (NSString *preferredTitle in WCAtlasRuntimeStringList(WCAtlasLongPressMenuPreferredOrderKey)) {
        for (id item in [remaining copy]) {
            if ([WCAtlasMenuSourceTitle(item) isEqualToString:preferredTitle]) {
                [ordered addObject:item];
                [remaining removeObjectIdenticalTo:item];
            }
        }
    }
    [ordered addObjectsFromArray:remaining];

    NSDictionary *mapping = [defaults dictionaryForKey:WCAtlasLongPressMenuTitleMapKey];
    for (id item in ordered) {
        NSString *sourceTitle = WCAtlasMenuSourceTitle(item);
        id renamedTitle = sourceTitle.length > 0 ? mapping[sourceTitle] : nil;
        WCAtlasSetMenuTitle(item,
                          [renamedTitle isKindOfClass:[NSString class]] && [renamedTitle length] > 0
                              ? renamedTitle
                              : sourceTitle);
    }
    return ordered;
}

static NSUInteger WCAtlasMessageType(id message) {
    id value = WCAtlasRuntimeSafeValue(message, @"m_uiMessageType");
    return [value respondsToSelector:@selector(unsignedIntegerValue)] ? [value unsignedIntegerValue] : 0;
}

static BOOL WCAtlasMessageIsIncoming(id message) {
    NSString *selfUserName = WCAtlasCurrentUserWXID();
    if (selfUserName.length == 0) return NO;
    NSString *fromUserName = WCAtlasRuntimeStringValue(message, @"m_nsFromUsr");
    NSString *realUserName = WCAtlasRuntimeStringValue(message, @"m_nsRealChatUsr");
    if ([fromUserName caseInsensitiveCompare:selfUserName] == NSOrderedSame) return NO;
    if (realUserName.length > 0 && [realUserName caseInsensitiveCompare:selfUserName] == NSOrderedSame) return NO;
    return fromUserName.length > 0;
}

static NSString *WCAtlasMessageSession(NSString *sessionUserName, id message) {
    if (sessionUserName.length > 0) return sessionUserName;
    NSString *selfUserName = WCAtlasCurrentUserWXID();
    NSString *fromUserName = WCAtlasRuntimeStringValue(message, @"m_nsFromUsr");
    NSString *toUserName = WCAtlasRuntimeStringValue(message, @"m_nsToUsr");
    return [fromUserName caseInsensitiveCompare:selfUserName] == NSOrderedSame ? toUserName : fromUserName;
}

static NSString *WCAtlasMessageDisplayContent(id message, NSString *sessionUserName) {
    NSString *content = WCAtlasRuntimeStringValue(message, @"m_nsContent") ?: @"";
    if ([sessionUserName hasSuffix:@"@chatroom"]) {
        NSRange prefix = [content rangeOfString:@":\n"];
        if (prefix.location != NSNotFound && prefix.location < 128) {
            content = [content substringFromIndex:NSMaxRange(prefix)];
        }
    }
    return content;
}

static id WCAtlasContactForUserNameWithManager(id manager, NSString *userName) {
    (void)manager;
    return WCAtlasPrivateContact(userName);
}

static NSString *WCAtlasContactDisplayName(id contact, NSString *fallback) {
    return WCAtlasPrivateContactDisplayName(contact, fallback) ?: @"未知用户";
}

BOOL WCAtlasShouldBlockIncomingMessage(NSString *sessionUserName, id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMessageBlockEnabledKey) ||
        !WCAtlasMessageIsIncoming(message)) return NO;

    NSString *session = WCAtlasMessageSession(sessionUserName, message);
    NSString *fromUserName = WCAtlasRuntimeStringValue(message, @"m_nsFromUsr");
    NSString *realUserName = WCAtlasRuntimeStringValue(message, @"m_nsRealChatUsr");
    NSArray *blockedUsers = WCAtlasRuntimeStringList(WCAtlasMessageBlockUsersKey);
    NSUInteger messageType = WCAtlasMessageType(message);
    BOOL blockedUser = WCAtlasRuntimeStringMatchesAny(session, blockedUsers) &&
                       WCAtlasMessageBlockConversationMatchesType(session, messageType);
    // Group messages carry the actual sender in m_nsRealChatUsr. Match it
    // before falling back to m_nsFromUsr, following WeChat's native field use.
    if (!blockedUser && realUserName.length > 0) {
        blockedUser = WCAtlasRuntimeStringMatchesAny(realUserName, blockedUsers) &&
                      WCAtlasMessageBlockConversationMatchesType(realUserName, messageType);
    }
    if (!blockedUser && fromUserName.length > 0) {
        blockedUser = WCAtlasRuntimeStringMatchesAny(fromUserName, blockedUsers) &&
                      WCAtlasMessageBlockConversationMatchesType(fromUserName, messageType);
    }
    NSString *blockedKeyword = nil;
    if (WCAtlasMessageType(message) == 1) {
        NSString *content = WCAtlasMessageDisplayContent(message, session);
        blockedKeyword = WCAtlasRuntimeMatchedTerm(content, WCAtlasMessageBlockKeywordsKey);
    }
    if (!blockedUser && blockedKeyword.length == 0) return NO;
    WCAtlasLog(@"已屏蔽一条新收到的消息（会话：%@，类型：%ld）",
             session ?: @"未知", (long)messageType);
    return YES;
}

BOOL WCAtlasDeleteBlockedIncomingMessage(id messageManager,
                                       NSString *sessionUserName,
                                       id message) {
    if (!WCAtlasShouldBlockIncomingMessage(sessionUserName, message)) return NO;

    NSString *session = WCAtlasMessageSession(sessionUserName, message);
    SEL selector = sel_registerName("DelMsg:MsgWrap:");
    if (!messageManager || session.length == 0 || !message ||
        ![messageManager respondsToSelector:selector]) return NO;

    ((void (*)(id, SEL, id, id))objc_msgSend)(messageManager, selector, session, message);
    return YES;
}

static NSMutableDictionary<NSString *, NSString *> *WCAtlasGroupMemberListCache(void) {
    static NSMutableDictionary *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

static NSSet<NSString *> *WCAtlasMemberSetFromList(NSString *memberList) {
    NSMutableSet *members = [NSMutableSet set];
    for (NSString *component in [memberList componentsSeparatedByString:@";"]) {
        NSString *member = [component stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (member.length > 0) [members addObject:member];
    }
    return members;
}

@interface WCAtlasGroupMemberChangeSnapshot : NSObject
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSSet<NSString *> *beforeMembers;
@end

@implementation WCAtlasGroupMemberChangeSnapshot
@end

id WCAtlasCaptureGroupMemberChange(id newContact, id oldContact) {
    if (!WCAtlasEnhancementEnabled(WCAtlasGroupMemberReminderEnabledKey)) return nil;
    NSString *session = WCAtlasPrivateContactUserName(newContact);
    if (![session hasSuffix:@"@chatroom"]) return nil;

    NSString *beforeList = WCAtlasRuntimeStringValue(oldContact, @"m_nsChatRoomMemList");
    if (beforeList.length == 0) {
        NSMutableDictionary *cache = WCAtlasGroupMemberListCache();
        @synchronized (cache) {
            beforeList = cache[session];
        }
    }
    WCAtlasGroupMemberChangeSnapshot *snapshot = [WCAtlasGroupMemberChangeSnapshot new];
    snapshot.sessionUserName = session;
    snapshot.beforeMembers = WCAtlasMemberSetFromList(beforeList ?: @"");
    return snapshot;
}

static NSString *WCAtlasGroupMemberDisplayName(id groupContact, id contactManager, NSString *memberUserName) {
    (void)groupContact;
    return WCAtlasContactDisplayName(WCAtlasContactForUserNameWithManager(contactManager, memberUserName), memberUserName);
}

static NSString *WCAtlasGroupMemberNames(NSSet<NSString *> *members, id groupContact, id contactManager) {
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *member in members) {
        [names addObject:WCAtlasGroupMemberDisplayName(groupContact, contactManager, member)];
    }
    [names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSUInteger visibleCount = MIN((NSUInteger)4, names.count);
    NSString *joined = [[names subarrayWithRange:NSMakeRange(0, visibleCount)] componentsJoinedByString:@"、"];
    if (names.count > visibleCount) {
        joined = [joined stringByAppendingFormat:@"等 %lu 人", (unsigned long)names.count];
    }
    return joined;
}

static BOOL WCAtlasInsertGroupMemberSystemMessage(NSString *sessionUserName, NSString *content) {
    if (sessionUserName.length == 0 || content.length == 0) return NO;

    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector]) return NO;

    id messageManager = WCAtlasServiceForClass(objc_getClass("CMessageMgr"));
    SEL addSelector = sel_registerName("AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:");
    if (!messageManager || ![messageManager respondsToSelector:addSelector]) return NO;

    id message = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([wrapClass alloc], initSelector, 10000);
    if (!message) return NO;
    WCAtlasRuntimeSetValue(message, @"m_nsFromUsr", sessionUserName);
    WCAtlasRuntimeSetValue(message, @"m_nsToUsr", WCAtlasCurrentUserWXID() ?: @"");
    WCAtlasRuntimeSetValue(message, @"m_uiStatus", @4);
    WCAtlasRuntimeSetValue(message, @"m_nsContent", content);
    WCAtlasRuntimeSetValue(message, @"m_uiCreateTime", @((NSUInteger)NSDate.date.timeIntervalSince1970));
    ((void (*)(id, SEL, NSString *, id, BOOL, BOOL))objc_msgSend)(messageManager,
                                                                 addSelector,
                                                                 sessionUserName,
                                                                 message,
                                                                 YES,
                                                                 NO);
    return YES;
}

void WCAtlasCompleteGroupMemberChange(id value, id contactManager, id newContact) {
    if (![value isKindOfClass:[WCAtlasGroupMemberChangeSnapshot class]]) return;
    WCAtlasGroupMemberChangeSnapshot *snapshot = value;
    NSString *afterList = WCAtlasRuntimeStringValue(newContact, @"m_nsChatRoomMemList");
    id groupContact = newContact;
    if (afterList.length == 0) {
        groupContact = WCAtlasContactForUserNameWithManager(contactManager, snapshot.sessionUserName);
        afterList = WCAtlasRuntimeStringValue(groupContact, @"m_nsChatRoomMemList");
    }
    if (afterList.length == 0) return;

    NSMutableDictionary *cache = WCAtlasGroupMemberListCache();
    @synchronized (cache) {
        cache[snapshot.sessionUserName] = afterList;
    }
    if (snapshot.beforeMembers.count == 0) return;

    NSSet *afterMembers = WCAtlasMemberSetFromList(afterList);
    NSMutableSet *joined = [afterMembers mutableCopy];
    [joined minusSet:snapshot.beforeMembers];
    NSMutableSet *left = [snapshot.beforeMembers mutableCopy];
    [left minusSet:afterMembers];
    if (joined.count == 0 && left.count == 0) return;

    NSMutableArray *changes = [NSMutableArray array];
    if (joined.count > 0) {
        [changes addObject:[NSString stringWithFormat:@"「%@」加入了群聊",
                            WCAtlasGroupMemberNames(joined, groupContact, contactManager)]];
    }
    if (left.count > 0) {
        [changes addObject:[NSString stringWithFormat:@"「%@」退出了群聊",
                            WCAtlasGroupMemberNames(left, groupContact, contactManager)]];
    }
    NSString *content = [changes componentsJoinedByString:@"；"];
    if (!WCAtlasInsertGroupMemberSystemMessage(snapshot.sessionUserName, content)) {
        WCAtlasLog(@"群成员变动提示写入失败：%@", snapshot.sessionUserName);
    }
}

void WCAtlasOpenChatForUserName(NSString *userName) {
    (void)WCAtlasPushPrivateChat(nil, userName, YES);
}

static UIViewController *WCAtlasFindControllerOfClass(UIViewController *controller, Class targetClass) {
    if (!controller || !targetClass) return nil;
    if ([controller isKindOfClass:targetClass]) return controller;
    UIViewController *found = WCAtlasFindControllerOfClass(controller.presentedViewController, targetClass);
    if (found) return found;
    for (UIViewController *child in controller.childViewControllers) {
        found = WCAtlasFindControllerOfClass(child, targetClass);
        if (found) return found;
    }
    return nil;
}

static void WCAtlasOpenMomentsTimelineAttempt(NSUInteger remainingAttempts) {
    Class entryClass = objc_getClass("FindFriendEntryViewController");
    SEL openSelector = sel_registerName("openAlbum");
    Method method = entryClass ? class_getInstanceMethod(entryClass, openSelector) : NULL;
    const char *typeEncoding = method ? method_getTypeEncoding(method) : NULL;
    if (!typeEncoding || strcmp(typeEncoding, "v16@0:8") != 0) {
        WCAtlasLog(@"打开朋友圈失败：当前版本入口 ABI 不匹配");
        return;
    }

    UIWindow *window = nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
        if (!candidate.hidden && candidate.alpha > 0.0 && candidate.windowLevel == UIWindowLevelNormal) {
            window = candidate;
            if (candidate.isKeyWindow) break;
        }
    }
    UIViewController *entry = WCAtlasFindControllerOfClass(window.rootViewController, entryClass);
    if (!entry) {
        if (remainingAttempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WCAtlasOpenMomentsTimelineAttempt(remainingAttempts - 1);
            });
        } else {
            WCAtlasLog(@"打开朋友圈失败：未找到发现页控制器");
        }
        return;
    }
    UITabBarController *tabBarController = entry.tabBarController;
    UIViewController *tabRoot = entry.navigationController ?: entry;
    if (tabBarController && tabBarController.selectedViewController != tabRoot) {
        tabBarController.selectedViewController = tabRoot;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try { ((void (*)(id, SEL))objc_msgSend)(entry, openSelector); }
        @catch (NSException *exception) {
            WCAtlasLog(@"打开朋友圈失败：%@", exception.reason ?: @"未知异常");
        }
    });
}

void WCAtlasOpenMomentsTimeline(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasOpenMomentsTimelineAttempt(8); });
}

BOOL WCAtlasHandleNotificationResponse(id response, void (^completionHandler)(void)) {
    id notification = WCAtlasRuntimeSafeValue(response, @"notification");
    id request = WCAtlasRuntimeSafeValue(notification, @"request");
    id content = WCAtlasRuntimeSafeValue(request, @"content");
    NSDictionary *userInfo = WCAtlasRuntimeSafeValue(content, @"userInfo");
    id rawWCAtlasType = [userInfo isKindOfClass:[NSDictionary class]] ? userInfo[@"wcatlas"] : nil;
    NSString *wcAtlasType = [rawWCAtlasType isKindOfClass:[NSString class]] ? rawWCAtlasType : nil;
    if ([wcAtlasType isEqualToString:@"moments-reminder"] ||
        [wcAtlasType isEqualToString:@"moments-interaction"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WCAtlasOpenMomentsTimeline(); });
        if (completionHandler) completionHandler();
        return YES;
    }

    if (!WCAtlasEnhancementEnabled(WCAtlasNotificationDirectChatEnabledKey)) return NO;
    id rawUserName = [userInfo isKindOfClass:[NSDictionary class]] ? userInfo[@"u"] : nil;
    NSString *userName = [rawUserName isKindOfClass:[NSString class]]
        ? [rawUserName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : nil;
    if (userName.length == 0) return NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasOpenChatForUserName(userName);
    });
    WCAtlasCompatibilityMarkTriggered(@"notification-direct-chat");
    if (completionHandler) completionHandler();
    return YES;
}

UIView *WCAtlasWalletHeaderForView(UIView *view) {
    Class headerClass = objc_getClass("WCPayWalletEntryHeaderView");
    if (!headerClass || ![view isKindOfClass:[UIView class]]) return nil;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:headerClass]) return ancestor;
    }
    return nil;
}

BOOL WCAtlasViewIsInsideWalletHeader(UIView *view) {
    return WCAtlasWalletHeaderForView(view) != nil;
}

void WCAtlasRefreshWalletHeaderBalance(id headerView) {
    if (!headerView) return;
    if (!WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey)) return;
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:WCAtlasWalletBalanceFenKey];
    unsigned long long balanceFen = [stored respondsToSelector:@selector(unsignedLongLongValue)]
        ? [stored unsignedLongLongValue]
        : 0;
    if (balanceFen == 0) return;
    Ivar timeoutNumberIvar = class_getInstanceVariable([headerView class], "_timeoutNumber");
    id timeoutNumber = timeoutNumberIvar ? object_getIvar(headerView, timeoutNumberIvar) : nil;
    SEL selector = sel_registerName("updateNumber:");
    if (timeoutNumber && [timeoutNumber respondsToSelector:selector]) {
        ((void (*)(id, SEL, unsigned long long))objc_msgSend)(timeoutNumber, selector, balanceFen);
    }
}
