#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Which corners a style applies to. The order matches CALayerMaskedCorners.
typedef NS_OPTIONS(NSUInteger, WCAtlasCornerCorners) {
    WCAtlasCornerTopLeft = 1 << 0,
    WCAtlasCornerTopRight = 1 << 1,
    WCAtlasCornerBottomLeft = 1 << 2,
    WCAtlasCornerBottomRight = 1 << 3,
    WCAtlasCornerAll = WCAtlasCornerTopLeft | WCAtlasCornerTopRight | WCAtlasCornerBottomLeft | WCAtlasCornerBottomRight,
};

/// Rounds `view` with the continuous corner curve and clips its content to the shape.
/// Radius 0 clears the corner properties again.
void WCAtlasApplyCornerRadius(UIView *view, CGFloat radius, WCAtlasCornerCorners corners);

/// Draws a border that follows the same rounded shape. The stroke uses its own sublayer so
/// `masksToBounds` cannot cut it in half. Pass width 0 to remove an existing border.
/// Re-apply after the view is laid out; the path is not observed automatically.
void WCAtlasApplyCornerBorder(UIView *view, CGFloat radius, WCAtlasCornerCorners corners,
                              CGFloat width, UIColor *_Nullable color);

/// Restores the properties this module touched, so a view can return to WeChat's own style.
void WCAtlasClearCornerStyle(UIView *view);

NS_ASSUME_NONNULL_END