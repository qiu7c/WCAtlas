#import "WCAtlasVirtualLocation.h"
#import "WCAtlasEnhancements.h"

#import <objc/runtime.h>
#import <stdatomic.h>
#import <float.h>
#import <math.h>
#import <UIKit/UIKit.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

NSString * const WCAtlasVirtualLocationEnabledKey = @"com.qiu7c.wcatlas.virtualLocation.enabled";
NSString * const WCAtlasVirtualLocationMomentsEnabledKey = @"com.qiu7c.wcatlas.virtualLocation.momentsEnabled";
NSString * const WCAtlasVirtualLocationLatitudeKey = @"com.qiu7c.wcatlas.virtualLocation.latitude";
NSString * const WCAtlasVirtualLocationLongitudeKey = @"com.qiu7c.wcatlas.virtualLocation.longitude";
NSString * const WCAtlasVirtualLocationNameKey = @"com.qiu7c.wcatlas.virtualLocation.name";
NSString * const WCAtlasVirtualLocationPresetsKey = @"com.qiu7c.wcatlas.virtualLocation.presets";

static const NSUInteger WCAtlasVirtualLocationPresetLimit = 20;
static _Atomic(double) WCAtlasVirtualLocationPickingDeadline;

/// A picker that goes away without either of its callbacks must not leave the
/// spoof switched off for the rest of the session, so the gate always expires.
static const NSTimeInterval WCAtlasVirtualLocationPickingTimeout = 300.0;
static NSString *WCAtlasVirtualLocationNotice;

#pragma mark - Switches

BOOL WCAtlasVirtualLocationEnabled(void) {
    return WCAtlasEnhancementEnabled(WCAtlasVirtualLocationEnabledKey);
}

BOOL WCAtlasVirtualLocationMomentsEnabled(void) {
    return WCAtlasEnhancementEnabled(WCAtlasVirtualLocationMomentsEnabledKey);
}

#pragma mark - Selection

BOOL WCAtlasVirtualLocationCoordinateIsValid(CLLocationCoordinate2D coordinate) {
    if (!isfinite(coordinate.latitude) || !isfinite(coordinate.longitude)) return NO;
    if (fabs(coordinate.latitude) > 90.0 || fabs(coordinate.longitude) > 180.0) return NO;
    // A cleared pair of doubles reads back as 0, 0, which is a legal coordinate
    // in the Gulf of Guinea but never a place someone picked.
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return NO;
    return YES;
}

CLLocationCoordinate2D WCAtlasVirtualLocationCoordinate(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    coordinate.latitude = [defaults doubleForKey:WCAtlasVirtualLocationLatitudeKey];
    coordinate.longitude = [defaults doubleForKey:WCAtlasVirtualLocationLongitudeKey];
    return coordinate;
}

BOOL WCAtlasVirtualLocationHasSelection(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:WCAtlasVirtualLocationLatitudeKey] == nil) return NO;
    if ([defaults objectForKey:WCAtlasVirtualLocationLongitudeKey] == nil) return NO;
    return WCAtlasVirtualLocationCoordinateIsValid(WCAtlasVirtualLocationCoordinate());
}

void WCAtlasVirtualLocationSetCoordinate(CLLocationCoordinate2D coordinate, NSString *name) {
    if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:coordinate.latitude forKey:WCAtlasVirtualLocationLatitudeKey];
    [defaults setDouble:coordinate.longitude forKey:WCAtlasVirtualLocationLongitudeKey];
    if (name.length > 0) {
        [defaults setObject:name forKey:WCAtlasVirtualLocationNameKey];
    } else {
        [defaults removeObjectForKey:WCAtlasVirtualLocationNameKey];
    }
    WCAtlasVirtualLocationSetPickerNotice(nil);
}

void WCAtlasVirtualLocationClear(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:WCAtlasVirtualLocationLatitudeKey];
    [defaults removeObjectForKey:WCAtlasVirtualLocationLongitudeKey];
    [defaults removeObjectForKey:WCAtlasVirtualLocationNameKey];
}

