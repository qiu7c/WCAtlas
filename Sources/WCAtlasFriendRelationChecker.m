#import "WCAtlasFriendRelationChecker.h"
#import "WCAtlasInAppNotification.h"
#import "WCAtlasLogging.h"
#import "WCAtlasPrivateAPI.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

NSString *const WCAtlasFriendRelationCheckDidUpdateNotification = @"WCAtlasFriendRelationCheckDidUpdateNotification";

NSString *const WCAtlasFriendRelationStatusIdle = @"idle";
NSString *const WCAtlasFriendRelationStatusRunning = @"running";
NSString *const WCAtlasFriendRelationStatusPaused = @"paused";
NSString *const WCAtlasFriendRelationStatusCompleted = @"completed";

NSString *const WCAtlasFriendRelationVerdictNormal = @"normal";
NSString *const WCAtlasFriendRelationVerdictSuspected = @"suspected";
NSString *const WCAtlasFriendRelationVerdictUncertain = @"uncertain";

static NSString *const WCAtlasFriendRelationPauseUser = @"user";
static NSString *const WCAtlasFriendRelationPauseBackground = @"background";
static NSString *const WCAtlasFriendRelationPauseInterrupted = @"interrupted";
static NSString *const WCAtlasFriendRelationPauseNetwork = @"network";

static id WCAtlasFriendRelationServiceForClass(Class serviceClass) {
    Class centerClass = NSClassFromString(@"MMServiceCenter");
    SEL centerSelector = NSSelectorFromString(@"defaultCenter");
    SEL serviceSelector = NSSelectorFromString(@"getService:");
    if (!serviceClass || ![centerClass respondsToSelector:centerSelector]) return nil;
    @try {
        id center = ((id (*)(id, SEL))objc_msgSend)(centerClass, centerSelector);
        if (![center respondsToSelector:serviceSelector]) return nil;
        return ((id (*)(id, SEL, Class))objc_msgSend)(center, serviceSelector, serviceClass);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL WCAtlasFriendRelationMethodReturnsObject(Method method) {
    if (!method) return NO;
    char type[16] = {0};
    method_getReturnType(method, type, sizeof(type));
    return type[0] == '@' || type[0] == '#';
}

static BOOL WCAtlasFriendRelationCanInvoke(id receiver, SEL selector, unsigned int argumentCount) {
    if (!receiver || !selector || ![receiver respondsToSelector:selector]) return NO;
    Method method = class_getInstanceMethod(object_getClass(receiver), selector);
    return method && method_getNumberOfArguments(method) == argumentCount;
}

static id WCAtlasFriendRelationObjectValue(id object, NSArray<NSString *> *names) {
    if (!object) return nil;
    for (NSString *name in names) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(object_getClass(object), selector);
        if (method && method_getNumberOfArguments(method) == 2 && WCAtlasFriendRelationMethodReturnsObject(method)) {
            id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
            if (value && value != NSNull.null) return value;
        }
        @try {
            id value = [object valueForKey:name];
            if (value && value != NSNull.null) return value;
        } @catch (__unused NSException *exception) {
        }
    }
    return nil;
}

static long long WCAtlasFriendRelationIntegerValue(id object,
                                                  NSArray<NSString *> *names,
                                                  BOOL *found) {
    if (found) *found = NO;
    if (!object) return 0;
    for (NSString *name in names) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(object_getClass(object), selector);
        if (method && method_getNumberOfArguments(method) == 2) {
            char type[16] = {0};
            method_getReturnType(method, type, sizeof(type));
            if (strchr("cCsSiIlLqQB", type[0])) {
                if (found) *found = YES;
                return ((long long (*)(id, SEL))objc_msgSend)(object, selector);
            }
            if (type[0] == '@') {
                id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                if ([value respondsToSelector:@selector(longLongValue)]) {
                    if (found) *found = YES;
                    return [value longLongValue];
                }
            }
        }
        @try {
            id value = [object valueForKey:name];
            if ([value respondsToSelector:@selector(longLongValue)]) {
                if (found) *found = YES;
                return [value longLongValue];
            }
        } @catch (__unused NSException *exception) {
        }
    }
    return 0;
}

static NSString *WCAtlasFriendRelationString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

static NSString *WCAtlasFriendRelationContactUserName(id contact) {
    return WCAtlasPrivateContactUserName(contact);
}

static NSString *WCAtlasFriendRelationContactDisplayName(id contact, NSString *fallback) {
    return WCAtlasPrivateContactDisplayName(contact, fallback) ?: @"";
}

