#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Defaults key for one profile page corner setting: `enabled`, `radius`, `margin`.
NSString *WCAtlasProfileCornerKey(NSString *name);

void WCAtlasInstallProfileCornerDefaults(void);

/// Rounds the rows of a contact's profile page. Returns 1 when the controller was found.
NSInteger WCAtlasInstallProfileCorner(void);

NS_ASSUME_NONNULL_END