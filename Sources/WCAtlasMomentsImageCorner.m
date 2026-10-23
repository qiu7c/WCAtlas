#import "WCAtlasMomentsImageCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasMomentsImageCornerPrefix = @"com.qiu7c.wcatlas.moments-corner.";

static char WCAtlasMomentsImageCornerStyledKey;
static NSUInteger WCAtlasMomentsImageCornerDepth;
static IMP WCAtlasMomentsImageCornerOriginal;
static BOOL WCAtlasMomentsImageCornerHooked;

NSString *WCAtlasMomentsImageCornerKey(NSString *name) {
    return [WCAtlasMomentsImageCornerPrefix stringByAppendingString:name];
}

void WCAtlasInstallMomentsImageCornerDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasMomentsImageCornerKey(@"enabled"): @NO,
        WCAtlasMomentsImageCornerKey(@"radius"): @8,
    }];
}

static BOOL WCAtlasMomentsImageCornerOn(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasMomentsImageCornerKey(@"enabled")];
}

static CGFloat WCAtlasMomentsImageCornerRadius(void) {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasMomentsImageCornerKey(@"radius")];
    return MAX(0, MIN(40, number ? number.doubleValue : 8));
}

/// The picture views WeChat uses inside a moments cell. Anything else in the cell (avatars,
/// labels, the like button icons) is left alone: avatars are already round, and rounding the
/// others would change the design rather than the pictures.
static BOOL WCAtlasMomentsImageCornerIsPicture(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    if ([name isEqualToString:@"WCImageView"] ||
        [name isEqualToString:@"MMWebImageView"] ||
        [name isEqualToString:@"MMImgFullScreenImageView"]) return YES;
    // A video feed uses a different branch: the picture is a plain UIImageView inside
    // WCSNSNodeVideoView, and the player sits next to it. Rounding the container clips both, which
    // is what makes the preview and the running video share the same corners.
    if ([name isEqualToString:@"WCSNSNodeVideoView"] ||
        [name isEqualToString:@"WCPlayerView"] ||
        [name isEqualToString:@"WCPlayerLayerView"]) return YES;
    // The templates are deliberately not matched: a card template is a wide container that also
    // holds text, so rounding it put a second, much bigger corner behind the picture and made a
    // shared song cover look squashed. Only the picture and the video views are rounded.
}

static void WCAtlasMomentsImageCornerStyle(UIView *view, CGFloat radius) {
    BOOL styled = objc_getAssociatedObject(view, &WCAtlasMomentsImageCornerStyledKey) != nil;
    if (radius <= 0) {
        if (styled) {
            view.layer.cornerRadius = 0;
            view.layer.masksToBounds = NO;
            objc_setAssociatedObject(view, &WCAtlasMomentsImageCornerStyledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    // Idempotent on purpose: this runs from a layout callback, and writing a value that is
    // already there would ask UIKit to lay out again.
    if (view.layer.cornerRadius != radius) view.layer.cornerRadius = radius;
    if (view.layer.cornerCurve != kCACornerCurveContinuous) view.layer.cornerCurve = kCACornerCurveContinuous;
    if (!view.layer.masksToBounds) view.layer.masksToBounds = YES;
    if (!styled) objc_setAssociatedObject(view, &WCAtlasMomentsImageCornerStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasMomentsImageCornerWalk(UIView *view, CGFloat radius, NSInteger depth) {
    if (!view || depth > 4) return;
    if (WCAtlasMomentsImageCornerIsPicture(view)) WCAtlasMomentsImageCornerStyle(view, radius);
    for (UIView *child in view.subviews) {
        WCAtlasMomentsImageCornerWalk(child, radius, depth + 1);
    }
}

static void WCAtlasMomentsImageCornerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasMomentsImageCornerDepth > 4) return;
    WCAtlasMomentsImageCornerDepth++;
    if (WCAtlasMomentsImageCornerOriginal) {
        ((void (*)(id, SEL))WCAtlasMomentsImageCornerOriginal)(self, command);
    }
    if (WCAtlasMomentsImageCornerOn()) {
        WCAtlasMomentsImageCornerWalk(self, WCAtlasMomentsImageCornerRadius(), 0);
    }
    WCAtlasMomentsImageCornerDepth--;
}

static BOOL WCAtlasMomentsImageCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

NSInteger WCAtlasInstallMomentsImageCorner(void) {
    WCAtlasInstallMomentsImageCornerDefaults();
    if (WCAtlasMomentsImageCornerHooked) return 1;
    // WCTimeLineCellView is the moments cell: the reference package ships helpers named
    // WCRefineFindWCTimeLineCellView and WCRefineIsTimelineCell, which is how it locates it.
    Class cls = NSClassFromString(@"WCTimeLineCellView");
    if (!cls) return 0;
    BOOL laidOut = WCAtlasMomentsImageCornerSwizzle(cls, @selector(layoutSubviews),
                                                    (IMP)WCAtlasMomentsImageCornerLayoutSubviews,
                                                    &WCAtlasMomentsImageCornerOriginal);
    if (!laidOut) return 0;
    WCAtlasMomentsImageCornerHooked = YES;
    return 1;
}

static void WCAtlasMomentsImageCornerRetry(NSInteger attemptsLeft) {
    if (WCAtlasInstallMomentsImageCorner()) return;
    if (attemptsLeft <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasMomentsImageCornerRetry(attemptsLeft - 1);
    });
}

__attribute__((constructor)) static void WCAtlasMomentsImageCornerBootstrap(void) {
    if (NSThread.isMainThread) {
        WCAtlasMomentsImageCornerRetry(40);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasMomentsImageCornerRetry(40);
    });
}