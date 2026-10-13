#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/// Virtual location state. All of it lives in the standard user defaults so the
/// hook, the settings rows and the picker share one source of truth.
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationEnabledKey;
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationMomentsEnabledKey;
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationLatitudeKey;
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationLongitudeKey;
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationNameKey;
FOUNDATION_EXPORT NSString * const WCAtlasVirtualLocationPresetsKey;

#pragma mark - Switches

/// Master switch. It also has to pass the shared enhancement gate, so a feature
/// disabled globally by the user stays disabled here too.
BOOL WCAtlasVirtualLocationEnabled(void);

/// Whether the spoof also applies while a moments screen is in front.
BOOL WCAtlasVirtualLocationMomentsEnabled(void);

#pragma mark - Selection

BOOL WCAtlasVirtualLocationHasSelection(void);
CLLocationCoordinate2D WCAtlasVirtualLocationCoordinate(void);

/// A coordinate is usable when it is finite, inside the legal ranges and not the
/// "0, 0" that a cleared default reads back as.
BOOL WCAtlasVirtualLocationCoordinateIsValid(CLLocationCoordinate2D coordinate);

void WCAtlasVirtualLocationSetCoordinate(CLLocationCoordinate2D coordinate, NSString * _Nullable name);
void WCAtlasVirtualLocationClear(void);

/// Moves the stored coordinate by a delta. The result is kept only when it is
/// still valid, so a nudge can never push the spoof off the map.
void WCAtlasVirtualLocationNudge(double latitudeDelta, double longitudeDelta);

/// "31.230416, 121.473701" and a human readable summary for the settings rows.
NSString *WCAtlasVirtualLocationCoordinateText(void);
NSString *WCAtlasVirtualLocationSummary(void);

#pragma mark - Hook entry point

/// The coordinate the CLLocation hook must hand back. Returns the untouched
/// original whenever the feature is off, has no selection, is being picked, or
/// the surface in front is excluded by its own switch.
CLLocationCoordinate2D WCAtlasVirtualLocationSpoofedCoordinate(CLLocationCoordinate2D original);

/// While a picker is on screen the spoof stands down: otherwise the picker would
/// offer the fake position as the user's own and picking would be a dead end.
/// The state expires on its own, so a picker that is dismissed without a callback
/// cannot leave the spoof switched off.
void WCAtlasVirtualLocationSetPicking(BOOL picking);
BOOL WCAtlasVirtualLocationIsPicking(void);

/// Best effort surface check, used only by the moments switch. The keyword list
/// is calibration pending because the class names belong to WeChat.
BOOL WCAtlasVirtualLocationFrontSurfaceLooksLikeMoments(void);

#pragma mark - Hooks

/// Installs the -[CLLocation coordinate] hook. Called once from the tweak's
/// %ctor, following the same shape as the other feature modules.
void WCAtlasVirtualLocationInstallHooks(void);

#pragma mark - Saved places

NSArray<NSDictionary<NSString *, id> *> *WCAtlasVirtualLocationPresets(void);
void WCAtlasVirtualLocationAddPreset(NSString *name, CLLocationCoordinate2D coordinate);
void WCAtlasVirtualLocationRemovePresetAtIndex(NSUInteger index);

#pragma mark - Picker feedback

/// Set when the WeChat picker cannot be opened, so the settings row can explain
/// the fallback instead of failing silently.
NSString * _Nullable WCAtlasVirtualLocationPickerNotice(void);
void WCAtlasVirtualLocationSetPickerNotice(NSString * _Nullable notice);

NS_ASSUME_NONNULL_END