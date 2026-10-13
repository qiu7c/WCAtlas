#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationCheckDidUpdateNotification;

FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationStatusIdle;
FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationStatusRunning;
FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationStatusPaused;
FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationStatusCompleted;

FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationVerdictNormal;
FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationVerdictSuspected;
FOUNDATION_EXPORT NSString *const WCAtlasFriendRelationVerdictUncertain;

@interface WCAtlasFriendRelationChecker : NSObject

+ (instancetype)sharedChecker;

@property(nonatomic, copy, readonly) NSString *status;
@property(nonatomic, copy, readonly, nullable) NSString *pauseReason;
@property(nonatomic, copy, readonly) NSString *sourceTitle;
@property(nonatomic, copy, readonly) NSArray<NSString *> *pendingUserNames;
@property(nonatomic, copy, readonly) NSString *currentDisplayName;
@property(nonatomic, assign, readonly) NSUInteger completedCount;
@property(nonatomic, assign, readonly) NSUInteger totalCount;
@property(nonatomic, assign, readonly) NSUInteger normalCount;
@property(nonatomic, assign, readonly) NSUInteger suspectedCount;
@property(nonatomic, assign, readonly) NSUInteger uncertainCount;
@property(nonatomic, assign, readonly) float progress;
@property(nonatomic, copy, readonly) NSString *progressTitle;

- (NSArray<NSDictionary<NSString *, NSString *> *> *)allFriendCandidates;
- (void)setPendingUserNames:(NSArray<NSString *> *)userNames sourceTitle:(NSString *)sourceTitle;
- (BOOL)start;
- (void)pause;
- (BOOL)resume;
- (void)stopAndSave;
- (BOOL)startRecheckWithUserNames:(NSArray<NSString *> *)userNames;

- (NSArray<NSDictionary<NSString *, id> *> *)itemsWithVerdict:(NSString *)verdict;
/// Returns the last validated official masked transfer name saved for this username.
/// Call on the main thread. Nil means no masked value has been received.
- (nullable NSString *)maskedRealNameForUserName:(NSString *)userName;
- (void)removeResultUserNames:(NSArray<NSString *> *)userNames;
/// Deletes contacts through WeChat's native contact operation chain. The
/// returned dictionary contains `deleted` and `failed` username arrays.
- (NSDictionary<NSString *, NSArray<NSString *> *> *)deleteUserNames:(NSArray<NSString *> *)userNames
                                                   retainChatHistory:(BOOL)retainChatHistory;

@end

NS_ASSUME_NONNULL_END
