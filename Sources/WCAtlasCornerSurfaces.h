#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds the defaults key for one corner setting of a surface.
/// `name` is `enabled` or `radius`.
NSString *WCAtlasCornerKey(NSString *identifier, NSString *name);

/// Registers the defaults for every surface that ships a usable class today.
void WCAtlasInstallCornerSurfaceDefaults(void);

/// Swizzles the layout entry point of each known surface view and applies its style.
/// Classes listed without a name yet are skipped, as are names WeChat no longer ships.
/// Safe to call more than once; it returns the number of surfaces that were installed.
NSInteger WCAtlasInstallCornerSurfaces(void);

/// Descriptors for the surfaces that are adapted today, for building the settings rows.
/// Each dictionary carries `identifier`, `title`, `subtitle` and `icon`.
NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasCornerSurfaceDescriptors(void);

/// How many surfaces the table lists at all, adapted or not. Shown next to the adapted count so
/// the settings page can say what is missing instead of silently hiding it.
NSUInteger WCAtlasCornerSurfaceTotalCount(void);

NS_ASSUME_NONNULL_END