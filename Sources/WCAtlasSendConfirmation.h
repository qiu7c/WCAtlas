#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^WCAtlasSendConfirmationValidator)(void);

FOUNDATION_EXPORT NSArray<NSString *> *WCAtlasSendConfirmationProtectedConversations(void);
FOUNDATION_EXPORT BOOL WCAtlasSendConfirmationIsProtectedConversation(NSString *username);
FOUNDATION_EXPORT void WCAtlasSendConfirmationSetProtected(NSString *username, BOOL protectedConversation);
/// Adds or removes several conversations in one account-scoped defaults update.
/// @return Number of valid, unique usernames processed; zero when the account or input is unavailable.
/// @discussion Enabling at least one conversation also enables the global send-confirmation switch.
FOUNDATION_EXPORT NSUInteger WCAtlasSendConfirmationSetProtectedConversations(
    NSArray<NSString *> *usernames, BOOL protectedConversation);
FOUNDATION_EXPORT NSString *WCAtlasSendConfirmationDisplayName(NSString *username);

/// Returns YES when the original action is being held for confirmation. The
/// caller must return without invoking the original method in that case.
FOUNDATION_EXPORT BOOL WCAtlasPresentSendConfirmationIfNeeded(UIViewController *presenter,
                                                             NSString *username,
                                                             NSString *summary,
                                                             WCAtlasSendConfirmationValidator _Nullable validator,
                                                             dispatch_block_t confirmedAction);
FOUNDATION_EXPORT void WCAtlasCancelPendingSendConfirmations(void);

NS_ASSUME_NONNULL_END
