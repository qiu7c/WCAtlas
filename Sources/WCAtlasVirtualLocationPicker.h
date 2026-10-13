#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Opens WeChat's own map picker so a coordinate can be chosen on a real map.
///
/// Returns NO when this WeChat build no longer has the picker, its initializer or
/// a place to present it from, which is the signal for the caller to fall back to
/// manual entry. Nothing here is required for the feature to work: the spoof
/// itself never depends on WeChat internals.
///
/// `onFinish` runs once the picker is gone, so the page underneath can refresh.
FOUNDATION_EXPORT NSString *WCAtlasVirtualLocationPickerTraceText(void);

FOUNDATION_EXPORT BOOL WCAtlasVirtualLocationPresentWeChatPicker(UIViewController * _Nullable fromViewController,
                                               void (^ _Nullable onFinish)(void));

NS_ASSUME_NONNULL_END