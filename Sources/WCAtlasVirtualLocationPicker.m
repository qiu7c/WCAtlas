#import "WCAtlasVirtualLocationPicker.h"

#import "WCAtlasVirtualLocation.h"

#import <objc/message.h>
#import <objc/runtime.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

#import "WCAtlasLogging.h"

static NSString *const WCAtlasVirtualLocationPickerClassName = @"MMPickLocationViewController";
/// Taken from the reference plugin's own call site: scene type 0, and "only use
/// user location" off.
static const NSInteger WCAtlasVirtualLocationPickerSceneType = 0;

static __weak UIViewController *WCAtlasVirtualLocationActivePicker;
static id WCAtlasVirtualLocationActiveBridge;
static BOOL WCAtlasVirtualLocationPickerHooksInstalled;
static void (^WCAtlasVirtualLocationFinishHandler)(void);

/// The app's own log lives in memory and dies with a crash, which is exactly the
/// case this diagnostic has to survive, so the picker also records its steps in a
/// small file, and the settings page reads them back.
static NSString *WCAtlasVirtualLocationTracePath(void) {
    NSArray<NSString *> *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *directory = library.firstObject ?: NSTemporaryDirectory();
    return [directory stringByAppendingPathComponent:@"WCAtlasVirtualLocationTrace.plist"];
}

static void WCAtlasVirtualLocationTrace(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    if (line.length == 0) return;
    WCAtlasLogAlways(@"[VL] %@", line);
    NSString *path = WCAtlasVirtualLocationTracePath();
    NSMutableArray<NSString *> *lines = [[NSArray arrayWithContentsOfFile:path] mutableCopy] ?: [NSMutableArray array];
    [lines addObject:line];
    while (lines.count > 16) [lines removeObjectAtIndex:0];
    [lines writeToFile:path atomically:YES];
}

NSString *WCAtlasVirtualLocationPickerTraceText(void) {
    NSArray<NSString *> *lines = [NSArray arrayWithContentsOfFile:WCAtlasVirtualLocationTracePath()];
    if (lines.count == 0) return @"";
    return [@"\n" stringByAppendingString:[lines componentsJoinedByString:@"\n"]];
}

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
    for (NSString *name in @[@"currLocation", @"getLocationPOIItem"]) {
        SEL selector = NSSelectorFromString(name);
        if (![picker respondsToSelector:selector]) {
            WCAtlasVirtualLocationTrace(@"[VL] picker has no %@", name);
            continue;
        }
        // Read the return type before calling anything. An accessor that hands back a
        // coordinate structure and one that hands back an object both turn up here, and
        // sending an object message to a structure would be the same class of mistake
        // that has already cost this path one crash. The encoding says which it is, and
        // the class name reaches the trace so the next report is conclusive.
        Method method = class_getInstanceMethod(object_getClass(picker), selector);
        const char *encoding = method ? method_getTypeEncoding(method) : NULL;
        CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
        if (encoding && encoding[0] == '{') {
            coordinate = ((WCAtlasVirtualLocationCoordinateMessage)objc_msgSend)(picker, selector);
            WCAtlasVirtualLocationTrace(@"[VL] %@ returned a structure", name);
        } else if (encoding && encoding[0] == '@') {
            id value = ((id (*)(id, SEL))objc_msgSend)(picker, selector);
            WCAtlasVirtualLocationTrace(@"[VL] %@ returned %@", name,
                                        value ? NSStringFromClass([value class]) : @"nil");
            if (!value || !WCAtlasVirtualLocationCoordinateFromObject(value, &coordinate)) continue;
        } else {
            WCAtlasVirtualLocationTrace(@"[VL] %@ has an unreadable return type", name);
            continue;
        }
        if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) continue;
        WCAtlasVirtualLocationSetCoordinate(coordinate, nil);
        return YES;
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
@property (nonatomic, weak, nullable) UIViewController *picker;
/// The reference sets this on its own bridge before handing the bridge to the
/// picker, so the picker very likely reads it back while it loads; a bridge that
/// cannot answer is missing configuration rather than merely quiet.
@property (nonatomic, weak, nullable) UIViewController *presentingController;
@end

@implementation WCAtlasVirtualLocationPickerBridge

