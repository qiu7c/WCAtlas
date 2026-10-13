#import "WCAtlasPrivateAPI.h"
#import "WCAtlasAccount.h"
#import "WCAtlasLogging.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>
#include <stdlib.h>
#include <stdatomic.h>

#pragma mark - Runtime ABI Helpers

static const char *WCAtlasPrivateUnqualifiedType(const char *type) {
    if (!type) return "";
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

static BOOL WCAtlasPrivateTypeIsObject(const char *type) {
    return WCAtlasPrivateUnqualifiedType(type)[0] == '@';
}

static BOOL WCAtlasPrivateTypeIsInteger(const char *type) {
    const char value = WCAtlasPrivateUnqualifiedType(type)[0];
    return value && strchr("cCsSiIlLqQB", value) != NULL;
}

static BOOL WCAtlasPrivateTypeIsVoid(const char *type) {
    return WCAtlasPrivateUnqualifiedType(type)[0] == 'v';
}

static BOOL WCAtlasPrivateTypeIsSelector(const char *type) {
    return WCAtlasPrivateUnqualifiedType(type)[0] == ':';
}

static NSMethodSignature *WCAtlasPrivateSignature(id receiver,
                                                SEL selector,
                                                NSUInteger argumentCount) {
    if (!receiver || !selector || ![receiver respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [receiver methodSignatureForSelector:selector];
    return signature.numberOfArguments == argumentCount ? signature : nil;
}

static BOOL WCAtlasPrivateObjectArguments(NSMethodSignature *signature,
                                        NSRange indexes) {
    if (!signature || NSMaxRange(indexes) > signature.numberOfArguments) return NO;
    for (NSUInteger index = indexes.location; index < NSMaxRange(indexes); index++) {
        if (!WCAtlasPrivateTypeIsObject([signature getArgumentTypeAtIndex:index])) return NO;
    }
    return YES;
}

#pragma mark - Service Center

id WCAtlasPrivateService(NSString *className) {
    Class serviceClass = className.length > 0 ? NSClassFromString(className) : Nil;
    return serviceClass ? WCAtlasServiceForClass(serviceClass) : nil;
}

#pragma mark - Current Chat

static id WCAtlasPrivateNoArgumentObject(id receiver, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature = WCAtlasPrivateSignature(receiver, selector, 2);
    if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType)) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(receiver, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static id WCAtlasPrivateObjectField(id object, NSArray<NSString *> *names) {
    if (!object) return nil;
    for (NSString *name in names) {
        id value = WCAtlasPrivateNoArgumentObject(object, name);
        if (value && value != NSNull.null) return value;
        @try {
            value = [object valueForKey:name];
            if (value && value != NSNull.null) return value;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

static NSString *WCAtlasPrivateNonemptyString(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return string.length > 0 ? string : nil;
}

static UIViewController *WCAtlasPrivateChatControllerInTree(UIViewController *controller,
                                                           Class chatControllerClass) {
    if (!controller || !chatControllerClass) return nil;
    UIViewController *found = WCAtlasPrivateChatControllerInTree(controller.presentedViewController,
                                                               chatControllerClass);
    if (found) return found;
    if ([controller isKindOfClass:UINavigationController.class]) {
        found = WCAtlasPrivateChatControllerInTree(
            ((UINavigationController *)controller).visibleViewController, chatControllerClass);
        if (found) return found;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        found = WCAtlasPrivateChatControllerInTree(
            ((UITabBarController *)controller).selectedViewController, chatControllerClass);
        if (found) return found;
    }
    if ([controller isKindOfClass:chatControllerClass] && controller.isViewLoaded &&
        controller.view.window &&
        (!controller.navigationController || controller.navigationController.topViewController == controller)) {
        return controller;
    }
    for (UIViewController *child in controller.childViewControllers.reverseObjectEnumerator) {
        found = WCAtlasPrivateChatControllerInTree(child, chatControllerClass);
        if (found) return found;
    }
    return nil;
}

UIViewController *WCAtlasPrivateCurrentChatController(void) {
    NSCAssert(NSThread.isMainThread, @"Current chat resolution must run on the main thread");
    Class chatControllerClass = NSClassFromString(@"BaseMsgContentViewController");
    if (!chatControllerClass) return nil;
    NSMutableOrderedSet<UIWindow *> *windows = [NSMutableOrderedSet orderedSet];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:UIWindowScene.class]) continue;
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows ?: @[]];
    for (UIWindow *window in windows.reverseObjectEnumerator) {
        if (window.hidden || window.alpha <= 0.0 ||
            [NSStringFromClass(window.class) containsString:@"iConsole"]) continue;
        UIViewController *controller = WCAtlasPrivateChatControllerInTree(
            window.rootViewController, chatControllerClass);
        if (controller) return controller;
    }
    return nil;
}

static UIViewController *WCAtlasPrivateVisibleChatControllerCandidate(id candidate) {
    Class chatControllerClass = NSClassFromString(@"BaseMsgContentViewController");
    if (!candidate || !chatControllerClass) return nil;
    if ([candidate isKindOfClass:UIViewController.class]) {
        UIViewController *controller = candidate;
        for (UIViewController *current = controller; current; current = current.parentViewController) {
            if ([current isKindOfClass:chatControllerClass] && current.isViewLoaded && current.view.window) {
                return current;
            }
        }
        if ([controller isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if ([visible isKindOfClass:chatControllerClass] && visible.isViewLoaded && visible.view.window) {
                return visible;
            }
        }
    }
    return nil;
}

UIViewController *WCAtlasPrivateChatControllerForView(id sourceView) {
    NSCAssert(NSThread.isMainThread, @"View chat resolution must run on the main thread");
    if (!sourceView) return WCAtlasPrivateCurrentChatController();
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSString *selectorName in @[@"getViewController", @"GetCurrentViewController"]) {
        id value = WCAtlasPrivateNoArgumentObject(sourceView, selectorName);
        if (value) [candidates addObject:value];
    }
    for (NSString *fieldName in @[@"_uiDelegate", @"uiDelegate", @"_parentView", @"parentView",
                                  @"linkDelegate", @"layoutDelegate", @"delegate", @"m_delegate"]) {
        id value = WCAtlasPrivateObjectField(sourceView, @[fieldName]);
        if (value) [candidates addObject:value];
    }
    if ([sourceView isKindOfClass:UIView.class]) {
        UIResponder *responder = sourceView;
        for (NSUInteger depth = 0; responder && depth < 16; depth++) {
            responder = responder.nextResponder;
            if (responder) [candidates addObject:responder];
        }
    }
    for (id candidate in [candidates copy]) {
        UIViewController *controller = WCAtlasPrivateVisibleChatControllerCandidate(candidate);
        if (controller) return controller;
        for (NSString *selectorName in @[@"getViewController", @"GetCurrentViewController"]) {
            controller = WCAtlasPrivateVisibleChatControllerCandidate(
                WCAtlasPrivateNoArgumentObject(candidate, selectorName));
            if (controller) return controller;
        }
    }
    return WCAtlasPrivateCurrentChatController();
}

UIViewController *WCAtlasPrivateChatControllerForInputToolView(id inputToolView) {
    NSCAssert(NSThread.isMainThread, @"Input-tool chat resolution must run on the main thread");
    return WCAtlasPrivateChatControllerForView(inputToolView);
}

NSString *WCAtlasPrivateChatUserNameForInputToolView(id inputToolView) {
    NSCAssert(NSThread.isMainThread, @"Input-tool chat-name resolution must run on the main thread");
    for (NSString *selectorName in @[@"currentChatId", @"currentSessionId", @"getChatName",
                                     @"getCurrentChatName", @"getChatUserName"]) {
        NSString *userName = WCAtlasPrivateNonemptyString(
            WCAtlasPrivateNoArgumentObject(inputToolView, selectorName));
        if (userName.length > 0) return userName;
    }
    id contact = WCAtlasPrivateObjectField(inputToolView, @[@"contact", @"_contact"]);
    NSString *userName = WCAtlasPrivateContactUserName(contact);
    if (userName.length > 0) return userName;
    UIViewController *controller = WCAtlasPrivateChatControllerForInputToolView(inputToolView);
    return WCAtlasPrivateChatUserName(controller);
}

id WCAtlasPrivateChatContact(id chatController) {
    if (!chatController) chatController = WCAtlasPrivateCurrentChatController();
    for (NSString *selectorName in @[@"GetContact", @"GetCContact"]) {
        id contact = WCAtlasPrivateNoArgumentObject(chatController, selectorName);
        if (contact) return contact;
    }
    return WCAtlasPrivateObjectField(chatController, @[@"m_contact", @"chatContact", @"contact"]);
}

NSString *WCAtlasPrivateChatUserName(id chatController) {
    if (!chatController) chatController = WCAtlasPrivateCurrentChatController();
    for (NSString *selectorName in @[@"getCurrentChatName", @"getChatUserName"]) {
        NSString *userName = WCAtlasPrivateNonemptyString(
            WCAtlasPrivateNoArgumentObject(chatController, selectorName));
        if (userName.length > 0) return userName;
    }
    id contact = WCAtlasPrivateChatContact(chatController);
    NSString *userName = WCAtlasPrivateNonemptyString(WCAtlasPrivateObjectField(
        contact, @[@"m_nsUsrName", @"m_nsUserName", @"getUsrName", @"userName", @"username"]));
    if (userName.length > 0) return userName;
    return WCAtlasPrivateNonemptyString(WCAtlasPrivateObjectField(
        chatController, @[@"m_nsUsrName", @"m_nsUserName", @"sessionUserName"]));
}

#pragma mark - Contacts

id WCAtlasPrivateContact(NSString *userName) {
    if (userName.length == 0) return nil;
    id manager = WCAtlasPrivateService(@"CContactMgr");
    id fallbackContact = nil;
    for (NSString *selectorName in @[
        @"getContactByName:", @"getContactForSearchByName:",
        @"getContactByNameFromCache:", @"getContact:"
    ]) {
        SEL selector = NSSelectorFromString(selectorName);
        NSMethodSignature *signature = WCAtlasPrivateSignature(manager, selector, 3);
        if (!WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1)) ||
            !WCAtlasPrivateTypeIsObject(signature.methodReturnType)) continue;
        @try {
            id contact = ((id (*)(id, SEL, id))objc_msgSend)(manager, selector, userName);
            if (!contact) continue;
            if (!fallbackContact) fallbackContact = contact;
            NSString *remark = WCAtlasPrivateNonemptyString(WCAtlasPrivateObjectField(
                contact, @[@"m_nsRemark", @"getRemark", @"remark", @"remarkName"]));
            if (remark.length > 0) return contact;
        } @catch (NSException *exception) {
            WCAtlasLog(@"联系人适配 %@ 调用失败：%@", selectorName,
                     exception.reason ?: exception.name);
        }
    }
    return fallbackContact;
}

static NSString *WCAtlasPrivateContactString(id contact, NSArray<NSString *> *names) {
    return WCAtlasPrivateNonemptyString(WCAtlasPrivateObjectField(contact, names));
}

NSString *WCAtlasPrivateContactUserName(id contact) {
    return WCAtlasPrivateContactString(contact,
        @[@"m_nsUsrName", @"m_nsUserName", @"getUsrName", @"userName", @"username"]);
}

NSString *WCAtlasPrivateContactNickname(id contact) {
    return WCAtlasPrivateContactString(contact,
        @[@"m_nsNickName", @"getNickName", @"nickName", @"nickname"]);
}

NSString *WCAtlasPrivateContactRemark(id contact) {
    return WCAtlasPrivateContactString(contact,
        @[@"m_nsRemark", @"getRemark", @"remark", @"remarkName"]);
}

NSString *WCAtlasPrivateContactAlias(id contact) {
    return WCAtlasPrivateContactString(contact,
        @[@"m_nsAliasName", @"m_nsAlias", @"getAlias", @"alias", @"aliasName"]);
}

NSString *WCAtlasPrivateContactDisplayName(id contact, NSString *fallback) {
    NSString *displayName = WCAtlasPrivateContactRemark(contact);
    if (displayName.length > 0) return displayName;
    displayName = WCAtlasPrivateContactString(contact,
        @[@"getContactDisplayName", @"getDisplayName"]);
    if (displayName.length > 0) return displayName;
    displayName = WCAtlasPrivateContactNickname(contact);
    if (displayName.length > 0) return displayName;
    return WCAtlasPrivateNonemptyString(fallback);
}

NSString *WCAtlasPrivateGroupMemberDisplayName(id groupContact, id memberContact) {
    NSCAssert(NSThread.isMainThread, @"Group member names must be read on the main thread");
    if (!memberContact) return nil;
    id manager = WCAtlasPrivateService(@"CContactMgr");
    SEL twoContactSelector = NSSelectorFromString(@"getChatRoomDisplayNameWithContact:chatContact:");
    for (id target in @[manager ?: NSNull.null, groupContact ?: NSNull.null]) {
        if (target == NSNull.null) continue;
        NSMethodSignature *signature = WCAtlasPrivateSignature(target, twoContactSelector, 4);
        if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType) ||
            !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2))) continue;
        @try {
            NSString *name = WCAtlasPrivateNonemptyString(
                ((id (*)(id, SEL, id, id))objc_msgSend)(target, twoContactSelector,
                                                        memberContact, groupContact));
            if (name.length > 0) return name;
        } @catch (__unused NSException *exception) {}
    }
    SEL oneContactSelector = NSSelectorFromString(@"getChatRoomDisplayNameWithContact:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(groupContact, oneContactSelector, 3);
    if (signature && WCAtlasPrivateTypeIsObject(signature.methodReturnType) &&
        WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1))) {
        @try {
            NSString *name = WCAtlasPrivateNonemptyString(
                ((id (*)(id, SEL, id))objc_msgSend)(groupContact, oneContactSelector, memberContact));
            if (name.length > 0) return name;
        } @catch (__unused NSException *exception) {}
    }
    return WCAtlasPrivateContactDisplayName(memberContact, nil);
}

