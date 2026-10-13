#import "WCAtlasMomentsCommentAntiDelete.h"

#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

static char WCAtlasMomentsDeletedCommentMarkerKey;

static void (*WCAtlasOriginalMergeDeletedComment)(id, SEL, id, BOOL);
static void (*WCAtlasOriginalMergeCommentList)(id, SEL, id);
static void (*WCAtlasOriginalMergeMessage)(id, SEL, id, BOOL);
static void (*WCAtlasOriginalTimelineCellUpdate)(id, SEL, id, id);
static void (*WCAtlasOriginalDetailSetDataItem)(id, SEL, id);
static void (*WCAtlasOriginalDetailUpdateFinished)(id, SEL, NSInteger, id, id);
static void (*WCAtlasOriginalCommentListConfig)(id, SEL, id, id, CGFloat);
static id (*WCAtlasOriginalListDisplayContent)(id, SEL, id, id, id);
static id (*WCAtlasOriginalFBDisplayComment)(id, SEL, id, id, id);
static id (*WCAtlasOriginalFBTotalDisplayComment)(id, SEL, id, id, id);
static id (*WCAtlasOriginalDisplayComment)(id, SEL, id, id, id);

static BOOL WCAtlasMomentsCommentAntiDeleteEnabled(void) {
    return WCAtlasEnhancementEnabled(WCAtlasMomentsCommentAntiDeleteEnabledKey);
}