static BOOL WCAtlasFriendRelationBoolSelector(id object, NSString *name, BOOL fallback) {
    SEL selector = NSSelectorFromString(name);
    Method method = object ? class_getInstanceMethod(object_getClass(object), selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return fallback;
    char type[16] = {0};
    method_getReturnType(method, type, sizeof(type));
    if (!strchr("cCsSiIlLqQB", type[0])) return fallback;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
}

static void WCAtlasFriendRelationInvokeObjectArgument(id target, SEL selector, id argument) {
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
}

static void WCAtlasFriendRelationInvokeNoArgument(id target, SEL selector) {
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static BOOL WCAtlasFriendRelationExcludedUserName(NSString *userName) {
    if (userName.length == 0 || [userName hasSuffix:@"@chatroom"] ||
        [userName hasPrefix:@"gh_"]) return YES;
    static NSSet<NSString *> *excluded;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        excluded = [NSSet setWithArray:@[
            @"filehelper", @"weixin", @"newsapp", @"fmessage", @"medianote",
            @"floatbottle", @"qqmail", @"tmessage", @"qmessage", @"qqsync",
            @"weibo", @"lbsapp", @"shakeapp", @"feedsapp", @"blogapp",
            @"voip", @"weixinreminder", @"officialaccounts", @"notification_messages"
        ]];
    });
    return [excluded containsObject:userName.lowercaseString];
}

static NSString *WCAtlasFriendRelationStoragePath(void) {
    NSURL *base = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                       inDomain:NSUserDomainMask
                                              appropriateForURL:nil
                                                         create:YES
                                                          error:nil];
    NSURL *directory = [base URLByAppendingPathComponent:@"WCAtlas" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
    return [[directory URLByAppendingPathComponent:@"friend-relation-check.json"] path];
}

@interface WCAtlasFriendRelationCgiBridge : NSObject
@property(nonatomic, copy) void (^handler)(id _Nullable response, id _Nullable error);
@property(nonatomic, assign) BOOL finished;
- (void)finishWithResponse:(nullable id)response error:(nullable id)error;
@end

@implementation WCAtlasFriendRelationCgiBridge

- (void)finishWithResponse:(id _Nullable)response error:(id _Nullable)error {
    void (^handler)(id, id) = nil;
    @synchronized (self) {
        if (self.finished) return;
        self.finished = YES;
        handler = self.handler;
        self.handler = nil;
    }
    if (handler) handler(response, error);
}

- (void)beforeTransferCgi:(__unused id)cgi didGetResponse:(id)response {
    [self finishWithResponse:response error:nil];
}

- (void)beforeTransferCgi:(__unused id)cgi didFailWith:(id)error {
    [self finishWithResponse:nil error:error];
}

- (void)beforeTransferCgi:(__unused id)cgi didFailWithError:(id)error {
    [self finishWithResponse:nil error:error];
}

@end

@interface WCAtlasFriendRelationChecker ()
@property(nonatomic, copy, readwrite) NSString *status;
@property(nonatomic, copy, readwrite, nullable) NSString *pauseReason;
@property(nonatomic, copy, readwrite) NSString *sourceTitle;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *pendingUserNames;
@property(nonatomic, copy) NSArray<NSString *> *activeQueue;
@property(nonatomic, assign) NSUInteger cursor;
@property(nonatomic, copy, readwrite) NSString *currentDisplayName;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *results;
@property(nonatomic, strong, nullable) id currentCgi;
@property(nonatomic, strong, nullable) WCAtlasFriendRelationCgiBridge *currentBridge;
@property(nonatomic, copy, nullable) NSString *waitingUserName;
@property(nonatomic, copy, nullable) dispatch_block_t timeoutBlock;
@property(nonatomic, copy, nullable) dispatch_block_t gapBlock;
@property(nonatomic, assign) NSInteger requestToken;
@property(nonatomic, assign) NSUInteger transportRetryCount;
@property(nonatomic, copy) NSString *lastProgressCapsuleStatus;
@end

@implementation WCAtlasFriendRelationChecker

+ (instancetype)sharedChecker {
    static WCAtlasFriendRelationChecker *checker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ checker = [WCAtlasFriendRelationChecker new]; });
    return checker;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _status = WCAtlasFriendRelationStatusIdle;
    _sourceTitle = @"全部好友";
    _pendingUserNames = @[];
    _activeQueue = @[];
    _currentDisplayName = @"";
    _results = [NSMutableDictionary dictionary];
    [self loadSnapshot];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appDidEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillEnterForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self cancelPendingWork];
}

