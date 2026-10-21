#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Defaults key for one home corner setting: `enabled`, `radius`, `margin`, `spacing`, `stroke`.
NSString *WCAtlasHomeCornerKey(NSString *name);

void WCAtlasInstallHomeCornerDefaults(void);

/// Rounds each conversation cell into a card. Returns 1 when the cell class was found and hooked,
/// 0 otherwise. The cell class turned out not to exist on 8.0.79, so this is kept harmless but the
/// table path below is the one that works.
NSInteger WCAtlasInstallHomeCorner(void);

/// Insets and rounds the home page table itself, which is what the switch promises and what the
/// reference implementation keys off (`homepageCornerEnabled`). Safe to call from every layout
/// pass: it returns after one defaults lookup while the switch is off.
void WCAtlasHomeCornerApplyToController(UIViewController *controller);

NS_ASSUME_NONNULL_END