/// The reference's selector table carries this name, and WeChat builds the picker
/// page around what its delegate answers, so the done item is very likely gated on
/// this method existing. The argument is deliberately untouched: its type is
/// unknown, and the coordinate can be read from the picker itself, which is safer
/// than treating an unknown pointer as an object.
/// The picker asks its delegate for the item it should show in the top right, and
/// the device log named this selector exactly. Without it the page has no done
/// item at all, which is what the reporter saw, and the only way out was cancel.
/// A system item brings the localised title without a literal in the source, and
/// its action is the save request the reference's selector table also carries.
- (id)onGetRightBarButton {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                         target:self
                                                         action:@selector(saveFromPicker:)];
}

- (void)saveFromPicker:(id)sender {
    (void)sender;
    WCAtlasVirtualLocationTrace(@"[VL] picker asked to save");
    WCAtlasVirtualLocationCaptureCoordinateFromPicker(self.picker);
    WCAtlasVirtualLocationFinishPicking();
    // The reporter's point: saving replaced the coordinate but left the picker page
    // on screen. Leave the page the way the reference does, popping when the picker
    // sits on a stack and dismissing when it was presented on its own.
    UINavigationController *navigation = self.picker.navigationController;
    if (navigation && navigation.viewControllers.count > 1) {
        [navigation popViewControllerAnimated:YES];
    } else if (self.picker.presentingViewController) {
        [self.picker dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)onFinishSelectedLocation {
    WCAtlasVirtualLocationTrace(@"[VL] picker finished");
    // The picker says it has a selection at this point, so this is the moment to
    // read it back through the accessors that were verified to exist in the
    // reference build, rather than silently keeping nothing.
    WCAtlasVirtualLocationCaptureCoordinateFromPicker(self.picker);
}

- (void)onCancelSeletctedLocation {
    WCAtlasVirtualLocationTrace(@"[VL] picker cancelled");
    // WeChat's own spelling, typo included.
    WCAtlasVirtualLocationFinishPicking();
}

/// The picker treats its delegate as a private protocol rather than a public one,
/// so a method this bridge does not implement is not an error the picker guards
/// against: it is a message send that ends the process. Answering every selector
/// turns that into a logged no-op. respondsToSelector: still consults the real
/// method list, so anything the picker does check for behaves exactly as before.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (signature) return signature;
    return [NSMethodSignature signatureWithObjCTypes:"@@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    WCAtlasVirtualLocationTrace(@"[VL] picker asked delegate for %@", NSStringFromSelector(invocation.selector));
}

@end

#pragma mark - Hooks

static void (*WCAtlasOriginalPickerViewDidDisappear)(id, SEL, BOOL);

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
    if (!pickerClass) {
        WCAtlasVirtualLocationTrace(@"[VL] class not found: %@", WCAtlasVirtualLocationPickerClassName);
        return NO;
    }
    SEL initializer = NSSelectorFromString(@"initWithSceneType:OnlyUseUserLocation:");
    if (![pickerClass instancesRespondToSelector:initializer]) {
        WCAtlasVirtualLocationTrace(@"[VL] initializer missing");
        return NO;
    }
    WCAtlasVirtualLocationInstallPickerHooks(pickerClass);
    id (*initializerMessage)(id, SEL, NSInteger, BOOL) = (id (*)(id, SEL, NSInteger, BOOL))objc_msgSend;
    UIViewController *picker = initializerMessage([pickerClass alloc], initializer,
                                                  WCAtlasVirtualLocationPickerSceneType, NO);
    if (!picker) {
        WCAtlasVirtualLocationTrace(@"[VL] picker init returned nil");
        return NO;
    }
    WCAtlasVirtualLocationPickerBridge *bridge = [WCAtlasVirtualLocationPickerBridge new];
    bridge.picker = picker;
    bridge.presentingController = fromViewController;
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
        WCAtlasVirtualLocationTrace(@"[VL] pushing picker");
        [navigation pushViewController:picker animated:YES];
        WCAtlasVirtualLocationTrace(@"[VL] pushed picker");
    } else {
        WCAtlasVirtualLocationTrace(@"[VL] presenting picker");
        UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:picker];
        [fromViewController presentViewController:wrapper animated:YES completion:nil];
        WCAtlasVirtualLocationTrace(@"[VL] presented picker");
    }
    return YES;
}