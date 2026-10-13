#import "WCAtlasVirtualLocationPicker.h"

#import "WCAtlasVirtualLocation.h"

#import <objc/message.h>
#import <objc/runtime.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

static NSString *const WCAtlasVirtualLocationPickerClassName = @"MMPickLocationViewController";
/// Taken from the reference plugin's own call site: scene type 0, and "only use
/// user location" off.
static const NSInteger WCAtlasVirtualLocationPickerSceneType = 0;

static __weak UIViewController *WCAtlasVirtualLocationActivePicker;
static id WCAtlasVirtualLocationActiveBridge;
static BOOL WCAtlasVirtualLocationPickerHooksInstalled;
static void (^WCAtlasVirtualLocationFinishHandler)(void);

#pragma mark - Coordinate extraction

typedef CLLocationCoordinate2D (*WCAtlasVirtualLocationCoordinateMessage)(id, SEL);

/// Reads a coordinate out of a WeChat object without assuming its class.
///
/// Only accessors that return a coordinate structure are tried through a struct
/// returning cast; object returning ones go through an object cast first, so a
/// wrong guess can never be interpreted as two doubles.
static BOOL WCAtlasVirtualLocationCoordinateFromObject(id object, CLLocationCoordinate2D *outCoordinate) {
    if (!object || !outCoordinate) return NO;
    if ([object isKindOfClass:CLLocation.class]) {
        CLLocationCoordinate2D coordinate = [(CLLocation *)object coordinate];
        if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) return NO;
        *outCoordinate = coordinate;
        return YES;
    }
    SEL locationSelector = NSSelectorFromString(@"location");
    if ([object respondsToSelector:locationSelector]) {
        id location = ((id (*)(id, SEL))objc_msgSend)(object, locationSelector);
        if ([location isKindOfClass:CLLocation.class]) {
            CLLocationCoordinate2D coordinate = [(CLLocation *)location coordinate];
            if (WCAtlasVirtualLocationCoordinateIsValid(coordinate)) {
                *outCoordinate = coordinate;
                return YES;
            }
        }
    }
    for (NSString *name in @[@"coordinate", @"coordinate2D"]) {
        SEL selector = NSSelectorFromString(name);
        if (![object respondsToSelector:selector]) continue;
        CLLocationCoordinate2D coordinate = ((WCAtlasVirtualLocationCoordinateMessage)objc_msgSend)(object, selector);
        if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) continue;
        *outCoordinate = coordinate;
        return YES;
    }
    return NO;
}

