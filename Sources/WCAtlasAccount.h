#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * _Nullable WCAtlasCurrentUserWXID(void);
FOUNDATION_EXPORT NSString * _Nullable WCAtlasCurrentUserNickname(void);
FOUNDATION_EXPORT NSString * _Nullable WCAtlasCurrentUserHeadImageURL(void);
FOUNDATION_EXPORT BOOL WCAtlasUpdateCachedCurrentUserContact(id _Nullable contact);
/// Refreshes the persisted profile only when WCAtlas's settings UI explicitly
/// requests it. This must not run from WeChat's startup/contact-sync hot path.
FOUNDATION_EXPORT BOOL WCAtlasRefreshCachedCurrentUserContact(void);
FOUNDATION_EXPORT void WCAtlasInstallServiceCenterCompatibility(void);
FOUNDATION_EXPORT id _Nullable WCAtlasDefaultServiceCenter(void);
FOUNDATION_EXPORT id _Nullable WCAtlasServiceForClass(Class serviceClass);

NS_ASSUME_NONNULL_END