static NSMutableDictionary *WCAtlasMomentsDeletedCommentCache(void) {
    static NSMutableDictionary *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

static BOOL WCAtlasMethodReturns(Method method, char expected) {
    char *type = method ? method_copyReturnType(method) : NULL;
    BOOL matches = type && type[0] == expected;
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodArgumentIs(Method method, unsigned int index, const char *accepted) {
    char *type = method ? method_copyArgumentType(method, index) : NULL;
    BOOL matches = type && accepted && strchr(accepted, type[0]) != NULL;
    if (type) free(type);
    return matches;
}

static id WCAtlasObjectGetter(id object, const char *name) {
    if (!object || !name) return nil;
    SEL selector = sel_registerName(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method || method_getNumberOfArguments(method) != 2 || !WCAtlasMethodReturns(method, '@')) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static id WCAtlasObjectOrIntegerGetter(id object, const char *name) {
    if (!object || !name) return nil;
    SEL selector = sel_registerName(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method || method_getNumberOfArguments(method) != 2) return nil;
    char *type = method_copyReturnType(method);
    char code = type ? type[0] : '\0';
    if (type) free(type);
    @try {
        switch (code) {
            case '@': return ((id (*)(id, SEL))objc_msgSend)(object, selector);
            case 'c': return @(((signed char (*)(id, SEL))objc_msgSend)(object, selector));
            case 'B': return @(((BOOL (*)(id, SEL))objc_msgSend)(object, selector));
            case 's': return @(((short (*)(id, SEL))objc_msgSend)(object, selector));
            case 'i': return @(((int (*)(id, SEL))objc_msgSend)(object, selector));
            case 'l': return @(((long (*)(id, SEL))objc_msgSend)(object, selector));
            case 'q': return @(((long long (*)(id, SEL))objc_msgSend)(object, selector));
            case 'C': return @(((unsigned char (*)(id, SEL))objc_msgSend)(object, selector));
            case 'S': return @(((unsigned short (*)(id, SEL))objc_msgSend)(object, selector));
            case 'I': return @(((unsigned int (*)(id, SEL))objc_msgSend)(object, selector));
            case 'L': return @(((unsigned long (*)(id, SEL))objc_msgSend)(object, selector));
            case 'Q': return @(((unsigned long long (*)(id, SEL))objc_msgSend)(object, selector));
            default: return nil;
        }
    } @catch (__unused NSException *exception) { return nil; }
}

static long long WCAtlasIntegerGetter(id object, const char *name, BOOL *available) {
    if (available) *available = NO;
    if (!object || !name) return 0;
    SEL selector = sel_registerName(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method || method_getNumberOfArguments(method) != 2) return 0;
    char *type = method_copyReturnType(method);
    char code = type ? type[0] : '\0';
    if (type) free(type);
    @try {
        switch (code) {
            case '@': {
                id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                if (![value respondsToSelector:@selector(longLongValue)]) return 0;
                if (available) *available = YES;
                return [value longLongValue];
            }
            case 'c': if (available) *available = YES; return ((signed char (*)(id, SEL))objc_msgSend)(object, selector);
            case 'B': if (available) *available = YES; return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
            case 's': if (available) *available = YES; return ((short (*)(id, SEL))objc_msgSend)(object, selector);
            case 'i': if (available) *available = YES; return ((int (*)(id, SEL))objc_msgSend)(object, selector);
            case 'l': if (available) *available = YES; return ((long (*)(id, SEL))objc_msgSend)(object, selector);
            case 'C': if (available) *available = YES; return ((unsigned char (*)(id, SEL))objc_msgSend)(object, selector);
            case 'S': if (available) *available = YES; return ((unsigned short (*)(id, SEL))objc_msgSend)(object, selector);
            case 'I': if (available) *available = YES; return ((unsigned int (*)(id, SEL))objc_msgSend)(object, selector);
            case 'L': if (available) *available = YES; return (long long)((unsigned long (*)(id, SEL))objc_msgSend)(object, selector);
            case 'q': if (available) *available = YES; return ((long long (*)(id, SEL))objc_msgSend)(object, selector);
            case 'Q': if (available) *available = YES; return (long long)((unsigned long long (*)(id, SEL))objc_msgSend)(object, selector);
            default: return 0;
        }
    } @catch (__unused NSException *exception) { return 0; }
}

static void WCAtlasSetInteger(id object, const char *name, long long value) {
    if (!object || !name) return;
    SEL selector = sel_registerName(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method || method_getNumberOfArguments(method) != 3 || !WCAtlasMethodReturns(method, 'v')) return;
    char *type = method_copyArgumentType(method, 2);
    char code = type ? type[0] : '\0';
    if (type) free(type);
    @try {
        switch (code) {
            case '@': ((void (*)(id, SEL, id))objc_msgSend)(object, selector, @(value)); break;
            case 'c': ((void (*)(id, SEL, signed char))objc_msgSend)(object, selector, (signed char)value); break;
            case 'B': ((void (*)(id, SEL, BOOL))objc_msgSend)(object, selector, value != 0); break;
            case 's': ((void (*)(id, SEL, short))objc_msgSend)(object, selector, (short)value); break;
            case 'i': ((void (*)(id, SEL, int))objc_msgSend)(object, selector, (int)value); break;
            case 'l': ((void (*)(id, SEL, long))objc_msgSend)(object, selector, (long)value); break;
            case 'C': ((void (*)(id, SEL, unsigned char))objc_msgSend)(object, selector, (unsigned char)(value > 0 ? value : 0)); break;
            case 'S': ((void (*)(id, SEL, unsigned short))objc_msgSend)(object, selector, (unsigned short)(value > 0 ? value : 0)); break;
            case 'I': ((void (*)(id, SEL, unsigned int))objc_msgSend)(object, selector, (unsigned int)(value > 0 ? value : 0)); break;
            case 'L': ((void (*)(id, SEL, unsigned long))objc_msgSend)(object, selector, (unsigned long)(value > 0 ? value : 0)); break;
            case 'q': ((void (*)(id, SEL, long long))objc_msgSend)(object, selector, value); break;
            case 'Q': ((void (*)(id, SEL, unsigned long long))objc_msgSend)(object, selector, (unsigned long long)(value > 0 ? value : 0)); break;
            default: break;
        }
    } @catch (__unused NSException *exception) {}
}

static NSArray *WCAtlasCommentUsers(id dataItem) {
    id comments = WCAtlasObjectGetter(dataItem, "commentUsers");
    return [comments isKindOfClass:NSArray.class] ? comments : nil;
}

static id<NSCopying> WCAtlasDataItemKey(id dataItem) {
    id tid = WCAtlasObjectOrIntegerGetter(dataItem, "tid");
    if ([tid conformsToProtocol:@protocol(NSCopying)]) return tid;
    NSString *description = [tid description];
    return description.length > 0 ? description : nil;
}

static NSSet *WCAtlasCommentIdentityKeys(id comment) {
    NSMutableSet *keys = [NSMutableSet set];
    const char *selectors[] = { "comment64ID", "commentID", "cpKeyForComment", "springClientId" };
    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); index++) {
        id value = WCAtlasObjectOrIntegerGetter(comment, selectors[index]);
        if (!value || value == NSNull.null) continue;
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] == 0) continue;
        [keys addObject:value];
    }
    return keys;
}