- (void)performOnMain:(dispatch_block_t)block {
    if (!block) return;
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

- (NSDictionary *)snapshotDictionary {
    return @{
        @"status": self.status ?: WCAtlasFriendRelationStatusIdle,
        @"pauseReason": self.pauseReason ?: @"",
        @"sourceTitle": self.sourceTitle ?: @"全部好友",
        @"pendingUserNames": self.pendingUserNames ?: @[],
        @"queue": self.activeQueue ?: @[],
        @"cursor": @(self.cursor),
        @"currentDisplayName": self.currentDisplayName ?: @"",
        @"results": self.results ?: @{},
        @"transportRetryCount": @(self.transportRetryCount),
        @"updatedAt": @([NSDate.date timeIntervalSince1970]),
    };
}

- (void)loadSnapshot {
    NSData *data = [NSData dataWithContentsOfFile:WCAtlasFriendRelationStoragePath()];
    NSDictionary *snapshot = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![snapshot isKindOfClass:NSDictionary.class]) return;
    NSString *status = WCAtlasFriendRelationString(snapshot[@"status"]);
    if ([status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        status = WCAtlasFriendRelationStatusPaused;
        _pauseReason = WCAtlasFriendRelationPauseInterrupted;
    } else {
        _pauseReason = WCAtlasFriendRelationString(snapshot[@"pauseReason"]);
    }
    if (status.length > 0) _status = status;
    NSString *sourceTitle = WCAtlasFriendRelationString(snapshot[@"sourceTitle"]);
    if (sourceTitle.length > 0) _sourceTitle = sourceTitle;
    NSArray *pending = snapshot[@"pendingUserNames"];
    NSArray *queue = snapshot[@"queue"];
    NSDictionary *results = snapshot[@"results"];
    if ([pending isKindOfClass:NSArray.class]) _pendingUserNames = [pending copy];
    if ([queue isKindOfClass:NSArray.class]) _activeQueue = [queue copy];
    if ([results isKindOfClass:NSDictionary.class]) _results = [results mutableCopy];
    _cursor = MIN([snapshot[@"cursor"] unsignedIntegerValue], _activeQueue.count);
    _currentDisplayName = [WCAtlasFriendRelationString(snapshot[@"currentDisplayName"]) copy] ?: @"";
    _transportRetryCount = [snapshot[@"transportRetryCount"] unsignedIntegerValue];
}

- (void)saveAndNotify {
    NSDictionary *snapshot = [self snapshotDictionary];
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
    if (data) [data writeToFile:WCAtlasFriendRelationStoragePath() options:NSDataWritingAtomic error:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasFriendRelationCheckDidUpdateNotification
                                                       object:self];
    NSString *previousStatus = self.lastProgressCapsuleStatus;
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        NSString *name = self.currentDisplayName.length > 0 ? self.currentDisplayName : @"好友";
        WCAtlasShowProgressCapsule(
            [NSString stringWithFormat:@"检测 %@ · %lu/%lu", name,
             (unsigned long)self.completedCount, (unsigned long)self.totalCount],
            self.progress, @"person.2.fill");
    } else if ([self.status isEqualToString:WCAtlasFriendRelationStatusCompleted] &&
               ![previousStatus isEqualToString:WCAtlasFriendRelationStatusCompleted]) {
        WCAtlasCompleteProgressCapsule(
            [NSString stringWithFormat:@"检测完成 · 正常 %lu · 疑似 %lu · 待核查 %lu",
             (unsigned long)self.normalCount, (unsigned long)self.suspectedCount,
             (unsigned long)self.uncertainCount], YES);
    } else if ([self.status isEqualToString:WCAtlasFriendRelationStatusPaused] &&
               [previousStatus isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        WCAtlasCompleteProgressCapsule(
            [NSString stringWithFormat:@"检测已暂停 · %lu/%lu",
             (unsigned long)self.completedCount, (unsigned long)self.totalCount], NO);
    } else if ([self.status isEqualToString:WCAtlasFriendRelationStatusIdle]) {
        WCAtlasDismissProgressCapsule();
    }
    self.lastProgressCapsuleStatus = self.status;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)allFriendCandidates {
    id manager = WCAtlasFriendRelationServiceForClass(NSClassFromString(@"CContactMgr"));
    NSArray *rawContacts = WCAtlasPrivateContactList();
    if (rawContacts.count == 0) WCAtlasLog(@"单删检测未取得联系人列表");
    SEL membershipSelector = NSSelectorFromString(@"isInContactList:");
    BOOL canCheckMembership = [manager respondsToSelector:membershipSelector];

    NSMutableArray *candidates = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id rawContact in rawContacts) {
        NSString *userName = WCAtlasFriendRelationContactUserName(rawContact);
        if (WCAtlasFriendRelationExcludedUserName(userName) || [seen containsObject:userName]) continue;
        id contact = WCAtlasPrivateContact(userName) ?: rawContact;
        if (!contact || !WCAtlasFriendRelationBoolSelector(contact, @"isMMContact", YES)) continue;
        if (WCAtlasFriendRelationBoolSelector(contact, @"isBrandContact", NO) ||
            WCAtlasFriendRelationBoolSelector(contact, @"isChatRoom", NO) ||
            WCAtlasFriendRelationBoolSelector(contact, @"isSelf", NO) ||
            WCAtlasFriendRelationBoolSelector(contact, @"isBrandSessionHolder", NO) ||
            WCAtlasFriendRelationBoolSelector(contact, @"isBrandServiceBoxSession", NO) ||
            WCAtlasFriendRelationBoolSelector(contact, @"isTemplateMsgHolder", NO)) continue;
        BOOL friendSceneFound = NO;
        long long friendScene = WCAtlasFriendRelationIntegerValue(contact,
            @[@"m_uiFriendScene"], &friendSceneFound);
        if (!friendSceneFound || friendScene == 0) continue;
        if (canCheckMembership) {
            BOOL inContactList = NO;
            @try {
                inContactList = ((BOOL (*)(id, SEL, id))objc_msgSend)(manager,
                                                                     membershipSelector,
                                                                     userName);
            } @catch (__unused NSException *exception) {}
            if (!inContactList) continue;
        }
        [seen addObject:userName];
        [candidates addObject:@{
            @"userName": userName,
            @"displayName": WCAtlasFriendRelationContactDisplayName(contact, userName),
        }];
    }
    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"displayName"] localizedStandardCompare:right[@"displayName"]];
    }];
    return candidates;
}

