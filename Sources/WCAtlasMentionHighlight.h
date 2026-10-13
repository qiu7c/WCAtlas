#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Enables group-chat mention highlighting and profile navigation.
FOUNDATION_EXPORT NSString *const WCAtlasMentionHighlightEnabledKey;

/// Installs ABI-checked hooks for WeChat's rich-text style and link event methods.
/// @discussion Safe to call once during tweak construction. Unsupported WeChat versions are
/// left untouched when the required classes, selectors, or complete method ABI are unavailable.
FOUNDATION_EXPORT void WCAtlasMentionHighlightInstallHooks(void);

NS_ASSUME_NONNULL_END
