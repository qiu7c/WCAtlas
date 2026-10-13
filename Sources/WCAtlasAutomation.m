#import "WCAtlasAutomation.h"
#import "WCAtlasBackgroundKeeper.h"
#import "WCAtlasLogging.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasSilkEncoder.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <UIKit/UIKit.h>

static NSString *const WCAtlasAutomationTasksKey = @"com.qiu7c.wcatlas.automation.tasks.v1";
static NSString *const WCAtlasAutomationSeedVersionKey = @"com.qiu7c.wcatlas.automation.seed-version";
static const NSUInteger WCAtlasAutomationMaximumResponseBytes = 1024 * 1024;

@implementation WCAtlasAutomationTask

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _identifier = NSUUID.UUID.UUIDString.lowercaseString;
    _name = @"定时消息";
    _targetUserName = @"";
    _targetUserNames = @[];
    _enabled = YES;
    _sourceType = WCAtlasAutomationSourceTypeFixedText;
    _fixedText = @"";
    _script = @"function main(input) {\n  return \"定时消息\";\n}";
    _nextFireDate = [NSDate dateWithTimeIntervalSinceNow:300.0];
    _repeatMode = WCAtlasAutomationRepeatModeOnce;
    _triggerMode = WCAtlasAutomationTriggerModeScheduled;
    _triggerKeyword = @"";
    _keywordScopeMode = WCAtlasAutomationKeywordScopeModeWhitelist;
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    WCAtlasAutomationTask *task = [[[self class] allocWithZone:zone] init];
    task.identifier = self.identifier;
    task.name = self.name;
    task.targetUserName = self.targetUserName;
    task.targetUserNames = self.targetUserNames;
    task.enabled = self.enabled;
    task.sourceType = self.sourceType;
    task.fixedText = self.fixedText;
    task.libraryItemIdentifier = self.libraryItemIdentifier;
    task.script = self.script;
    task.nextFireDate = self.nextFireDate;
    task.repeatMode = self.repeatMode;
    task.triggerMode = self.triggerMode;
    task.triggerKeyword = self.triggerKeyword;
    task.keywordScopeMode = self.keywordScopeMode;
    task.lastRunDate = self.lastRunDate;
    task.lastResult = self.lastResult;
    return task;
}

@end

@interface WCAtlasAutomationManager ()
@property (nonatomic, strong) NSMutableArray<WCAtlasAutomationTask *> *mutableTasks;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) dispatch_queue_t scriptQueue;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) NSUInteger activeExecutions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *recentIncomingMessages;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *completionHandlers;
@end

@implementation WCAtlasAutomationManager

+ (instancetype)sharedManager {
    static WCAtlasAutomationManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] init]; });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _scriptQueue = dispatch_queue_create("com.qiu7c.wcatlas.automation-scripts", DISPATCH_QUEUE_SERIAL);
    _completionHandlers = [NSMutableDictionary dictionary];
    _mutableTasks = [NSMutableArray array];
    _recentIncomingMessages = [NSMutableDictionary dictionary];
    [self loadTasks];
    return self;
}

