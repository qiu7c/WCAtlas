#import "WCAtlasNavigationAppearance.h"

#import "WCAtlasEnhancements.h"

#import <objc/runtime.h>
#import <string.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

NSString *const WCAtlasBlackBackItemKey = @"com.qiu7c.wcatlas.interface.black-back-item";

UIColor *WCAtlasBackChevronColor(void) {
    return UIColor.blackColor;
}

UIImage *WCAtlasBackChevronImage(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Drawn at the size the system chevron occupies next to a 17pt title.
        // The stroke is inset by half its width so the round caps are not clipped
        // by the image bounds.
        CGSize size = CGSizeMake(13.0, 22.0);
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        UIImage *drawn = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            UIBezierPath *path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(10.1, 2.2)];
            [path addLineToPoint:CGPointMake(2.2, 11.0)];
            [path addLineToPoint:CGPointMake(10.1, 19.8)];
            path.lineWidth = 2.4;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [WCAtlasBackChevronColor() setStroke];
            [path stroke];
        }];
        image = [drawn imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return image;
}

BOOL WCAtlasNavigationAppearanceIsOwnedViewController(UIViewController *controller) {
    if (!controller) return NO;
    const char *name = object_getClassName(controller);
    if (!name) return NO;
    return strncmp(name, "WCAtlas", 7) == 0;
}

static BOOL WCAtlasBackItemStyleEnabled(void) {
    // Registered here as well as in the settings catalogue so the default holds
    // even before the settings page has ever been opened.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ WCAtlasBlackBackItemKey: @YES }];
    return WCAtlasEnhancementEnabled(WCAtlasBlackBackItemKey);
}

void WCAtlasApplyBackButtonStyle(UINavigationBar *bar, UINavigationItem *item) {
    if (!item) return;
    if (!WCAtlasBackItemStyleEnabled()) {
        WCAtlasRestoreBackButtonStyle(bar);
        return;
    }
    // Only the chevron. The page below may be one we do not own, and its title
    // would otherwise arrive in our bar as blue text.
    item.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    if (!bar) return;
    bar.backIndicatorImage = WCAtlasBackChevronImage();
    bar.backIndicatorTransitionMaskImage = WCAtlasBackChevronImage();
}

void WCAtlasRestoreBackButtonStyle(UINavigationBar *bar) {
    if (!bar) return;
    // nil means "use the system chevron", which is the state these bars are in
    // before we touch them.
    if (bar.backIndicatorImage == WCAtlasBackChevronImage()) bar.backIndicatorImage = nil;
    if (bar.backIndicatorTransitionMaskImage == WCAtlasBackChevronImage()) {
        bar.backIndicatorTransitionMaskImage = nil;
    }
}

#pragma mark - Hooks

static void (*WCAtlasOriginalOwnedViewControllerViewWillAppear)(id, SEL, BOOL);
static void (*WCAtlasOriginalOwnedViewControllerViewWillDisappear)(id, SEL, BOOL);

static void WCAtlasOwnedViewControllerViewWillAppearReplacement(id self, SEL _cmd, BOOL animated) {
    if (WCAtlasOriginalOwnedViewControllerViewWillAppear) {
        WCAtlasOriginalOwnedViewControllerViewWillAppear(self, _cmd, animated);
    }
    if (!WCAtlasNavigationAppearanceIsOwnedViewController(self)) return;
    UIViewController *controller = self;
    WCAtlasApplyBackButtonStyle(controller.navigationController.navigationBar, controller.navigationItem);
}

static void WCAtlasOwnedViewControllerViewWillDisappearReplacement(id self, SEL _cmd, BOOL animated) {
    if (WCAtlasOriginalOwnedViewControllerViewWillDisappear) {
        WCAtlasOriginalOwnedViewControllerViewWillDisappear(self, _cmd, animated);
    }
    if (!WCAtlasNavigationAppearanceIsOwnedViewController(self)) return;
    UIViewController *controller = self;
    WCAtlasRestoreBackButtonStyle(controller.navigationController.navigationBar);
}

void WCAtlasNavigationAppearanceInstallHooks(void) {
    Class controllerClass = objc_getClass("UIViewController");
    if (!controllerClass) return;
    // Every appearance in the app passes through these two, so the class name
    // check is what keeps the work down to our own pages.
    SEL appearSelector = sel_registerName("viewWillAppear:");
    SEL disappearSelector = sel_registerName("viewWillDisappear:");
    if (class_getInstanceMethod(controllerClass, appearSelector)) {
        MSHookMessageEx(controllerClass,
                        appearSelector,
                        (IMP)WCAtlasOwnedViewControllerViewWillAppearReplacement,
                        (IMP *)&WCAtlasOriginalOwnedViewControllerViewWillAppear);
    }
    if (class_getInstanceMethod(controllerClass, disappearSelector)) {
        MSHookMessageEx(controllerClass,
                        disappearSelector,
                        (IMP)WCAtlasOwnedViewControllerViewWillDisappearReplacement,
                        (IMP *)&WCAtlasOriginalOwnedViewControllerViewWillDisappear);
    }
}