/// Last resort read of the picker's own selection.
///
/// Deliberately narrow: names that could mean "where the user really is" are left
/// out, because writing the real position into the fake one is worse than not
/// capturing anything at all.
static BOOL WCAtlasVirtualLocationCaptureCoordinateFromPicker(id picker) {
    if (!picker) return NO;
    for (NSString *name in @[@"selectedLocation", @"currentSelectedLocation"]) {
        SEL selector = NSSelectorFromString(name);
        if (![picker respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(picker, selector);
        CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
        if (value && WCAtlasVirtualLocationCoordinateFromObject(value, &coordinate)) {
            WCAtlasVirtualLocationSetCoordinate(coordinate, nil);
            return YES;
        }
    }
    return NO;
}

static void WCAtlasVirtualLocationFinishPicking(void) {
    WCAtlasVirtualLocationSetPicking(NO);
    WCAtlasVirtualLocationActiveBridge = nil;
    WCAtlasVirtualLocationActivePicker = nil;
    void (^handler)(void) = WCAtlasVirtualLocationFinishHandler;
    WCAtlasVirtualLocationFinishHandler = nil;
    if (handler) handler();
}

#pragma mark - Picker delegate

/// The picker calls back through WeChat's own selectors, so this class exists
/// only to answer them. Both are implemented without arguments on purpose: the
/// reference names them without a colon, and an argument that is not really there
/// would be read as a pointer.
@interface WCAtlasVirtualLocationPickerBridge : NSObject
@end

@implementation WCAtlasVirtualLocationPickerBridge

- (void)onFinishSelectedLocation {
    // The coordinate arrives through wx_saveSelectedLocation:, so the gate stays
    // up until the picker actually goes away.
}

- (void)onCancelSeletctedLocation {
    // WeChat's own spelling, typo included.
    WCAtlasVirtualLocationFinishPicking();
}

@end

#pragma mark - Hooks

static void (*WCAtlasOriginalSaveSelectedLocation)(id, SEL, id);
static void (*WCAtlasOriginalPickerViewDidDisappear)(id, SEL, BOOL);

static void WCAtlasSaveSelectedLocationReplacement(id self, SEL _cmd, id location) {
    if (WCAtlasOriginalSaveSelectedLocation) WCAtlasOriginalSaveSelectedLocation(self, _cmd, location);
    // Pass straight through unless our own picking session is running, so a normal
    // "send location" behaves exactly as it did before.
    if (!WCAtlasVirtualLocationActiveBridge) return;
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    if (WCAtlasVirtualLocationCoordinateFromObject(location, &coordinate)) {
        WCAtlasVirtualLocationSetCoordinate(coordinate, nil);
    }
    WCAtlasVirtualLocationFinishPicking();
}

static void WCAtlasPickerViewDidDisappearReplacement(id self, SEL _cmd, BOOL animated) {
    if (WCAtlasOriginalPickerViewDidDisappear) WCAtlasOriginalPickerViewDidDisappear(self, _cmd, animated);
    if (self != WCAtlasVirtualLocationActivePicker) return;
    // Covers a dismissal that never reached either callback.
    WCAtlasVirtualLocationCaptureCoordinateFromPicker(self);
    WCAtlasVirtualLocationFinishPicking();
}

static void WCAtlasVirtualLocationInstallPickerHooks(Class pickerClass) {
    if (WCAtlasVirtualLocationPickerHooksInstalled || !pickerClass) return;
    WCAtlasVirtualLocationPickerHooksInstalled = YES;
    SEL saveSelector = NSSelectorFromString(@"wx_saveSelectedLocation:");
    if (class_getInstanceMethod(pickerClass, saveSelector)) {
        MSHookMessageEx(pickerClass,
                        saveSelector,
                        (IMP)WCAtlasSaveSelectedLocationReplacement,
                        (IMP *)&WCAtlasOriginalSaveSelectedLocation);
    }
    SEL disappearSelector = @selector(viewDidDisappear:);
    if (class_getInstanceMethod(pickerClass, disappearSelector)) {
        MSHookMessageEx(pickerClass,
                        disappearSelector,
                        (IMP)WCAtlasPickerViewDidDisappearReplacement,
                        (IMP *)&WCAtlasOriginalPickerViewDidDisappear);
    }
}

#pragma mark - Presentation

BOOL WCAtlasVirtualLocationPresentWeChatPicker(UIViewController *fromViewController,
                                               void (^onFinish)(void)) {
    if (!fromViewController) return NO;
    Class pickerClass = objc_getClass(WCAtlasVirtualLocationPickerClassName.UTF8String);
    if (!pickerClass) return NO;
    SEL initializer = NSSelectorFromString(@"initWithSceneType:OnlyUseUserLocation:");
    if (![pickerClass instancesRespondToSelector:initializer]) return NO;
    WCAtlasVirtualLocationInstallPickerHooks(pickerClass);
    id (*initializerMessage)(id, SEL, NSInteger, BOOL) = (id (*)(id, SEL, NSInteger, BOOL))objc_msgSend;
    UIViewController *picker = initializerMessage([pickerClass alloc], initializer,
                                                  WCAtlasVirtualLocationPickerSceneType, NO);
    if (!picker) return NO;
    WCAtlasVirtualLocationPickerBridge *bridge = [WCAtlasVirtualLocationPickerBridge new];
    SEL delegateSelector = NSSelectorFromString(@"setDelegate:");
    if ([picker respondsToSelector:delegateSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(picker, delegateSelector, bridge);
        WCAtlasVirtualLocationActiveBridge = bridge;
    }
    WCAtlasVirtualLocationActivePicker = picker;
    WCAtlasVirtualLocationFinishHandler = [onFinish copy];
    WCAtlasVirtualLocationSetPicking(YES);
    // The reference pushes when there is a stack and presents otherwise, which is
    // also what keeps the picker's own back button working.
    UINavigationController *navigation = fromViewController.navigationController;
    if (navigation) {
        [navigation pushViewController:picker animated:YES];
    } else {
        UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:picker];
        [fromViewController presentViewController:wrapper animated:YES completion:nil];
    }
    return YES;
}