void WCAtlasVirtualLocationNudge(double latitudeDelta, double longitudeDelta) {
    if (!WCAtlasVirtualLocationHasSelection()) return;
    CLLocationCoordinate2D coordinate = WCAtlasVirtualLocationCoordinate();
    CLLocationCoordinate2D moved = coordinate;
    moved.latitude += latitudeDelta;
    moved.longitude += longitudeDelta;
    if (!WCAtlasVirtualLocationCoordinateIsValid(moved)) return;
    WCAtlasVirtualLocationSetCoordinate(moved, [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasVirtualLocationNameKey]);
}

NSString *WCAtlasVirtualLocationCoordinateText(void) {
    if (!WCAtlasVirtualLocationHasSelection()) return @"未选择";
    CLLocationCoordinate2D coordinate = WCAtlasVirtualLocationCoordinate();
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

NSString *WCAtlasVirtualLocationSummary(void) {
    if (!WCAtlasVirtualLocationHasSelection()) return @"未选择";
    NSString *name = [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasVirtualLocationNameKey];
    NSString *coordinates = WCAtlasVirtualLocationCoordinateText();
    return name.length > 0 ? [NSString stringWithFormat:@"%@（%@）", name, coordinates] : coordinates;
}

#pragma mark - Hook entry point

void WCAtlasVirtualLocationSetPicking(BOOL picking) {
    double deadline = picking ? NSDate.date.timeIntervalSince1970 + WCAtlasVirtualLocationPickingTimeout : 0.0;
    atomic_store(&WCAtlasVirtualLocationPickingDeadline, deadline);
}

BOOL WCAtlasVirtualLocationIsPicking(void) {
    double deadline = atomic_load(&WCAtlasVirtualLocationPickingDeadline);
    if (deadline <= 0.0) return NO;
    if (NSDate.date.timeIntervalSince1970 > deadline) {
        atomic_store(&WCAtlasVirtualLocationPickingDeadline, 0.0);
        return NO;
    }
    return YES;
}

static UIViewController *WCAtlasVirtualLocationWindowRootViewController(void) {
    UIWindow *window = nil;
    UIWindow *firstWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (!firstWindow) firstWindow = candidate;
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) break;
    }
    // The scene lookup is the whole story: the deprecated keyWindow fallback it
    // used to carry is both warned about and redundant, and the first window of
    // the first scene still beats having none at all.
    if (!window) window = firstWindow;
    return window.rootViewController;
}

static UIViewController *WCAtlasVirtualLocationFrontViewController(void) {
    UIViewController *controller = WCAtlasVirtualLocationWindowRootViewController();
    for (NSInteger depth = 0; controller && depth < 12; depth++) {
        UIViewController *next = nil;
        if ([controller isKindOfClass:UINavigationController.class]) {
            next = ((UINavigationController *)controller).visibleViewController;
        } else if ([controller isKindOfClass:UITabBarController.class]) {
            next = ((UITabBarController *)controller).selectedViewController;
        } else if ([controller isKindOfClass:UISplitViewController.class]) {
            next = ((UISplitViewController *)controller).viewControllers.lastObject;
        }
        if (next && next != controller) {
            controller = next;
            continue;
        }
        UIViewController *presented = controller.presentedViewController;
        if (!presented || presented == controller) break;
        controller = presented;
    }
    return controller;
}

BOOL WCAtlasVirtualLocationFrontSurfaceLooksLikeMoments(void) {
    static NSArray<NSString *> *keywords;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // WeChat internals; the list is calibration pending and only ever causes
        // the moments switch to stand the spoof down, never to change a value.
        keywords = @[@"moments", @"sns", @"timeline", @"wcstory", @"sight"];
    });
    NSString *className = NSStringFromClass(WCAtlasVirtualLocationFrontViewController().class);
    if (className.length == 0) return NO;
    NSString *lowercase = className.lowercaseString;
    for (NSString *keyword in keywords) {
        if ([lowercase containsString:keyword]) return YES;
    }
    return NO;
}