NSString *WCAtlasPrivateNotificationDisplayName(NSString *userName, NSString *eventFallback) {
    NSCAssert(NSThread.isMainThread, @"Notification contact names must be resolved on the main thread");
    NSString *normalizedUserName = WCAtlasPrivateNonemptyString(userName);
    id contact = normalizedUserName.length > 0 ? WCAtlasPrivateContact(normalizedUserName) : nil;
    NSString *name = WCAtlasPrivateContactRemark(contact);
    if (name.length > 0) return name;
    id listContact = nil;
    if (normalizedUserName.length > 0) {
        for (id candidate in WCAtlasPrivateContactList()) {
            NSString *candidateUserName = WCAtlasPrivateContactUserName(candidate);
            NSString *candidateAlias = WCAtlasPrivateContactAlias(candidate);
            if ([candidateUserName isEqualToString:normalizedUserName] ||
                [candidateAlias isEqualToString:normalizedUserName]) {
                listContact = candidate;
                break;
            }
        }
    }
    name = WCAtlasPrivateContactRemark(listContact);
    if (name.length > 0) return name;
    name = WCAtlasPrivateContactDisplayName(contact, nil);
    if (name.length > 0) return name;
    name = WCAtlasPrivateContactDisplayName(listContact, nil);
    if (name.length > 0) return name;
    name = WCAtlasPrivateNonemptyString(eventFallback);
    if (name.length > 0) return name;
    return normalizedUserName;
}

NSString *WCAtlasPrivateContactHeadImageURL(id contact) {
    return WCAtlasPrivateContactString(contact, @[
        @"m_nsHeadHDImgUrl", @"m_nsHeadImgUrlHD", @"m_nsHeadImgUrl",
        @"headImgUrl", @"headImageURL"
    ]);
}

UIImage *WCAtlasPrivateContactAvatarImage(id contact) {
    NSCAssert(NSThread.isMainThread, @"Contact avatar images must be read on the main thread");
    for (NSString *selectorName in @[@"getContactHeadImage", @"contactHeadImage", @"headImage"]) {
        id image = WCAtlasPrivateNoArgumentObject(contact, selectorName);
        if ([image isKindOfClass:UIImage.class]) return image;
    }
    return nil;
}

static BOOL WCAtlasPrivateAvatarHelperSignature(NSMethodSignature *signature) {
    return signature && WCAtlasPrivateTypeIsObject(signature.methodReturnType) &&
        WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2)) &&
        WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:4]) &&
        WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:5]);
}

UIView *WCAtlasPrivateContactAvatarView(id contact, NSString *userName, BOOL roundCorner) {
    NSCAssert(NSThread.isMainThread, @"Contact avatar views must be built on the main thread");
    NSString *resolvedUserName = WCAtlasPrivateContactUserName(contact) ?:
        WCAtlasPrivateNonemptyString(userName);
    NSString *headImageURL = WCAtlasPrivateContactHeadImageURL(contact) ?: @"";
    Class helperClass = NSClassFromString(@"MMHeadImageHelper");
    if (helperClass && resolvedUserName.length > 0) {
        for (NSString *selectorName in @[
            @"getContactHeadImageViewWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner:",
            @"getMainFrameHeadImageViewWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner:",
            @"getProfileHeadImageViewWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner:"
        ]) {
            SEL selector = NSSelectorFromString(selectorName);
            NSMethodSignature *signature = WCAtlasPrivateSignature(helperClass, selector, 6);
            if (!WCAtlasPrivateAvatarHelperSignature(signature)) continue;
            @try {
                id view = ((id (*)(id, SEL, id, id, BOOL, BOOL))objc_msgSend)(
                    helperClass, selector, resolvedUserName, headImageURL, YES, roundCorner);
                if ([view isKindOfClass:UIView.class]) return view;
            } @catch (NSException *exception) {
                WCAtlasLog(@"头像适配 %@ 调用失败：%@", selectorName,
                         exception.reason ?: exception.name);
            }
        }
    }
    UIImage *image = WCAtlasPrivateContactAvatarImage(contact);
    if (!image) return nil;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    return imageView;
}

#pragma mark - Contact and Group Lists

static NSArray *WCAtlasPrivateEnumerableSnapshot(id value) {
    if (!value || [value isKindOfClass:NSString.class] ||
        ![value conformsToProtocol:@protocol(NSFastEnumeration)]) return @[];
    NSMutableArray *items = [NSMutableArray array];
    @try {
        for (id item in value) if (item) [items addObject:item];
    } @catch (__unused NSException *exception) {
        return @[];
    }
    return items;
}

NSArray *WCAtlasPrivateContactList(void) {
    NSCAssert(NSThread.isMainThread, @"Contact lists must be read on the main thread");
    id manager = WCAtlasPrivateService(@"CContactMgr");
    SEL selector = NSSelectorFromString(@"getContactList:contactType:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(manager, selector, 4);
    if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType) ||
        !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:2]) ||
        !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:3])) return @[];
    @try {
        id value = ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
            manager, selector, 1, 0);
        return WCAtlasPrivateEnumerableSnapshot(value);
    } @catch (NSException *exception) {
        WCAtlasLog(@"联系人列表适配调用失败：%@", exception.reason ?: exception.name);
        return @[];
    }
}

static BOOL WCAtlasPrivateContactIsGroup(id contact, NSString *userName) {
    if ([userName hasSuffix:@"@chatroom"]) return YES;
    SEL selector = NSSelectorFromString(@"isChatroom");
    NSMethodSignature *signature = WCAtlasPrivateSignature(contact, selector, 2);
    if (!signature || !WCAtlasPrivateTypeIsInteger(signature.methodReturnType)) return NO;
    @try { return ((BOOL (*)(id, SEL))objc_msgSend)(contact, selector); }
    @catch (__unused NSException *exception) { return NO; }
}

NSArray *WCAtlasPrivateGroupContactList(void) {
    NSCAssert(NSThread.isMainThread, @"Group lists must be read on the main thread");
    NSMutableArray *groups = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    void (^appendContact)(id) = ^(id contact) {
        NSString *userName = WCAtlasPrivateContactUserName(contact);
        if (userName.length == 0 || [seen containsObject:userName] ||
            !WCAtlasPrivateContactIsGroup(contact, userName)) return;
        [seen addObject:userName];
        [groups addObject:contact];
    };

    id sessionManager = WCAtlasPrivateService(@"MMNewSessionMgr");
    id sessions = WCAtlasPrivateNoArgumentObject(sessionManager, @"SessionNewArray");
    for (id session in WCAtlasPrivateEnumerableSnapshot(sessions)) {
        NSString *userName = WCAtlasPrivateContactUserName(session);
        if (userName.length == 0 || [seen containsObject:userName]) continue;
        appendContact(WCAtlasPrivateContact(userName));
    }
    for (id contact in WCAtlasPrivateContactList()) appendContact(contact);

    id dataLogic = WCAtlasPrivateService(@"ContactsDataLogic");
    id cachedGroups = WCAtlasPrivateNoArgumentObject(dataLogic, @"getChatRoomContacts");
    for (id contact in WCAtlasPrivateEnumerableSnapshot(cachedGroups)) appendContact(contact);
    return groups;
}

#pragma mark - Homepage Sessions

static id WCAtlasPrivateHomeObjectAtIndexPath(id target, NSIndexPath *indexPath) {
    if (!target || !indexPath) return nil;
    for (NSString *selectorName in @[@"getCellDataAtIndexPath:", @"getSessionInfoAtIndexPath:"]) {
        SEL selector = NSSelectorFromString(selectorName);
        NSMethodSignature *signature = WCAtlasPrivateSignature(target, selector, 3);
        if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType) ||
            !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1))) continue;
        @try {
            id value = ((id (*)(id, SEL, id))objc_msgSend)(target, selector, indexPath);
            if (value) return value;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

id WCAtlasPrivateHomeSessionData(id owner, UITableView *tableView, NSIndexPath *indexPath) {
    NSCAssert(NSThread.isMainThread, @"Homepage sessions must be read on the main thread");
    if (!indexPath) return nil;
    id data = WCAtlasPrivateHomeObjectAtIndexPath(owner, indexPath);
    if (data) return data;
    if (!tableView) return nil;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    data = WCAtlasPrivateObjectField(cell, @[@"m_cellData", @"cellData", @"m_sessionInfo", @"sessionInfo"]);
    if (data) return data;
    id delegate = tableView.delegate;
    return delegate != owner ? WCAtlasPrivateHomeObjectAtIndexPath(delegate, indexPath) : nil;
}

static NSString *WCAtlasPrivateHomeSessionUserNameAtDepth(id sessionData, NSUInteger depth) {
    if (!sessionData || depth > 4) return nil;
    NSString *userName = WCAtlasPrivateContactUserName(sessionData);
    if (userName.length > 0) return userName;
    id nested = WCAtlasPrivateObjectField(sessionData,
        @[@"m_cellData", @"cellData", @"m_sessionInfo", @"sessionInfo", @"m_contact", @"contact"]);
    return nested == sessionData ? nil : WCAtlasPrivateHomeSessionUserNameAtDepth(nested, depth + 1);
}

NSString *WCAtlasPrivateHomeSessionUserName(id sessionData) {
    return WCAtlasPrivateHomeSessionUserNameAtDepth(sessionData, 0);
}

static BOOL WCAtlasPrivateInvokeObjectSetter(id receiver, NSString *name, id value) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = WCAtlasPrivateSignature(receiver, selector, 3);
    if (!signature || !WCAtlasPrivateTypeIsVoid(signature.methodReturnType) ||
        !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1))) return NO;
    @try {
        ((void (*)(id, SEL, id))objc_msgSend)(receiver, selector, value);
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static void WCAtlasPrivateSetHomeScalar(id object, NSString *key, NSNumber *value) {
    @try { [object setValue:value forKey:key]; }
    @catch (__unused NSException *exception) {}
}

static NSUInteger WCAtlasPrivateHomeUnsignedValue(id object, NSArray<NSString *> *names) {
    for (NSString *name in names) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature = WCAtlasPrivateSignature(object, selector, 2);
        if (signature) {
            @try {
                if (WCAtlasPrivateTypeIsInteger(signature.methodReturnType)) {
                    return ((NSUInteger (*)(id, SEL))objc_msgSend)(object, selector);
                }
                if (WCAtlasPrivateTypeIsObject(signature.methodReturnType)) {
                    id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                    if ([value respondsToSelector:@selector(unsignedIntegerValue)]) {
                        return [value unsignedIntegerValue];
                    }
                }
            } @catch (__unused NSException *exception) {}
        }
        @try {
            id value = [object valueForKey:name];
            if ([value respondsToSelector:@selector(unsignedIntegerValue)]) {
                return [value unsignedIntegerValue];
            }
        } @catch (__unused NSException *exception) {}
    }
    return 0;
}

NSDictionary<NSString *, NSNumber *> *WCAtlasPrivateHomeUnreadStateForUserNames(NSArray *memberUserNames) {
    NSCAssert(NSThread.isMainThread, @"Homepage unread state must be read on the main thread");
    if (![memberUserNames isKindOfClass:NSArray.class] || memberUserNames.count == 0) {
        return @{@"count": @0, @"dot": @NO};
    }
    id manager = WCAtlasPrivateService(@"MMNewSessionMgr");
    SEL selector = NSSelectorFromString(@"GetSessionByUserName:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(manager, selector, 3);
    if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType) ||
        !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1))) {
        return @{@"count": @0, @"dot": @NO};
    }
    NSUInteger total = 0;
    BOOL hasDot = NO;
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (id value in memberUserNames) {
        NSString *userName = WCAtlasPrivateNonemptyString(value);
        if (userName.length == 0 || [userName hasPrefix:@"wcatlas_home_category_"] ||
            [seen containsObject:userName]) continue;
        [seen addObject:userName];
        @try {
            id session = ((id (*)(id, SEL, id))objc_msgSend)(manager, selector, userName);
            NSUInteger unread = WCAtlasPrivateHomeUnsignedValue(
                session, @[@"m_uUnReadCount", @"unReadCount", @"unreadCount"]);
            BOOL showAsDot = unread > 0 && WCAtlasPrivateHomeUnsignedValue(
                session, @[@"m_bShowUnReadAsRedDot", @"showUnReadAsRedDot"]) != 0;
            if (unread > 0 && !showAsDot) {
                id contact = WCAtlasPrivateObjectField(session, @[@"m_contact", @"contact"]);
                if (!contact) contact = WCAtlasPrivateContact(userName);
                showAsDot = WCAtlasPrivateHomeUnsignedValue(
                    contact, @[@"isDoNotDisturbMode"]) != 0;
            }
            if (showAsDot) hasDot = YES;
            else total = unread > NSUIntegerMax - total ? NSUIntegerMax : total + unread;
        } @catch (__unused NSException *exception) {}
    }
    return @{@"count": @(total), @"dot": @(hasDot)};
}

