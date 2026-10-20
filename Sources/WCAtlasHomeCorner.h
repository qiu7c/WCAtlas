#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Defaults key for one home corner setting: `enabled`, `radius`, `margin`, `spacing`, `stroke`.
NSString *WCAtlasHomeCornerKey(NSString *name);

void WCAtlasInstallHomeCornerDefaults(void);

/// Rounds each conversation cell into a card, with its own horizontal margin and row spacing.
/// Returns 1 when the cell class was found and hooked, 0 otherwise.
NSInteger WCAtlasInstallHomeCorner(void);

NS_ASSUME_NONNULL_END