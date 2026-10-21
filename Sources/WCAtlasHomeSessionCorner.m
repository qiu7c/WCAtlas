#import "WCAtlasHomeSessionCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasHomeSessionCornerPrefix = @"com.qiu7c.wcatlas.home-corner.";

static NSUInteger WCAtlasHomeSessionCornerDepth;
static IMP WCAtlasHomeSessionCornerOriginalLayout;
static IMP WCAtlasHomeSessionCornerOriginalBackground;
static BOOL WCAtlasHomeSessionCornerHooked;

NSString *WCAtlasHomeSessionCornerKey(NSString *name) {
    return [WCAtlasHomeSessionCornerPrefix stringByAppendingString:name];
}

void WCAtlasInstallHomeSessionCornerDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasHomeSessionCornerKey(@"enabled"): @NO,
        WCAtlasHomeSessionCornerKey(@"radius"): @12,
        WCAtlasHomeSessionCornerKey(@"margin"): @8,
        WCAtlasHomeSessionCornerKey(@"spacing"): @6,
    }];
}

static BOOL WCAtlasHomeSessionCornerOn(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasHomeSessionCornerKey(@"enabled")];
}

static CGFloat WCAtlasHomeSessionCornerValue(NSString *name, CGFloat fallback, CGFloat maximum) {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasHomeSessionCornerKey(name)];
    return number ? MAX(0, MIN(maximum, number.doubleValue)) : fallback;
}

static UIColor *WCAtlasHomeSessionCornerCardColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.11 alpha:1.0]
            : UIColor.whiteColor;
    }];
}

static UIColor *WCAtlasHomeSessionCornerPageColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.04 alpha:1.0]
            : [UIColor colorWithWhite:0.95 alpha:1.0];
    }];
}

/// The row content sits four levels under the table: MainFrameItemView, a plain UIView, the cell
/// content view, the cell, then MainFrameTableView.
static UIView *WCAtlasHomeSessionCornerFindTable(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([NSStringFromClass(candidate.class) isEqualToString:@"MainFrameTableView"]) return candidate;
    }
    return nil;
}

static void WCAtlasHomeSessionCornerStyle(UIView *item) {
    if (!WCAtlasHomeSessionCornerOn()) {
        item.layer.cornerRadius = 0;
        item.layer.masksToBounds = NO;
        item.backgroundColor = UIColor.clearColor;
        if (item.superview) item.frame = item.superview.bounds;
        return;
    }
    CGFloat radius = WCAtlasHomeSessionCornerValue(@"radius", 12, 40);
    item.backgroundColor = WCAtlasHomeSessionCornerCardColor();
    item.layer.cornerCurve = kCACornerCurveContinuous;
    item.layer.cornerRadius = radius;
    item.layer.masksToBounds = YES;
    // The table is what shows through the gaps. White cards on a white table read as no rounding
    // at all, which is why the first two attempts looked like nothing had happened.
    UIView *table = WCAtlasHomeSessionCornerFindTable(item);
    if (table) table.backgroundColor = WCAtlasHomeSessionCornerPageColor();
}

static void WCAtlasHomeSessionCornerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    // Shrink the row before the original lays its labels out, so they reflow inside the card
    // instead of assuming the full width of the table.
    if (WCAtlasHomeSessionCornerOn() && self.superview) {
        CGFloat margin = WCAtlasHomeSessionCornerValue(@"margin", 8, 24);
        CGFloat spacing = WCAtlasHomeSessionCornerValue(@"spacing", 6, 16);
        CGRect host = self.superview.bounds;
        if (host.size.width > margin * 2 + 40) {
            self.frame = CGRectInset(host, margin, spacing / 2.0);
        }
    }
    if (WCAtlasHomeSessionCornerOriginalLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalLayout)(self, command);
    }
    if ([self isKindOfClass:UIView.class]) WCAtlasHomeSessionCornerStyle(self);
    WCAtlasHomeSessionCornerDepth--;
}

/// WeChat paints the row itself when the highlight changes, so our card colour has to go back on
/// afterwards or a single tap would flatten it.
static void WCAtlasHomeSessionCornerBackground(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerOriginalBackground) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalBackground)(self, command);
    }
    if ([self isKindOfClass:UIView.class]) WCAtlasHomeSessionCornerStyle(self);
}

static BOOL WCAtlasHomeSessionCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    // Copy first: replacing an inherited method would change the superclass instead.
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

NSInteger WCAtlasInstallHomeSessionCorner(void) {
    WCAtlasInstallHomeSessionCornerDefaults();
    if (WCAtlasHomeSessionCornerHooked) return 1;
    Class cls = NSClassFromString(@"MainFrameItemView");
    if (!cls) return 0;
    BOOL laidOut = WCAtlasHomeSessionCornerSwizzle(cls, @selector(layoutSubviews),
                                                   (IMP)WCAtlasHomeSessionCornerLayoutSubviews,
                                                   &WCAtlasHomeSessionCornerOriginalLayout);
    if (!laidOut) return 0;
    WCAtlasHomeSessionCornerSwizzle(cls, @selector(updateBackgroundColor),
                                    (IMP)WCAtlasHomeSessionCornerBackground,
                                    &WCAtlasHomeSessionCornerOriginalBackground);
    WCAtlasHomeSessionCornerHooked = YES;
    return 1;
}

/// The row class only exists once WeChat's own image is loaded, so keep knocking instead of
/// giving up on the first try the way the constructor-time code did before.
static void WCAtlasHomeSessionCornerRetry(NSInteger attemptsLeft) {
    if (WCAtlasInstallHomeSessionCorner()) return;
    if (attemptsLeft <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasHomeSessionCornerRetry(attemptsLeft - 1);
    });
}

__attribute__((constructor)) static void WCAtlasHomeSessionCornerBootstrap(void) {
    if (NSThread.isMainThread) {
        WCAtlasHomeSessionCornerRetry(40);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasHomeSessionCornerRetry(40);
    });
}