static NSString *WCAtlasAutomationString(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (WCAtlasAutomationTask *)taskFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    NSString *identifier = WCAtlasAutomationString(dictionary[@"id"]);
    if (identifier.length == 0) return nil;
    WCAtlasAutomationTask *task = [WCAtlasAutomationTask new];
    task.identifier = identifier;
    task.name = WCAtlasAutomationString(dictionary[@"name"]);
    task.targetUserName = WCAtlasAutomationString(dictionary[@"target"]);
    NSMutableArray *targets = [NSMutableArray array];
    for (id value in [dictionary[@"targets"] isKindOfClass:NSArray.class] ? dictionary[@"targets"] : @[]) {
        NSString *target = WCAtlasAutomationString(value);
        if (target.length && ![targets containsObject:target]) [targets addObject:target];
    }
    if (targets.count == 0 && task.targetUserName.length) [targets addObject:task.targetUserName];
    task.targetUserNames = targets.copy;
    task.enabled = [dictionary[@"enabled"] boolValue];
    task.sourceType = MAX(WCAtlasAutomationSourceTypeFixedText,
                          MIN(WCAtlasAutomationSourceTypeJavaScript, [dictionary[@"source"] integerValue]));
    task.fixedText = [dictionary[@"text"] isKindOfClass:NSString.class] ? dictionary[@"text"] : @"";
    task.libraryItemIdentifier = WCAtlasAutomationString(dictionary[@"library"]);
    task.script = [dictionary[@"script"] isKindOfClass:NSString.class] ? dictionary[@"script"] : @"";
    NSTimeInterval fire = [dictionary[@"nextFire"] doubleValue];
    task.nextFireDate = fire > 0 ? [NSDate dateWithTimeIntervalSince1970:fire] : NSDate.date;
    task.repeatMode = [dictionary[@"repeat"] integerValue] == WCAtlasAutomationRepeatModeDaily
        ? WCAtlasAutomationRepeatModeDaily : WCAtlasAutomationRepeatModeOnce;
    task.triggerMode = [dictionary[@"trigger"] integerValue] == WCAtlasAutomationTriggerModeKeyword
        ? WCAtlasAutomationTriggerModeKeyword : WCAtlasAutomationTriggerModeScheduled;
    task.triggerKeyword = WCAtlasAutomationString(dictionary[@"keyword"]);
    task.keywordScopeMode = [dictionary[@"keywordScope"] integerValue] == WCAtlasAutomationKeywordScopeModeBlacklist
        ? WCAtlasAutomationKeywordScopeModeBlacklist : WCAtlasAutomationKeywordScopeModeWhitelist;
    NSTimeInterval lastRun = [dictionary[@"lastRun"] doubleValue];
    task.lastRunDate = lastRun > 0 ? [NSDate dateWithTimeIntervalSince1970:lastRun] : nil;
    task.lastResult = [dictionary[@"lastResult"] isKindOfClass:NSString.class]
        ? dictionary[@"lastResult"] : nil;
    return task;
}

- (NSDictionary *)dictionaryForTask:(WCAtlasAutomationTask *)task {
    NSMutableDictionary *dictionary = [@{
        @"id": task.identifier ?: @"",
        @"name": task.name ?: @"",
        @"target": task.targetUserName ?: @"",
        @"targets": task.targetUserNames ?: @[],
        @"enabled": @(task.isEnabled),
        @"source": @(task.sourceType),
        @"text": task.fixedText ?: @"",
        @"script": task.script ?: @"",
        @"nextFire": @((task.nextFireDate ?: NSDate.date).timeIntervalSince1970),
        @"repeat": @(task.repeatMode),
        @"trigger": @(task.triggerMode),
        @"keyword": task.triggerKeyword ?: @"",
        @"keywordScope": @(task.keywordScopeMode),
    } mutableCopy];
    if (task.libraryItemIdentifier.length) dictionary[@"library"] = task.libraryItemIdentifier;
    if (task.lastRunDate) dictionary[@"lastRun"] = @(task.lastRunDate.timeIntervalSince1970);
    if (task.lastResult.length) dictionary[@"lastResult"] = task.lastResult;
    return dictionary;
}

