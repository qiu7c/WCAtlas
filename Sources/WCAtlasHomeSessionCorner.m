#import "WCAtlasHomeSessionCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasHomeSessionCornerPrefix = @"com.qiu7c.wcatlas.home-corner.";

static char WCAtlasHomeSessionCornerStyledKey;
static NSUInteger WCAtlasHomeSessionCornerDepth;
static IMP WCAtlasHomeSessionCornerOriginal;
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

/// The card sits on the page background, so it needs a colour of its own; the gaps then read as
/// gaps instead of more white.
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

static void WCAtlasHomeSessionCornerStyleCell(UITableViewCell *cell) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults boolForKey:WCAtlasHomeSessionCornerKey(@"enabled")];
    BOOL styled = objc_getAssociatedObject(cell, &WCAtlasHomeSessionCornerStyledKey) != nil;
    UIView *content = cell.contentView;
    if (!enabled) {
        if (styled) {
            content.frame = cell.bounds;
            content.backgroundColor = UIColor.clearColor;
            content.layer.cornerRadius = 0;
            content.layer.masksToBounds = NO;
            cell.backgroundColor = UIColor.clearColor;
            objc_setAssociatedObject(cell, &WCAtlasHomeSessionCornerStyledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (cell.bounds.size.width <= 0) return;
    CGFloat margin = MAX(0, MIN(24, [defaults doubleForKey:WCAtlasHomeSessionCornerKey(@"margin")]));
    CGFloat spacing = MAX(0, MIN(16, [defaults doubleForKey:WCAtlasHomeSessionCornerKey(@"spacing")]));
    CGFloat radius = MAX(0, MIN(40, [defaults doubleForKey:WCAtlasHomeSessionCornerKey(@"radius")]));

    content.frame = CGRectInset(cell.bounds, margin, spacing / 2.0);
    content.backgroundColor = WCAtlasHomeSessionCornerCardColor();
    content.layer.cornerCurve = kCACornerCurveContinuous;
    content.layer.cornerRadius = radius;
    content.layer.masksToBounds = YES;
    cell.backgroundColor = UIColor.clearColor;
    // The table behind the cards is what shows through the gaps. Without it the white cards sit
    // on white and the rounding is invisible, which is exactly what happened before.
    cell.superview.backgroundColor = WCAtlasHomeSessionCornerPageColor();
    objc_setAssociatedObject(cell, &WCAtlasHomeSessionCornerStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasHomeSessionCornerLayoutSubviews(id self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    if (WCAtlasHomeSessionCornerOriginal) ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginal)(self, command);
    if ([self isKindOfClass:UITableViewCell.class]) WCAtlasHomeSessionCornerStyleCell((UITableViewCell *)self);
    WCAtlasHomeSessionCornerDepth--;
}

NSInteger WCAtlasInstallHomeSessionCorner(void) {
    if (WCAtlasHomeSessionCornerHooked) return 1;
    // NewMainFrameCell is the conversation row, taken from a view hierarchy dump of the home
    // page rather than guessed.
    Class cls = NSClassFromString(@"NewMainFrameCell");
    if (!cls) return 0;
    SEL selector = @selector(layoutSubviews);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return 0;
    // Replace only this class's own implementation; an inherited one would change the superclass.
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return 0;
    WCAtlasHomeSessionCornerOriginal = method_getImplementation(method);
    method_setImplementation(method, (IMP)WCAtlasHomeSessionCornerLayoutSubviews);
    WCAtlasHomeSessionCornerHooked = YES;
    return 1;
}