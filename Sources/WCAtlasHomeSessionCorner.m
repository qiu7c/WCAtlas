#import "WCAtlasHomeSessionCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasHomeSessionCornerPrefix = @"com.qiu7c.wcatlas.home-corner.";

static IMP WCAtlasCornerOriginalItemLayout;
static IMP WCAtlasCornerOriginalItemBackground;
static IMP WCAtlasCornerOriginalTableLayout;
static BOOL WCAtlasCornerHooked;
static NSUInteger WCAtlasCornerDepth;

// Every helper is declared here so where its definition sits can never break the build again.
NSString *WCAtlasHomeSessionCornerKey(NSString *name);
void WCAtlasInstallHomeSessionCornerDefaults(void);
static BOOL WCAtlasCornerOn(void);
static CGFloat WCAtlasCornerValue(NSString *name, CGFloat fallback, CGFloat maximum);
static UIColor *WCAtlasCornerPageColor(void);
static UITableView *WCAtlasCornerTable(UIView *view);
static UITableViewCell *WCAtlasCornerCell(UIView *view);
static void WCAtlasCornerClearRow(UIView *item, UITableViewCell *cell);
static void WCAtlasCornerInsetItem(UIView *item);
static void WCAtlasCornerPaintTable(UITableView *table);
static BOOL WCAtlasCornerIsPinned(UIView *item);
static void WCAtlasCornerApply(UIView *item);
static BOOL WCAtlasCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original);

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

static BOOL WCAtlasCornerOn(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasHomeSessionCornerKey(@"enabled")];
}

static CGFloat WCAtlasCornerValue(NSString *name, CGFloat fallback, CGFloat maximum) {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasHomeSessionCornerKey(name)];
    return number ? MAX(0, MIN(maximum, number.doubleValue)) : fallback;
}

static UIColor *WCAtlasCornerPageColor(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.04 alpha:1.0]
                : [UIColor colorWithWhite:0.92 alpha:1.0];
        }];
    });
    return color;
}

static UITableView *WCAtlasCornerTable(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableView.class]) return (UITableView *)candidate;
    }
    return nil;
}

static UITableViewCell *WCAtlasCornerCell(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UITableViewCell.class]) return (UITableViewCell *)candidate;
    }
    return nil;
}

static void WCAtlasCornerClearRow(UIView *item, UITableViewCell *cell) {
    if (item.backgroundColor != UIColor.clearColor) item.backgroundColor = UIColor.clearColor;
    if (item.superview && item.superview.backgroundColor != UIColor.clearColor) {
        item.superview.backgroundColor = UIColor.clearColor;
    }
    if (cell.contentView.backgroundColor != UIColor.clearColor) cell.contentView.backgroundColor = UIColor.clearColor;
    if (cell.backgroundColor != UIColor.clearColor) cell.backgroundColor = UIColor.clearColor;
    UIEdgeInsets inset = UIEdgeInsetsMake(0, 0, 0, CGFLOAT_MAX);
    if (!UIEdgeInsetsEqualToEdgeInsets(cell.separatorInset, inset)) cell.separatorInset = inset;
}

/// The row shrinks from its own parent, never from the table: the table's bounds are the whole
/// screen, and using them turned every row into a screen tall cell and blanked the page.
static void WCAtlasCornerInsetItem(UIView *item) {
    UIView *host = item.superview;
    if (!host) return;
    CGFloat margin = WCAtlasCornerValue(@"margin", 8, 24);
    CGRect bounds = host.bounds;
    if (bounds.size.width <= margin * 2 + 40) return;
    CGRect target = CGRectMake(bounds.origin.x + margin, bounds.origin.y,
                               bounds.size.width - margin * 2, bounds.size.height);
    if (!CGRectEqualToRect(item.frame, target)) item.frame = target;
}

/// Only the colour of the page is handled here. Nothing about the table's size or shape is
/// touched, so the search field, the signed in banner and the mini program panel keep working.
static void WCAtlasCornerPaintTable(UITableView *table) {
    if (table.backgroundColor != UIColor.clearColor) table.backgroundColor = UIColor.clearColor;
    UIView *host = table.superview;
    if (host && host.backgroundColor != WCAtlasCornerPageColor()) {
        host.backgroundColor = WCAtlasCornerPageColor();
    }
}

/// MainFrameCellData is built from a session info (initWithSessionInfo:), and the pinned flag
/// lives on that session: the existing private API helper reads m_bIsTop and m_uTopTime there.
static BOOL WCAtlasCornerIsPinned(UIView *item) {
    id cellData = nil;
    @try {
        cellData = [item valueForKey:@"m_cellData"];
    } @catch (__unused NSException *exception) {
        return NO;
    }
    if (!cellData) return NO;
    for (NSString *key in @[@"sessionInfo", @"m_sessionInfo", @"session", @"m_session"]) {
        id session = nil;
        @try {
            session = [cellData valueForKey:key];
        } @catch (__unused NSException *exception) {
            session = nil;
        }
        if (!session) continue;
        for (NSString *flag in @[@"m_bIsTop", @"m_uTopTime"]) {
            id value = nil;
            @try {
                value = [session valueForKey:flag];
            } @catch (__unused NSException *exception) {
                value = nil;
            }
            if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) return YES;
        }
    }
    return NO;
}

