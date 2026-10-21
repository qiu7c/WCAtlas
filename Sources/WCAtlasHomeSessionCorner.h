#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Defaults key for one home conversation corner setting: `enabled`, `radius`, `margin`, `spacing`.
NSString *WCAtlasHomeSessionCornerKey(NSString *name);

void WCAtlasInstallHomeSessionCornerDefaults(void);

/// Turns each conversation row into a card: the row content is inset by the margin, spaced by
/// the gap and rounded with the continuous curve. Returns 1 when NewMainFrameCell was found.
NSInteger WCAtlasInstallHomeSessionCorner(void);

NS_ASSUME_NONNULL_END