#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const WCAtlasInAppNotificationSymbolKey;
FOUNDATION_EXPORT NSString *const WCAtlasInAppNotificationHeightKey;
FOUNDATION_EXPORT NSString *const WCAtlasInAppNotificationBlurIntensityKey;
FOUNDATION_EXPORT CGFloat const WCAtlasInAppNotificationMinimumHeight;
FOUNDATION_EXPORT CGFloat const WCAtlasInAppNotificationMaximumHeight;

FOUNDATION_EXPORT NSString *WCAtlasInAppNotificationResolvedSymbolName(NSString *requestedSymbolName);
FOUNDATION_EXPORT CGFloat WCAtlasInAppNotificationPreferredHeight(void);
FOUNDATION_EXPORT CGFloat WCAtlasInAppNotificationBlurIntensity(void);

FOUNDATION_EXPORT void WCAtlasShowInAppNotification(NSString *title,
                                                   NSString *body,
                                                   NSString *identifier,
                                                   NSString *symbolName,
                                                   dispatch_block_t _Nullable action);
FOUNDATION_EXPORT void WCAtlasShowTransientHUD(NSString *message,
                                             NSString *symbolName);
FOUNDATION_EXPORT void WCAtlasShowProgressCapsule(NSString *message,
                                                float progress,
                                                NSString *symbolName);
FOUNDATION_EXPORT void WCAtlasCompleteProgressCapsule(NSString *message,
                                                    BOOL success);
FOUNDATION_EXPORT void WCAtlasDismissProgressCapsule(void);
FOUNDATION_EXPORT void WCAtlasDismissInAppNotifications(void);

NS_ASSUME_NONNULL_END
