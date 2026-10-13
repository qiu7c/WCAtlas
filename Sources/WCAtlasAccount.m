#import "WCAtlasAccount.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const WCAtlasCachedWXIDKey = @"com.qiu7c.wcatlas.authorization.cached-wxid";
static NSString *const WCAtlasCachedNicknameKey = @"com.qiu7c.wcatlas.authorization.cached-nickname";
static NSString *const WCAtlasCachedHeadImageURLKey = @"com.qiu7c.wcatlas.authorization.cached-head-image-url";

static id WCAtlasServiceCenterFromCurrentContext(id self, SEL command) {
    (void)self;
    (void)command;
    Class contextClass = objc_getClass("MMContext");
    SEL currentContextSelector = sel_registerName("currentContext");
    SEL serviceCenterSelector = sel_registerName("serviceCenter");
    if (!contextClass || ![contextClass respondsToSelector:currentContextSelector]) return nil;
    id context = ((id (*)(id, SEL))objc_msgSend)(contextClass, currentContextSelector);
    if (!context || ![context respondsToSelector:serviceCenterSelector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(context, serviceCenterSelector);
}

void WCAtlasInstallServiceCenterCompatibility(void) {
    Class centerClass = objc_getClass("MMServiceCenter");
    if (!centerClass) return;
    SEL selector = sel_registerName("defaultCenter");
    if ([centerClass respondsToSelector:selector]) return;
    Class metaclass = object_getClass(centerClass);
    if (metaclass) class_addMethod(metaclass, selector, (IMP)WCAtlasServiceCenterFromCurrentContext, "@@:");
}

id WCAtlasDefaultServiceCenter(void) {
    id contextCenter = WCAtlasServiceCenterFromCurrentContext(nil, NULL);
    if (contextCenter) return contextCenter;
    Class centerClass = objc_getClass("MMServiceCenter");
    SEL selector = sel_registerName("defaultCenter");
    if (!centerClass || ![centerClass respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(centerClass, selector);
}

id WCAtlasServiceForClass(Class serviceClass) {
    id center = WCAtlasDefaultServiceCenter();
    SEL selector = sel_registerName("getService:");
    if (!center || !serviceClass || ![center respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL, Class))objc_msgSend)(center, selector, serviceClass);
}

static NSString *WCAtlasContactString(id contact, const char *selectorName) {
    if (!contact || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    id value = nil;
    if ([contact respondsToSelector:selector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(contact, selector);
    } else {
        NSString *key = [NSString stringWithUTF8String:selectorName];
        @try { value = [contact valueForKey:key]; }
        @catch (__unused NSException *exception) { return nil; }
    }
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length > 0 ? text : nil;
}

BOOL WCAtlasUpdateCachedCurrentUserContact(id contact) {
    NSString *wxid = WCAtlasContactString(contact, "m_nsUsrName");
    if (wxid.length == 0) return NO;
    NSString *nickname = WCAtlasContactString(contact, "m_nsNickName");
    NSString *headImageURL = WCAtlasContactString(contact, "m_nsHeadImgUrl");
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *cachedWXID = [defaults stringForKey:WCAtlasCachedWXIDKey];
    NSString *cachedNickname = [defaults stringForKey:WCAtlasCachedNicknameKey];
    NSString *cachedHeadImageURL = [defaults stringForKey:WCAtlasCachedHeadImageURLKey];
    BOOL wxidChanged = ![(cachedWXID ?: @"") isEqualToString:wxid];
    BOOL nicknameChanged = ![(cachedNickname ?: @"") isEqualToString:(nickname ?: @"")];
    BOOL headImageChanged = ![(cachedHeadImageURL ?: @"") isEqualToString:(headImageURL ?: @"")];
    if (!wxidChanged && !nicknameChanged && !headImageChanged) return NO;

    if (wxidChanged) [defaults setObject:wxid forKey:WCAtlasCachedWXIDKey];
    if (nicknameChanged) {
        if (nickname.length > 0) [defaults setObject:nickname forKey:WCAtlasCachedNicknameKey];
        else [defaults removeObjectForKey:WCAtlasCachedNicknameKey];
    }
    if (headImageChanged) {
        if (headImageURL.length > 0) [defaults setObject:headImageURL forKey:WCAtlasCachedHeadImageURLKey];
        else [defaults removeObjectForKey:WCAtlasCachedHeadImageURLKey];
    }
    return YES;
}

BOOL WCAtlasRefreshCachedCurrentUserContact(void) {
    Class contactManagerClass = objc_getClass("CContactMgr");
    id manager = WCAtlasServiceForClass(contactManagerClass);
    SEL selector = sel_registerName("getSelfContact");
    if (!manager || ![manager respondsToSelector:selector]) return NO;
    id contact = ((id (*)(id, SEL))objc_msgSend)(manager, selector);
    return WCAtlasUpdateCachedCurrentUserContact(contact);
}

NSString *WCAtlasCurrentUserWXID(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasCachedWXIDKey];
}

NSString *WCAtlasCurrentUserNickname(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasCachedNicknameKey];
}

NSString *WCAtlasCurrentUserHeadImageURL(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasCachedHeadImageURLKey];
}