static BOOL WCAtlasCommentsMatch(id first, id second, id dataItem) {
    if (!first || !second) return NO;
    if (first == second) return YES;
    NSSet *firstKeys = WCAtlasCommentIdentityKeys(first);
    NSSet *secondKeys = WCAtlasCommentIdentityKeys(second);
    if (firstKeys.count > 0 && secondKeys.count > 0 && [firstKeys intersectsSet:secondKeys]) return YES;

    Class utilityClass = objc_getClass("WCCommentUIUtil");
    SEL selector = sel_registerName("isSameComment:andComment:isAd:");
    Method method = utilityClass ? class_getClassMethod(utilityClass, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 5 ||
        (!WCAtlasMethodReturns(method, 'B') && !WCAtlasMethodReturns(method, 'c')) || !WCAtlasMethodArgumentIs(method, 2, "@") ||
        !WCAtlasMethodArgumentIs(method, 3, "@") || !WCAtlasMethodArgumentIs(method, 4, "Bc")) return NO;
    BOOL isAd = WCAtlasIntegerGetter(dataItem, "isAd", NULL) != 0;
    @try { return ((BOOL (*)(id, SEL, id, id, BOOL))objc_msgSend)(utilityClass, selector, first, second, isAd); }
    @catch (__unused NSException *exception) { return NO; }
}

static BOOL WCAtlasCommentListContains(NSArray *comments, id candidate, id dataItem, id __autoreleasing *matched) {
    for (id comment in comments) {
        if (WCAtlasCommentsMatch(comment, candidate, dataItem)) {
            if (matched) *matched = comment;
            return YES;
        }
    }
    return NO;
}

