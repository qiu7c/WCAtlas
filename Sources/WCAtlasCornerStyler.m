#import "WCAtlasCornerStyler.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char WCAtlasCornerBorderKey;

static CACornerMask WCAtlasMaskedCorners(WCAtlasCornerCorners corners) {
    CACornerMask mask = 0;
    if (corners & WCAtlasCornerTopLeft) mask |= kCALayerMinXMinYCorner;
    if (corners & WCAtlasCornerTopRight) mask |= kCALayerMaxXMinYCorner;
    if (corners & WCAtlasCornerBottomLeft) mask |= kCALayerMinXMaxYCorner;
    if (corners & WCAtlasCornerBottomRight) mask |= kCALayerMaxXMaxYCorner;
    return mask;
}

static UIBezierPath *WCAtlasCornerPath(CGRect rect, CGFloat radius, WCAtlasCornerCorners corners) {
    if (radius <= 0) return [UIBezierPath bezierPathWithRect:rect];
    UIRectCorner cornersValue = (UIRectCorner)corners;
    return [UIBezierPath bezierPathWithRoundedRect:rect
                                 byRoundingCorners:cornersValue
                                       cornerRadii:CGSizeMake(radius, radius)];
}

void WCAtlasApplyCornerRadius(UIView *view, CGFloat radius, WCAtlasCornerCorners corners) {
    if (!view) return;
    CALayer *layer = view.layer;
    if (radius <= 0) {
        layer.cornerRadius = 0;
        layer.maskedCorners = 0;
        layer.masksToBounds = NO;
        return;
    }
    // Continuous is the squircle curve: it keeps the curvature smooth at the join with the
    // straight edges, which is what the stock iOS icon corners look like.
    layer.cornerCurve = kCACornerCurveContinuous;
    layer.cornerRadius = radius;
    layer.maskedCorners = WCAtlasMaskedCorners(corners);
    layer.masksToBounds = YES;
}

void WCAtlasApplyCornerBorder(UIView *view, CGFloat radius, WCAtlasCornerCorners corners,
                              CGFloat width, UIColor *_Nullable color) {
    if (!view) return;
    CAShapeLayer *border = objc_getAssociatedObject(view, &WCAtlasCornerBorderKey);
    if (width <= 0 || radius <= 0 || !color) {
        [border removeFromSuperlayer];
        objc_setAssociatedObject(view, &WCAtlasCornerBorderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!border) {
        border = [CAShapeLayer layer];
        border.fillColor = UIColor.clearColor.CGColor;
        objc_setAssociatedObject(view, &WCAtlasCornerBorderKey, border, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [view.layer addSublayer:border];
    }
    // The view clips its content, so the stroke is inset by half its width; otherwise the outer
    // half of the line would be cut off and the border would look thinner than it is.
    CGRect rect = CGRectInset(view.bounds, width / 2.0, width / 2.0);
    border.frame = view.bounds;
    border.path = WCAtlasCornerPath(rect, MAX(radius - width / 2.0, 0), corners).CGPath;
    border.lineWidth = width;
    border.strokeColor = color.CGColor;
}

void WCAtlasClearCornerStyle(UIView *view) {
    if (!view) return;
    CALayer *layer = view.layer;
    layer.cornerRadius = 0;
    layer.cornerCurve = kCACornerCurveCircular;
    layer.maskedCorners = 0;
    layer.masksToBounds = NO;
    CAShapeLayer *border = objc_getAssociatedObject(view, &WCAtlasCornerBorderKey);
    [border removeFromSuperlayer];
    objc_setAssociatedObject(view, &WCAtlasCornerBorderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}