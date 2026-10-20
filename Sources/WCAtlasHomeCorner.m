#import "WCAtlasHomeCorner.h"

#import "WCAtlasCornerStyler.h"

#import <objc/runtime.h>

static NSString *const WCAtlasHomeCornerPrefix = @"com.qiu7c.wcatlas.corner.home.";

static char WCAtlasHomeCornerStyledKey;
static NSUInteger WCAtlasHomeCornerDepth;

NSString *WCAtlasHomeCornerKey(NSString *name) {
    return [WCAtlasHomeCornerPrefix stringByAppendingString:name];
}

void WCAtlasInstallHomeCornerDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasHomeCornerKey(@"enabled"): @NO,
        WCAtlasHomeCornerKey(@"radius"): @12,
        WCAtlasHomeCornerKey(@"margin"): @8,
        WCAtlasHomeCornerKey(@"spacing"): @0,
        WCAtlasHomeCornerKey(@"stroke"): @0,
    }];
}

/// The card sits on top of the page background, so it needs an opaque colour of its own.
static UIColor *WCAtlasHomeCornerCardColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.11 alpha:1.0]
            : UIColor.whiteColor;
    }];
}

static void WCAtlasHomeCornerStyleCell(UITableViewCell *cell) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults boolForKey:WCAtlasHomeCornerKey(@"enabled")];
    BOOL styled = objc_getAssociatedObject(cell, &WCAtlasHomeCornerStyledKey) != nil;
    UIView *content = cell.contentView;
    if (!enabled || content.bounds.size.width <= 0) {
        // Only undo what this module did; WeChat rounds nothing here today, but pretending the
        // original frame is ours to guess would be worse than leaving a card in place.
        if (styled && !enabled) {
            content.frame = cell.bounds;
            content.backgroundColor = UIColor.clearColor;
            cell.backgroundColor = UIColor.clearColor;
            WCAtlasClearCornerStyle(content);
            objc_setAssociatedObject(cell, &WCAtlasHomeCornerStyledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    CGFloat margin = MAX(0, MIN(24, [defaults doubleForKey:WCAtlasHomeCornerKey(@"margin")]));
    CGFloat spacing = MAX(0, MIN(16, [defaults doubleForKey:WCAtlasHomeCornerKey(@"spacing")]));
    CGFloat radius = MAX(0, MIN(40, [defaults doubleForKey:WCAtlasHomeCornerKey(@"radius")]));
    CGFloat stroke = MAX(0, MIN(3, [defaults doubleForKey:WCAtlasHomeCornerKey(@"stroke")]));

    content.frame = CGRectInset(cell.bounds, margin, spacing / 2.0);
    content.backgroundColor = WCAtlasHomeCornerCardColor();
    cell.backgroundColor = UIColor.clearColor;
    WCAtlasApplyCornerRadius(content, radius, WCAtlasCornerAll);
    WCAtlasApplyCornerBorder(content, radius, WCAtlasCornerAll, stroke, stroke > 0 ? UIColor.separatorColor : nil);
    objc_setAssociatedObject(cell, &WCAtlasHomeCornerStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static IMP WCAtlasHomeCornerOriginal;
static BOOL WCAtlasHomeCornerHooked;

static void WCAtlasHomeCornerLayoutSubviews(id self, SEL command) {
    if (WCAtlasHomeCornerDepth > 4) return;
    WCAtlasHomeCornerDepth++;
    if (WCAtlasHomeCornerOriginal) ((void (*)(id, SEL))WCAtlasHomeCornerOriginal)(self, command);
    if ([self isKindOfClass:UITableViewCell.class]) WCAtlasHomeCornerStyleCell((UITableViewCell *)self);
    WCAtlasHomeCornerDepth--;
}

NSInteger WCAtlasInstallHomeCorner(void) {
    if (WCAtlasHomeCornerHooked) return 1;
    // MMBaseSessionTableViewCell is the conversation row on the home page. The name comes from
    // the WCRefine package, and a wrong name only means the lookup fails.
    Class cls = NSClassFromString(@"MMBaseSessionTableViewCell");
    if (!cls) return 0;
    SEL selector = @selector(layoutSubviews);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return 0;
    // Give the class its own implementation first; replacing an inherited method would change
    // the superclass and can make the replacement call itself.
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return 0;
    WCAtlasHomeCornerOriginal = method_getImplementation(method);
    method_setImplementation(method, (IMP)WCAtlasHomeCornerLayoutSubviews);
    WCAtlasHomeCornerHooked = YES;
    return 1;
}