- (void)setPendingUserNames:(NSArray<NSString *> *)userNames sourceTitle:(NSString *)sourceTitle {
    [self performOnMain:^{
        NSMutableOrderedSet *normalized = [NSMutableOrderedSet orderedSet];
        for (id value in userNames) {
            NSString *userName = WCAtlasFriendRelationString(value);
            if (!WCAtlasFriendRelationExcludedUserName(userName)) [normalized addObject:userName];
        }
        self.pendingUserNames = normalized.array;
        self.sourceTitle = sourceTitle.length > 0 ? sourceTitle : @"自选好友";
        if ([self.status isEqualToString:WCAtlasFriendRelationStatusCompleted]) {
            self.status = WCAtlasFriendRelationStatusIdle;
            self.pauseReason = nil;
            self.activeQueue = @[];
            self.cursor = 0;
            self.currentDisplayName = @"";
        }
        [self saveAndNotify];
    }];
}

- (BOOL)start {
    if (!NSThread.isMainThread) {
        __block BOOL started = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{ started = [self start]; });
        return started;
    }
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return NO;
    NSArray *queue = self.pendingUserNames;
    if (queue.count == 0) {
        queue = [[self allFriendCandidates] valueForKey:@"userName"];
        self.pendingUserNames = queue ?: @[];
        self.sourceTitle = @"全部好友";
    }
    if (queue.count == 0) return NO;
    WCAtlasLog(@"单删检测准备启动：候选 %lu 人，来源 %@",
             (unsigned long)queue.count, self.sourceTitle ?: @"");
    [self cancelPendingWork];
    self.activeQueue = [queue copy];
    self.cursor = 0;
    self.results = [NSMutableDictionary dictionary];
    self.status = WCAtlasFriendRelationStatusRunning;
    self.pauseReason = nil;
    self.currentDisplayName = @"准备开始";
    self.transportRetryCount = 0;
    [self saveAndNotify];
    [self startNext];
    return YES;
}

- (void)pause {
    [self pauseWithReason:WCAtlasFriendRelationPauseUser];
}

- (void)pauseWithReason:(NSString *)reason {
    [self performOnMain:^{
        if (![self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return;
        [self cancelPendingWork];
        self.status = WCAtlasFriendRelationStatusPaused;
        self.pauseReason = reason ?: WCAtlasFriendRelationPauseUser;
        self.currentDisplayName = [self.pauseReason isEqualToString:WCAtlasFriendRelationPauseNetwork]
            ? @"支付网络异常，已暂停" : @"检测已暂停";
        [self saveAndNotify];
    }];
}

- (BOOL)resume {
    if (!NSThread.isMainThread) {
        __block BOOL resumed = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{ resumed = [self resume]; });
        return resumed;
    }
    if (![self.status isEqualToString:WCAtlasFriendRelationStatusPaused] ||
        self.cursor >= self.activeQueue.count) return NO;
    [self cancelPendingWork];
    self.status = WCAtlasFriendRelationStatusRunning;
    self.pauseReason = nil;
    self.currentDisplayName = @"继续检测";
    self.transportRetryCount = 0;
    [self saveAndNotify];
    [self startNext];
    return YES;
}

- (void)stopAndSave {
    [self performOnMain:^{
        [self cancelPendingWork];
        if (![self.status isEqualToString:WCAtlasFriendRelationStatusCompleted]) {
            self.status = WCAtlasFriendRelationStatusPaused;
            self.pauseReason = WCAtlasFriendRelationPauseUser;
        }
        [self saveAndNotify];
    }];
}

- (BOOL)startRecheckWithUserNames:(NSArray<NSString *> *)userNames {
    [self setPendingUserNames:userNames sourceTitle:@"结果复检"];
    return [self start];
}

- (void)appDidEnterBackground {
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        [self pauseWithReason:WCAtlasFriendRelationPauseBackground];
    }
}

