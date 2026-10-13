#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Feature key for the black back item. Registered as ON, because the blue
/// system back item is the default this tweak exists to remove.
FOUNDATION_EXPORT NSString *const WCAtlasBlackBackItemKey;

/// The colour of every back chevron our pages draw.
///
/// Pure black on purpose: the system default is the blue navigation bar tint,
/// which is exactly what these bars should not show. This is the single token to
/// change if the arrow should follow the interface style instead.
FOUNDATION_EXPORT UIColor *WCAtlasBackChevronColor(void);

/// A pure black chevron, drawn rather than tinted.
///
/// A navigation bar renders the back indicator by tinting its alpha, so an image
/// that is merely drawn in black would still come out blue. Marking the image as
/// original keeps the colour it was drawn with.
FOUNDATION_EXPORT UIImage *WCAtlasBackChevronImage(void);

/// YES only for view controllers this tweak owns.
///
/// The prefix check is what keeps WeChat's own navigation bars untouched: the
/// system back item there is WeChat's to style, not ours.
FOUNDATION_EXPORT BOOL WCAtlasNavigationAppearanceIsOwnedViewController(UIViewController * _Nullable controller);

/// Makes a bar show nothing but our chevron.
///
/// The display mode is set on the item, so a navigation controller we do not own
/// keeps its own configuration. The chevron image is a bar property and is
/// therefore swapped on the bar itself, which is why it has to be handed back in
/// WCAtlasRestoreBackButtonStyle. Does nothing when the feature is switched off.
FOUNDATION_EXPORT void WCAtlasApplyBackButtonStyle(UINavigationBar * _Nullable bar, UINavigationItem *item);

/// Hands the bar's chevron back to the system.
///
/// Safe to call from any page and more than once: it only clears the image while
/// that image is still the one this file installed.
FOUNDATION_EXPORT void WCAtlasRestoreBackButtonStyle(UINavigationBar * _Nullable bar);

/// Styles the back item of every page this tweak owns.
///
/// Pages that already inherit WCAtlasCardTableViewController style themselves,
/// which covers the two WCP prefixed editors; this hook is what reaches the pages
/// that do not share that base. Called once from the tweak's %ctor.
FOUNDATION_EXPORT void WCAtlasNavigationAppearanceInstallHooks(void);

NS_ASSUME_NONNULL_END