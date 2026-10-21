#import "WCAtlasHomeSessionCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasHomeSessionCornerPrefix = @"com.qiu7c.wcatlas.home-corner.";

static NSUInteger WCAtlasHomeSessionCornerDepth;
static IMP WCAtlasHomeSessionCornerOriginalLayout;
static IMP WCAtlasHomeSessionCornerOriginalBannerLayout;
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
static UITableView *WCAtlasHomeSessionCornerTable(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableView.class]) return (UITableView *)candidate;
    }
    return nil;
}

static UITableViewCell *WCAtlasHomeSessionCornerCell(UIView *view) {
    for (UIView *candidate = view.superview; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableViewCell.class]) return (UITableViewCell *)candidate;
    }
    return nil;
}

static void WCAtlasHomeSessionCornerClearLayers(UIView *item, UITableViewCell *cell) {
    // Everything between the card and the table is painted white by WeChat and would cover the
    // card completely. That is why a row with a real 8pt margin still looked untouched: the
    // margin was there, the square white content view behind it was just as wide as before.
    item.superview.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.backgroundColor = UIColor.clearColor;
    cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, CGFLOAT_MAX);
}

static void WCAtlasHomeSessionCornerStyle(UIView *item, UITableViewCell *cell, UITableView *table) {
    CGFloat radius = WCAtlasHomeSessionCornerValue(@"radius", 12, 40);
    NSIndexPath *indexPath = (cell && table) ? [table indexPathForCell:cell] : nil;
    // Each section is one card: the rows inside a section sit flush against each other and only
    // the first and the last one are rounded, so pinned conversations read as their own card and
    // the rest reads as another. The gap the user sets separates the two cards.
    NSInteger rows = 1;
    if (indexPath) {
        rows = MAX(1, [table numberOfRowsInSection:indexPath.section]);
    }
    BOOL first = indexPath != nil && indexPath.row == 0;
    BOOL last = indexPath != nil && indexPath.row >= rows - 1;

    item.backgroundColor = WCAtlasHomeSessionCornerCardColor();
    item.layer.cornerCurve = kCACornerCurveContinuous;
    item.layer.masksToBounds = YES;
    if (first && last) {
        item.layer.cornerRadius = radius;
        item.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (first) {
        item.layer.cornerRadius = radius;
        item.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    } else if (last) {
        item.layer.cornerRadius = radius;
        item.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else {
        item.layer.cornerRadius = 0;
        item.layer.maskedCorners = 0;
    }
    if (cell) WCAtlasHomeSessionCornerClearLayers(item, cell);
    if (table) table.backgroundColor = WCAtlasHomeSessionCornerPageColor();
}

/// Only the outside of a card gets a gap; rows inside one section stay flush so the card is
/// continuous instead of turning every conversation into its own island.
static void WCAtlasHomeSessionCornerInsetCell(UITableViewCell *cell, UITableView *table) {
    if (!cell || !cell.superview) return;
    CGFloat margin = WCAtlasHomeSessionCornerValue(@"margin", 8, 24);
    CGFloat spacing = WCAtlasHomeSessionCornerValue(@"spacing", 6, 16);
    NSIndexPath *indexPath = table ? [table indexPathForCell:cell] : nil;
    NSInteger rows = indexPath ? MAX(1, [table numberOfRowsInSection:indexPath.section]) : 1;
    CGFloat top = (indexPath == nil || indexPath.row == 0) ? spacing / 2.0 : 0;
    CGFloat bottom = (indexPath == nil || indexPath.row >= rows - 1) ? spacing / 2.0 : 0;
    CGRect host = cell.superview.bounds;
    // Shrink the cell itself rather than its content, so the avatar and the labels keep their own
    // offsets and simply start further inside; the table is what the gaps show through.
    if (host.size.width > margin * 2 + 40 && host.size.height > top + bottom + 8) {
        cell.frame = CGRectMake(host.origin.x + margin,
                                host.origin.y + top,
                                host.size.width - margin * 2,
                                host.size.height - top - bottom);
    }
}

static void WCAtlasHomeSessionCornerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    UITableViewCell *cell = WCAtlasHomeSessionCornerCell(self);
    UITableView *table = WCAtlasHomeSessionCornerTable(self);
    if (WCAtlasHomeSessionCornerOn()) WCAtlasHomeSessionCornerInsetCell(cell, table);
    if (WCAtlasHomeSessionCornerOriginalLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalLayout)(self, command);
    }
    if ([self isKindOfClass:UIView.class]) WCAtlasHomeSessionCornerStyle(self, cell, table);
    WCAtlasHomeSessionCornerDepth--;
}

/// The row above the conversations ("已登录2台其他设备") is an MFBannerBtn inside a plain
/// MMTableViewCell rather than a conversation cell, so it needs the same card treatment on its
/// own class or it stays a full width strip that lines up with nothing.
static void WCAtlasHomeSessionCornerBannerLayoutSubviews(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerDepth > 4) return;
    WCAtlasHomeSessionCornerDepth++;
    UITableViewCell *cell = WCAtlasHomeSessionCornerCell(self);
    UITableView *table = WCAtlasHomeSessionCornerTable(self);
    if (WCAtlasHomeSessionCornerOn()) WCAtlasHomeSessionCornerInsetCell(cell, table);
    if (WCAtlasHomeSessionCornerOriginalBannerLayout) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalBannerLayout)(self, command);
    }
    if ([self isKindOfClass:UIView.class]) WCAtlasHomeSessionCornerStyle(self, cell, table);
    WCAtlasHomeSessionCornerDepth--;
}

/// WeChat paints the row itself when the highlight changes, so our card colour has to go back on
/// afterwards or a single tap would flatten it.
static void WCAtlasHomeSessionCornerBackground(UIView *self, SEL command) {
    if (WCAtlasHomeSessionCornerOriginalBackground) {
        ((void (*)(id, SEL))WCAtlasHomeSessionCornerOriginalBackground)(self, command);
    }
    if ([self isKindOfClass:UIView.class]) {
        WCAtlasHomeSessionCornerStyle(self,
                                      WCAtlasHomeSessionCornerCell(self),
                                      WCAtlasHomeSessionCornerTable(self));
    }
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
    // The banner row above the list is optional: if WeChat stops shipping it the conversation
    // cards still work, so a miss here must not fail the whole install.
    Class bannerClass = NSClassFromString(@"MFWebMMBtn");
    if (bannerClass) {
        WCAtlasHomeSessionCornerSwizzle(bannerClass, @selector(layoutSubviews),
                                        (IMP)WCAtlasHomeSessionCornerBannerLayoutSubviews,
                                        &WCAtlasHomeSessionCornerOriginalBannerLayout);
    }
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