- (void)appWillEnterForeground {
    if ([self.pauseReason isEqualToString:WCAtlasFriendRelationPauseBackground]) {
        self.currentDisplayName = @"已从后台暂停，点击继续";
        [self saveAndNotify];
    }
}

- (void)cancelPendingWork {
    self.requestToken += 1;
    if (self.timeoutBlock) dispatch_block_cancel(self.timeoutBlock);
    if (self.gapBlock) dispatch_block_cancel(self.gapBlock);
    self.timeoutBlock = nil;
    self.gapBlock = nil;
    self.currentBridge.handler = nil;
    self.currentBridge = nil;
    self.currentCgi = nil;
    self.waitingUserName = nil;
}

- (id)contactForUserName:(NSString *)userName {
    return WCAtlasPrivateContact(userName);
}

- (BOOL)isStillFriendCandidate:(NSString *)userName {
    if (WCAtlasFriendRelationExcludedUserName(userName)) return NO;
    id manager = WCAtlasFriendRelationServiceForClass(NSClassFromString(@"CContactMgr"));
    SEL selector = NSSelectorFromString(@"isInContactList:");
    if ([manager respondsToSelector:selector]) {
        @try { return ((BOOL (*)(id, SEL, id))objc_msgSend)(manager, selector, userName); }
        @catch (__unused NSException *exception) {}
    }
    return [self contactForUserName:userName] != nil;
}

- (void)startNext {
    if (![self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return;
    NSUInteger skipped = 0;
    while (self.cursor < self.activeQueue.count) {
        NSString *userName = self.activeQueue[self.cursor];
        if ([self isStillFriendCandidate:userName]) {
            if (skipped > 0) {
                WCAtlasLog(@"单删检测跳过 %lu 个已不在通讯录的账号",
                         (unsigned long)skipped);
            }
            [self fireCgiForUserName:userName];
            return;
        }
        self.cursor += 1;
        skipped += 1;
    }
    if (skipped > 0) {
        WCAtlasLog(@"单删检测没有剩余可调用账号：本轮跳过 %lu 个",
                 (unsigned long)skipped);
    }
    [self cancelPendingWork];
    self.status = WCAtlasFriendRelationStatusCompleted;
    self.pauseReason = nil;
    self.currentDisplayName = @"检测完成";
    [self saveAndNotify];
}

- (void)fireCgiForUserName:(NSString *)userName {
    if (![self.status isEqualToString:WCAtlasFriendRelationStatusRunning] || userName.length == 0) return;
    Class cgiClass = NSClassFromString(@"WCPayBeforeTransferCgi");
    SEL usernameSelector = NSSelectorFromString(@"setUsername:");
    SEL delegateSelector = NSSelectorFromString(@"setDelegate:");
    SEL startSelector = NSSelectorFromString(@"startRequest");
    id cgi = nil;
    @try { cgi = cgiClass ? [cgiClass new] : nil; }
    @catch (NSException *exception) {
        WCAtlasLog(@"单删检测创建支付 CGI 失败：%@", exception.reason ?: exception.name);
    }
    Method usernameMethod = cgi ? class_getInstanceMethod(object_getClass(cgi), usernameSelector) : NULL;
    Method delegateMethod = cgi ? class_getInstanceMethod(object_getClass(cgi), delegateSelector) : NULL;
    Method startMethod = cgi ? class_getInstanceMethod(object_getClass(cgi), startSelector) : NULL;
    BOOL compatible = cgi && [cgi respondsToSelector:usernameSelector] &&
        [cgi respondsToSelector:delegateSelector] && [cgi respondsToSelector:startSelector];
    if (!cgi || !compatible) {
        WCAtlasLog(@"单删检测支付 CGI 不兼容：class=%@ username=%@ delegate=%@ start=%@",
                 cgiClass ? NSStringFromClass(cgiClass) : @"nil",
                 usernameMethod ? @"YES" : @"NO",
                 delegateMethod ? @"YES" : @"NO",
                 startMethod ? @"YES" : @"NO");
        [self completeCurrentUser:userName
                         display:WCAtlasFriendRelationContactDisplayName([self contactForUserName:userName], userName)
                         verdict:WCAtlasFriendRelationVerdictUncertain
                            mask:nil
                         retcode:-1
                          retmsg:@"当前微信支付模块不支持检测"];
        [self pauseWithReason:WCAtlasFriendRelationPauseNetwork];
        return;
    }

    NSString *displayName = WCAtlasFriendRelationContactDisplayName([self contactForUserName:userName], userName);
    self.currentDisplayName = displayName;
    self.requestToken += 1;
    NSInteger token = self.requestToken;
    self.waitingUserName = userName;
    WCAtlasFriendRelationCgiBridge *bridge = [WCAtlasFriendRelationCgiBridge new];
    __weak typeof(self) weakSelf = self;
    bridge.handler = ^(id response, id error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || token != self.requestToken ||
                ![self.waitingUserName isEqualToString:userName]) return;
            [self handleCgiResponse:response error:error userName:userName displayName:displayName];
        });
    };
    self.currentCgi = cgi;
    self.currentBridge = bridge;
    @try {
        WCAtlasFriendRelationInvokeObjectArgument(cgi, usernameSelector, userName);
        WCAtlasFriendRelationInvokeObjectArgument(cgi, delegateSelector, bridge);
        [self saveAndNotify];
        WCAtlasFriendRelationInvokeNoArgument(cgi, startSelector);
        WCAtlasLog(@"单删检测已启动支付 CGI：%@", userName);
    } @catch (NSException *exception) {
        WCAtlasLog(@"单删检测调用支付 CGI 失败：%@", exception.reason ?: exception.name);
        [self handleCgiResponse:nil error:exception userName:userName displayName:displayName];
        return;
    }

    dispatch_block_t timeout = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || token != self.requestToken ||
            ![self.waitingUserName isEqualToString:userName]) return;
        NSError *error = [NSError errorWithDomain:@"com.wcatlas.friendrelation"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"timeout"}];
        [self handleCgiResponse:nil error:error userName:userName displayName:displayName];
    });
    self.timeoutBlock = timeout;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), timeout);
}

