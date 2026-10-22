#import "WCAtlasProfileCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasProfileCornerPrefix = @"com.qiu7c.wcatlas.profile-corner.";

static NSUInteger WCAtlasProfileCornerDepth;
static IMP WCAtlasProfileCornerOriginal;
static BOOL WCAtlasProfileCornerHooked;

NSString *WCAtlasProfileCornerKey(NSString *name) {
    return [WCAtlasProfileCornerPrefix stringByAppendingString:name];
}

void WCAtlasInstallProfileCornerDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasProfileCornerKey(@"enabled"): @NO,
        WCAtlasProfileCornerKey(@"radius"): @12,
        WCAtlasProfileCornerKey(@"margin"): @12,
    }];
}

static BOOL WCAtlasProfileCornerOn(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasProfileCornerKey(@"enabled")];
}

static CGFloat WCAtlasProfileCornerValue(NSString *name, CGFloat fallback, CGFloat maximum) {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasProfileCornerKey(name)];
    return number ? MAX(0, MIN(maximum, number.doubleValue)) : fallback;
}

static UIColor *WCAtlasProfileCornerCardColor(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.11 alpha:1.0]
                : UIColor.whiteColor;
        }];
    });
    return color;
}

static UIColor *WCAtlasProfileCornerPageColor(void) {
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

/// The profile page is a UITableView named TextStateProfileTableView inside
/// ContactInfoViewController; its rows are plain MMTableViewCell, so they are only touched from
/// this controller's layout pass and never globally.
static UITableView *WCAtlasProfileCornerTable(UIView *root) {
    if ([root isKindOfClass:UITableView.class] &&
        [NSStringFromClass(root.class) isEqualToString:@"TextStateProfileTableView"]) {
        return (UITableView *)root;
    }
    for (UIView *child in root.subviews) {
        UITableView *found = WCAtlasProfileCornerTable(child);
        if (found) return found;
    }
    return nil;
}

static void WCAtlasProfileCornerStyleCell(UITableViewCell *cell, CGFloat radius, CGFloat margin) {
    UIView *card = cell.contentView;
    if (!card) return;
    // The card is the content view; the cell behind it keeps its own background, so that has to
    // go clear or the rounded corners show as square white patches.
    if (cell.backgroundColor != UIColor.clearColor) cell.backgroundColor = UIColor.clearColor;
    UIEdgeInsets inset = UIEdgeInsetsMake(0, 0, 0, CGFLOAT_MAX);
    if (!UIEdgeInsetsEqualToEdgeInsets(cell.separatorInset, inset)) cell.separatorInset = inset;

    CGRect bounds = card.bounds;
    if (bounds.size.width <= margin * 2 + 40) return;
    CGRect target = CGRectMake(margin, 0, bounds.size.width - margin * 2, bounds.size.height);
    if (!CGRectEqualToRect(card.frame, target)) card.frame = target;
    if (card.backgroundColor != WCAtlasProfileCornerCardColor()) {
        card.backgroundColor = WCAtlasProfileCornerCardColor();
    }
    if (card.layer.cornerRadius != radius) card.layer.cornerRadius = radius;
    if (card.layer.cornerCurve != kCACornerCurveContinuous) card.layer.cornerCurve = kCACornerCurveContinuous;
    if (!card.layer.masksToBounds) card.layer.masksToBounds = YES;
}

static void WCAtlasProfileCornerApply(UIViewController *controller) {
    if (!WCAtlasProfileCornerOn()) return;
    UITableView *table = WCAtlasProfileCornerTable(controller.view);
    if (!table) return;
    CGFloat radius = WCAtlasProfileCornerValue(@"radius", 12, 40);
    CGFloat margin = WCAtlasProfileCornerValue(@"margin", 12, 32);
    if (table.backgroundColor != WCAtlasProfileCornerPageColor()) {
        table.backgroundColor = WCAtlasProfileCornerPageColor();
    }
    if (table.layer.cornerRadius != 0) table.layer.cornerRadius = 0;
    for (UITableViewCell *cell in table.visibleCells) {
        WCAtlasProfileCornerStyleCell(cell, radius, margin);
    }
}

static void WCAtlasProfileCornerViewDidLayout(UIViewController *self, SEL command) {
    if (WCAtlasProfileCornerDepth > 4) return;
    WCAtlasProfileCornerDepth++;
    if (WCAtlasProfileCornerOriginal) {
        ((void (*)(id, SEL))WCAtlasProfileCornerOriginal)(self, command);
    }
    WCAtlasProfileCornerApply(self);
    WCAtlasProfileCornerDepth--;
}

static BOOL WCAtlasProfileCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
    method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

NSInteger WCAtlasInstallProfileCorner(void) {
    WCAtlasInstallProfileCornerDefaults();
    if (WCAtlasProfileCornerHooked) return 1;
    Class cls = NSClassFromString(@"ContactInfoViewController");
    if (!cls) return 0;
    BOOL laidOut = WCAtlasProfileCornerSwizzle(cls, @selector(viewDidLayoutSubviews),
                                               (IMP)WCAtlasProfileCornerViewDidLayout,
                                               &WCAtlasProfileCornerOriginal);
    if (!laidOut) return 0;
    WCAtlasProfileCornerHooked = YES;
    return 1;
}

static void WCAtlasProfileCornerRetry(NSInteger attemptsLeft) {
    if (WCAtlasInstallProfileCorner()) return;
    if (attemptsLeft <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasProfileCornerRetry(attemptsLeft - 1);
    });
}

__attribute__((constructor)) static void WCAtlasProfileCornerBootstrap(void) {
    if (NSThread.isMainThread) {
        WCAtlasProfileCornerRetry(40);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasProfileCornerRetry(40);
    });
}