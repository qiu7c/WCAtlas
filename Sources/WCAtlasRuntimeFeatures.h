#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSArray *WCAtlasManagedLongPressMenuItems(NSArray *items);

FOUNDATION_EXPORT BOOL WCAtlasShouldBlockIncomingMessage(NSString *sessionUserName, id message);
FOUNDATION_EXPORT BOOL WCAtlasDeleteBlockedIncomingMessage(id messageManager,
                                                         NSString *sessionUserName,
                                                         id message);

FOUNDATION_EXPORT id WCAtlasCaptureGroupMemberChange(id newContact, id oldContact);
FOUNDATION_EXPORT void WCAtlasCompleteGroupMemberChange(id snapshot, id contactManager, id newContact);

FOUNDATION_EXPORT BOOL WCAtlasHandleNotificationResponse(id response, void (^completionHandler)(void));
FOUNDATION_EXPORT void WCAtlasOpenChatForUserName(NSString *userName);
FOUNDATION_EXPORT void WCAtlasOpenMomentsTimeline(void);

FOUNDATION_EXPORT UIView *WCAtlasWalletHeaderForView(UIView *view);
FOUNDATION_EXPORT BOOL WCAtlasViewIsInsideWalletHeader(UIView *view);
FOUNDATION_EXPORT void WCAtlasRefreshWalletHeaderBalance(id headerView);
