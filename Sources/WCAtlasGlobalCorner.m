#import "WCAtlasGlobalCorner.h"

#import "WCAtlasCornerStyler.h"

#import <objc/runtime.h>

NSString *const WCAtlasGlobalCornerEnabledKey = @"com.qiu7c.wcatlas.corner.global.enabled";
NSString *const WCAtlasGlobalCornerRadiusKey = @"com.qiu7c.wcatlas.corner.global.radius";
NSString *const WCAtlasGlobalCornerMarginKey = @"com.qiu7c.wcatlas.corner.global.margin";
NSString *const WCAtlasGlobalCornerSpacingKey = @"com.qiu7c.wcatlas.corner.global.spacing";
NSString *const WCAtlasGlobalCornerStrokeKey = @"com.qiu7c.wcatlas.corner.global.stroke";
NSString *const WCAtlasGlobalCornerExcludedClassesKey = @"com.qiu7c.wcatlas.corner.global.excluded";
NSString *const WCAtlasGlobalCornerDefaultsDidChangeNotification = @"WCAtlasGlobalCornerDefaultsDidChange";

static UIColor *WCAtlasGlobalCornerStrokeColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        if (traits.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.22];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.08];
    }];
}

static BOOL WCAtlasGlobalCornerIsExcluded(UIViewController *controller, NSUserDefaults *defaults) {
    NSArray *excluded = [defaults arrayForKey:WCAtlasGlobalCornerExcludedClassesKey];
    if (![excluded isKindOfClass:NSArray.class] || excluded.count == 0) return NO;
    Class current = controller.class;
    while (current) {
        if ([excluded containsObject:NSStringFromClass(current)]) return YES;
        current = class_getSuperclass(current);
    }
    return NO;
}

void WCAtlasInstallGlobalCornerDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WCAtlasGlobalCornerEnabledKey: @NO,
        WCAtlasGlobalCornerRadiusKey: @16,
        WCAtlasGlobalCornerMarginKey: @8,
        WCAtlasGlobalCornerSpacingKey: @0,
        WCAtlasGlobalCornerStrokeKey: @0,
        WCAtlasGlobalCornerExcludedClassesKey: @[],
    }];
}

void WCAtlasGlobalCornerApplyToController(UIViewController *controller) {
    if (!controller) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults boolForKey:WCAtlasGlobalCornerEnabledKey]) return;
    if (WCAtlasGlobalCornerIsExcluded(controller, defaults)) return;
    UIView *view = controller.view;
    if (!view) return;
    CGFloat radius = [defaults doubleForKey:WCAtlasGlobalCornerRadiusKey];
    CGFloat stroke = [defaults doubleForKey:WCAtlasGlobalCornerStrokeKey];
    if (radius <= 0) {
        WCAtlasClearCornerStyle(view);
        return;
    }
    WCAtlasApplyCornerRadius(view, radius, WCAtlasCornerAll);
    WCAtlasApplyCornerBorder(view, radius, WCAtlasCornerAll, stroke, WCAtlasGlobalCornerStrokeColor());
}