- (void)loadTasks {
    NSArray *saved = [NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasAutomationTasksKey];
    for (NSDictionary *dictionary in saved ?: @[]) {
        WCAtlasAutomationTask *task = [self taskFromDictionary:dictionary];
        if (task) [self.mutableTasks addObject:task];
    }
    if ([NSUserDefaults.standardUserDefaults integerForKey:WCAtlasAutomationSeedVersionKey] < 1) {
        WCAtlasAutomationTask *sample = [WCAtlasAutomationTask new];
        sample.name = @"示例：三角洲每日密码";
        sample.enabled = NO;
        sample.sourceType = WCAtlasAutomationSourceTypeJavaScript;
        sample.repeatMode = WCAtlasAutomationRepeatModeDaily;
        sample.script = @"function main(input) {\n"
            @"  var raw = httpGet('https://ovoy.cc/1.php');\n"
            @"  var data = JSON.parse(raw);\n"
            @"  if (!data.success || !data.passwords) throw new Error('接口未返回有效密码');\n"
            @"  var lines = ['三角洲每日密码 ' + (data.date || '')];\n"
            @"  Object.keys(data.passwords).forEach(function(name) {\n"
            @"    lines.push(name + '：' + data.passwords[name]);\n"
            @"  });\n"
            @"  return lines.join('\\n');\n"
            @"}";
        [self.mutableTasks addObject:sample];
        [NSUserDefaults.standardUserDefaults setInteger:1 forKey:WCAtlasAutomationSeedVersionKey];
        [self persistTasks];
    }
}

- (void)updateBackgroundRequirement {
    BOOL required = self.activeExecutions > 0;
    for (WCAtlasAutomationTask *task in self.mutableTasks) {
        if (task.isEnabled) {
            required = YES;
            break;
        }
    }
    WCAtlasBackgroundKeeperSetAutomationRequired(required);
}

- (void)persistTasks {
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:self.mutableTasks.count];
    for (WCAtlasAutomationTask *task in self.mutableTasks) [records addObject:[self dictionaryForTask:task]];
    [NSUserDefaults.standardUserDefaults setObject:records forKey:WCAtlasAutomationTasksKey];
}

- (NSArray<WCAtlasAutomationTask *> *)tasks {
    NSMutableArray *copies = [NSMutableArray arrayWithCapacity:self.mutableTasks.count];
    for (WCAtlasAutomationTask *task in self.mutableTasks) [copies addObject:task.copy];
    return copies;
}

- (void)start {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self start]; });
        return;
    }
    if (self.started) return;
    self.started = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification object:nil];
    self.timer = [NSTimer timerWithTimeInterval:10.0 target:self
                                      selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self updateBackgroundRequirement];
    [self runDueTasks];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self runDueTasks];
}

- (void)timerFired:(NSTimer *)timer {
    (void)timer;
    [self runDueTasks];
}

- (void)saveTask:(WCAtlasAutomationTask *)task {
    if (!task.identifier.length) task.identifier = NSUUID.UUID.UUIDString.lowercaseString;
    NSUInteger index = [self.mutableTasks indexOfObjectPassingTest:^BOOL(WCAtlasAutomationTask *candidate,
                                                                         NSUInteger idx,
                                                                         BOOL *stop) {
        (void)idx;
        (void)stop;
        return [candidate.identifier isEqualToString:task.identifier];
    }];
    if (index == NSNotFound) [self.mutableTasks addObject:task.copy];
    else self.mutableTasks[index] = task.copy;
    [self persistTasks];
    [self updateBackgroundRequirement];
    [self runDueTasks];
}

- (void)deleteTaskWithIdentifier:(NSString *)identifier {
    NSIndexSet *indexes = [self.mutableTasks indexesOfObjectsPassingTest:^BOOL(WCAtlasAutomationTask *task,
                                                                               NSUInteger idx,
                                                                               BOOL *stop) {
        (void)idx;
        (void)stop;
        return [task.identifier isEqualToString:identifier];
    }];
    if (indexes.count) {
        [self.mutableTasks removeObjectsAtIndexes:indexes];
        [self persistTasks];
        [self updateBackgroundRequirement];
    }
}

- (WCAtlasAutomationTask *)storedTaskWithIdentifier:(NSString *)identifier {
    for (WCAtlasAutomationTask *task in self.mutableTasks) {
        if ([task.identifier isEqualToString:identifier]) return task;
    }
    return nil;
}

- (WCAtlasQuickReplyItem *)libraryItemForTask:(WCAtlasAutomationTask *)task {
    for (WCAtlasQuickReplyItem *item in WCAtlasQuickReplyStore.sharedStore.items) {
        if ([item.identifier isEqualToString:task.libraryItemIdentifier]) return item;
    }
    return nil;
}