static void WCAtlasMarkDeletedComment(id comment) {
    if (comment) objc_setAssociatedObject(comment, &WCAtlasMomentsDeletedCommentMarkerKey, @YES,
                                          OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasCacheDeletedComment(id dataItem, id comment, NSUInteger index) {
    id<NSCopying> itemKey = WCAtlasDataItemKey(dataItem);
    if (!itemKey || !comment) return;
    NSDictionary *entry = @{ @"comment": comment,
                             @"index": @(index),
                             @"keys": WCAtlasCommentIdentityKeys(comment) };
    NSMutableDictionary *cache = WCAtlasMomentsDeletedCommentCache();
    @synchronized (cache) {
        NSMutableArray *entries = cache[itemKey];
        if (!entries) {
            entries = [NSMutableArray array];
            cache[itemKey] = entries;
        }
        for (NSDictionary *existing in entries) {
            if (WCAtlasCommentsMatch(existing[@"comment"], comment, dataItem)) return;
        }
        [entries addObject:entry];
    }
}

static void WCAtlasRestoreDeletedComments(id dataItem) {
    if (!WCAtlasMomentsCommentAntiDeleteEnabled() || !dataItem) return;
    id<NSCopying> itemKey = WCAtlasDataItemKey(dataItem);
    NSMutableArray *comments = (NSMutableArray *)WCAtlasCommentUsers(dataItem);
    if (!itemKey || ![comments respondsToSelector:@selector(insertObject:atIndex:)]) return;

    NSMutableDictionary *cache = WCAtlasMomentsDeletedCommentCache();
    @synchronized (cache) {
        NSArray *entries = [cache[itemKey] copy];
        if (entries.count == 0) return;
        BOOL countAvailable = NO;
        long long originalCount = WCAtlasIntegerGetter(dataItem, "commentCount", &countAvailable);
        for (NSDictionary *entry in entries) {
            id cachedComment = entry[@"comment"];
            id matched = nil;
            if (WCAtlasCommentListContains(comments, cachedComment, dataItem, &matched)) {
                WCAtlasMarkDeletedComment(matched);
                continue;
            }
            NSUInteger index = MIN([entry[@"index"] unsignedIntegerValue], comments.count);
            WCAtlasMarkDeletedComment(cachedComment);
            @try { [comments insertObject:cachedComment atIndex:index]; }
            @catch (__unused NSException *exception) {}
        }
        if (countAvailable && (long long)comments.count > originalCount) {
            WCAtlasSetInteger(dataItem, "setCommentCount:", (long long)comments.count);
            WCAtlasSetInteger(dataItem, "setRealCommentCount:", (long long)comments.count);
        }
    }
}

static id WCAtlasDeletedCommentDisplayContent(id original, id comment) {
    if (!WCAtlasMomentsCommentAntiDeleteEnabled() || !original ||
        ![objc_getAssociatedObject(comment, &WCAtlasMomentsDeletedCommentMarkerKey) boolValue]) return original;
    NSString *suffix = [[NSUserDefaults.standardUserDefaults stringForKey:WCAtlasMomentsCommentAntiDeleteTextKey]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (suffix.length == 0) suffix = @"←该评论已删除";
    unichar first = [suffix characterAtIndex:0];
    if (![NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:first]) {
        suffix = [@" " stringByAppendingString:suffix];
    }

    NSString *plain = [original isKindOfClass:NSAttributedString.class]
        ? [(NSAttributedString *)original string]
        : ([original isKindOfClass:NSString.class] ? original : nil);
    if (!plain || [plain hasSuffix:suffix]) return original;
    if (![original isKindOfClass:NSAttributedString.class]) return [plain stringByAppendingString:suffix];

    NSMutableAttributedString *result = [(NSAttributedString *)original mutableCopy];
    NSRange suffixRange = NSMakeRange(result.length, suffix.length);
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:suffix]];
    CGFloat size = [NSUserDefaults.standardUserDefaults doubleForKey:WCAtlasMomentsCommentAntiDeleteFontSizeKey];
    size = MIN(24.0, MAX(6.0, size > 0.0 ? size : 12.0));
    UIFont *font = nil;
    if (suffixRange.location > 0) {
        font = [result attribute:NSFontAttributeName atIndex:suffixRange.location - 1 effectiveRange:NULL];
    }
    font = [font isKindOfClass:UIFont.class] ? [font fontWithSize:size] : [UIFont systemFontOfSize:size];
    UIColor *color = WCAtlasColorForDefaultsKey(WCAtlasMomentsCommentAntiDeleteColorKey,
                                               [UIColor colorWithWhite:0.56 alpha:1.0]);
    [result addAttributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: color }
                    range:suffixRange];
    return result;
}

static void WCAtlasMergeDeletedComment(id self, SEL _cmd, id comment, BOOL deletedByOwner) {
    if (!WCAtlasMomentsCommentAntiDeleteEnabled()) {
        WCAtlasOriginalMergeDeletedComment(self, _cmd, comment, deletedByOwner);
        return;
    }
    NSArray *oldComments = [WCAtlasCommentUsers(self) copy] ?: @[];
    WCAtlasOriginalMergeDeletedComment(self, _cmd, comment, deletedByOwner);
    NSArray *currentComments = WCAtlasCommentUsers(self) ?: @[];
    [oldComments enumerateObjectsUsingBlock:^(id oldComment, NSUInteger index, __unused BOOL *stop) {
        if (!WCAtlasCommentListContains(currentComments, oldComment, self, NULL)) {
            WCAtlasCacheDeletedComment(self, oldComment, index);
        }
    }];
    WCAtlasRestoreDeletedComments(self);
}

