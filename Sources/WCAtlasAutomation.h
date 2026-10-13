#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCAtlasAutomationSourceType) {
    WCAtlasAutomationSourceTypeFixedText = 0,
    WCAtlasAutomationSourceTypeLibraryText = 1,
    WCAtlasAutomationSourceTypeJavaScript = 2,
};

typedef NS_ENUM(NSInteger, WCAtlasAutomationRepeatMode) {
    WCAtlasAutomationRepeatModeOnce = 0,
    WCAtlasAutomationRepeatModeDaily = 1,
};

typedef NS_ENUM(NSInteger, WCAtlasAutomationTriggerMode) {
    WCAtlasAutomationTriggerModeScheduled = 0,
    WCAtlasAutomationTriggerModeKeyword = 1,
};

typedef NS_ENUM(NSInteger, WCAtlasAutomationKeywordScopeMode) {
    /// Reply only in the selected conversations.
    WCAtlasAutomationKeywordScopeModeWhitelist = 0,
    /// Reply in every conversation except the selected conversations.
    WCAtlasAutomationKeywordScopeModeBlacklist = 1,
};

@interface WCAtlasAutomationTask : NSObject <NSCopying>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *targetUserName;
@property (nonatomic, copy) NSArray<NSString *> *targetUserNames;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign) WCAtlasAutomationSourceType sourceType;
@property (nonatomic, copy) NSString *fixedText;
@property (nonatomic, copy, nullable) NSString *libraryItemIdentifier;
@property (nonatomic, copy) NSString *script;
@property (nonatomic, strong) NSDate *nextFireDate;
@property (nonatomic, assign) WCAtlasAutomationRepeatMode repeatMode;
@property (nonatomic, assign) WCAtlasAutomationTriggerMode triggerMode;
@property (nonatomic, copy) NSString *triggerKeyword;
@property (nonatomic, assign) WCAtlasAutomationKeywordScopeMode keywordScopeMode;
@property (nonatomic, strong, nullable) NSDate *lastRunDate;
@property (nonatomic, copy, nullable) NSString *lastResult;
@end

@interface WCAtlasAutomationManager : NSObject
+ (instancetype)sharedManager;
- (NSArray<WCAtlasAutomationTask *> *)tasks;
- (void)start;
- (void)saveTask:(WCAtlasAutomationTask *)task;
- (void)deleteTaskWithIdentifier:(NSString *)identifier;
- (void)runTaskNow:(WCAtlasAutomationTask *)task;
/// Executes one message-library JavaScript in the supplied conversation without creating a task.
/// The script uses the same HTTP helpers, result schema, media download/conversion, and unified
/// private send adapters as scheduled/keyword automation. Completion is delivered on the main thread.
- (void)runJavaScript:(NSString *)script
       targetUserName:(NSString *)targetUserName
            completion:(void (^ _Nullable)(NSString *result))completion;
@end

/// Starts the in-process automation scheduler. Safe to call repeatedly.
FOUNDATION_EXPORT void WCAtlasAutomationStart(void);

/// Delivers one incoming WeChat message wrapper to enabled keyword automations.
/// The wrapper is read-only; unsupported/non-text/self messages are ignored.
FOUNDATION_EXPORT void WCAtlasAutomationHandleIncomingMessage(id _Nullable message);

NS_ASSUME_NONNULL_END