static NSString *WCAtlasAutomationHTTPRequest(NSString *method,
                                             NSString *URLString,
                                             NSString *body,
                                             NSString *contentType,
                                             NSInteger *statusCode,
                                             NSString **failureReason) {
    NSURL *URL = [NSURL URLWithString:WCAtlasAutomationString(URLString)];
    NSString *scheme = URL.scheme.lowercaseString;
    if (!URL || (![@"http" isEqualToString:scheme] && ![@"https" isEqualToString:scheme])) {
        if (failureReason) *failureReason = @"HTTP 地址无效";
        return nil;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    request.HTTPMethod = method;
    if (body) {
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:contentType.length ? contentType : @"application/json; charset=utf-8"
       forHTTPHeaderField:@"Content-Type"];
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    __block NSURLResponse *response = nil;
    __block NSError *responseError = nil;
    NSURLSessionDataTask *dataTask = [NSURLSession.sharedSession
        dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *URLResponse, NSError *error) {
        responseData = data;
        response = URLResponse;
        responseError = error;
        dispatch_semaphore_signal(semaphore);
    }];
    [dataTask resume];
    if (dispatch_semaphore_wait(semaphore,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(22.0 * NSEC_PER_SEC))) != 0) {
        [dataTask cancel];
        if (failureReason) *failureReason = @"HTTP 请求超时";
        return nil;
    }
    if (responseError) {
        if (failureReason) *failureReason = responseError.localizedDescription;
        return nil;
    }
    if (responseData.length > WCAtlasAutomationMaximumResponseBytes) {
        if (failureReason) *failureReason = @"HTTP 响应超过 1 MB";
        return nil;
    }
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (statusCode) *statusCode = code;
        if (code < 200 || code >= 300) {
            if (failureReason) *failureReason = [NSString stringWithFormat:@"HTTP 状态码 %ld", (long)code];
            return nil;
        }
    }
    NSString *text = [[NSString alloc] initWithData:responseData ?: NSData.data
                                           encoding:NSUTF8StringEncoding];
    if (!text && failureReason) *failureReason = @"HTTP 响应不是 UTF-8 文本";
    return text;
}

static NSString *WCAtlasAutomationDownloadURL(NSString *URLString, NSString *type, NSString **failureReason) {
    NSURL *URL = [NSURL URLWithString:WCAtlasAutomationString(URLString)];
    if (!URL || ![@[@"http", @"https"] containsObject:URL.scheme.lowercaseString]) {
        if (failureReason) *failureReason = @"媒体地址无效";
        return nil;
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSURLResponse *response = nil;
    __block NSError *requestError = nil;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:URL
        completionHandler:^(NSData *value, NSURLResponse *URLResponse, NSError *error) {
        data = value; response = URLResponse; requestError = error; dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 32 * NSEC_PER_SEC)) != 0) {
        [task cancel]; if (failureReason) *failureReason = @"媒体请求超时"; return nil;
    }
    if (requestError || data.length == 0) {
        if (failureReason) *failureReason = requestError.localizedDescription ?: @"媒体响应为空";
        return nil;
    }
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
        if (status < 200 || status >= 300) {
            if (failureReason) *failureReason = [NSString stringWithFormat:@"媒体 HTTP 状态码 %ld", (long)status];
            return nil;
        }
    }
    NSUInteger limit = [type isEqualToString:@"video"] ? 200 * 1024 * 1024 : 50 * 1024 * 1024;
    if (data.length > limit) { if (failureReason) *failureReason = @"媒体文件过大"; return nil; }
    NSString *extension = URL.pathExtension.lowercaseString;
    if ([@[@"php", @"asp", @"aspx", @"cgi"] containsObject:extension]) extension = nil;
    if (!extension.length) extension = response.suggestedFilename.pathExtension.lowercaseString;
    if ([@[@"php", @"asp", @"aspx", @"cgi"] containsObject:extension]) extension = nil;
    NSString *MIMEType = response.MIMEType.lowercaseString;
    if (!extension.length && [MIMEType hasPrefix:@"image/"]) extension = [MIMEType substringFromIndex:6];
    if (!extension.length && [MIMEType isEqualToString:@"video/quicktime"]) extension = @"mov";
    if (!extension.length && [MIMEType hasPrefix:@"video/"]) extension = @"mp4";
    if (!extension.length && [MIMEType hasPrefix:@"audio/"]) extension = [MIMEType substringFromIndex:6];
    if (!extension.length) extension = [type isEqualToString:@"image"] ? @"jpg" :
        ([type isEqualToString:@"video"] ? @"mp4" : @"audio");
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"wcatlas-%@.%@", NSUUID.UUID.UUIDString, extension]];
    if (![data writeToFile:path atomically:YES]) {
        if (failureReason) *failureReason = @"媒体临时文件写入失败";
        return nil;
    }
    return path;
}

