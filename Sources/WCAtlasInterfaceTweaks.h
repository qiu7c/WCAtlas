#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString *const WCAtlasChatInputRoundingEnabledKey;
FOUNDATION_EXPORT NSString *const WCAtlasChatInputInnerRoundingKey;
FOUNDATION_EXPORT NSString *const WCAtlasChatInputOuterRoundingKey;
FOUNDATION_EXPORT NSString *const WCAtlasChatInputInnerRadiusKey;
FOUNDATION_EXPORT NSString *const WCAtlasChatInputOuterRadiusKey;
FOUNDATION_EXPORT NSString *const WCAtlasHideChatMuteIconKey;
FOUNDATION_EXPORT NSString *const WCAtlasGlobalAvatarRoundingEnabledKey;
FOUNDATION_EXPORT NSString *const WCAtlasGlobalAvatarCornerPercentKey;

/// Applies rounding to WeChat's real inner avatar image when available, while
/// retaining the head view as the stable lifecycle owner.
FOUNDATION_EXPORT void WCAtlasApplyGlobalAvatarRoundingToHeadView(UIView *headView);
/// Keeps a custom avatar out of the global setting while allowing that view to
/// retain its own independently configured corner style.
FOUNDATION_EXPORT void WCAtlasExcludeHeadViewFromGlobalAvatarRounding(UIView *headView);
FOUNDATION_EXPORT BOOL WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(UIView *headView);
FOUNDATION_EXPORT void WCAtlasRefreshTrackedGlobalAvatarViews(void);
FOUNDATION_EXPORT unsigned int WCAtlasGlobalAvatarScaledCornerSize(unsigned int originalSize);

/// Keeps WCAtlas search bars visually continuous with their containing page and
/// rounds the actual editable field instead of exposing a second square layer.
FOUNDATION_EXPORT void WCAtlasStyleSearchBar(UISearchBar *searchBar);
/// Places the search bar inside the table's scrollable page instead of letting
/// UINavigationBar create a separate full-width search background layer.
FOUNDATION_EXPORT void WCAtlasInstallSearchBarInTableView(UISearchBar *searchBar, UITableView *tableView);

/// Applies or restores WCAtlas's chat input rounding on an existing MMInputToolView.
FOUNDATION_EXPORT void WCAtlasApplyChatInputRoundingToToolView(UIView *inputToolView);
FOUNDATION_EXPORT void WCAtlasRestoreChatInputRoundingFromToolView(UIView *inputToolView);
FOUNDATION_EXPORT void WCAtlasUpdateChatMuteIconVisibility(UIViewController *controller);
FOUNDATION_EXPORT void WCAtlasUpdateChatMuteImageView(UIImageView *imageView);
FOUNDATION_EXPORT void WCAtlasUpdateChatMuteMemberLabel(UILabel *label);
FOUNDATION_EXPORT BOOL WCAtlasShouldForceHideChatMuteImageView(UIImageView *imageView);
/// Fast path for the global UIImageView hook. Returns YES only after WCAtlas has
/// positively identified and taken ownership of the mute icon's hidden state.
FOUNDATION_EXPORT BOOL WCAtlasShouldKeepManagedChatMuteImageViewHidden(UIImageView *imageView);
FOUNDATION_EXPORT BOOL WCAtlasShouldKeepManagedChatMuteMemberLabelHidden(UILabel *label);
