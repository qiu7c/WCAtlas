#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Manual coordinate entry: the fallback path of the virtual location picker.
///
/// It is the part of the feature that never depends on WeChat internals, so it
/// stays usable no matter which WeChat version is installed. Entry is inline
/// rather than alert based because both numbers usually have to be edited
/// together before the coordinate makes sense.
@interface WCAtlasVirtualLocationEditorViewController : WCAtlasCardTableViewController

/// Called after a coordinate was saved or cleared, so the caller can refresh the
/// row it opened this page from.
@property (nonatomic, copy, nullable) void (^onChange)(void);

@end

NS_ASSUME_NONNULL_END