- (id)executeScript:(NSString *)script input:(NSDictionary *)input error:(NSString **)error {
    if (script.length == 0) {
        if (error) *error = @"JS 脚本为空";
        return nil;
    }
    JSContext *context = [[JSContext alloc] init];
    __block NSString *HTTPFailure = nil;
    context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
        HTTPFailure = exception.toString ?: @"JavaScript 执行异常";
        ctx.exception = exception;
    };
    context[@"httpGet"] = ^NSString *(id URLValue) {
        NSInteger status = 0;
        NSString *failure = nil;
        NSString *value = WCAtlasAutomationHTTPRequest(@"GET", WCAtlasAutomationString(URLValue),
                                                      nil, nil, &status, &failure);
        HTTPFailure = failure;
        return value ?: @"";
    };
    context[@"httpPost"] = ^NSString *(id URLValue, id bodyValue, id contentTypeValue) {
        NSInteger status = 0;
        NSString *failure = nil;
        NSString *body = [bodyValue isKindOfClass:NSString.class] ? bodyValue : @"";
        NSString *contentType = [contentTypeValue isKindOfClass:NSString.class] ? contentTypeValue : nil;
        NSString *value = WCAtlasAutomationHTTPRequest(@"POST", WCAtlasAutomationString(URLValue),
                                                      body, contentType, &status, &failure);
        HTTPFailure = failure;
        return value ?: @"";
    };
    JSValue *evaluation = [context evaluateScript:script withSourceURL:
        [NSURL URLWithString:@"wcatlas-automation://task.js"]];
    if (context.exception) {
        if (error) *error = context.exception.toString ?: @"JavaScript 执行失败";
        return nil;
    }
    JSValue *main = context[@"main"];
    JSValue *result = main.isObject
        ? [main callWithArguments:@[input ?: @{}]]
        : evaluation;
    if (context.exception) {
        if (error) *error = context.exception.toString ?: @"JavaScript main 执行失败";
        return nil;
    }
    id object = result.isString ? result.toString : [result toObject];
    if ((!object || object == NSNull.null) ||
        ([object isKindOfClass:NSString.class] && WCAtlasAutomationString(object).length == 0)) {
        if (error) *error = HTTPFailure ?: @"JS 必须返回文字或消息对象";
        return nil;
    }
    return object;
}

- (void)completeTaskIdentifier:(NSString *)identifier result:(NSString *)result {
    void (^completion)(NSString *) = self.completionHandlers[identifier];
    if (completion) [self.completionHandlers removeObjectForKey:identifier];
    WCAtlasAutomationTask *stored = [self storedTaskWithIdentifier:identifier];
    if (!stored) {
        if (self.activeExecutions > 0) self.activeExecutions--;
        [self updateBackgroundRequirement];
        if (completion) completion(result);
        return;
    }
    stored.lastRunDate = NSDate.date;
    stored.lastResult = result;
    [self persistTasks];
    WCAtlasLog(@"自动任务 %@ %@", identifier, result);
    if (self.activeExecutions > 0) self.activeExecutions--;
    [self updateBackgroundRequirement];
    if (completion) completion(result);
}