CLLocationCoordinate2D WCAtlasVirtualLocationSpoofedCoordinate(CLLocationCoordinate2D original) {
    if (!WCAtlasVirtualLocationEnabled()) return original;
    if (WCAtlasVirtualLocationIsPicking()) return original;
    if (!WCAtlasVirtualLocationHasSelection()) return original;
    if (WCAtlasVirtualLocationFrontSurfaceLooksLikeMoments() && !WCAtlasVirtualLocationMomentsEnabled()) return original;
    CLLocationCoordinate2D spoofed = WCAtlasVirtualLocationCoordinate();
    if (!WCAtlasVirtualLocationCoordinateIsValid(spoofed)) return original;
    return spoofed;
}

#pragma mark - Saved places

NSArray<NSDictionary<NSString *, id> *> *WCAtlasVirtualLocationPresets(void) {
    NSArray *stored = [NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasVirtualLocationPresetsKey];
    NSMutableArray<NSDictionary<NSString *, id> *> *presets = [NSMutableArray array];
    for (id entry in stored) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *preset = entry;
        id latitude = preset[@"latitude"];
        id longitude = preset[@"longitude"];
        if (![latitude respondsToSelector:@selector(doubleValue)]) continue;
        if (![longitude respondsToSelector:@selector(doubleValue)]) continue;
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
        if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) continue;
        [presets addObject:preset];
    }
    return presets;
}

void WCAtlasVirtualLocationAddPreset(NSString *name, CLLocationCoordinate2D coordinate) {
    if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) return;
    if (name.length == 0) name = WCAtlasVirtualLocationCoordinateText();
    NSMutableArray *presets = [WCAtlasVirtualLocationPresets() mutableCopy];
    NSDictionary *entry = @{ @"name": name,
                             @"latitude": @(coordinate.latitude),
                             @"longitude": @(coordinate.longitude) };
    [presets removeObject:entry];
    [presets insertObject:entry atIndex:0];
    while (presets.count > WCAtlasVirtualLocationPresetLimit) {
        [presets removeLastObject];
    }
    [NSUserDefaults.standardUserDefaults setObject:presets forKey:WCAtlasVirtualLocationPresetsKey];
}

void WCAtlasVirtualLocationRemovePresetAtIndex(NSUInteger index) {
    NSMutableArray *presets = [WCAtlasVirtualLocationPresets() mutableCopy];
    if (index >= presets.count) return;
    [presets removeObjectAtIndex:index];
    [NSUserDefaults.standardUserDefaults setObject:presets forKey:WCAtlasVirtualLocationPresetsKey];
}

#pragma mark - Picker feedback

NSString *WCAtlasVirtualLocationPickerNotice(void) {
    return WCAtlasVirtualLocationNotice;
}

void WCAtlasVirtualLocationSetPickerNotice(NSString *notice) {
    WCAtlasVirtualLocationNotice = [notice copy];
}

#pragma mark - Hooks

static CLLocationCoordinate2D (*WCAtlasVirtualLocationOriginalCoordinate)(id, SEL);

/// CLLocationCoordinate2D is a pair of doubles, so arm64 hands the original
/// value back in the vector registers and a plain function pointer is enough.
static CLLocationCoordinate2D WCAtlasVirtualLocationCoordinateReplacement(id self, SEL _cmd) {
    CLLocationCoordinate2D original = kCLLocationCoordinate2DInvalid;
    if (WCAtlasVirtualLocationOriginalCoordinate) {
        original = WCAtlasVirtualLocationOriginalCoordinate(self, _cmd);
    }
    return WCAtlasVirtualLocationSpoofedCoordinate(original);
}

void WCAtlasVirtualLocationInstallHooks(void) {
    // Registered here rather than while the settings page loads, so the two
    // switches show their real default from the very first launch.
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasVirtualLocationEnabledKey: @NO,
        WCAtlasVirtualLocationMomentsEnabledKey: @NO,
    }];
    Class locationClass = objc_getClass("CLLocation");
    SEL coordinateSelector = sel_registerName("coordinate");
    Method coordinateMethod = locationClass ? class_getInstanceMethod(locationClass, coordinateSelector) : NULL;
    if (!coordinateMethod) return;
    MSHookMessageEx(locationClass,
                    coordinateSelector,
                    (IMP)WCAtlasVirtualLocationCoordinateReplacement,
                    (IMP *)&WCAtlasVirtualLocationOriginalCoordinate);
}