#import "WCAtlasMomentsImageCorner.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const WCAtlasMomentsImageCornerPrefix = @"com.qiu7c.wcatlas.moments-corner.";

static char WCAtlasMomentsImageCornerStyledKey;
static NSUInteger WCAtlasMomentsImageCornerDepth;
static IMP WCAtlasMomentsImageCornerOriginal;
static BOOL WCAtlasMomentsImageCornerHooked;
static BOOL WCAtlasMomentsImageCornerSwizzle(Class cls, SEL selector, IMP replacement, IMP *original);

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
    // A mosaic thumbnail is one picture made of several pieces: rounding the pieces would leave
    // gaps between them, so the container itself is rounded and its pieces are clipped by it.
    if ([name isEqualToString:@"WCPuzzleImageView"]) return YES;
    // A shared video channel feed is one rounded card holding the cover and the play badge.
    if ([name isEqualToString:@"WCContentItemFinderView"]) return YES;
    // The video channel row on a profile is five plain UIImageViews inside its entrance view, not
    // WCImageViews, so they are matched here. The size guard leaves the avatars and the little
    // badges alone: only the thumbnails are big enough.
    if ([name isEqualToString:@"UIImageView"]) {
        if (view.bounds.size.width < 40 || view.bounds.size.height < 40) return NO;
        for (UIView *parent = view.superview; parent; parent = parent.superview) {
            if ([NSStringFromClass(parent.class) isEqualToString:@"WCFinderWXContactEntranceView"]) return YES;
        }
        return NO;
    }
    // A video feed uses a different branch: the picture is a plain UIImageView inside
    // WCSNSNodeVideoView, and the player sits next to it. Rounding the container clips both, which
    // is what makes the preview and the running video share the same corners.
    if ([name isEqualToString:@"WCSNSNodeVideoView"] ||
        [name isEqualToString:@"WCPlayerView"] ||
        [name isEqualToString:@"WCPlayerLayerView"]) return YES;
    // The templates are deliberately not matched: a card template is a wide container that also
    // holds text, so rounding it put a second, much bigger corner behind the picture and made a
    // shared song cover look squashed. Only the picture and the video views are rounded.
    return NO;
}