- (void)executeTask:(WCAtlasAutomationTask *)task input:(NSDictionary *)triggerInput {
    NSMutableArray<NSString *> *targets = [NSMutableArray array];
    for (id value in task.targetUserNames ?: @[]) {
        NSString *candidate = WCAtlasAutomationString(value);
        if (candidate.length && ![targets containsObject:candidate]) [targets addObject:candidate];
    }
    NSString *legacyTarget = WCAtlasAutomationString(task.targetUserName);
    if (targets.count == 0 && legacyTarget.length) [targets addObject:legacyTarget];
    if (targets.count == 0) { [self completeTaskIdentifier:task.identifier result:@"失败：目标会话为空"]; return; }
    NSString *identifier = task.identifier;
    dispatch_async(self.scriptQueue, ^{
        NSString *failure = nil;
        id output = nil;
        WCAtlasQuickReplyItem *item = task.sourceType == WCAtlasAutomationSourceTypeLibraryText
            ? [self libraryItemForTask:task] : nil;
        NSMutableDictionary *input = [triggerInput isKindOfClass:NSDictionary.class]
            ? [triggerInput mutableCopy] : [NSMutableDictionary dictionary];
        input[@"target"] = targets.firstObject;
        input[@"targets"] = targets;
        input[@"timestamp"] = @((long long)NSDate.date.timeIntervalSince1970);
        if (task.sourceType == WCAtlasAutomationSourceTypeFixedText) output = task.fixedText;
        else if (task.sourceType == WCAtlasAutomationSourceTypeJavaScript)
            output = [self executeScript:task.script input:input error:&failure];
        else if (!item) failure = @"消息库素材不存在";
        else if (item.type == WCAtlasQuickReplyTypeJavaScript)
            output = [self executeScript:item.text input:input error:&failure];
        else if (item.type == WCAtlasQuickReplyTypeText) output = item.text;
        else if (item.type == WCAtlasQuickReplyTypeImage || item.type == WCAtlasQuickReplyTypeVideo ||
                 item.type == WCAtlasQuickReplyTypeVoice) {
            NSString *path = [WCAtlasQuickReplyStore.sharedStore absoluteMediaPathForItem:item];
            NSString *type = item.type == WCAtlasQuickReplyTypeImage ? @"image" :
                (item.type == WCAtlasQuickReplyTypeVideo ? @"video" : @"voice");
            if (path.length) output = @{ @"type": type, @"path": path, @"metadata": item.metadata ?: @{} };
            else failure = @"消息库媒体文件已丢失";
        } else failure = @"该消息库素材不支持自动发送";
        if (!failure && [output isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *payload = [(NSDictionary *)output mutableCopy];
            NSString *type = WCAtlasAutomationString(payload[@"type"]).lowercaseString;
            if (![@[@"text", @"image", @"video", @"voice"] containsObject:type]) {
                failure = @"JS 消息类型不支持";
            } else if (![type isEqualToString:@"text"]) {
                NSString *path = WCAtlasAutomationString(payload[@"path"]);
                if (!path.length) {
                    path = WCAtlasAutomationDownloadURL(payload[@"url"], type, &failure);
                    if (path.length) payload[@"temporary"] = @YES;
                }
                if (path.length) payload[@"path"] = path;
                NSDictionary *voiceMetadata = [payload[@"metadata"] isKindOfClass:NSDictionary.class]
                    ? payload[@"metadata"] : @{};
                BOOL isNativeSilk = [voiceMetadata[@"voiceFormat"] unsignedIntegerValue] == 4 ||
                    [payload[@"voiceFormat"] unsignedIntegerValue] == 4;
                if (!failure && [type isEqualToString:@"voice"] && !isNativeSilk) {
                    NSString *silkPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"wcatlas-%@.aud", NSUUID.UUID.UUIDString]];
                    NSUInteger duration = 0;
                    NSError *encodeError = nil;
                    if (!WCAtlasEncodeAudioFileToSilk(path, silkPath, &duration, &encodeError)) {
                        failure = encodeError.localizedDescription ?: @"语音转码失败";
                    } else {
                        if ([payload[@"temporary"] boolValue]) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
                        payload[@"path"] = silkPath;
                        payload[@"temporary"] = @YES;
                        NSDictionary *existingMetadata = [payload[@"metadata"] isKindOfClass:NSDictionary.class]
                            ? payload[@"metadata"] : @{};
                        NSMutableDictionary *metadata = [existingMetadata mutableCopy];
                        metadata[@"voiceTime"] = @(duration);
                        payload[@"metadata"] = metadata;
                    }
                }
            }
            output = payload;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *sendFailure = failure;
            NSUInteger submitted = 0;
            NSString *type = @"text";
            NSString *text = nil;
            NSString *path = nil;
            NSDictionary *metadata = nil;
            if ([output isKindOfClass:NSString.class]) text = WCAtlasAutomationString(output);
            else if ([output isKindOfClass:NSDictionary.class]) {
                type = WCAtlasAutomationString(output[@"type"]).lowercaseString;
                text = WCAtlasAutomationString(output[@"text"]);
                path = WCAtlasAutomationString(output[@"path"]);
                metadata = [output[@"metadata"] isKindOfClass:NSDictionary.class] ? output[@"metadata"] : @{};
            } else if (!sendFailure) sendFailure = @"任务没有生成可发送内容";
            if (!sendFailure && [type isEqualToString:@"text"] && text.length == 0) sendFailure = @"发送文字为空";
            if (!sendFailure) for (NSString *target in targets) {
                BOOL sent = [type isEqualToString:@"text"] ? WCAtlasPrivateSendTextMessage(target, text) :
                    ([type isEqualToString:@"image"] ? WCAtlasPrivateSendImageMessage(target, path) :
                     ([type isEqualToString:@"voice"] ? WCAtlasPrivateSendVoiceMessage(target, path,
                         [metadata[@"voiceTime"] unsignedIntegerValue], [metadata[@"voiceFormat"] unsignedIntegerValue] ?: 4) :
                       ([type isEqualToString:@"video"] ? WCAtlasPrivateSendVideoMessage(target, path) : NO)));
                if (sent) submitted++;
            }
            if ([output isKindOfClass:NSDictionary.class] && [output[@"temporary"] boolValue]) {
                if ([type isEqualToString:@"video"]) {
                    NSString *temporaryPath = [path copy];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC),
                        dispatch_get_main_queue(), ^{ [NSFileManager.defaultManager removeItemAtPath:temporaryPath error:nil]; });
                } else [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            }
            NSString *result = sendFailure.length ? [@"失败：" stringByAppendingString:sendFailure] :
                (submitted == targets.count ? [NSString stringWithFormat:@"已提交 %lu 个会话", (unsigned long)submitted] :
                 [NSString stringWithFormat:@"失败：仅提交 %lu/%lu", (unsigned long)submitted, (unsigned long)targets.count]);
            [self completeTaskIdentifier:identifier result:result];
        });
    });
}