- (BOOL)isTransportErrorCode:(long long)code message:(NSString *)message {
    if (code == 9999 || code == -2 || code == -3) return YES;
    NSString *lower = message.lowercaseString ?: @"";
    for (NSString *needle in @[@"timeout", @"no_start", @"networkingerror",
                               @"网络通信", @"网络异常", @"网络繁忙"]) {
        if ([lower containsString:needle.lowercaseString]) return YES;
    }
    return NO;
}

- (BOOL)isNotFriendErrorCode:(long long)code message:(NSString *)message {
    if (code == 0x10010401LL) return YES;
    NSString *normalized = message ?: @"";
    for (NSString *needle in @[@"不是收款方好友", @"对方添加你为好友", @"不是你的好友",
                               @"不是好友", @"非好友"]) {
        if ([normalized containsString:needle]) return YES;
    }
    return NO;
}

- (void)handleCgiResponse:(id)response
                    error:(id)error
                 userName:(NSString *)userName
              displayName:(NSString *)displayName {
    if (![self.waitingUserName isEqualToString:userName]) return;
    if (self.timeoutBlock) dispatch_block_cancel(self.timeoutBlock);
    self.timeoutBlock = nil;
    self.currentBridge.handler = nil;
    self.currentBridge = nil;
    self.currentCgi = nil;
    self.waitingUserName = nil;

    BOOL codeFound = NO;
    long long code = WCAtlasFriendRelationIntegerValue(response,
        @[@"retcode", @"errorCode", @"m_errorCode", @"code"], &codeFound);
    if (!codeFound) {
        code = WCAtlasFriendRelationIntegerValue(error,
            @[@"code", @"errorCode", @"m_errorCode", @"retcode"], &codeFound);
    }
    NSMutableArray<NSString *> *messages = [NSMutableArray array];
    for (id object in @[response ?: NSNull.null, error ?: NSNull.null]) {
        if (object == NSNull.null) continue;
        NSString *message = WCAtlasFriendRelationString(WCAtlasFriendRelationObjectValue(object,
            @[@"retmsg", @"errorDesc", @"m_nsErrorDesc", @"localizedDescription", @"reason"]));
        if (message.length > 0 && ![messages containsObject:message]) [messages addObject:message];
    }
    NSString *message = [messages componentsJoinedByString:@" · "];
    NSString *mask = WCAtlasPrivateMaskedTransferName(response);

    if ([self isTransportErrorCode:code message:message]) {
        if (self.transportRetryCount < 2 &&
            [self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
            self.transportRetryCount += 1;
            NSTimeInterval delay = self.transportRetryCount == 1 ? 3.0 : 8.0;
            self.currentDisplayName = [NSString stringWithFormat:@"支付网络繁忙，%.0f 秒后重试（%lu/2）",
                                       delay, (unsigned long)self.transportRetryCount];
            [self saveAndNotify];
            NSInteger token = self.requestToken;
            __weak typeof(self) weakSelf = self;
            dispatch_block_t retry = dispatch_block_create(0, ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || token != self.requestToken ||
                    ![self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return;
                [self fireCgiForUserName:userName];
            });
            self.gapBlock = retry;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), retry);
            return;
        }
        [self completeCurrentUser:userName display:displayName
                         verdict:WCAtlasFriendRelationVerdictUncertain mask:mask
                         retcode:code retmsg:message.length > 0 ? message : @"支付网络异常"];
        [self pauseWithReason:WCAtlasFriendRelationPauseNetwork];
        return;
    }

    self.transportRetryCount = 0;
    NSString *verdict = WCAtlasFriendRelationVerdictUncertain;
    if ([self isNotFriendErrorCode:code message:message]) {
        verdict = WCAtlasFriendRelationVerdictSuspected;
    } else if (mask.length > 0) {
        verdict = WCAtlasFriendRelationVerdictNormal;
    }
    [self completeCurrentUser:userName display:displayName verdict:verdict mask:mask
                     retcode:code retmsg:message];
}

