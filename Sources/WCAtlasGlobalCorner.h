#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Master switch for the card style applied to whole pages.
extern NSString *const WCAtlasGlobalCornerEnabledKey;
/// Corner radius in points for the page card.
extern NSString *const WCAtlasGlobalCornerRadiusKey;
/// Inset from the screen edge, in points.
extern NSString *const WCAtlasGlobalCornerMarginKey;
/// Gap between the card and the content it holds, in points.
extern NSString *const WCAtlasGlobalCornerSpacingKey;
/// Border width in points; 0 draws no border.
extern NSString *const WCAtlasGlobalCornerStrokeKey;
/// NSArray of view-controller class names that keep WeChat's own layout.
extern NSString *const WCAtlasGlobalCornerExcludedClassesKey;

extern NSString *const WCAtlasGlobalCornerDefaultsDidChangeNotification;

/// Registers the defaults this module owns. Call once during setup.
void WCAtlasInstallGlobalCornerDefaults(void);

/// Rounds the host view of the controllers that opt in. Safe to call repeatedly.
void WCAtlasGlobalCornerApplyToController(UIViewController *controller);

NS_ASSUME_NONNULL_END