- (void)executeTask:(WCAtlasAutomationTask *)task {
    [self executeTask:task input:nil];
}

- (NSDate *)nextDailyDateAfterDate:(NSDate *)date now:(NSDate *)now {
    NSDate *candidate = date ?: now;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    do {
        candidate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:candidate options:0];
    } while ([candidate compare:now] != NSOrderedDescending);
    return candidate;
}

- (void)runDueTasks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self runDueTasks]; });
        return;
    }
    NSDate *now = NSDate.date;
    NSMutableArray<WCAtlasAutomationTask *> *due = [NSMutableArray array];
    for (WCAtlasAutomationTask *task in self.mutableTasks) {
        if (!task.isEnabled || task.triggerMode != WCAtlasAutomationTriggerModeScheduled ||
            [task.nextFireDate compare:now] == NSOrderedDescending) continue;
        [due addObject:task.copy];
        if (task.repeatMode == WCAtlasAutomationRepeatModeDaily) {
            task.nextFireDate = [self nextDailyDateAfterDate:task.nextFireDate now:now];
        } else {
            task.enabled = NO;
        }
    }
    if (due.count) {
        self.activeExecutions += due.count;
        [self persistTasks];
        [self updateBackgroundRequirement];
    }
    for (WCAtlasAutomationTask *task in due) {
        [self executeTask:task];
    }
}