/// A text only entry is a grey block with no picture inside, so there is nothing for the picture
/// walk to find. The block itself is rounded instead, which is what makes the two lines read as one
/// card rather than a pair of grey strips.
static BOOL WCAtlasMomentsImageCornerIsTextBlock(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [name isEqualToString:@"WCListTextCellView"];
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

static char WCAtlasMomentsImageCornerShapeKey;

/// The walk is the expensive part, not the rounding: it compares class names down the whole
/// subtree. A cell keeps the same bounds for every scroll pass, so remembering the size and the
/// radius and skipping the walk when neither changed makes scrolling essentially free, while a
/// rotation or a settings change still re-walks once.
static void WCAtlasMomentsImageCornerWalk(UIView *view, CGFloat radius, NSInteger depth);
static void WCAtlasMomentsImageCornerWalkIfNeeded(UIView *root) {
    CGFloat radius = WCAtlasMomentsImageCornerRadius();
    NSString *shape = [NSString stringWithFormat:@"%.1fx%.1f@%.1f",
                       root.bounds.size.width, root.bounds.size.height, radius];
    if ([objc_getAssociatedObject(root, &WCAtlasMomentsImageCornerShapeKey) isEqual:shape]) return;
    objc_setAssociatedObject(root, &WCAtlasMomentsImageCornerShapeKey, shape,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasMomentsImageCornerWalk(root, radius, 0);
}

static void WCAtlasMomentsImageCornerWalk(UIView *view, CGFloat radius, NSInteger depth) {
    if (!view || depth > 6) return;
    if (WCAtlasMomentsImageCornerIsTextBlock(view)) {
        // The grey block is a child of the cell, not the cell itself: rounding the cell rounded the
        // full screen width and left the visible block square.
        for (UIView *block in view.subviews) {
            if (block.bounds.size.width < 60) continue;
            if (block.bounds.size.width > view.bounds.size.width - 20) continue;
            WCAtlasMomentsImageCornerStyle(block, radius);
        }
    }
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
        WCAtlasMomentsImageCornerWalkIfNeeded(self);
    }
    WCAtlasMomentsImageCornerDepth--;
}

/// Each page gets its own hook and its own saved original: two swizzles that shared a slot
/// would end up calling each other's original instead of the one they replaced.

static IMP WCAtlasMomentsImageCornerOriginalProfileTable;
static void WCAtlasMomentsImageCornerLayoutProfileTable(UIView *self, SEL command) {
    if (WCAtlasMomentsImageCornerDepth > 4) return;
    WCAtlasMomentsImageCornerDepth++;
    if (WCAtlasMomentsImageCornerOriginalProfileTable) {
        ((void (*)(id, SEL))WCAtlasMomentsImageCornerOriginalProfileTable)(self, command);
    }
    if (WCAtlasMomentsImageCornerOn()) {
        WCAtlasMomentsImageCornerWalkIfNeeded(self);
    }
    WCAtlasMomentsImageCornerDepth--;
}

static void WCAtlasMomentsImageCornerInstallProfileTable(void) {
    Class cls = NSClassFromString(@"TextStateProfileTableView");
    if (!cls) return;
    WCAtlasMomentsImageCornerSwizzle(cls, @selector(layoutSubviews),
                                     (IMP)WCAtlasMomentsImageCornerLayoutProfileTable,
                                     &WCAtlasMomentsImageCornerOriginalProfileTable);
}

static IMP WCAtlasMomentsImageCornerOriginalGridTemplate;
static void WCAtlasMomentsImageCornerLayoutGridTemplate(UIView *self, SEL command) {
    if (WCAtlasMomentsImageCornerDepth > 4) return;
    WCAtlasMomentsImageCornerDepth++;
    if (WCAtlasMomentsImageCornerOriginalGridTemplate) {
        ((void (*)(id, SEL))WCAtlasMomentsImageCornerOriginalGridTemplate)(self, command);
    }
    if (WCAtlasMomentsImageCornerOn()) {
        WCAtlasMomentsImageCornerWalkIfNeeded(self);
    }
    WCAtlasMomentsImageCornerDepth--;
}

static void WCAtlasMomentsImageCornerInstallGridTemplate(void) {
    Class cls = NSClassFromString(@"WCContentItemViewTemplateGrid");
    if (!cls) return;
    WCAtlasMomentsImageCornerSwizzle(cls, @selector(layoutSubviews),
                                     (IMP)WCAtlasMomentsImageCornerLayoutGridTemplate,
                                     &WCAtlasMomentsImageCornerOriginalGridTemplate);
}

static IMP WCAtlasMomentsImageCornerOriginalListBase;
static void WCAtlasMomentsImageCornerLayoutListBase(UIView *self, SEL command) {
    if (WCAtlasMomentsImageCornerDepth > 4) return;
    WCAtlasMomentsImageCornerDepth++;
    if (WCAtlasMomentsImageCornerOriginalListBase) {
        ((void (*)(id, SEL))WCAtlasMomentsImageCornerOriginalListBase)(self, command);
    }
    if (WCAtlasMomentsImageCornerOn()) {
        WCAtlasMomentsImageCornerWalkIfNeeded(self);
    }
    WCAtlasMomentsImageCornerDepth--;
}

/// Every cell of the my moments list inherits this class, so one hook covers the photo, video,
/// hybrid, text and feed cells, including the ones added later.
static void WCAtlasMomentsImageCornerInstallListBase(void) {
    Class cls = NSClassFromString(@"WCListBaseCellView");
    if (!cls) return;
    WCAtlasMomentsImageCornerSwizzle(cls, @selector(layoutSubviews),
                                     (IMP)WCAtlasMomentsImageCornerLayoutListBase,
                                     &WCAtlasMomentsImageCornerOriginalListBase);
}

static void WCAtlasMomentsImageCornerInstallPages(void) {
    WCAtlasMomentsImageCornerInstallProfileTable();
    WCAtlasMomentsImageCornerInstallGridTemplate();
    WCAtlasMomentsImageCornerInstallListBase();
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

/// The timeline cell is the moments feed itself; the three list cells are the "my moments" page;
/// the profile table holds the five thumbnails on a contact page. Nothing else is touched.

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
    // Only the pages that show these pictures are hooked. A hook on MMTableViewCell would reach
    // every table in WeChat, which is far more than this feature is allowed to touch.
    WCAtlasMomentsImageCornerInstallPages();
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