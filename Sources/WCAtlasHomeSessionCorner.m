#import "WCAtlasHomeSessionCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasHomeSessionCornerPrefix = @"com.qiu7c.wcatlas.home-corner.";

static NSUInteger WCAtlasHomeSessionCornerDepth;
static IMP WCAtlasHomeSessionCornerOriginalLayout;
static IMP WCAtlasHomeSessionCornerOriginalBannerLayout;
static IMP WCAtlasHomeSessionCornerOriginalBackground;
static IMP WCAtlasHomeSessionCornerOriginalHighlight;
static IMP WCAtlasHomeSessionCornerOriginalTableLayout;
static void WCAtlasHomeSessionCornerTableLayout(UIView *self, SEL command);
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


static UIColor *WCAtlasHomeSessionCornerPageColor(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.04 alpha:1.0]
                : [UIColor colorWithWhite:0.95 alpha:1.0];
        }];
    });
    return color;
}

/// The row content sits four levels under the table: MainFrameItemView, a plain UIView, the cell
/// content view, the cell, then MainFrameTableView.
static UITableView *WCAtlasHomeSessionCornerTable(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableView.class]) return (UITableView *)candidate;
    }
    return nil;
}

static UITableViewCell *WCAtlasHomeSessionCornerCell(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableViewCell.class]) return (UITableViewCell *)candidate;
    }
    return nil;
}

/// The whole list is the card. The reference implementation hangs its home page switch off a
/// "main frame" setting for exactly this reason: one frame, one corner radius, no per row maths,
/// so rows cannot end up with gaps, clipped content or a dim that is wider than the card.
static char WCAtlasHomeSessionCornerMaskKey;

/// The reference implementation masks the scroll view instead of resizing it: applyScrollCornerMask
/// and tableCornerOutsets in that package say as much. A mask clips the list at the top and the
/// bottom so the card ends where the screen ends, and because no frame changes the pull to refresh
/// gesture and the table's own layout both keep working.
static void WCAtlasHomeSessionCornerStyleList(UITableView *table) {
    UIView *host = table.superview;
    if (!host) return;
    CGFloat margin = WCAtlasHomeSessionCornerValue(@"margin", 8, 24);
    CGFloat spacing = WCAtlasHomeSessionCornerValue(@"spacing", 6, 16);
    CGFloat radius = WCAtlasHomeSessionCornerValue(@"radius", 12, 40);
    if (radius <= 0) radius = 12;
    CGRect bounds = table.bounds;
    if (bounds.size.width <= margin * 2 + 40) return;
    if (bounds.size.height <= spacing + 40) return;
    CGRect rect = CGRectMake(bounds.origin.x + margin,
                             bounds.origin.y + spacing / 2.0,
                             bounds.size.width - margin * 2,
                             bounds.size.height - spacing);
    CAShapeLayer *mask = objc_getAssociatedObject(table, &WCAtlasHomeSessionCornerMaskKey);
    if (![mask isKindOfClass:CAShapeLayer.class]) {
        mask = [CAShapeLayer layer];
        objc_setAssociatedObject(table, &WCAtlasHomeSessionCornerMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Only rebuild when the shape would actually change, so this never becomes a layout feedback
    // loop while scrolling.
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    if (!CGPathEqualToPath(mask.path, path.CGPath)) {
        mask.path = path.CGPath;
    }
    if (table.layer.mask != mask) table.layer.mask = mask;
    // Everything inside the mask has to be transparent, otherwise WeChat's own white row
    // backgrounds hide the card and the corners.
    if (table.backgroundColor != UIColor.clearColor) table.backgroundColor = UIColor.clearColor;
    if (host.backgroundColor != WCAtlasHomeSessionCornerPageColor()) {
        host.backgroundColor = WCAtlasHomeSessionCornerPageColor();
    }
}

static void WCAtlasHomeSessionCornerClearRow(UIView *card, UITableViewCell *cell) {
    // The rows themselves must stay transparent, otherwise WeChat's white cell background covers
    // the card and the rounding is invisible again.
    card.backgroundColor = UIColor.clearColor;
    if (card.superview) card.superview.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.backgroundColor = UIColor.clearColor;
    // Setting the inset invalidates the cell's layout, so only do it when it would change.
    UIEdgeInsets inset = UIEdgeInsetsMake(0, 0, 0, CGFLOAT_MAX);
    if (!UIEdgeInsetsEqualToEdgeInsets(cell.separatorInset, inset)) cell.separatorInset = inset;
}

static void WCAtlasHomeSessionCornerApply(UIView *card) {
    if (!WCAtlasHomeSessionCornerOn()) return;
    UITableViewCell *cell = WCAtlasHomeSessionCornerCell(card);
    UITableView *table = WCAtlasHomeSessionCornerTable(card);
    if (cell) WCAtlasHomeSessionCornerClearRow(card, cell);
    if (table) WCAtlasHomeSessionCornerStyleList(table);
}

static void WCAtlasHomeSessionCornerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    if (WCAtlasHomeSessionCornerOriginalLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalLayout)(self, command);
    }
    WCAtlasHomeSessionCornerApply(self);
    WCAtlasHomeSessionCornerDepth--;
}