static void WCAtlasMergeCommentList(id self, SEL _cmd, id localFeed) {
    WCAtlasOriginalMergeCommentList(self, _cmd, localFeed);
    WCAtlasRestoreDeletedComments(self);
}

static void WCAtlasMergeMessage(id self, SEL _cmd, id message, BOOL parseContent) {
    WCAtlasOriginalMergeMessage(self, _cmd, message, parseContent);
    WCAtlasRestoreDeletedComments(self);
}

static void WCAtlasTimelineCellUpdate(id self, SEL _cmd, id dataItem, id actionAreaVM) {
    WCAtlasRestoreDeletedComments(dataItem);
    WCAtlasOriginalTimelineCellUpdate(self, _cmd, dataItem, actionAreaVM);
}

static void WCAtlasDetailSetDataItem(id self, SEL _cmd, id dataItem) {
    WCAtlasRestoreDeletedComments(dataItem);
    WCAtlasOriginalDetailSetDataItem(self, _cmd, dataItem);
}

static void WCAtlasDetailUpdateFinished(id self, SEL _cmd, NSInteger result, id itemID, id dataItem) {
    WCAtlasRestoreDeletedComments(dataItem);
    WCAtlasOriginalDetailUpdateFinished(self, _cmd, result, itemID, dataItem);
}

static void WCAtlasCommentListConfig(id self, SEL _cmd, id comment, id dataItem, CGFloat width) {
    if (WCAtlasMomentsCommentAntiDeleteEnabled()) {
        BOOL available = NO;
        long long status = WCAtlasIntegerGetter(comment, "delStatus", &available);
        NSString *content = WCAtlasObjectGetter(comment, "content");
        if (available && status == 1 && [content isKindOfClass:NSString.class] && content.length > 0) {
            NSUInteger index = [WCAtlasCommentUsers(dataItem) indexOfObjectIdenticalTo:comment];
            WCAtlasCacheDeletedComment(dataItem, comment, index == NSNotFound ? WCAtlasCommentUsers(dataItem).count : index);
            WCAtlasMarkDeletedComment(comment);
            WCAtlasSetInteger(comment, "setDelStatus:", 0);
        }
        WCAtlasRestoreDeletedComments(dataItem);
    }
    WCAtlasOriginalCommentListConfig(self, _cmd, comment, dataItem, width);
}

static id WCAtlasListDisplayContent(id self, SEL _cmd, id comment, id dataItem, id pageContext) {
    return WCAtlasDeletedCommentDisplayContent(
        WCAtlasOriginalListDisplayContent(self, _cmd, comment, dataItem, pageContext), comment);
}

static id WCAtlasFBDisplayComment(id self, SEL _cmd, id comment, id dataItem, id pageContext) {
    return WCAtlasDeletedCommentDisplayContent(
        WCAtlasOriginalFBDisplayComment(self, _cmd, comment, dataItem, pageContext), comment);
}

static id WCAtlasFBTotalDisplayComment(id self, SEL _cmd, id comment, id dataItem, id pageContext) {
    return WCAtlasDeletedCommentDisplayContent(
        WCAtlasOriginalFBTotalDisplayComment(self, _cmd, comment, dataItem, pageContext), comment);
}

static id WCAtlasDisplayComment(id self, SEL _cmd, id comment, id dataItem, id pageContext) {
    return WCAtlasDeletedCommentDisplayContent(
        WCAtlasOriginalDisplayComment(self, _cmd, comment, dataItem, pageContext), comment);
}

static BOOL WCAtlasInstallInstanceHook(NSString *className, NSString *selectorName, NSUInteger argumentCount,
                                     char returnType, const char *argumentTypes, IMP replacement, IMP *original) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != argumentCount || !WCAtlasMethodReturns(method, returnType)) return NO;
    for (unsigned int index = 2; index < argumentCount; index++) {
        if (!WCAtlasMethodArgumentIs(method, index, (char[]){ argumentTypes[index - 2], '\0' })) return NO;
    }
    MSHookMessageEx(cls, selector, replacement, original);
    return *original != NULL;
}

