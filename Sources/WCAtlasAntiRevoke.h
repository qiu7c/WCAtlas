#import "WCAtlasCardTableViewController.h"

/// Returns YES when the incoming revoke command was handled and must be swallowed.
FOUNDATION_EXPORT BOOL WCAtlasHandleRevokeMessage(id messageManager, id incomingMessage);

/// Returns the compact side prompt associated with an intercepted message.
FOUNDATION_EXPORT NSString *WCAtlasAntiRevokeSidePromptForMessage(id message);
FOUNDATION_EXPORT BOOL WCAtlasAntiRevokeIsLocalPromptMessage(id message);
FOUNDATION_EXPORT NSString *const WCAtlasAntiRevokePromptDidChangeNotification;
FOUNDATION_EXPORT void WCAtlasAntiRevokeSetPersistenceEnabled(BOOL enabled);

@interface WCAtlasAntiRevokeRecordsViewController : WCAtlasCardTableViewController
@end

@interface WCAtlasAntiRevokeAppearanceViewController : UIViewController
@end