/// The row above the conversations ("signed in elsewhere") is an MFBannerBtn inside a plain
/// MMTableViewCell rather than a conversation cell, so it needs its own hook to stay transparent
/// and let the same card show through.
static void WCAtlasHomeSessionCornerBannerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    if (WCAtlasHomeSessionCornerOriginalBannerLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalBannerLayout)(self, command);
    }
    WCAtlasHomeSessionCornerApply(self);
    WCAtlasHomeSessionCornerDepth--;
}

/// WeChat repaints the row when the highlight changes; the row has to go transparent again or a
/// single tap restores its white background on top of the card.
static void WCAtlasHomeSessionCornerBackground(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerOriginalBackground) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalBackground)(self, command);
    }
    WCAtlasHomeSessionCornerApply(self);
}

static void WCAtlasHomeSessionCornerHighlight(UIView *self, SEL command, BOOL highlighted) {
    if (WCAtlasHomeSessionCornerOriginalHighlight) {
        ((void (*)(id, SEL, BOOL))WCAtlasHomeSessionCornerOriginalHighlight)(self, command, highlighted);
    }
    WCAtlasHomeSessionCornerApply(self);
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
    WCAtlasHomeSessionCornerSwizzle(cls, @selector(setLabelHighlighted:),
                                    (IMP)WCAtlasHomeSessionCornerHighlight,
                                    &WCAtlasHomeSessionCornerOriginalHighlight);
    // The banner row is optional: if WeChat stops shipping it the list card still works, so a
    // miss here must not fail the whole install.
    Class bannerClass = NSClassFromString(@"MFWebMMBtn");
    if (bannerClass) {
        WCAtlasHomeSessionCornerSwizzle(bannerClass, @selector(layoutSubviews),
                                        (IMP)WCAtlasHomeSessionCornerBannerLayoutSubviews,
                                        &WCAtlasHomeSessionCornerOriginalBannerLayout);
    }
    Class tableClass = NSClassFromString(@"MainFrameTableView");
    if (tableClass) {
        WCAtlasHomeSessionCornerSwizzle(tableClass, @selector(layoutSubviews),
                                        (IMP)WCAtlasHomeSessionCornerTableLayout,
                                        &WCAtlasHomeSessionCornerOriginalTableLayout);
    }
    WCAtlasHomeSessionCornerHooked = YES;
    return 1;
}

/// Scrolling to the top makes the table re-lay itself out on its own (the refresh control changes
/// the content inset), and that pass used to drop our frame. Hooking the table keeps the card in
/// place without waiting for a row to lay out again.
static void WCAtlasHomeSessionCornerTableLayout(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerOriginalTableLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalTableLayout)(self, command);
    }
    if (!WCAtlasHomeSessionCornerOn()) return;
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    WCAtlasHomeSessionCornerStyleList((UITableView *)self);
    WCAtlasHomeSessionCornerDepth--;
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