- (void)runTaskNow:(WCAtlasAutomationTask *)task {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self runTaskNow:task]; });
        return;
    }
    self.activeExecutions++;
    [self updateBackgroundRequirement];
    [self executeTask:task.copy];
}

- (void)runJavaScript:(NSString *)script
       targetUserName:(NSString *)targetUserName
            completion:(void (^)(NSString *))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self runJavaScript:script targetUserName:targetUserName completion:completion];
        });
        return;
    }
    NSString *target = WCAtlasAutomationString(targetUserName);
    if (script.length == 0 || target.length == 0) {
        if (completion) completion(script.length == 0 ? @"失败：JS 脚本为空" : @"失败：目标会话为空");
        return;
    }
    WCAtlasAutomationTask *task = [WCAtlasAutomationTask new];
    task.name = @"消息库 JS";
    task.sourceType = WCAtlasAutomationSourceTypeJavaScript;
    task.script = script;
    task.targetUserName = target;
    task.targetUserNames = @[target];
    if (completion) self.completionHandlers[task.identifier] = [completion copy];
    self.activeExecutions++;
    [self updateBackgroundRequirement];
    [self executeTask:task input:@{ @"trigger": @"manual", @"session": target }];
}

- (void)handleIncomingInfo:(NSDictionary *)info {
    if (![info isKindOfClass:NSDictionary.class] || [info[@"fromSelf"] boolValue]) return;
    NSString *session = WCAtlasAutomationString(info[@"session"]);
    NSString *content = WCAtlasAutomationString(info[@"content"]);
    NSString *messageID = WCAtlasAutomationString(info[@"identifier"]);
    if (!session.length || !content.length) return;
    NSDate *now = NSDate.date;
    for (NSString *key in self.recentIncomingMessages.allKeys.copy) {
        if ([now timeIntervalSinceDate:self.recentIncomingMessages[key]] > 300) [self.recentIncomingMessages removeObjectForKey:key];
    }
    if (messageID.length && self.recentIncomingMessages[messageID]) return;
    if (messageID.length) self.recentIncomingMessages[messageID] = now;
    for (WCAtlasAutomationTask *stored in self.mutableTasks) {
        if (!stored.isEnabled || stored.triggerMode != WCAtlasAutomationTriggerModeKeyword) continue;
        NSString *keyword = WCAtlasAutomationString(stored.triggerKeyword);
        if (!keyword.length || [content rangeOfString:keyword options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
        NSArray *configuredTargets = stored.targetUserNames.count ? stored.targetUserNames :
            (stored.targetUserName.length ? @[stored.targetUserName] : @[]);
        BOOL selected = [configuredTargets containsObject:session];
        if (stored.keywordScopeMode == WCAtlasAutomationKeywordScopeModeWhitelist) {
            if (!selected) continue;
        } else if (selected) {
            continue;
        }
        WCAtlasAutomationTask *task = stored.copy;
        task.targetUserNames = @[session];
        task.targetUserName = session;
        self.activeExecutions++;
        [self executeTask:task input:@{ @"trigger": @"keyword", @"message": content,
                                       @"sender": info[@"sender"] ?: @"", @"session": session }];
    }
    [self updateBackgroundRequirement];
}

@end

void WCAtlasAutomationStart(void) {
    [WCAtlasAutomationManager.sharedManager start];
}

void WCAtlasAutomationHandleIncomingMessage(id message) {
    NSDictionary *info = WCAtlasPrivateIncomingTextMessageInfo(message);
    if (!info) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [WCAtlasAutomationManager.sharedManager handleIncomingInfo:info];
    });
}