static id WCAtlasPrivateCreateHomeCategorySession(NSDictionary *entry) {
    NSString *userName = WCAtlasPrivateNonemptyString(entry[@"userName"]);
    NSString *title = WCAtlasPrivateNonemptyString(entry[@"title"]);
    if (userName.length == 0 || title.length == 0) return nil;
    Class contactClass = NSClassFromString(@"CContact");
    Class sessionClass = NSClassFromString(@"MMSessionInfo");
    if (!contactClass || !sessionClass) return nil;
    @try {
        id contact = [[contactClass alloc] init];
        id session = [[sessionClass alloc] init];
        BOOL contactUserNameSet = WCAtlasPrivateInvokeObjectSetter(contact, @"setM_nsUsrName:", userName) ||
                                  WCAtlasPrivateInvokeObjectSetter(contact, @"setM_nsUserName:", userName);
        BOOL sessionUserNameSet = WCAtlasPrivateInvokeObjectSetter(session, @"setM_nsUserName:", userName) ||
                                  WCAtlasPrivateInvokeObjectSetter(session, @"setM_nsUsrName:", userName);
        if (!contact || !session || !contactUserNameSet || !sessionUserNameSet ||
            !WCAtlasPrivateInvokeObjectSetter(contact, @"setM_nsNickName:", title) ||
            !WCAtlasPrivateInvokeObjectSetter(contact, @"setM_nsRemark:", title) ||
            !WCAtlasPrivateInvokeObjectSetter(session, @"setM_contact:", contact)) return nil;
        NSString *subtitle = WCAtlasPrivateNonemptyString(entry[@"subtitle"]);
        WCAtlasPrivateInvokeObjectSetter(session, @"setM_draftMsg:", subtitle ?: @"");
        NSDictionary<NSString *, NSNumber *> *unreadState =
            WCAtlasPrivateHomeUnreadStateForUserNames(entry[@"sessionUserNames"]);
        NSUInteger unreadCount = [unreadState[@"count"] unsignedIntegerValue];
        BOOL showAsDot = unreadCount == 0 && [unreadState[@"dot"] boolValue];
        WCAtlasPrivateSetHomeScalar(session, @"m_uUnReadCount",
                                    @(unreadCount > 0 ? unreadCount : (showAsDot ? 1 : 0)));
        WCAtlasPrivateSetHomeScalar(session, @"m_bShowUnReadAsRedDot", @(showAsDot));
        WCAtlasPrivateSetHomeScalar(session, @"m_uLastTime", @0);
        WCAtlasPrivateSetHomeScalar(session, @"m_bShouldUpdateTimeField", @NO);
        WCAtlasPrivateSetHomeScalar(session, @"m_bIsTop", @NO);
        WCAtlasPrivateSetHomeScalar(session, @"m_uTopTime", @0);
        WCAtlasPrivateSetHomeScalar(session, @"sortTime", @(-1));
        return session;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL WCAtlasPrivateHomeSessionIsPinned(id session) {
    for (NSString *key in @[@"m_bIsTop", @"m_uTopTime"]) {
        @try {
            id value = [session valueForKey:key];
            if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) return YES;
        } @catch (__unused NSException *exception) {}
    }
    return NO;
}

static NSMutableDictionary<NSString *, id> *WCAtlasPrivateHomeCategorySessionCache(void) {
    static NSMutableDictionary<NSString *, id> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

id WCAtlasPrivateHomeCategorySession(NSString *userName) {
    NSCAssert(NSThread.isMainThread, @"Homepage category sessions must be read on the main thread");
    return userName.length > 0 ? WCAtlasPrivateHomeCategorySessionCache()[userName] : nil;
}

NSUInteger WCAtlasPrivateHomeCategoryUnreadCountForUserName(NSString *userName) {
    NSCAssert(NSThread.isMainThread, @"Homepage category unread counts must be read on the main thread");
    id session = WCAtlasPrivateHomeCategorySession(userName);
    if (WCAtlasPrivateHomeUnsignedValue(
            session, @[@"m_bShowUnReadAsRedDot", @"showUnReadAsRedDot"]) != 0) return 0;
    return WCAtlasPrivateHomeUnsignedValue(
        session, @[@"m_uUnReadCount", @"unReadCount", @"unreadCount"]);
}

BOOL WCAtlasPrivateHomeCategoryShowsUnreadDot(NSString *userName) {
    NSCAssert(NSThread.isMainThread, @"Homepage category unread dots must be read on the main thread");
    id session = WCAtlasPrivateHomeCategorySession(userName);
    return WCAtlasPrivateHomeUnsignedValue(
        session, @[@"m_bShowUnReadAsRedDot", @"showUnReadAsRedDot"]) != 0;
}

BOOL WCAtlasPrivateConfigureHomeCategoryCellData(id cellData, NSString *title, NSString *subtitle,
                                                 NSString *avatarUserName) {
    NSCAssert(NSThread.isMainThread, @"Homepage category cell data must be formatted on the main thread");
    if (!cellData || title.length == 0) return NO;
    if (!WCAtlasPrivateInvokeObjectSetter(cellData, @"setM_textForNameLabel:", title) ||
        !WCAtlasPrivateInvokeObjectSetter(cellData, @"setM_textForMessageLabel:", subtitle ?: @"") ||
        !WCAtlasPrivateInvokeObjectSetter(cellData, @"setM_textForTimeLabel:", @"")) return NO;
    if (avatarUserName.length > 0) {
        WCAtlasPrivateInvokeObjectSetter(cellData, @"setM_nsHeadImgUsrName:", avatarUserName);
        NSString *URLString = WCAtlasPrivateContactHeadImageURL(WCAtlasPrivateContact(avatarUserName));
        if (URLString.length > 0) WCAtlasPrivateInvokeObjectSetter(cellData, @"setM_nsHeadImgUrl:", URLString);
    }
    SEL updateSelector = NSSelectorFromString(@"updateWidthForNameLabel");
    NSMethodSignature *signature = WCAtlasPrivateSignature(cellData, updateSelector, 2);
    if (signature && WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) {
        @try { ((void (*)(id, SEL))objc_msgSend)(cellData, updateSelector); }
        @catch (__unused NSException *exception) {}
    }
    return YES;
}

BOOL WCAtlasPrivateConfigureVisibleHomeCategoryItemView(id itemView, NSString *title,
                                                        NSString *subtitle,
                                                        NSString *avatarUserName) {
    NSCAssert(NSThread.isMainThread, @"Visible homepage category views must be updated on the main thread");
    if (!itemView || title.length == 0) return NO;
    id cellData = WCAtlasPrivateObjectField(itemView, @[@"m_cellData", @"cellData"]);
    BOOL updated = WCAtlasPrivateConfigureHomeCategoryCellData(
        cellData, title, subtitle ?: @"", avatarUserName);
    NSArray<NSArray *> *labelValues = @[
        @[@"m_nameLabel", @"nameLabel", title],
        @[@"m_messageLabel", @"messageLabel", subtitle ?: @""],
        @[@"m_timeLabel", @"timeLabel", @""]
    ];
    for (NSArray *entry in labelValues) {
        id label = WCAtlasPrivateObjectField(itemView, @[entry[0], entry[1]]);
        if (![label isKindOfClass:UILabel.class]) continue;
        ((UILabel *)label).text = entry[2];
        updated = YES;
    }
    id headView = WCAtlasPrivateObjectField(itemView, @[@"m_frameHeadView", @"frameHeadView"]);
    if ([headView isKindOfClass:UIView.class]) {
        [(UIView *)headView setNeedsLayout];
        [(UIView *)headView layoutIfNeeded];
        updated = YES;
    }
    return updated;
}

BOOL WCAtlasPrivateReplaceHomeCategorySessions(
    id sessionManager,
    NSSet<NSString *> *hiddenUserNames,
    NSArray<NSDictionary *> *categoryEntries) {
    NSCAssert(NSThread.isMainThread, @"Homepage sessions must be replaced on the main thread");
    if (!sessionManager) return NO;
    SEL getter = NSSelectorFromString(@"normalSessions");
    SEL setter = NSSelectorFromString(@"setNormalSessions:");
    NSMethodSignature *getterSignature = WCAtlasPrivateSignature(sessionManager, getter, 2);
    NSMethodSignature *setterSignature = WCAtlasPrivateSignature(sessionManager, setter, 3);
    if (!getterSignature || !WCAtlasPrivateTypeIsObject(getterSignature.methodReturnType) ||
        !setterSignature || !WCAtlasPrivateTypeIsVoid(setterSignature.methodReturnType) ||
        !WCAtlasPrivateObjectArguments(setterSignature, NSMakeRange(2, 1))) return NO;
    @try {
        id nativeValue = ((id (*)(id, SEL))objc_msgSend)(sessionManager, getter);
        if (![nativeValue isKindOfClass:NSArray.class]) return NO;
        NSMutableArray *sessions = [(NSArray *)nativeValue mutableCopy];
        NSIndexSet *remove = [sessions indexesOfObjectsPassingTest:^BOOL(id session, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop;
            NSString *userName = WCAtlasPrivateHomeSessionUserName(session);
            return [userName hasPrefix:@"wcatlas_home_category_"] ||
                   (userName.length > 0 && [hiddenUserNames containsObject:userName]);
        }];
        [sessions removeObjectsAtIndexes:remove];
        NSUInteger insertionIndex = 0;
        while (insertionIndex < sessions.count &&
               WCAtlasPrivateHomeSessionIsPinned(sessions[insertionIndex])) insertionIndex++;
        NSMutableDictionary<NSString *, id> *replacementCache = [NSMutableDictionary dictionary];
        for (NSDictionary *entry in categoryEntries ?: @[]) {
            id session = WCAtlasPrivateCreateHomeCategorySession(entry);
            NSString *userName = WCAtlasPrivateNonemptyString(entry[@"userName"]);
            if (session && userName.length > 0) {
                replacementCache[userName] = session;
                [sessions insertObject:session atIndex:insertionIndex++];
            }
        }
        ((void (*)(id, SEL, id))objc_msgSend)(sessionManager, setter, sessions);
        [WCAtlasPrivateHomeCategorySessionCache() setDictionary:replacementCache];
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"首页分类原生会话适配失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

BOOL WCAtlasPrivateRefreshHomeSessionList(void) {
    NSCAssert(NSThread.isMainThread, @"Homepage sessions must be refreshed on the main thread");
    id manager = WCAtlasPrivateService(@"MainSessionMgr");
    SEL notifySelector = NSSelectorFromString(@"updateMainSessionListNotify:");
    NSMethodSignature *notifySignature = WCAtlasPrivateSignature(manager, notifySelector, 3);
    if (notifySignature && WCAtlasPrivateTypeIsVoid(notifySignature.methodReturnType) &&
        WCAtlasPrivateTypeIsInteger([notifySignature getArgumentTypeAtIndex:2])) {
        @try {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, notifySelector, YES);
            return YES;
        } @catch (__unused NSException *exception) {}
    }
    SEL updateSelector = NSSelectorFromString(@"updateMainSessionList");
    NSMethodSignature *updateSignature = WCAtlasPrivateSignature(manager, updateSelector, 2);
    if (!updateSignature || !WCAtlasPrivateTypeIsVoid(updateSignature.methodReturnType)) return NO;
    @try {
        ((void (*)(id, SEL))objc_msgSend)(manager, updateSelector);
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

#pragma mark - Rich Text Mentions

static char WCAtlasPrivateMentionMessageKey;
static char WCAtlasPrivateMentionRefreshedMessageKey;
static char WCAtlasPrivateMentionRichTextViewKey;

static id WCAtlasPrivateFindMentionRichTextSubview(id root, NSUInteger depth) {
    if (!root || depth > 12) return nil;
    Class richTextClass = NSClassFromString(@"RichTextView");
    if ((richTextClass && [root isKindOfClass:richTextClass]) ||
        [NSStringFromClass([root class]) isEqualToString:@"RichTextView"]) return root;
    if (![root isKindOfClass:UIView.class]) return nil;
    for (UIView *subview in [(UIView *)root subviews]) {
        id match = WCAtlasPrivateFindMentionRichTextSubview(subview, depth + 1);
        if (match) return match;
    }
    return nil;
}

static id WCAtlasPrivateMentionRichTextView(id cell) {
    id associated = objc_getAssociatedObject(cell, &WCAtlasPrivateMentionRichTextViewKey);
    if (associated) return associated;
    id richTextView = WCAtlasPrivateObjectField(cell,
        @[@"getRichTextView", @"richTextView", @"m_richTextView"]);
    return richTextView ?: WCAtlasPrivateFindMentionRichTextSubview(cell, 0);
}

static BOOL WCAtlasPrivateLooksLikeMessageWrap(id value) {
    if (!value || [value isKindOfClass:NSString.class] ||
        [value isKindOfClass:NSAttributedString.class]) return NO;
    Class messageWrapClass = NSClassFromString(@"CMessageWrap");
    if (messageWrapClass && [value isKindOfClass:messageWrapClass]) return YES;
    id type = WCAtlasPrivateObjectField(value, @[@"m_uiMessageType", @"messageType"]);
    id from = WCAtlasPrivateObjectField(value, @[@"m_nsFromUsr", @"fromUser"]);
    id to = WCAtlasPrivateObjectField(value, @[@"m_nsToUsr", @"toUser"]);
    id mentions = WCAtlasPrivateObjectField(value,
        @[@"m_nsAtUserList", @"atUserList", @"m_nsMsgSource", @"msgSource"]);
    return mentions != nil || (type != nil && (from != nil || to != nil));
}

static id WCAtlasPrivateMessageWrapFromViewModel(id viewModel) {
    if (!viewModel) return nil;
    id message = WCAtlasPrivateObjectField(viewModel,
        @[@"getCurrentMessageWrap", @"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
    if (WCAtlasPrivateLooksLikeMessageWrap(message)) return message;
    id parent = WCAtlasPrivateObjectField(viewModel, @[@"parentModel", @"m_parentModel"]);
    message = WCAtlasPrivateObjectField(parent,
        @[@"getCurrentMessageWrap", @"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
    if (WCAtlasPrivateLooksLikeMessageWrap(message)) return message;
    // Only a real CMessageWrap (or a compatible wrapper exposing message metadata)
    // may be used directly. TextMessageViewModel also exposes text content, so a
    // content-only check incorrectly binds the view model and loses m_nsAtUserList.
    return WCAtlasPrivateLooksLikeMessageWrap(viewModel) ? viewModel : nil;
}

static id WCAtlasPrivateMentionMessageWrap(id richTextView) {
    id associated = objc_getAssociatedObject(richTextView, &WCAtlasPrivateMentionMessageKey);
    if (associated) return associated;
    // TextMessageViewModel style getters call the mention adapter before a live cell/rich view is
    // available. Resolve BaseMessageViewModel.messageWrap directly in that path; otherwise the
    // official m_nsAtUserList is invisible and no mention styles can be produced.
    id directMessage = WCAtlasPrivateMessageWrapFromViewModel(richTextView);
    if (directMessage) return directMessage;
    if (WCAtlasPrivateLooksLikeMessageWrap(richTextView)) return richTextView;
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSString *field in @[@"linkDelegate", @"layoutDelegate", @"delegate", @"m_delegate"]) {
        id delegate = WCAtlasPrivateObjectField(richTextView, @[field]);
        if (delegate && ![candidates containsObject:delegate]) [candidates addObject:delegate];
    }
    id responder = richTextView;
    for (NSUInteger depth = 0; responder && depth < 64; depth++) {
        if (![candidates containsObject:responder]) [candidates addObject:responder];
        id next = WCAtlasPrivateNoArgumentObject(responder, @"nextResponder");
        if (!next || next == responder) break;
        responder = next;
    }
    id superview = WCAtlasPrivateNoArgumentObject(richTextView, @"superview");
    for (NSUInteger depth = 0; superview && depth < 64; depth++) {
        if (![candidates containsObject:superview]) [candidates addObject:superview];
        id next = WCAtlasPrivateNoArgumentObject(superview, @"superview");
        if (!next || next == superview) break;
        superview = next;
    }
    for (id object in candidates) {
        id wrap = WCAtlasPrivateObjectField(object, @[@"getCurrentMessageWrap", @"currentMessageWrap",
                                                       @"messageWrap", @"m_messageWrap", @"msgWrap"]);
        if (WCAtlasPrivateLooksLikeMessageWrap(wrap)) return wrap;
        id viewModel = WCAtlasPrivateObjectField(object, @[@"viewModel", @"m_viewModel"]);
        wrap = WCAtlasPrivateObjectField(viewModel, @[@"getCurrentMessageWrap", @"messageWrap",
                                                       @"m_messageWrap", @"msgWrap"]);
        if (WCAtlasPrivateLooksLikeMessageWrap(wrap)) return wrap;
    }
    return nil;
}

static BOOL WCAtlasPrivateBindResolvedMentionContext(id cell, id richTextView,
                                                       id viewModel, BOOL refresh) {
    if (!cell || !richTextView) return NO;
    // Preserve the exact delegate-returned view even if WeChat has not attached the
    // view model yet; the following setter/layout callback can then complete binding.
    objc_setAssociatedObject(cell, &WCAtlasPrivateMentionRichTextViewKey,
                             richTextView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id message = WCAtlasPrivateMessageWrapFromViewModel(viewModel);
    if (!message) {
        message = WCAtlasPrivateMessageWrapFromViewModel(WCAtlasPrivateObjectField(cell,
            @[@"viewModel", @"m_viewModel"]));
    }
    if (!message) {
        id candidate = WCAtlasPrivateObjectField(cell,
            @[@"getCurrentMessageWrap", @"currentMessageWrap", @"messageWrap", @"m_messageWrap", @"msgWrap"]);
        if (WCAtlasPrivateLooksLikeMessageWrap(candidate)) message = candidate;
    }
    if (!message) return NO;
    objc_setAssociatedObject(richTextView, &WCAtlasPrivateMentionMessageKey,
                             message, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasPrivateEnableMentionClickHandling(richTextView);
    if (!refresh) return YES;
    if (objc_getAssociatedObject(richTextView, &WCAtlasPrivateMentionRefreshedMessageKey) == message) return YES;
    id styles = WCAtlasPrivateObjectField(richTextView, @[@"arrStyles"]);
    id content = WCAtlasPrivateObjectField(richTextView, @[@"getContent", @"content", @"nsContent"]);
    if (![styles isKindOfClass:NSArray.class] || ![content isKindOfClass:NSString.class]) return YES;
    SEL selector = NSSelectorFromString(@"setArrStyles:withContent:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(richTextView, selector, 4);
    if (!signature || !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2))) return YES;
    @try {
        if (WCAtlasPrivateTypeIsInteger(signature.methodReturnType)) {
            ((BOOL (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, content);
        } else if (WCAtlasPrivateTypeIsObject(signature.methodReturnType)) {
            ((id (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, content);
        } else if (WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, content);
        } else {
            return YES;
        }
        objc_setAssociatedObject(richTextView, &WCAtlasPrivateMentionRefreshedMessageKey,
                                 message, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    @catch (__unused NSException *exception) {}
    return YES;
}

BOOL WCAtlasPrivateBindMentionContext(id cell, id viewModel, BOOL refresh) {
    NSCAssert(NSThread.isMainThread, @"Mention context must be bound on the main thread");
    if (!cell) return NO;
    return WCAtlasPrivateBindResolvedMentionContext(cell,
        WCAtlasPrivateMentionRichTextView(cell), viewModel, refresh);
}

BOOL WCAtlasPrivateBindMentionRichTextView(id cell, id richTextView,
                                            id viewModel, BOOL refresh) {
    NSCAssert(NSThread.isMainThread, @"Mention rich-text view must be bound on the main thread");
    return WCAtlasPrivateBindResolvedMentionContext(cell, richTextView, viewModel, refresh);
}

BOOL WCAtlasPrivateReplayMentionStyles(id richTextView, NSString *content) {
    NSCAssert(NSThread.isMainThread, @"Mention styles must be replayed on the main thread");
    if (!richTextView) return NO;
    id styles = WCAtlasPrivateObjectField(richTextView, @[@"arrStyles"]);
    NSString *resolvedContent = [content isKindOfClass:NSString.class] ? content : nil;
    if (!resolvedContent) {
        id current = WCAtlasPrivateObjectField(richTextView, @[@"getContent", @"content", @"nsContent"]);
        if ([current isKindOfClass:NSString.class]) resolvedContent = current;
    }
    if (![styles isKindOfClass:NSArray.class] || resolvedContent.length == 0) return NO;
    SEL selector = NSSelectorFromString(@"setArrStyles:withContent:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(richTextView, selector, 4);
    if (!signature || !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2))) return NO;
    @try {
        if (WCAtlasPrivateTypeIsInteger(signature.methodReturnType)) {
            ((BOOL (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, resolvedContent);
        } else if (WCAtlasPrivateTypeIsObject(signature.methodReturnType)) {
            ((id (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, resolvedContent);
        } else if (WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(richTextView, selector, styles, resolvedContent);
        } else {
            return NO;
        }
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

void WCAtlasPrivateClearMentionContext(id cell) {
    NSCAssert(NSThread.isMainThread, @"Mention context must be cleared on the main thread");
    id richTextView = WCAtlasPrivateMentionRichTextView(cell);
    if (!richTextView) return;
    objc_setAssociatedObject(richTextView, &WCAtlasPrivateMentionMessageKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(richTextView, &WCAtlasPrivateMentionRefreshedMessageKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &WCAtlasPrivateMentionRichTextViewKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NSArray<NSString *> *WCAtlasPrivateMentionUserNames(id richTextView) {
    NSCAssert(NSThread.isMainThread, @"Mention metadata must be read on the main thread");
    id message = WCAtlasPrivateMentionMessageWrap(richTextView);
    id raw = WCAtlasPrivateObjectField(message, @[@"m_nsAtUserList", @"atUserList"]);
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    if ([raw isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)raw) {
            if ([value isKindOfClass:NSString.class] && [value length] > 0) [result addObject:value];
        }
        id atAll = WCAtlasPrivateObjectField(message, @[@"m_nsAtAll", @"m_bAtAll", @"atAll"]);
        if ([atAll respondsToSelector:@selector(boolValue)] && [atAll boolValue] &&
            ![result containsObject:@"notify@all"]) [result addObject:@"notify@all"];
        return result;
    }
    if (![raw isKindOfClass:NSString.class] || [raw length] == 0) {
        NSString *source = WCAtlasPrivateNonemptyString(
            WCAtlasPrivateObjectField(message, @[@"m_nsMsgSource", @"msgSource"]));
        if (source.length > 0) {
            NSRange open = [source rangeOfString:@"<atuserlist>" options:NSCaseInsensitiveSearch];
            NSRange close = [source rangeOfString:@"</atuserlist>" options:NSCaseInsensitiveSearch];
            if (open.location != NSNotFound && close.location != NSNotFound &&
                close.location >= NSMaxRange(open)) {
                raw = [source substringWithRange:NSMakeRange(NSMaxRange(open),
                    close.location - NSMaxRange(open))];
                raw = [(NSString *)raw stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
                raw = [(NSString *)raw stringByReplacingOccurrencesOfString:@"<![CDATA[" withString:@""];
                raw = [(NSString *)raw stringByReplacingOccurrencesOfString:@"]]>" withString:@""];
            }
        }
    }
    if ([raw isKindOfClass:NSString.class] && [raw length] > 0) {
        NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",;| \t\r\n"];
        for (NSString *part in [raw componentsSeparatedByCharactersInSet:separators]) {
            NSString *userName = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (userName.length > 0) [result addObject:userName];
        }
    }
    id atAll = WCAtlasPrivateObjectField(message, @[@"m_nsAtAll", @"m_bAtAll", @"atAll"]);
    if ([atAll respondsToSelector:@selector(boolValue)] && [atAll boolValue] &&
        ![result containsObject:@"notify@all"]) [result addObject:@"notify@all"];
    return result;
}

static NSArray<NSValue *> *WCAtlasPrivateVisibleMentionRanges(NSString *content) {
    if (content.length == 0) return @[];
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSCharacterSet *terminators = [NSCharacterSet characterSetWithCharactersInString:
        @"\u2004\u2005\t\r\n,，。！？!?：:；;（）()[]【】<>"];
    NSUInteger cursor = 0;
    while (cursor < content.length) {
        NSRange marker = [content rangeOfString:@"@" options:0
            range:NSMakeRange(cursor, content.length - cursor)];
        if (marker.location == NSNotFound) break;
        NSUInteger end = marker.location + 1;
        while (end < content.length) {
            unichar character = [content characterAtIndex:end];
            if ([terminators characterIsMember:character] ||
                (character == ' ' && end > marker.location + 1)) break;
            end++;
        }
        if (end > marker.location + 1) {
            [ranges addObject:[NSValue valueWithRange:
                NSMakeRange(marker.location, end - marker.location)]];
        }
        cursor = MAX(end, marker.location + 1);
    }
    return ranges;
}

static NSArray<NSString *> *WCAtlasPrivateMentionDisplayNames(NSString *userName,
                                                               id groupContact) {
    NSString *lowercase = userName.lowercaseString;
    if ([lowercase isEqualToString:@"notify@all"] || [lowercase isEqualToString:@"@all"] ||
        [lowercase isEqualToString:@"all"] || [lowercase isEqualToString:@"everyone"]) {
        return @[@"所有人", @"all", @"everyone"];
    }
    id contact = WCAtlasPrivateContact(userName);
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
    NSString *roomName = WCAtlasPrivateGroupMemberDisplayName(groupContact, contact);
    if (roomName.length > 0) [names addObject:roomName];
    for (NSString *name in @[WCAtlasPrivateContactRemark(contact) ?: @"",
                             WCAtlasPrivateContactNickname(contact) ?: @"",
                             WCAtlasPrivateContactDisplayName(contact, nil) ?: @""]) {
        if (name.length > 0) [names addObject:name];
    }
    return names.array;
}

NSArray<NSDictionary<NSString *, id> *> *WCAtlasPrivateMentionLinks(id context,
                                                                    NSString *content) {
    NSCAssert(NSThread.isMainThread, @"Mention links must be built on the main thread");
    if (![content isKindOfClass:NSString.class] || content.length == 0) return @[];
    NSArray<NSString *> *userNames = WCAtlasPrivateMentionUserNames(context);
    NSArray<NSValue *> *ranges = WCAtlasPrivateVisibleMentionRanges(content);
    if (userNames.count == 0 || ranges.count == 0) return @[];
    NSString *chatUserName = WCAtlasPrivateMentionChatUserName(context);
    id groupContact = [chatUserName hasSuffix:@"@chatroom"]
        ? WCAtlasPrivateContact(chatUserName) : nil;
    NSMutableIndexSet *usedRanges = [NSMutableIndexSet indexSet];
    NSMutableArray<NSDictionary<NSString *, id> *> *links = [NSMutableArray array];
    for (NSString *userName in userNames) {
        if (![userName isKindOfClass:NSString.class] || userName.length == 0) continue;
        NSUInteger matchedIndex = NSNotFound;
        NSArray<NSString *> *displayNames = WCAtlasPrivateMentionDisplayNames(userName, groupContact);
        for (NSUInteger index = 0; index < ranges.count && matchedIndex == NSNotFound; index++) {
            if ([usedRanges containsIndex:index]) continue;
            NSRange range = ranges[index].rangeValue;
            if (NSMaxRange(range) > content.length) continue;
            NSString *token = [content substringWithRange:range];
            NSString *visibleName = token.length > 1 ? [token substringFromIndex:1] : @"";
            if ([displayNames containsObject:visibleName]) matchedIndex = index;
        }
        if (matchedIndex == NSNotFound) {
            NSUInteger candidate = NSNotFound;
            for (NSUInteger index = 0; index < ranges.count; index++) {
                if (![usedRanges containsIndex:index]) { candidate = index; break; }
            }
            if (candidate < ranges.count) matchedIndex = candidate;
        }
        if (matchedIndex == NSNotFound || matchedIndex >= ranges.count) continue;
        NSRange range = ranges[matchedIndex].rangeValue;
        if (range.length == 0 || NSMaxRange(range) > content.length) continue;
        NSString *token = [content substringWithRange:range];
        [usedRanges addIndex:matchedIndex];
        [links addObject:@{@"token": token,
                           @"username": userName,
                           @"displayRange": [NSValue valueWithRange:range]}];
    }
    return links;
}

NSString *WCAtlasPrivateMentionChatUserName(id richTextView) {
    NSCAssert(NSThread.isMainThread, @"Mention chat metadata must be read on the main thread");
    id message = WCAtlasPrivateMentionMessageWrap(richTextView);
    for (NSString *field in @[@"m_nsFromUsr", @"m_nsToUsr", @"m_nsRealChatUsr",
                               @"fromUser", @"toUser", @"realChatUser"]) {
        id value = WCAtlasPrivateObjectField(message, @[field]);
        if ([value isKindOfClass:NSString.class] && [value hasSuffix:@"@chatroom"]) return value;
    }
    return nil;
}

BOOL WCAtlasPrivateEnableMentionClickHandling(id richTextView) {
    NSCAssert(NSThread.isMainThread, @"Mention click handling must be enabled on the main thread");
    SEL selector = NSSelectorFromString(@"setBHandleTextClick:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(richTextView, selector, 3);
    if (!signature || !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:2])) return NO;
    @try {
        if (WCAtlasPrivateTypeIsInteger(signature.methodReturnType)) {
            ((BOOL (*)(id, SEL, BOOL))objc_msgSend)(richTextView, selector, YES);
        } else if (WCAtlasPrivateTypeIsObject(signature.methodReturnType)) {
            ((id (*)(id, SEL, BOOL))objc_msgSend)(richTextView, selector, YES);
        } else if (WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(richTextView, selector, YES);
        } else {
            return NO;
        }
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL WCAtlasPrivateSetFirstValue(id object, id value, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        @try {
            [object setValue:value forKey:key];
            return YES;
        } @catch (__unused NSException *exception) {}
    }
    return NO;
}

id WCAtlasPrivateMentionLinkStyle(NSRange range, NSString *URLString) {
    NSCAssert(NSThread.isMainThread, @"Mention styles must be created on the main thread");
    Class styleClass = NSClassFromString(@"LinkStyle");
    if (!styleClass || range.location == NSNotFound || range.length == 0 || URLString.length == 0) return nil;
    id style = [[styleClass alloc] init];
    if (!style || !WCAtlasPrivateSetFirstValue(style, [NSValue valueWithRange:range],
                                               @[@"range", @"originalRange"]) ||
        !WCAtlasPrivateSetFirstValue(style, URLString, @[@"nsUrl", @"url", @"URL"])) return nil;
    WCAtlasPrivateSetFirstValue(style, URLString, @[@"nsSourceUrl", @"sourceUrl"]);
    WCAtlasPrivateSetFirstValue(style, @5, @[@"eDataDectorType", @"dataDetectorType"]);
    WCAtlasPrivateSetFirstValue(style, @1, @[@"jumpType"]);
    UIColor *clearColor = UIColor.clearColor;
    WCAtlasPrivateSetFirstValue(style, clearColor, @[@"oTextColor"]);
    WCAtlasPrivateSetFirstValue(style, clearColor, @[@"oDrawColor"]);
    WCAtlasPrivateSetFirstValue(style, clearColor, @[@"oHighlightedColor"]);
    WCAtlasPrivateSetFirstValue(style, @YES, @[@"bBackgroundEnabled", @"backgroundEnabled"]);
    WCAtlasPrivateSetFirstValue(style, @NO, @[@"bDrawsUnderLine", @"drawsUnderLine"]);
    return style;
}

BOOL WCAtlasPrivateConfigureMentionRichTextConfig(id config, UIColor *normalColor,
                                                  UIColor *highlightedColor) {
    NSCAssert(NSThread.isMainThread, @"Mention config must be updated on the main thread");
    if (!config || !normalColor || !highlightedColor) return NO;
    BOOL normalUpdated = WCAtlasPrivateSetFirstValue(config, normalColor, @[@"linkColor"]);
    BOOL highlightedUpdated = WCAtlasPrivateSetFirstValue(config, highlightedColor, @[@"linkHLColor"]);
    return normalUpdated || highlightedUpdated;
}

static NSString *WCAtlasPrivateMentionLinkURLStringAtDepth(id event, NSUInteger depth) {
    if (!event || depth > 4) return nil;
    if ([event isKindOfClass:NSString.class]) return event;
    if ([event isKindOfClass:NSURL.class]) return [event absoluteString];
    if ([event isKindOfClass:NSDictionary.class]) {
        for (NSString *key in @[@"url", @"URL", @"nsUrl", @"link", @"style",
                                @"LinkStyle", @"mention"]) {
            NSString *candidate = WCAtlasPrivateMentionLinkURLStringAtDepth(event[key], depth + 1);
            if (candidate.length > 0) return candidate;
        }
    }
    id nested = WCAtlasPrivateObjectField(event,
        @[@"nsUrl", @"url", @"URL", @"linkStyle", @"LinkStyle", @"style", @"mention"]);
    return nested == event ? nil : WCAtlasPrivateMentionLinkURLStringAtDepth(nested, depth + 1);
}

NSString *WCAtlasPrivateMentionLinkURLString(id event) {
    NSCAssert(NSThread.isMainThread, @"Mention link events must be read on the main thread");
    return WCAtlasPrivateMentionLinkURLStringAtDepth(event, 0);
}

BOOL WCAtlasPrivateJumpToMentionProfile(id context, NSString *userName,
                                        NSString *displayName, NSInteger scene) {
    NSCAssert(NSThread.isMainThread, @"Mention profile navigation must run on the main thread");
    if (!context || userName.length == 0) return NO;
    SEL selector = NSSelectorFromString(@"jumpToUserProfile:Displayname:Scence:");
    NSMutableArray *candidates = [NSMutableArray arrayWithObject:context];
    for (NSString *field in @[@"delegate", @"linkDelegate", @"layoutDelegate", @"m_delegate"]) {
        id candidate = WCAtlasPrivateObjectField(context, @[field]);
        if (candidate && ![candidates containsObject:candidate]) [candidates addObject:candidate];
    }
    id responder = context;
    for (NSUInteger depth = 0; responder && depth < 32; depth++) {
        if (![candidates containsObject:responder]) [candidates addObject:responder];
        id next = WCAtlasPrivateNoArgumentObject(responder, @"nextResponder");
        if (!next || next == responder) break;
        responder = next;
    }
    for (id target in candidates) {
        NSMethodSignature *signature = WCAtlasPrivateSignature(target, selector, 5);
        if (!signature || !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2)) ||
            !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:4])) continue;
        @try {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = target;
            invocation.selector = selector;
            id resolvedUserName = userName;
            id resolvedDisplayName = displayName ?: @"";
            NSInteger resolvedScene = scene;
            [invocation setArgument:&resolvedUserName atIndex:2];
            [invocation setArgument:&resolvedDisplayName atIndex:3];
            [invocation setArgument:&resolvedScene atIndex:4];
            [invocation invoke];
            return YES;
        } @catch (__unused NSException *exception) {}
    }
    return NO;
}

#pragma mark - Moments Upload Metadata

id WCAtlasPrivateCreateMomentsAppInfo(NSString *appID, NSString *appName) {
    NSString *resolvedID = WCAtlasPrivateNonemptyString(appID);
    NSString *resolvedName = WCAtlasPrivateNonemptyString(appName);
    Class appInfoClass = NSClassFromString(@"WCAppInfo");
    if (!appInfoClass || resolvedID.length == 0 || resolvedName.length == 0) return nil;

    SEL initSelector = @selector(init);
    SEL appIDSelector = NSSelectorFromString(@"setAppID:");
    SEL appNameSelector = NSSelectorFromString(@"setAppName:");
    NSMethodSignature *initSignature = [appInfoClass instanceMethodSignatureForSelector:initSelector];
    NSMethodSignature *appIDSignature = [appInfoClass instanceMethodSignatureForSelector:appIDSelector];
    NSMethodSignature *appNameSignature = [appInfoClass instanceMethodSignatureForSelector:appNameSelector];
    if (!initSignature || initSignature.numberOfArguments != 2 ||
        !WCAtlasPrivateTypeIsObject(initSignature.methodReturnType) ||
        !appIDSignature || appIDSignature.numberOfArguments != 3 ||
        !WCAtlasPrivateTypeIsVoid(appIDSignature.methodReturnType) ||
        !WCAtlasPrivateTypeIsObject([appIDSignature getArgumentTypeAtIndex:2]) ||
        !appNameSignature || appNameSignature.numberOfArguments != 3 ||
        !WCAtlasPrivateTypeIsVoid(appNameSignature.methodReturnType) ||
        !WCAtlasPrivateTypeIsObject([appNameSignature getArgumentTypeAtIndex:2])) return nil;

    @try {
        id info = [[appInfoClass alloc] init];
        if (!info) return nil;
        ((void (*)(id, SEL, id))objc_msgSend)(info, appIDSelector, resolvedID);
        ((void (*)(id, SEL, id))objc_msgSend)(info, appNameSelector, resolvedName);
        return info;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static char WCAtlasPrivateMomentsTailCellKey;
static char WCAtlasPrivateMomentsTailManagerKey;

static id WCAtlasPrivateMomentsTableManager(id composer) {
    if (!composer) return nil;
    @try { return [composer valueForKey:@"m_tableViewManager"]; }
    @catch (__unused NSException *exception) { return nil; }
}

static id WCAtlasPrivateCreateMomentsTailCell(id composer, SEL action, NSString *rightValue) {
    Class cellClass = NSClassFromString(@"WCTableViewCellManager");
    if (!cellClass || !action || rightValue.length == 0) return nil;
    SEL selector = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:titleColor:badge:rightValue:rightImage:withRightRedDot:selected:");
    NSMethodSignature *signature = [cellClass methodSignatureForSelector:selector];
    if (signature.numberOfArguments == 12 && WCAtlasPrivateTypeIsObject(signature.methodReturnType) &&
        WCAtlasPrivateTypeIsSelector([signature getArgumentTypeAtIndex:2]) &&
        WCAtlasPrivateObjectArguments(signature, NSMakeRange(3, 7)) &&
        WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:10]) &&
        WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:11])) {
        return ((id (*)(id, SEL, SEL, id, id, id, id, id, id, id, BOOL, BOOL))objc_msgSend)(
            cellClass, selector, action, composer, nil, @"发圈尾巴", nil, nil, rightValue, nil, NO, NO);
    }
    selector = NSSelectorFromString(@"normalCellForSel:target:title:rightValue:canRightValueCopy:");
    signature = [cellClass methodSignatureForSelector:selector];
    if (signature.numberOfArguments == 7 && WCAtlasPrivateTypeIsObject(signature.methodReturnType) &&
        WCAtlasPrivateTypeIsSelector([signature getArgumentTypeAtIndex:2]) &&
        WCAtlasPrivateObjectArguments(signature, NSMakeRange(3, 3)) &&
        WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:6])) {
        return ((id (*)(id, SEL, SEL, id, id, id, BOOL))objc_msgSend)(
            cellClass, selector, action, composer, @"发圈尾巴", rightValue, NO);
    }
    return nil;
}

BOOL WCAtlasPrivateInstallMomentsTailCell(id composer, SEL action, NSString *rightValue) {
    if (!NSThread.isMainThread || !composer || objc_getAssociatedObject(composer, &WCAtlasPrivateMomentsTailCellKey)) return NO;
    @try {
        id manager = WCAtlasPrivateMomentsTableManager(composer);
        SEL countSelector = NSSelectorFromString(@"getSectionCount");
        SEL sectionSelector = NSSelectorFromString(@"getSectionAt:");
        NSMethodSignature *countSignature = WCAtlasPrivateSignature(manager, countSelector, 2);
        NSMethodSignature *sectionSignature = WCAtlasPrivateSignature(manager, sectionSelector, 3);
        if (!WCAtlasPrivateTypeIsInteger(countSignature.methodReturnType) ||
            !WCAtlasPrivateTypeIsObject(sectionSignature.methodReturnType) ||
            !WCAtlasPrivateTypeIsInteger([sectionSignature getArgumentTypeAtIndex:2])) return NO;
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(manager, countSelector);
        if (count == 0) return NO;
        id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(manager, sectionSelector, 0);
        id cell = WCAtlasPrivateCreateMomentsTailCell(composer, action, rightValue);
        SEL addSelector = NSSelectorFromString(@"addCell:");
        NSMethodSignature *addSignature = WCAtlasPrivateSignature(section, addSelector, 3);
        if (!cell || !WCAtlasPrivateTypeIsObject(addSignature.methodReturnType) ||
            !WCAtlasPrivateTypeIsObject([addSignature getArgumentTypeAtIndex:2])) return NO;
        ((void (*)(id, SEL, id))objc_msgSend)(section, addSelector, cell);
        objc_setAssociatedObject(composer, &WCAtlasPrivateMomentsTailCellKey, cell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(composer, &WCAtlasPrivateMomentsTailManagerKey, manager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasPrivateReloadMomentsTailCell(composer, rightValue);
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

void WCAtlasPrivateReloadMomentsTailCell(id composer, NSString *rightValue) {
    if (!NSThread.isMainThread || !composer || rightValue.length == 0) return;
    id cell = objc_getAssociatedObject(composer, &WCAtlasPrivateMomentsTailCellKey);
    id manager = objc_getAssociatedObject(composer, &WCAtlasPrivateMomentsTailManagerKey);
    if (!cell || !manager) return;
    @try {
        for (NSString *keyPath in @[@"cellConfig.rightConfig.title", @"m_rightValue", @"rightValue"]) {
            @try { [cell setValue:rightValue forKeyPath:keyPath]; break; }
            @catch (__unused NSException *exception) {}
        }
        id tableView = WCAtlasPrivateNoArgumentObject(manager, @"tableView");
        if ([tableView respondsToSelector:@selector(reloadData)]) [tableView reloadData];
    } @catch (__unused NSException *exception) {}
}

void WCAtlasPrivateResignMomentsComposerInput(id composer) {
    if (!NSThread.isMainThread || !composer) return;
    SEL selector = NSSelectorFromString(@"resignInput");
    NSMethodSignature *signature = WCAtlasPrivateSignature(composer, selector, 2);
    if (!signature || !WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) return;
    @try { ((void (*)(id, SEL))objc_msgSend)(composer, selector); }
    @catch (__unused NSException *exception) {}
}

#pragma mark - Native Navigation

static UIViewController *WCAtlasPrivateProfileController(id contact,
                                                        NSString *userName) {
    Class controllerClass = NSClassFromString(@"ContactInfoViewController");
    if (!controllerClass) return nil;
    UIViewController *controller = [[controllerClass alloc] init];
    if (!controller) return nil;

    @try {
        [controller setValue:contact forKey:@"m_contact"];
        @try { [controller setValue:contact forKey:@"m_chatContact"]; }
        @catch (__unused NSException *exception) {}
        return controller;
    } @catch (__unused NSException *exception) {}

    SEL setter = NSSelectorFromString(@"setM_contact:");
    NSMethodSignature *setterSignature = WCAtlasPrivateSignature(controller, setter, 3);
    if (setterSignature && WCAtlasPrivateTypeIsVoid(setterSignature.methodReturnType) &&
        WCAtlasPrivateObjectArguments(setterSignature, NSMakeRange(2, 1))) {
        @try {
            ((void (*)(id, SEL, id))objc_msgSend)(controller, setter, contact);
            @try { [controller setValue:contact forKey:@"m_chatContact"]; }
            @catch (__unused NSException *exception) {}
            return controller;
        } @catch (__unused NSException *exception) {}
    }
    WCAtlasLog(@"资料页联系人注入失败：%@", userName);
    return nil;
}

BOOL WCAtlasPushPrivateContactProfile(UIViewController *source, NSString *userName) {
    NSCAssert(NSThread.isMainThread, @"Native profile navigation must run on the main thread");
    if (!source || userName.length == 0) return NO;
    id contact = WCAtlasPrivateContact(userName);
    if (!contact) {
        WCAtlasLog(@"资料页适配未找到联系人：%@", userName);
        return NO;
    }
    UIViewController *controller = WCAtlasPrivateProfileController(contact, userName);
    if (!controller) {
        WCAtlasLog(@"资料页适配无法构造控制器：%@", userName);
        return NO;
    }
    UINavigationController *navigationController = source.navigationController;
    if (!navigationController && [source isKindOfClass:UINavigationController.class]) {
        navigationController = (UINavigationController *)source;
    }
    if (navigationController) {
        [navigationController pushViewController:controller animated:YES];
    } else {
        [source presentViewController:controller animated:YES completion:nil];
    }
    return YES;
}

static UINavigationController *WCAtlasPrivateNavigationController(UIViewController *source) {
    if ([source isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)source;
    }
    if (source.navigationController) return source.navigationController;
    Class managerClass = NSClassFromString(@"CAppViewControllerManager");
    SEL selector = NSSelectorFromString(@"getCurrentNavigationController");
    NSMethodSignature *signature = WCAtlasPrivateSignature(managerClass, selector, 2);
    if (!signature || !WCAtlasPrivateTypeIsObject(signature.methodReturnType)) return nil;
    @try {
        id navigationController = ((id (*)(id, SEL))objc_msgSend)(managerClass, selector);
        return [navigationController isKindOfClass:UINavigationController.class]
            ? navigationController : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

BOOL WCAtlasPushPrivateGroupProfile(UIViewController *source, NSString *groupUserName) {
    NSCAssert(NSThread.isMainThread, @"Native group navigation must run on the main thread");
    if (!source || ![groupUserName hasSuffix:@"@chatroom"]) return NO;
    id contact = WCAtlasPrivateContact(groupUserName);
    Class controllerClass = NSClassFromString(@"ChatRoomInfoViewController");
    UIViewController *controller = contact && controllerClass ? [[controllerClass alloc] init] : nil;
    if (!controller) return NO;

    BOOL injected = NO;
    SEL setter = NSSelectorFromString(@"setM_chatRoomContact:");
    NSMethodSignature *signature = WCAtlasPrivateSignature(controller, setter, 3);
    if (signature && WCAtlasPrivateTypeIsVoid(signature.methodReturnType) &&
        WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 1))) {
        @try {
            ((void (*)(id, SEL, id))objc_msgSend)(controller, setter, contact);
            injected = YES;
        } @catch (__unused NSException *exception) {}
    }
    if (!injected) {
        @try {
            [controller setValue:contact forKey:@"m_chatRoomContact"];
            injected = YES;
        } @catch (__unused NSException *exception) {}
    }
    UINavigationController *navigationController = WCAtlasPrivateNavigationController(source);
    if (!injected || !navigationController) return NO;
    [navigationController pushViewController:controller animated:YES];
    return YES;
}

static BOOL WCAtlasPrivatePushChatSelector(id messageLogic,
                                         NSString *selectorName,
                                         id target,
                                         UINavigationController *navigationController,
                                         BOOL animated) {
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature = WCAtlasPrivateSignature(messageLogic, selector, 5);
    if (!signature || !WCAtlasPrivateTypeIsVoid(signature.methodReturnType) ||
        !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2)) ||
        !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:4])) return NO;
    @try {
        ((void (*)(id, SEL, id, id, BOOL))objc_msgSend)(
            messageLogic, selector, target, navigationController, animated);
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"聊天页适配 %@ 调用失败：%@", selectorName,
                 exception.reason ?: exception.name);
        return NO;
    }
}

BOOL WCAtlasPushPrivateChat(UIViewController *source, NSString *userName, BOOL animated) {
    NSCAssert(NSThread.isMainThread, @"Native chat navigation must run on the main thread");
    NSString *resolvedUserName = [userName isKindOfClass:NSString.class] && userName.length > 0
        ? userName : nil;
    if (resolvedUserName.length == 0) return NO;
    UINavigationController *navigationController = WCAtlasPrivateNavigationController(source);
    if (!navigationController) return NO;
    UIViewController *visibleController = navigationController.visibleViewController;
    NSString *visibleUserName = WCAtlasPrivateChatUserName(visibleController) ?: @"";
    if ([visibleUserName isEqualToString:resolvedUserName]) {
        return YES;
    }

    id messageLogic = WCAtlasPrivateService(@"MMMsgLogicManager");
    if (WCAtlasPrivatePushChatSelector(messageLogic,
            @"PushOtherBaseMsgControllerByUserName:navigationController:animated:",
            resolvedUserName, navigationController, animated)) return YES;
    id contact = WCAtlasPrivateContact(resolvedUserName);
    return contact && WCAtlasPrivatePushChatSelector(messageLogic,
            @"PushOtherBaseMsgControllerByContact:navigationController:animated:",
            contact, navigationController, animated);
}

#pragma mark - Message Submission

static BOOL WCAtlasPrivateSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0 || !value) return NO;
    NSString *capitalized = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                          withString:[[key substringToIndex:1] uppercaseString]];
    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@:", capitalized]);
    NSMethodSignature *signature = WCAtlasPrivateSignature(object, setter, 3);
    if (signature && WCAtlasPrivateTypeIsVoid(signature.methodReturnType)) {
        const char *argumentType = [signature getArgumentTypeAtIndex:2];
        @try {
            if (WCAtlasPrivateTypeIsObject(argumentType)) {
                ((void (*)(id, SEL, id))objc_msgSend)(object, setter, value);
                return YES;
            }
        } @catch (__unused NSException *exception) {}
    }
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static id WCAtlasPrivateInitializeMessageWrap(Class wrapClass,
                                             SEL initializer,
                                             char argumentCode) {
    id allocated = [wrapClass alloc];
    switch (argumentCode) {
        case 'c': return ((id (*)(id, SEL, signed char))objc_msgSend)(allocated, initializer, 1);
        case 'C': return ((id (*)(id, SEL, unsigned char))objc_msgSend)(allocated, initializer, 1);
        case 's': return ((id (*)(id, SEL, short))objc_msgSend)(allocated, initializer, 1);
        case 'S': return ((id (*)(id, SEL, unsigned short))objc_msgSend)(allocated, initializer, 1);
        case 'i': return ((id (*)(id, SEL, int))objc_msgSend)(allocated, initializer, 1);
        case 'I': return ((id (*)(id, SEL, unsigned int))objc_msgSend)(allocated, initializer, 1);
        case 'l': return ((id (*)(id, SEL, long))objc_msgSend)(allocated, initializer, 1);
        case 'L': return ((id (*)(id, SEL, unsigned long))objc_msgSend)(allocated, initializer, 1);
        case 'q': return ((id (*)(id, SEL, long long))objc_msgSend)(allocated, initializer, 1);
        case 'Q': return ((id (*)(id, SEL, unsigned long long))objc_msgSend)(allocated, initializer, 1);
        case 'B': return ((id (*)(id, SEL, BOOL))objc_msgSend)(allocated, initializer, YES);
        default: return nil;
    }
}

static void WCAtlasPrivateSubmitMessage(id manager,
                                      SEL selector,
                                      id target,
                                      id wrap,
                                      const char *returnType) {
    switch (WCAtlasPrivateUnqualifiedType(returnType)[0]) {
        case 'v': ((void (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'c': (void)((signed char (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'C': (void)((unsigned char (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 's': (void)((short (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'S': (void)((unsigned short (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'i': (void)((int (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'I': (void)((unsigned int (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'l': (void)((long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'L': (void)((unsigned long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'q': (void)((long long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'Q': (void)((unsigned long long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'B': (void)((BOOL (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        default: break;
    }
}

BOOL WCAtlasPrivateSendTextMessage(NSString *userName, NSString *text) {
    NSCAssert(NSThread.isMainThread, @"Message submission must run on the main thread");
    NSString *target = WCAtlasPrivateNonemptyString(userName);
    NSString *content = WCAtlasPrivateNonemptyString(text);
    NSString *currentUser = WCAtlasPrivateNonemptyString(WCAtlasCurrentUserWXID());
    if (target.length == 0 || content.length == 0 || currentUser.length == 0) return NO;

    Class wrapClass = NSClassFromString(@"CMessageWrap");
    SEL initializer = NSSelectorFromString(@"initWithMsgType:");
    Method initializerMethod = wrapClass ? class_getInstanceMethod(wrapClass, initializer) : NULL;
    if (!initializerMethod || method_getNumberOfArguments(initializerMethod) != 3) return NO;
    char *returnType = method_copyReturnType(initializerMethod);
    BOOL objectReturn = WCAtlasPrivateTypeIsObject(returnType);
    if (returnType) free(returnType);
    if (!objectReturn) return NO;
    char *argumentType = method_copyArgumentType(initializerMethod, 2);
    BOOL integerArgument = WCAtlasPrivateTypeIsInteger(argumentType);
    char argumentCode = WCAtlasPrivateUnqualifiedType(argumentType)[0];
    if (argumentType) free(argumentType);
    if (!integerArgument) return NO;

    id wrap = nil;
    @try {
        wrap = WCAtlasPrivateInitializeMessageWrap(wrapClass, initializer, argumentCode);
    } @catch (__unused NSException *exception) {
        return NO;
    }
    if (!wrap || !WCAtlasPrivateSetValue(wrap, @"m_nsFromUsr", currentUser) ||
        !WCAtlasPrivateSetValue(wrap, @"m_nsToUsr", target) ||
        !WCAtlasPrivateSetValue(wrap, @"m_nsContent", content)) return NO;
    WCAtlasPrivateSetValue(wrap, @"m_uiMessageType", @1);
    WCAtlasPrivateSetValue(wrap, @"m_uiStatus", @1);
    WCAtlasPrivateSetValue(wrap, @"m_uiCreateTime",
                         @((NSUInteger)NSDate.date.timeIntervalSince1970));

    id manager = WCAtlasPrivateService(@"CMessageMgr");
    SEL sendSelector = NSSelectorFromString(@"AddMsg:MsgWrap:");
    NSMethodSignature *sendSignature = WCAtlasPrivateSignature(manager, sendSelector, 4);
    if (!sendSignature ||
        !WCAtlasPrivateObjectArguments(sendSignature, NSMakeRange(2, 2)) ||
        (!WCAtlasPrivateTypeIsVoid(sendSignature.methodReturnType) &&
         !WCAtlasPrivateTypeIsInteger(sendSignature.methodReturnType))) return NO;
    @try {
        WCAtlasPrivateSubmitMessage(manager, sendSelector, target, wrap,
                                  sendSignature.methodReturnType);
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"文本消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

@interface WCAtlasPrivateMediaSendSession : NSObject
@property (nonatomic, strong) id logic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@end
@implementation WCAtlasPrivateMediaSendSession
@end

static _Atomic(double) WCAtlasPrivateVoiceUploadDeadline;

BOOL WCAtlasPrivateVoiceUploadCompatibilityActive(void) {
    return atomic_load(&WCAtlasPrivateVoiceUploadDeadline) > NSDate.date.timeIntervalSince1970;
}

static NSMutableSet<WCAtlasPrivateMediaSendSession *> *WCAtlasPrivateMediaSessions(void) {
    static NSMutableSet *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

BOOL WCAtlasPrivateSendImageMessage(NSString *userName, NSString *imagePath) {
    NSCAssert(NSThread.isMainThread, @"Image submission must run on the main thread");
    NSString *target = WCAtlasPrivateNonemptyString(userName);
    NSString *path = WCAtlasPrivateNonemptyString(imagePath);
    UIImage *image = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    id contact = target.length ? WCAtlasPrivateContact(target) : nil;
    Class providerClass = NSClassFromString(@"PasteboardMsgProvider");
    Class logicClass = NSClassFromString(@"ForwardMessageLogicController");
    SEL makeSelector = NSSelectorFromString(@"GetMessageFromImage:contact:");
    SEL sendSelector = NSSelectorFromString(@"forwardNoConfirmForMsgList:toContacts:");
    Method makeMethod = providerClass ? class_getClassMethod(providerClass, makeSelector) : NULL;
    Method sendMethod = logicClass ? class_getInstanceMethod(logicClass, sendSelector) : NULL;
    char *makeReturnType = makeMethod ? method_copyReturnType(makeMethod) : NULL;
    BOOL makeReturnsObject = WCAtlasPrivateTypeIsObject(makeReturnType);
    if (makeReturnType) free(makeReturnType);
    char *makeFirstType = makeMethod ? method_copyArgumentType(makeMethod, 2) : NULL;
    char *makeSecondType = makeMethod ? method_copyArgumentType(makeMethod, 3) : NULL;
    BOOL makeArgumentsAreObjects = WCAtlasPrivateTypeIsObject(makeFirstType) && WCAtlasPrivateTypeIsObject(makeSecondType);
    if (makeFirstType) free(makeFirstType);
    if (makeSecondType) free(makeSecondType);
    char *sendReturnType = sendMethod ? method_copyReturnType(sendMethod) : NULL;
    char sendReturnEncoding[2] = { WCAtlasPrivateUnqualifiedType(sendReturnType)[0], '\0' };
    char *sendFirstType = sendMethod ? method_copyArgumentType(sendMethod, 2) : NULL;
    char *sendSecondType = sendMethod ? method_copyArgumentType(sendMethod, 3) : NULL;
    BOOL sendABIValid = (WCAtlasPrivateTypeIsVoid(sendReturnType) || WCAtlasPrivateTypeIsInteger(sendReturnType)) &&
        WCAtlasPrivateTypeIsObject(sendFirstType) && WCAtlasPrivateTypeIsObject(sendSecondType);
    if (sendReturnType) free(sendReturnType);
    if (sendFirstType) free(sendFirstType);
    if (sendSecondType) free(sendSecondType);
    if (!image || !contact || !makeMethod || method_getNumberOfArguments(makeMethod) != 4 ||
        !makeReturnsObject || !makeArgumentsAreObjects ||
        !sendMethod || method_getNumberOfArguments(sendMethod) != 4 || !sendABIValid) return NO;
    id message = nil;
    id logic = nil;
    WCAtlasPrivateMediaSendSession *session = nil;
    @try {
        message = ((id (*)(id, SEL, id, id))objc_msgSend)(providerClass, makeSelector, image, contact);
        logic = message ? [logicClass new] : nil;
        if (!logic) return NO;
        session = [WCAtlasPrivateMediaSendSession new];
        session.logic = logic; session.message = message; session.contact = contact;
        [WCAtlasPrivateMediaSessions() addObject:session];
        WCAtlasPrivateSubmitMessage(logic, sendSelector, @[message], @[contact], sendReturnEncoding);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [WCAtlasPrivateMediaSessions() removeObject:session]; });
        return YES;
    } @catch (NSException *exception) {
        if (session) [WCAtlasPrivateMediaSessions() removeObject:session];
        WCAtlasLog(@"图片消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

static BOOL WCAtlasPrivateInvokeThreeObjects(id receiver, SEL selector, id first, id second, id third,
                                            const char *returnType) {
    switch (WCAtlasPrivateUnqualifiedType(returnType)[0]) {
        case 'v': ((void (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case '@': (void)((id (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'c': (void)((signed char (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'C': (void)((unsigned char (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 's': (void)((short (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'S': (void)((unsigned short (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'i': (void)((int (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'I': (void)((unsigned int (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'l': (void)((long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'L': (void)((unsigned long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'q': (void)((long long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'Q': (void)((unsigned long long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'B': (void)((BOOL (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        default: return NO;
    }
}

BOOL WCAtlasPrivateSendVideoMessage(NSString *userName, NSString *videoPath) {
    NSCAssert(NSThread.isMainThread, @"Video submission must run on the main thread");
    NSString *target = WCAtlasPrivateNonemptyString(userName);
    NSString *path = WCAtlasPrivateNonemptyString(videoPath);
    NSString *currentUser = WCAtlasPrivateNonemptyString(WCAtlasCurrentUserWXID());
    if (!target || !currentUser || ![NSFileManager.defaultManager fileExistsAtPath:path]) return NO;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!track) return NO;
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    CGImageRef frame = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.1, 600) actualTime:NULL error:nil];
    UIImage *thumbnail = frame ? [UIImage imageWithCGImage:frame] : nil;
    if (frame) CGImageRelease(frame);
    NSString *thumbnailPath = nil;
    NSData *thumbnailData = thumbnail ? UIImageJPEGRepresentation(thumbnail, 0.85) : nil;
    if (thumbnailData.length) {
        thumbnailPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"wcatlas-video-%@.jpg", NSUUID.UUID.UUIDString]];
        if (![thumbnailData writeToFile:thumbnailPath atomically:YES]) thumbnailPath = nil;
    }
    @try {
        id videoInfo = nil;
        Class highClass = NSClassFromString(@"OpenApiMgrHelper");
        SEL highSelector = NSSelectorFromString(@"genCaptureVideoInfoWithVideoData:mediaMessage:param:");
        NSMethodSignature *highSignature = WCAtlasPrivateSignature(highClass, highSelector, 5);
        if (track.estimatedDataRate >= 5000000.0 && highSignature &&
            WCAtlasPrivateTypeIsObject(highSignature.methodReturnType) &&
            WCAtlasPrivateObjectArguments(highSignature, NSMakeRange(2, 3))) {
            NSData *videoData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
            if (videoData.length) videoInfo = ((id (*)(id, SEL, id, id, id))objc_msgSend)(highClass, highSelector, videoData, nil, nil);
        }
        if (!videoInfo) {
            Class infoClass = NSClassFromString(@"CaptureVideoInfo");
            SEL infoSelector = NSSelectorFromString(@"genVideoInfoWithVideoUrl:thumb:");
            NSMethodSignature *infoSignature = WCAtlasPrivateSignature(infoClass, infoSelector, 4);
            if (!infoSignature || !WCAtlasPrivateTypeIsObject(infoSignature.methodReturnType) ||
                !WCAtlasPrivateObjectArguments(infoSignature, NSMakeRange(2, 2))) return NO;
            videoInfo = ((id (*)(id, SEL, id, id))objc_msgSend)(infoClass, infoSelector,
                [NSURL fileURLWithPath:path], thumbnail);
        }
        if (!videoInfo) return NO;
        if (thumbnailPath.length) WCAtlasPrivateSetValue(videoInfo, @"thumb_path", thumbnailPath);
        id manager = WCAtlasPrivateService(@"CMessageMgr");
        SEL addSelector = NSSelectorFromString(@"AddVideoMsg:ToUsr:VideoInfo:");
        NSMethodSignature *signature = WCAtlasPrivateSignature(manager, addSelector, 5);
        if (!signature || !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 3))) return NO;
        BOOL submitted = WCAtlasPrivateInvokeThreeObjects(manager, addSelector, currentUser, target,
                                                         videoInfo, signature.methodReturnType);
        return submitted;
    } @catch (NSException *exception) {
        WCAtlasLog(@"视频消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    } @finally {
        if (thumbnailPath.length) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC),
            dispatch_get_main_queue(), ^{ [NSFileManager.defaultManager removeItemAtPath:thumbnailPath error:nil]; });
    }
}

BOOL WCAtlasPrivateSendVoiceMessage(NSString *userName, NSString *voicePath,
                                  NSUInteger durationMilliseconds, NSUInteger voiceFormat) {
    NSCAssert(NSThread.isMainThread, @"Voice submission must run on the main thread");
    NSString *target = WCAtlasPrivateNonemptyString(userName);
    NSString *path = WCAtlasPrivateNonemptyString(voicePath);
    NSString *currentUser = WCAtlasPrivateNonemptyString(WCAtlasCurrentUserWXID());
    if (!target || !currentUser || ![NSFileManager.defaultManager fileExistsAtPath:path]) return NO;
    Class wrapClass = NSClassFromString(@"CMessageWrap");
    SEL initializer = NSSelectorFromString(@"initWithMsgType:");
    Method initializerMethod = wrapClass ? class_getInstanceMethod(wrapClass, initializer) : NULL;
    if (!initializerMethod || method_getNumberOfArguments(initializerMethod) != 3) return NO;
    char *argumentType = method_copyArgumentType(initializerMethod, 2);
    char argumentCode = WCAtlasPrivateUnqualifiedType(argumentType)[0];
    BOOL integerArgument = WCAtlasPrivateTypeIsInteger(argumentType);
    if (argumentType) free(argumentType);
    if (!integerArgument) return NO;
    id manager = WCAtlasPrivateService(@"CMessageMgr");
    id sender = WCAtlasPrivateService(@"AudioSender");
    SEL addSelector = NSSelectorFromString(@"AddLocalMsg:MsgWrap:");
    SEL pathSelector = NSSelectorFromString(@"getPathOfAudio:");
    SEL uploaderSelector = NSSelectorFromString(@"uploaderForMsgWrap:");
    SEL resendSelector = NSSelectorFromString(@"ResendVoiceMsg:MsgWrap:");
    NSMethodSignature *addSignature = WCAtlasPrivateSignature(manager, addSelector, 4);
    NSMethodSignature *pathSignature = WCAtlasPrivateSignature(wrapClass, pathSelector, 3);
    if (!addSignature || !WCAtlasPrivateObjectArguments(addSignature, NSMakeRange(2, 2)) ||
        (!WCAtlasPrivateTypeIsVoid(addSignature.methodReturnType) &&
         !WCAtlasPrivateTypeIsInteger(addSignature.methodReturnType)) ||
        !pathSignature || !WCAtlasPrivateTypeIsObject(pathSignature.methodReturnType) ||
        !WCAtlasPrivateTypeIsObject([pathSignature getArgumentTypeAtIndex:2])) return NO;
    @try {
        id wrap = WCAtlasPrivateInitializeMessageWrap(wrapClass, initializer, argumentCode);
        if (!wrap) return NO;
        WCAtlasPrivateSetValue(wrap, @"m_uiMessageType", @34);
        WCAtlasPrivateSetValue(wrap, @"m_nsFromUsr", currentUser);
        WCAtlasPrivateSetValue(wrap, @"m_nsRealChatUsr", currentUser);
        WCAtlasPrivateSetValue(wrap, @"m_nsToUsr", target);
        WCAtlasPrivateSetValue(wrap, @"m_uiStatus", @1);
        NSUInteger now = (NSUInteger)NSDate.date.timeIntervalSince1970;
        WCAtlasPrivateSetValue(wrap, @"m_uiCreateTime", @(now));
        WCAtlasPrivateSetValue(wrap, @"m_uiSendTime", @(now));
        id extendInfo = WCAtlasPrivateObjectField(wrap, @[@"m_extendInfoWithMsgType"]);
        if (durationMilliseconds) WCAtlasPrivateSetValue(extendInfo, @"m_uiVoiceTime", @(durationMilliseconds));
        WCAtlasPrivateSetValue(extendInfo, @"m_uiVoiceFormat", @(voiceFormat));
        WCAtlasPrivateSetValue(extendInfo, @"m_uiVoiceForwardFlag", @1);
        WCAtlasPrivateSubmitMessage(manager, addSelector, target, wrap, addSignature.methodReturnType);
        NSString *destination = ((id (*)(id, SEL, id))objc_msgSend)(wrapClass, pathSelector, wrap);
        if (![destination isKindOfClass:NSString.class] || destination.length == 0) return NO;
        [NSFileManager.defaultManager createDirectoryAtPath:destination.stringByDeletingLastPathComponent
                                withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
        if (![NSFileManager.defaultManager copyItemAtPath:path toPath:destination error:nil]) return NO;
        id resendTarget = sender;
        if (![resendTarget respondsToSelector:resendSelector] && [sender respondsToSelector:uploaderSelector])
            resendTarget = ((id (*)(id, SEL, id))objc_msgSend)(sender, uploaderSelector, wrap);
        NSMethodSignature *resendSignature = WCAtlasPrivateSignature(resendTarget, resendSelector, 4);
        if (!resendSignature || !WCAtlasPrivateObjectArguments(resendSignature, NSMakeRange(2, 2)) ||
            (!WCAtlasPrivateTypeIsVoid(resendSignature.methodReturnType) &&
             !WCAtlasPrivateTypeIsInteger(resendSignature.methodReturnType))) return NO;
        atomic_store(&WCAtlasPrivateVoiceUploadDeadline, NSDate.date.timeIntervalSince1970 + 12.0);
        WCAtlasPrivateSubmitMessage(resendTarget, resendSelector, target, wrap, resendSignature.methodReturnType);
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"语音消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

NSDictionary<NSString *, id> *WCAtlasPrivateIncomingTextMessageInfo(id message) {
    if (!message) return nil;
    id (^KVCValue)(NSString *) = ^id(NSString *key) {
        @try { return [message valueForKey:key]; }
        @catch (__unused NSException *exception) { return nil; }
    };
    NSNumber *type = KVCValue(@"m_uiMessageType");
    if (![type respondsToSelector:@selector(integerValue)] || type.integerValue != 1) return nil;
    NSString *from = WCAtlasPrivateNonemptyString(KVCValue(@"m_nsFromUsr"));
    NSString *to = WCAtlasPrivateNonemptyString(KVCValue(@"m_nsToUsr"));
    NSString *content = WCAtlasPrivateNonemptyString(KVCValue(@"m_nsContent"));
    NSString *realSender = WCAtlasPrivateNonemptyString(KVCValue(@"m_nsRealChatUsr"));
    NSString *currentUser = WCAtlasPrivateNonemptyString(WCAtlasCurrentUserWXID());
    if (!content.length || (!from.length && !to.length)) return nil;
    BOOL fromSelf = currentUser.length && [from isEqualToString:currentUser];
    NSString *session = [from hasSuffix:@"@chatroom"] ? from :
        ([to hasSuffix:@"@chatroom"] ? to : (fromSelf ? to : from));
    if (!session.length) return nil;
    id createTime = KVCValue(@"m_uiCreateTime");
    NSString *identifier = [NSString stringWithFormat:@"%@:%@:%llu:%lu", session,
        realSender ?: from ?: @"",
        [createTime respondsToSelector:@selector(unsignedLongLongValue)] ? [createTime unsignedLongLongValue] : 0,
        (unsigned long)content.hash];
    return @{ @"session": session, @"sender": realSender ?: from ?: @"", @"content": content,
              @"identifier": identifier, @"fromSelf": @(fromSelf) };
}

#pragma mark - Transfer Verification

static NSString *WCAtlasPrivateTransferString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        id stringValue = [value stringValue];
        return [stringValue isKindOfClass:NSString.class]
            ? [stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : nil;
    }
    return nil;
}

static BOOL WCAtlasPrivateTransferNameContainsMask(NSString *value) {
    return [value rangeOfString:@"*"].location != NSNotFound ||
        [value rangeOfString:@"＊"].location != NSNotFound;
}

static NSString *WCAtlasPrivateNormalizeMaskedTransferName(id value) {
    NSString *candidate = WCAtlasPrivateTransferString(value);
    if (candidate.length == 0 || candidate.length > 80 ||
        !WCAtlasPrivateTransferNameContainsMask(candidate)) return nil;

    for (NSArray<NSString *> *pair in @[@[@"（", @"）"], @[@"(", @")"]]) {
        NSRange open = [candidate rangeOfString:pair[0]];
        if (open.location == NSNotFound) continue;
        NSRange searchRange = NSMakeRange(NSMaxRange(open), candidate.length - NSMaxRange(open));
        NSRange close = [candidate rangeOfString:pair[1] options:0 range:searchRange];
        if (close.location == NSNotFound || close.location <= NSMaxRange(open)) continue;
        NSString *inner = [candidate substringWithRange:
            NSMakeRange(NSMaxRange(open), close.location - NSMaxRange(open))];
        inner = [inner stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (WCAtlasPrivateTransferNameContainsMask(inner)) {
            candidate = inner;
            break;
        }
    }

    NSCharacterSet *wrappers = [NSCharacterSet characterSetWithCharactersInString:
        @" \t\r\n•·●○◆◇()[]{}（）【】<>《》:："];
    candidate = [candidate stringByTrimmingCharactersInSet:wrappers];
    NSRange asciiMask = [candidate rangeOfString:@"*"];
    NSRange fullwidthMask = [candidate rangeOfString:@"＊"];
    NSUInteger maskLocation = MIN(asciiMask.location, fullwidthMask.location);
    if (maskLocation == NSNotFound) return nil;
    if (maskLocation > 0) candidate = [candidate substringFromIndex:maskLocation];
    NSCharacterSet *hiddenAndWrappers = [NSCharacterSet characterSetWithCharactersInString:
        @"*＊ \t\r\n•·●○◆◇()[]{}（）【】<>《》:："];
    if (candidate.length == 0 || candidate.length > 32 ||
        [candidate rangeOfCharacterFromSet:hiddenAndWrappers.invertedSet].location == NSNotFound) return nil;
    return candidate;
}

static id WCAtlasPrivateTransferObjectValue(id object, NSString *name) {
    if (!object || name.length == 0) return nil;
    if ([object isKindOfClass:NSDictionary.class]) {
        id value = ((NSDictionary *)object)[name];
        return value == NSNull.null ? nil : value;
    }
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = WCAtlasPrivateSignature(object, selector, 2);
    if (signature && WCAtlasPrivateTypeIsObject(signature.methodReturnType)) {
        @try {
            id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
            if (value && value != NSNull.null) return value;
        } @catch (__unused NSException *exception) {}
    }
    @try {
        id value = [object valueForKey:name];
        return value == NSNull.null ? nil : value;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *WCAtlasPrivateMaskedTransferNameAtDepth(id response, NSUInteger depth) {
    if (!response || depth > 3) return nil;
    NSString *directMaskedName = WCAtlasPrivateNormalizeMaskedTransferName(response);
    if (directMaskedName.length > 0) return directMaskedName;
    for (NSString *field in @[
        @"maskTruename", @"maskTrueName", @"receiverMaskTrueName",
        @"m_nsTransferReceiverTrueName", @"m_nsF2FMaskTrueName", @"m_nsTruthName",
        @"m_nsReceiverTrueName", @"m_nsSelectedTruthNameFromQRCode", @"maskRealname",
        @"truenameMask", @"realName", @"receiver_true_name", @"receiverTrueName",
        @"true_name", @"trueName", @"truename"
    ]) {
        NSString *maskedName = WCAtlasPrivateNormalizeMaskedTransferName(
            WCAtlasPrivateTransferObjectValue(response, field));
        if (maskedName.length > 0) return maskedName;
    }
    if (depth == 3) return nil;
    for (NSString *container in @[
        @"data", @"response", @"resp", @"result", @"transferMoneyData",
        @"payControlData", @"lastReqKeyStruct"
    ]) {
        id nested = WCAtlasPrivateTransferObjectValue(response, container);
        if (!nested || nested == response) continue;
        NSString *maskedName = WCAtlasPrivateMaskedTransferNameAtDepth(nested, depth + 1);
        if (maskedName.length > 0) return maskedName;
    }
    return nil;
}

NSString *WCAtlasPrivateMaskedTransferName(id response) {
    return WCAtlasPrivateMaskedTransferNameAtDepth(response, 0);
}

NSString *WCAtlasPrivateMaskedTransferNameSuffix(NSString *maskedName) {
    NSString *validated = WCAtlasPrivateNormalizeMaskedTransferName(maskedName);
    if (validated.length == 0) return nil;
    NSCharacterSet *ignored = [NSCharacterSet characterSetWithCharactersInString:
        @"*＊ \t\r\n•·●○◆◇()[]{}（）【】<>《》:："];
    __block NSString *suffix = nil;
    [validated enumerateSubstringsInRange:NSMakeRange(0, validated.length)
                                  options:NSStringEnumerationByComposedCharacterSequences |
                                          NSStringEnumerationReverse
                               usingBlock:^(NSString *substring, __unused NSRange substringRange,
                                            __unused NSRange enclosingRange, BOOL *stop) {
        if ([substring rangeOfCharacterFromSet:ignored].location == NSNotFound) {
            suffix = substring;
            *stop = YES;
        }
    }];
    return suffix;
}

#pragma mark - Group Invitations

static WCAtlasPrivateGroupInvitationResult
WCAtlasPrivateInvokeGroupInvitation(id manager,
                                  NSString *selectorName,
                                  NSString *groupUserName,
                                  NSArray<NSString *> *memberList) {
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature = WCAtlasPrivateSignature(manager, selector, 4);
    if (!WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2))) {
        return WCAtlasPrivateGroupInvitationResultUnsupported;
    }
    const char *returnType = WCAtlasPrivateUnqualifiedType(signature.methodReturnType);
    @try {
        if (strcmp(returnType, @encode(void)) == 0) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(manager, selector,
                                                      groupUserName, memberList);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
        if (WCAtlasPrivateTypeIsObject(returnType)) {
            (void)((id (*)(id, SEL, id, id))objc_msgSend)(manager, selector,
                                                          groupUserName, memberList);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
        if (WCAtlasPrivateTypeIsInteger(returnType)) {
            (void)((NSInteger (*)(id, SEL, id, id))objc_msgSend)(
                manager, selector, groupUserName, memberList);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
    } @catch (NSException *exception) {
        WCAtlasLog(@"群邀请适配 %@ 调用失败：%@", selectorName,
                 exception.reason ?: exception.name);
        return WCAtlasPrivateGroupInvitationResultRejected;
    }
    return WCAtlasPrivateGroupInvitationResultUnsupported;
}

static WCAtlasPrivateGroupInvitationResult
WCAtlasPrivateInvokeExtendedGroupInvitation(id manager,
                                          NSString *groupUserName,
                                          NSArray<NSString *> *memberList) {
    NSString *selectorName = @"InviteGroupMember:withMemberList:withInviterScene:withTicket:withUserData:withMsgHistoryInfo:";
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature = WCAtlasPrivateSignature(manager, selector, 8);
    if (!signature ||
        !WCAtlasPrivateObjectArguments(signature, NSMakeRange(2, 2)) ||
        !WCAtlasPrivateTypeIsInteger([signature getArgumentTypeAtIndex:4]) ||
        !WCAtlasPrivateObjectArguments(signature, NSMakeRange(5, 3))) {
        return WCAtlasPrivateGroupInvitationResultUnsupported;
    }
    const char *returnType = WCAtlasPrivateUnqualifiedType(signature.methodReturnType);
    @try {
        if (strcmp(returnType, @encode(void)) == 0) {
            ((void (*)(id, SEL, id, id, NSInteger, id, id, id))objc_msgSend)(
                manager, selector, groupUserName, memberList, 0, nil, nil, nil);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
        if (WCAtlasPrivateTypeIsObject(returnType)) {
            (void)((id (*)(id, SEL, id, id, NSInteger, id, id, id))objc_msgSend)(
                manager, selector, groupUserName, memberList, 0, nil, nil, nil);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
        if (WCAtlasPrivateTypeIsInteger(returnType)) {
            (void)((NSInteger (*)(id, SEL, id, id, NSInteger, id, id, id))objc_msgSend)(
                manager, selector, groupUserName, memberList, 0, nil, nil, nil);
            return WCAtlasPrivateGroupInvitationResultSubmitted;
        }
    } @catch (NSException *exception) {
        WCAtlasLog(@"群邀请适配 %@ 调用失败：%@", selectorName,
                 exception.reason ?: exception.name);
        return WCAtlasPrivateGroupInvitationResultRejected;
    }
    return WCAtlasPrivateGroupInvitationResultUnsupported;
}

WCAtlasPrivateGroupInvitationResult
WCAtlasPrivateInviteGroupMember(NSString *groupUserName, NSString *memberUserName) {
    if (![groupUserName hasSuffix:@"@chatroom"] || memberUserName.length == 0 ||
        [memberUserName hasSuffix:@"@chatroom"] ||
        [memberUserName isEqualToString:@"filehelper"] ||
        [memberUserName isEqualToString:WCAtlasCurrentUserWXID()]) {
        return WCAtlasPrivateGroupInvitationResultRejected;
    }
    id manager = WCAtlasPrivateService(@"CGroupMgr");
    if (!manager) return WCAtlasPrivateGroupInvitationResultUnsupported;
    NSArray<NSString *> *members = @[memberUserName];

    // WeChatX 2.2-2 prefers the current six-argument CGroupMgr API.
    WCAtlasPrivateGroupInvitationResult result = WCAtlasPrivateInvokeExtendedGroupInvitation(
        manager, groupUserName, members);
    if (result != WCAtlasPrivateGroupInvitationResultUnsupported) return result;

    // Older WeChat builds expose the same CGroupMgr operation with two objects.
    result = WCAtlasPrivateInvokeGroupInvitation(
        manager, @"InviteGroupMember:withMemberList:", groupUserName, members);
    if (result != WCAtlasPrivateGroupInvitationResultUnsupported) return result;

    // Older WeChat builds expose the same operation as direct group addition.
    result = WCAtlasPrivateInvokeGroupInvitation(
        manager, @"AddGroupMember:withMemberList:", groupUserName, members);
    if (result == WCAtlasPrivateGroupInvitationResultUnsupported) {
        WCAtlasLog(@"群邀请适配未发现可用接口：%@ -> %@", memberUserName, groupUserName);
    }
    return result;
}