static void WCAtlasCornerApply(UIView *item) {
    if (!WCAtlasCornerOn()) return;
    UITableViewCell *cell = WCAtlasCornerCell(item);
    UITableView *table = WCAtlasCornerTable(item);
    if (!cell || !table) return;
    WCAtlasCornerClearRow(item, cell);
    // Pinned rows sit on a grey strip in WeChat; the card wants them white like every other row.
    if (WCAtlasCornerIsPinned(item)) {
        if (item.backgroundColor != UIColor.whiteColor) item.backgroundColor = UIColor.whiteColor;
    } else if (item.backgroundColor != UIColor.clearColor) {
        item.backgroundColor = UIColor.clearColor;
    }

    // The corners belong to the rows, not to the scroll view. The first row rounds its top, the
    // last row rounds its bottom, which is what makes the bottom of the list read as cut off while
    // every row above it stays a straight edge. A mask on the table would instead clip the search
    // field, the banner and anything WeChat lays over the page.
    NSIndexPath *indexPath = [table indexPathForCell:cell];
    NSInteger sections = MAX(1, (NSInteger)table.numberOfSections);
    NSInteger rows = indexPath ? MAX(1, [table numberOfRowsInSection:indexPath.section]) : 1;
    BOOL first = (indexPath == nil) || (indexPath.section == 0 && indexPath.row == 0);
    BOOL last = (indexPath == nil) || (indexPath.section == sections - 1 && indexPath.row >= rows - 1);
    CGFloat radius = WCAtlasCornerValue(@"radius", 12, 40);
    CACornerMask corners = 0;
    if (first) corners |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (last) corners |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    CGFloat wantedRadius = corners ? radius : 0;
    CALayer *layer = item.layer;
    if (layer.cornerRadius != wantedRadius) layer.cornerRadius = wantedRadius;
    if (layer.cornerCurve != kCACornerCurveContinuous) layer.cornerCurve = kCACornerCurveContinuous;
    if (layer.maskedCorners != corners) layer.maskedCorners = corners;
    BOOL wantsClip = (corners != 0);
    if (layer.masksToBounds != wantsClip) layer.masksToBounds = wantsClip;

    WCAtlasCornerInsetItem(item);
    WCAtlasCornerPaintTable(table);
}

static void WCAtlasCornerItemLayout(UIView *self, SEL command) {
    if (WCAtlasCornerDepth > 4) return;
    WCAtlasCornerDepth++;
    if (WCAtlasCornerOriginalItemLayout) {
        ((void (*)(id, SEL))WCAtlasCornerOriginalItemLayout)(self, command);
    }
    WCAtlasCornerApply(self);
    WCAtlasCornerDepth--;
}

static void WCAtlasCornerItemBackground(UIView *self, SEL command) {
    if (WCAtlasCornerOriginalItemBackground) {
        ((void (*)(id, SEL))WCAtlasCornerOriginalItemBackground)(self, command);
    }
    WCAtlasCornerApply(self);
}

static void WCAtlasCornerTableLayout(UIView *self, SEL command) {
    if (WCAtlasCornerOriginalTableLayout) {
        ((void (*)(id, SEL))WCAtlasCornerOriginalTableLayout)(self, command);
    }
    if (!WCAtlasCornerOn()) return;
    WCAtlasCornerPaintTable((UITableView *)self);
}

static BOOL WCAtlasCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

NSInteger WCAtlasInstallHomeSessionCorner(void) {
    WCAtlasInstallHomeSessionCornerDefaults();
    if (WCAtlasCornerHooked) return 1;
    Class itemClass = NSClassFromString(@"MainFrameItemView");
    if (!itemClass) return 0;
    BOOL laidOut = WCAtlasCornerSwizzle(itemClass, @selector(layoutSubviews),
                                        (IMP)WCAtlasCornerItemLayout,
                                        &WCAtlasCornerOriginalItemLayout);
    if (!laidOut) return 0;
    WCAtlasCornerSwizzle(itemClass, @selector(updateBackgroundColor),
                         (IMP)WCAtlasCornerItemBackground,
                         &WCAtlasCornerOriginalItemBackground);
    Class tableClass = NSClassFromString(@"MainFrameTableView");
    if (tableClass) {
        WCAtlasCornerSwizzle(tableClass, @selector(layoutSubviews),
                             (IMP)WCAtlasCornerTableLayout,
                             &WCAtlasCornerOriginalTableLayout);
    }
    WCAtlasCornerHooked = YES;
    return 1;
}

/// The row class only exists once WeChat's own image is loaded, so keep knocking instead of giving
/// up on the first try the way a plain constructor-time call did before.
static void WCAtlasCornerRetry(NSInteger attemptsLeft) {
    if (WCAtlasInstallHomeSessionCorner()) return;
    if (attemptsLeft <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasCornerRetry(attemptsLeft - 1);
    });
}

__attribute__((constructor)) static void WCAtlasCornerBootstrap(void) {
    if (NSThread.isMainThread) {
        WCAtlasCornerRetry(40);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasCornerRetry(40);
    });
}