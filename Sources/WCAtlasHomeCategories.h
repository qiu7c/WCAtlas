#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const WCAtlasHomeCategoriesEnabledKey;
FOUNDATION_EXPORT NSString *const WCAtlasHomeCategoriesDataKey;

/// Rebuilds WCAtlas category entries inside WeChat's native homepage session array.
/// @param sessionManager The live `MainSessionMgr` instance currently rebuilding its sessions.
/// @discussion Main-thread only. Each first-level category becomes one synthetic native session;
/// assigned conversations are removed from the root list. Unsupported native models are ignored.
FOUNDATION_EXPORT void WCAtlasHomeCategoriesApplyToSessionManager(id _Nullable sessionManager);

/// Handles a tap on a WCAtlas synthetic category session.
/// @param controller Native homepage controller used for navigation.
/// @param tableView Native homepage table used as a session lookup fallback.
/// @param indexPath Selected native index path.
/// @return YES when the row is a WCAtlas category and the category page was pushed.
FOUNDATION_EXPORT BOOL WCAtlasHomeCategoriesHandleSelection(id _Nullable controller,
                                                            UITableView * _Nullable tableView,
                                                            NSIndexPath * _Nullable indexPath);

/// Builds the safe leading-swipe actions for a synthetic homepage category.
/// @param controller Native homepage controller or table delegate used to present rename/avatar UI.
/// @param tableView Native homepage table used to resolve the row's session model.
/// @param indexPath Candidate homepage row.
/// @return A configuration containing rename and avatar actions for a WCAtlas category, or nil when
/// the row is native, input is incomplete, or the current WeChat version cannot resolve its model.
/// @discussion Main-thread only. The actions update WCAtlas-owned defaults and its local avatar
/// directory, and never invoke native session mutation selectors. Unsupported native row models
/// return nil so WeChat's original behavior can be preserved.
FOUNDATION_EXPORT UISwipeActionsConfiguration * _Nullable
WCAtlasHomeCategoriesLeadingSwipeActions(id _Nullable controller,
                                         UITableView * _Nullable tableView,
                                         NSIndexPath * _Nullable indexPath);

/// Returns whether a username belongs to a WCAtlas synthetic category session.
/// @param userName Candidate native session username.
/// @return YES only for WCAtlas's reserved category prefix; nil and native usernames return NO.
/// @discussion Thread-safe and pure. This performs no native call and has no version fallback.
FOUNDATION_EXPORT BOOL WCAtlasHomeCategoriesIsSyntheticUserName(NSString * _Nullable userName);

/// Returns whether a native selection-list object represents a WCAtlas synthetic category.
/// @param object A contact, session, cell-data wrapper, or nil supplied by WeChat's selection UI.
/// @return YES only when the object's resolved username uses WCAtlas's reserved category prefix.
/// @discussion Main-thread only. Username extraction is delegated to `WCAtlasPrivateAPI`; unresolved and
/// native objects return NO, so unsupported WeChat versions preserve their original list contents.
FOUNDATION_EXPORT BOOL WCAtlasHomeCategoriesShouldFilterSelectionObject(id _Nullable object);

/// Removes WCAtlas synthetic categories from a native selection-list array.
/// @param objects Native contacts or session wrappers, or nil.
/// @return The original value when it is not an array or contains no synthetic item; otherwise a
/// filtered array preserving order and object identity for every native entry.
/// @discussion Main-thread only. Intended for forwarding/recent-target lists only; it does not mutate
/// WeChat's source array and falls back to the original value when models cannot be resolved.
FOUNDATION_EXPORT id _Nullable WCAtlasHomeCategoriesFilterSelectionObjects(id _Nullable objects);

/// Returns the locally generated folder image used by synthetic homepage avatar views.
/// @discussion Main-thread UI helper. The image contains no account or conversation data.
FOUNDATION_EXPORT UIImage *WCAtlasHomeCategoryIconImage(void);

/// Returns the configured local-file avatar for a synthetic homepage category, falling back to the
/// generated folder icon when the category has no custom image or its original file cannot be read.
/// @param userName Synthetic category username; native and nil usernames receive the default icon.
/// @discussion Main-thread UI helper. It reads only WCAtlas-owned defaults and performs no native call.
FOUNDATION_EXPORT UIImage *WCAtlasHomeCategoryIconImageForUserName(NSString * _Nullable userName);

/// Restores the configured title, empty secondary line, and folder avatar after WeChat formats a
/// synthetic category cell.
/// @param cellData Native `MainFrameCellData` after an original formatting method returns.
/// @discussion Main-thread only. Non-category and unsupported models are left unchanged; native
/// field access is delegated to `WCAtlasPrivateAPI` and failure preserves WeChat's original text.
FOUNDATION_EXPORT void WCAtlasHomeCategoriesConfigureCellData(id _Nullable cellData);

/// Lays out WCAtlas's numeric unread badge over a synthetic category's homepage avatar.
/// @param itemView Native `MainFrameItemView` after its original layout has completed.
/// @discussion Main-thread only. Native rows and zero-count categories hide the WCAtlas-owned
/// badge. The view is reused across scrolling and clamps counts above 99 to `99+`; unsupported
/// view hierarchies fail closed without changing WeChat's native unread view.
FOUNDATION_EXPORT void WCAtlasHomeCategoriesLayoutUnreadBadge(UIView * _Nullable itemView);

/// Settings controller for first-level categories, nested folders, and conversation assignments.
@interface WCAtlasHomeCategoriesViewController : UITableViewController
@end

NS_ASSUME_NONNULL_END
