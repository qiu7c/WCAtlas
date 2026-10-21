#import "WCAtlasGlobalCorner.h"

#import "WCAtlasCornerSurfaces.h"
#import "WCAtlasHomeCorner.h"

#import <objc/runtime.h>

/// The original implementation, so the hooked controller still lays itself out normally.
static void (*WCAtlasOriginalViewDidLayoutSubviews)(id, SEL);
/// Set once the controller hook is really in place. Read by the settings page, because "the
/// switch does nothing" and "the hook was never installed" look identical from the outside.
static BOOL WCAtlasCornerLayoutHooked;

BOOL WCAtlasCornerLayoutHookInstalled(void) {
    return WCAtlasCornerLayoutHooked;
}

static void WCAtlasReplacementViewDidLayoutSubviews(id self, SEL command) {
    if (WCAtlasOriginalViewDidLayoutSubviews) WCAtlasOriginalViewDidLayoutSubviews(self, command);
    // The constructor runs before WeChat has necessarily registered its own classes, and a class
    // that is missing then would otherwise never be hooked. Installing is a no-op once it worked.
    WCAtlasInstallHomeCorner();
    WCAtlasInstallCornerSurfaces();
    // Every controller reaches here. The apply function returns immediately while the switch is
    // off, so a disabled style costs one defaults lookup per layout pass.
    WCAtlasGlobalCornerApplyToController(self);
    // The home page card needs a real class, and the one the reference implementation keys off
    // is the main table view rather than a conversation cell.
    WCAtlasHomeCornerApplyToController(self);
}

/// Returns NO while UIKit is not there yet, so the caller can try again.
static BOOL WCAtlasInstallCornerHook(void) {
    if (WCAtlasCornerLayoutHooked) return YES;
    Class controllerClass = NSClassFromString(@"UIViewController");
    if (!controllerClass) return NO;
    Method method = class_getInstanceMethod(controllerClass, @selector(viewDidLayoutSubviews));
    if (!method) return NO;
    WCAtlasOriginalViewDidLayoutSubviews = (void (*)(id, SEL))method_getImplementation(method);
    method_setImplementation(method, (IMP)WCAtlasReplacementViewDidLayoutSubviews);
    WCAtlasCornerLayoutHooked = YES;
    return YES;
}

static void WCAtlasCornerSetup(void) {
    WCAtlasInstallGlobalCornerDefaults();
    WCAtlasInstallCornerSurfaceDefaults();
    WCAtlasInstallHomeCornerDefaults();
    WCAtlasInstallCornerSurfaces();
    WCAtlasInstallHomeCorner();
}

/// A constructor can run before UIKit is loaded, and the first version simply gave up in that
/// case, which left the whole feature switched off while the settings page still looked fine.
/// This keeps knocking until the class exists, then installs the rest once.
static void WCAtlasCornerRetry(NSInteger attemptsLeft) {
    if (WCAtlasInstallCornerHook()) {
        WCAtlasInstallCornerSurfaces();
        WCAtlasInstallHomeCorner();
        return;
    }
    if (attemptsLeft <= 0) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasCornerRetry(attemptsLeft - 1);
    });
}

__attribute__((constructor)) static void WCAtlasCornerBootstrap(void) {
    WCAtlasCornerSetup();
    if (NSThread.isMainThread) {
        WCAtlasCornerRetry(100);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasCornerRetry(100);
    });
}