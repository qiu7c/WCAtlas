#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<NSString *> *WCAtlasMessageBlockedConversations(void);
FOUNDATION_EXPORT NSArray<NSString *> *WCAtlasMessageBlockTypesForConversation(NSString *username);
FOUNDATION_EXPORT BOOL WCAtlasMessageBlockConversationMatchesType(NSString *username, NSUInteger messageType);
FOUNDATION_EXPORT void WCAtlasMessageBlockSetTypesForConversation(NSString *username, NSArray<NSString *> *types);
FOUNDATION_EXPORT NSString *WCAtlasMessageBlockSummaryForConversation(NSString *username);
FOUNDATION_EXPORT UIViewController *WCAtlasMessageBlockTypeController(NSString *username);

@interface WCAtlasMessageBlockViewController : WCAtlasCardTableViewController
@end

NS_ASSUME_NONNULL_END