- (void)completeCurrentUser:(NSString *)userName
                    display:(NSString *)displayName
                    verdict:(NSString *)verdict
                       mask:(nullable NSString *)mask
                    retcode:(long long)retcode
                     retmsg:(nullable NSString *)retmsg {
    if (userName.length == 0) return;
    self.results[userName] = @{
        @"userName": userName,
        @"displayName": displayName.length > 0 ? displayName : userName,
        @"verdict": verdict ?: WCAtlasFriendRelationVerdictUncertain,
        @"mask": mask ?: @"",
        @"maskLastChar": WCAtlasPrivateMaskedTransferNameSuffix(mask) ?: @"",
        @"retcode": @(retcode),
        @"retmsg": retmsg ?: @"",
        @"checkedAt": @([NSDate.date timeIntervalSince1970]),
    };
    if (self.cursor < self.activeQueue.count &&
        [self.activeQueue[self.cursor] isEqualToString:userName]) self.cursor += 1;
    self.currentDisplayName = displayName ?: userName;
    [self saveAndNotify];
    if (![self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return;
    if (self.cursor >= self.activeQueue.count) {
        [self startNext];
        return;
    }
    NSTimeInterval gap = 1.0 + arc4random_uniform(4001) / 1000.0;
    NSInteger token = self.requestToken;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t next = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || token != self.requestToken ||
            ![self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) return;
        [self startNext];
    });
    self.gapBlock = next;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(gap * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), next);
}

- (NSUInteger)completedCount { return MIN(self.cursor, self.activeQueue.count); }
- (NSUInteger)totalCount { return self.activeQueue.count; }

- (NSUInteger)countForVerdict:(NSString *)verdict {
    NSUInteger count = 0;
    for (NSDictionary *item in self.results.allValues) {
        if ([item[@"verdict"] isEqualToString:verdict]) count += 1;
    }
    return count;
}

- (NSUInteger)normalCount { return [self countForVerdict:WCAtlasFriendRelationVerdictNormal]; }
- (NSUInteger)suspectedCount { return [self countForVerdict:WCAtlasFriendRelationVerdictSuspected]; }
- (NSUInteger)uncertainCount { return [self countForVerdict:WCAtlasFriendRelationVerdictUncertain]; }

- (float)progress {
    return self.totalCount > 0 ? (float)self.completedCount / (float)self.totalCount : 0.0f;
}

- (NSString *)progressTitle {
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        return [NSString stringWithFormat:@"正在检测 %@（%lu/%lu）",
                self.currentDisplayName.length > 0 ? self.currentDisplayName : @"好友",
                (unsigned long)self.completedCount, (unsigned long)self.totalCount];
    }
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusPaused]) {
        return [NSString stringWithFormat:@"已暂停 %lu/%lu",
                (unsigned long)self.completedCount, (unsigned long)self.totalCount];
    }
    if ([self.status isEqualToString:WCAtlasFriendRelationStatusCompleted]) return @"检测完成";
    return self.pendingUserNames.count > 0
        ? [NSString stringWithFormat:@"待检测 %lu 人", (unsigned long)self.pendingUserNames.count]
        : @"未开始";
}

