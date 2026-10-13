#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Refreshes both optional per-message time labels without forcing a layout pass.
FOUNDATION_EXPORT void WCAtlasScheduleMessageTimeRefresh(UIView *cell);
FOUNDATION_EXPORT void WCAtlasHideMessageTimeLabels(UIView *cell);
/// Repositions the labels synchronously after the native message cell has
/// completed its own layout pass.
FOUNDATION_EXPORT void WCAtlasLayoutMessageTimeLabels(UIView *cell);
/// Shared lightweight message anchor used by message-time and anti-revoke
/// side labels. It never scans the complete private view hierarchy.
FOUNDATION_EXPORT UIView * _Nullable WCAtlasMessageSideAnchorView(UIView *cell);
/// WeChat represents an oversized text message as several
/// TextMessageSubViewModel instances. Returns YES only for the head or tail
/// segment selected to own per-message metadata; ordinary messages return YES.
FOUNDATION_EXPORT BOOL WCAtlasShouldShowSplitMessageMetadata(id _Nullable viewModel,
                                                             BOOL preferHeadPart);
/// Returns the currently visible bubble-side time label, if any. This lets
/// other per-message annotations avoid occupying the same frame.
FOUNDATION_EXPORT UILabel * _Nullable WCAtlasVisibleMessageTimeSideLabel(UIView *cell);

NS_ASSUME_NONNULL_END