static BOOL WCAtlasInstallClassHook(NSString *className, NSString *selectorName, NSUInteger argumentCount,
                                  IMP replacement, IMP *original) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);
    Method method = cls ? class_getClassMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != argumentCount || !WCAtlasMethodReturns(method, '@')) return NO;
    for (unsigned int index = 2; index < argumentCount; index++) {
        if (!WCAtlasMethodArgumentIs(method, index, "@")) return NO;
    }
    MSHookMessageEx(object_getClass(cls), selector, replacement, original);
    return *original != NULL;
}

void WCAtlasMomentsCommentAntiDeleteInstallHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUInteger installed = 0;
        installed += WCAtlasInstallInstanceHook(@"WCDataItem", @"mergeWithDeletedComment:isDeletedByFeedOwner:", 4, 'v', "@B",
                                               (IMP)WCAtlasMergeDeletedComment, (IMP *)&WCAtlasOriginalMergeDeletedComment);
        installed += WCAtlasInstallInstanceHook(@"WCDataItem", @"mergeCommentListWithLocalFeed:", 3, 'v', "@",
                                               (IMP)WCAtlasMergeCommentList, (IMP *)&WCAtlasOriginalMergeCommentList);
        installed += WCAtlasInstallInstanceHook(@"WCDataItem", @"mergeMessage:needParseContent:", 4, 'v', "@B",
                                               (IMP)WCAtlasMergeMessage, (IMP *)&WCAtlasOriginalMergeMessage);
        installed += WCAtlasInstallInstanceHook(@"WCTimeLineCellView", @"updateWithDataItem:actionAreaVM:", 4, 'v', "@@",
                                               (IMP)WCAtlasTimelineCellUpdate, (IMP *)&WCAtlasOriginalTimelineCellUpdate);
        installed += WCAtlasInstallInstanceHook(@"WCCommentDetailViewControllerFB", @"setDataItem:", 3, 'v', "@",
                                               (IMP)WCAtlasDetailSetDataItem, (IMP *)&WCAtlasOriginalDetailSetDataItem);
        installed += WCAtlasInstallInstanceHook(@"WCCommentDetailViewControllerFB", @"onUpdateDataItemDetailFinished:itemId:dataItem:", 5, 'v', "q@@",
                                               (IMP)WCAtlasDetailUpdateFinished, (IMP *)&WCAtlasOriginalDetailUpdateFinished);
        installed += WCAtlasInstallInstanceHook(@"WCCommentListContentView", @"config:dataItem:width:", 5, 'v', "@@d",
                                               (IMP)WCAtlasCommentListConfig, (IMP *)&WCAtlasOriginalCommentListConfig);
        installed += WCAtlasInstallClassHook(@"WCCommentListContentView", @"getDisplayContent:dataItem:pageContext:", 5,
                                            (IMP)WCAtlasListDisplayContent, (IMP *)&WCAtlasOriginalListDisplayContent);
        installed += WCAtlasInstallClassHook(@"WCCommentViewFB", @"getDisplayCommentContent:dataItem:pageContext:", 5,
                                            (IMP)WCAtlasFBDisplayComment, (IMP *)&WCAtlasOriginalFBDisplayComment);
        installed += WCAtlasInstallClassHook(@"WCCommentViewFB", @"totalDisplayContentWithComment:inDataItem:pageContext:", 5,
                                            (IMP)WCAtlasFBTotalDisplayComment, (IMP *)&WCAtlasOriginalFBTotalDisplayComment);
        installed += WCAtlasInstallClassHook(@"WCCommentView", @"getDisplayCommentContent:dataItem:pageContext:", 5,
                                            (IMP)WCAtlasDisplayComment, (IMP *)&WCAtlasOriginalDisplayComment);
        WCAtlasLog(@"朋友圈评论防删除 Hook：%lu/11", (unsigned long)installed);
    });
}
