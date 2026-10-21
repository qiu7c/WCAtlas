#import "WCAtlasGlobalCorner.h"

#import "WCAtlasCornerSurfaces.h"
#import "WCAtlasHomeCorner.h"

#import <objc/runtime.h>

/// The original implementation, so the hooked controller still lays itself out normally.
static void (*WCAtlasOriginalViewDidLayoutSubviews)(id, SEL);

static void WCAtlasReplacementViewDidLayoutSubviews(id self, SEL command) {
    if (WCAtlasOriginalViewDidLayoutSubviews) WCAtlasOriginalViewDidLayoutSubviews(self, command);
    // The constructor runs before WeChat has necessarily registered its own classes, and a class
    // that is missing then would otherwise never be hooked. Installing is a no-op once it worked.
    WCAtlasInstallHomeCorner();
    WCAtlasInstallCornerSurfaces();
    // Every controller reaches here. The apply function returns immediately while the switch is
    // off, so a disabled style costs one defaults lookup per layout pass.
    WCAtlasGlobalCornerApplyToController(self);
}

static void WCAtlasInstallCornerHook(void) {
    Method method = class_getInstanceMethod(UIViewController.class, @selector(viewDidLayoutSubviews));
    if (!method) return;
    WCAtlasOriginalViewDidLayoutSubviews = (void (*)(id, SEL))method_getImplementation(method);
    method_setImplementation(method, (IMP)WCAtlasReplacementViewDidLayoutSubviews);
}

static void WCAtlasCornerSetup(void) {
    WCAtlasInstallGlobalCornerDefaults();
    WCAtlasInstallCornerSurfaceDefaults();
    WCAtlasInstallHomeCornerDefaults();
    WCAtlasInstallCornerHook();
    WCAtlasInstallCornerSurfaces();
    WCAtlasInstallHomeCorner();
}

__attribute__((constructor)) static void WCAtlasCornerBootstrap(void) {
    // UIViewController lives in UIKit, which may not be loaded when the dylib is linked in.
    // Hopping to the main queue also keeps the swizzle off the loader thread.
    if (NSThread.isMainThread) {
        WCAtlasCornerSetup();
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasCornerSetup();
    });
}