- (NSArray<NSDictionary<NSString *, id> *> *)itemsWithVerdict:(NSString *)verdict {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *item in self.results.allValues) {
        if ([item[@"verdict"] isEqualToString:verdict]) [items addObject:item];
    }
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"displayName"] localizedStandardCompare:right[@"displayName"]];
    }];
    return items;
}

- (NSString *)maskedRealNameForUserName:(NSString *)userName {
    if (userName.length == 0) return nil;
    NSString *maskedName = WCAtlasFriendRelationString(self.results[userName][@"mask"]);
    return WCAtlasPrivateMaskedTransferName(maskedName);
}

- (void)removeResultUserNames:(NSArray<NSString *> *)userNames {
    [self performOnMain:^{
        [self.results removeObjectsForKeys:userNames];
        [self saveAndNotify];
    }];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)deleteUserNames:(NSArray<NSString *> *)userNames
                                                   retainChatHistory:(BOOL)retainChatHistory {
    NSAssert(NSThread.isMainThread, @"Contact deletion must run on the main thread");
    NSMutableArray<NSString *> *deleted = [NSMutableArray array];
    NSMutableArray<NSString *> *failed = [NSMutableArray array];
    id contactManager = WCAtlasFriendRelationServiceForClass(NSClassFromString(@"CContactMgr"));
    id contactOPLog = retainChatHistory
        ? WCAtlasFriendRelationServiceForClass(NSClassFromString(@"CContactOPLog")) : nil;
    SEL retainSelector = NSSelectorFromString(@"add_DeleteContact:isRetainChatHistory:delScene:sync:");
    SEL fullDeleteSelector = NSSelectorFromString(@"deleteContact:listType:andScene:sync:local:");
    SEL basicDeleteSelector = NSSelectorFromString(@"deleteContact:listType:");
    SEL localDeleteSelector = NSSelectorFromString(@"deleteContactLocal:listType:");
    SEL membershipSelector = NSSelectorFromString(@"isInContactList:");

    for (id candidate in userNames) {
        NSString *userName = [candidate isKindOfClass:NSString.class] ? candidate : nil;
        if (userName.length == 0 || !contactManager) {
            if (userName.length > 0) [failed addObject:userName];
            continue;
        }
        id contact = [self contactForUserName:userName];
        if (!contact) {
            [failed addObject:userName];
            continue;
        }

        @try {
            if (retainChatHistory && WCAtlasFriendRelationCanInvoke(contactOPLog, retainSelector, 6)) {
                ((void (*)(id, SEL, id, BOOL, NSUInteger, BOOL))objc_msgSend)(
                    contactOPLog, retainSelector, userName, YES, 0, YES);
            }
            if (WCAtlasFriendRelationCanInvoke(contactManager, fullDeleteSelector, 7)) {
                ((void (*)(id, SEL, id, NSUInteger, NSUInteger, BOOL, BOOL))objc_msgSend)(
                    contactManager, fullDeleteSelector, contact, 1, 0, YES, YES);
            } else if (WCAtlasFriendRelationCanInvoke(contactManager, basicDeleteSelector, 4)) {
                ((void (*)(id, SEL, id, NSUInteger))objc_msgSend)(
                    contactManager, basicDeleteSelector, contact, 1);
            } else {
                [failed addObject:userName];
                continue;
            }

            BOOL canReadMembership = WCAtlasFriendRelationCanInvoke(contactManager, membershipSelector, 3);
            BOOL stillInContactList = canReadMembership
                ? ((BOOL (*)(id, SEL, id))objc_msgSend)(contactManager, membershipSelector, userName)
                : [self contactForUserName:userName] != nil;
            if (stillInContactList && WCAtlasFriendRelationCanInvoke(contactManager, localDeleteSelector, 4)) {
                ((void (*)(id, SEL, id, NSUInteger))objc_msgSend)(
                    contactManager, localDeleteSelector, contact, 1);
                stillInContactList = canReadMembership
                    ? ((BOOL (*)(id, SEL, id))objc_msgSend)(contactManager, membershipSelector, userName)
                    : NO;
            }
            if (stillInContactList) [failed addObject:userName];
            else [deleted addObject:userName];
        } @catch (NSException *exception) {
            WCAtlasLog(@"删除好友 %@ 失败：%@", userName, exception.reason ?: exception.name);
            [failed addObject:userName];
        }
    }

    if (deleted.count > 0) {
        [self.results removeObjectsForKeys:deleted];
        NSMutableArray *pending = [self.pendingUserNames mutableCopy] ?: [NSMutableArray array];
        [pending removeObjectsInArray:deleted];
        self.pendingUserNames = [pending copy];
        [self saveAndNotify];
    }
    return @{ @"deleted": [deleted copy], @"failed": [failed copy] };
}

@end
