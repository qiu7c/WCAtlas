#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Defaults key for one moments image corner setting: `enabled`, `radius`.
NSString *WCAtlasMomentsImageCornerKey(NSString *name);

void WCAtlasInstallMomentsImageCornerDefaults(void);

/// Rounds the pictures inside every moments cell. Returns 1 when the cell class was found.
NSInteger WCAtlasInstallMomentsImageCorner(void);

NS_ASSUME_NONNULL_END