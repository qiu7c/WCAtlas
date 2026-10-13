#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Single source of truth for the geometry of every WCAtlas settings surface.
//
// Rows, cards, accessories and the profile header all measure themselves from
// these values so alignment holds by construction instead of being re-derived
// (and drifting) per page. Every metric is expressed at scale 1.0 and must be
// passed through WCAtlasSettingsScale() so the user facing 设置页缩放 keeps
// working.

#pragma mark - Layout

/// Corner radius of a grouped card surface (and the profile card).
extern const CGFloat WCAtlasSettingsCornerRadius;
/// Corner radius of an inner surface such as the profile search field.
extern const CGFloat WCAtlasSettingsInnerCornerRadius;
/// Corner radius of the identity badge.
extern const CGFloat WCAtlasSettingsBadgeCornerRadius;
/// Horizontal distance from the table edge to a card.
extern const CGFloat WCAtlasSettingsCardInsetH;
/// Width reserved for the leading icon column. Fixed, so titles line up.
extern const CGFloat WCAtlasSettingsIconColumnWidth;
/// Point size of the glyph drawn centred inside that column.
extern const CGFloat WCAtlasSettingsIconSize;
/// Gap between the icon column and the title.
extern const CGFloat WCAtlasSettingsIconTitleSpacing;
/// Left and right content inset inside a card.
extern const CGFloat WCAtlasSettingsRowInsetH;
/// Extra leading indent applied to a nested (child) row.
extern const CGFloat WCAtlasSettingsChildIndent;
/// Vertical padding above and below a row's content.
extern const CGFloat WCAtlasSettingsRowVerticalPadding;
/// Floor for a row's height so compact single line rows do not collapse.
extern const CGFloat WCAtlasSettingsRowMinHeight;
/// Trailing inset shared by every accessory so right edges line up.
extern const CGFloat WCAtlasSettingsAccessoryTrailing;
/// Gap between two stacked accessory parts (value + chevron, switch + chevron).
extern const CGFloat WCAtlasSettingsAccessorySpacing;
/// Rendered size of a disclosure chevron.
extern const CGFloat WCAtlasSettingsChevronSize;
/// Upper bound for a trailing value label before it truncates.
extern const CGFloat WCAtlasSettingsValueMaxWidth;
/// Separator start, aligned with the title's left edge (row inset + icon column + gap).
extern const CGFloat WCAtlasSettingsSeparatorInsetLeading;
/// Estimated row height handed to the table view.
extern const CGFloat WCAtlasSettingsEstimatedRowHeight;
/// Estimated section header and footer height handed to the table view.
extern const CGFloat WCAtlasSettingsEstimatedSectionHeight;
/// Padding above a section title, inside the header view.
extern const CGFloat WCAtlasSettingsSectionTopPadding;
/// Padding below a section title, inside the header view.
extern const CGFloat WCAtlasSettingsSectionBottomPadding;
/// Height used by an untitled section so the first card sits close to the top.
extern const CGFloat WCAtlasSettingsUntitledSectionHeight;
/// Edge length of the profile avatar.
extern const CGFloat WCAtlasSettingsAvatarSize;
/// Corner radius of the profile avatar.
extern const CGFloat WCAtlasSettingsAvatarCornerRadius;
/// Height of the profile search field.
extern const CGFloat WCAtlasSettingsSearchFieldHeight;
/// Space above and below a header card.
extern const CGFloat WCAtlasSettingsCardVerticalMargin;
/// Gap between the avatar column and the profile text column.
extern const CGFloat WCAtlasSettingsProfileRowSpacing;
/// Gap between the nickname row and the identity line under it.
extern const CGFloat WCAtlasSettingsProfileTextSpacing;
/// Gap between the profile row and the search field inside the same card.
extern const CGFloat WCAtlasSettingsProfileSearchSpacing;

/// Applies the settings page scale to one metric.
CGFloat WCAtlasSettingsScale(CGFloat value, CGFloat scale);

#pragma mark - Typography

UIFont *WCAtlasSettingsTitleFont(CGFloat scale);
UIFont *WCAtlasSettingsSubtitleFont(CGFloat scale);
UIFont *WCAtlasSettingsValueFont(CGFloat scale);
UIFont *WCAtlasSettingsSectionFont(CGFloat scale);
UIFont *WCAtlasSettingsBadgeFont(CGFloat scale);
UIFont *WCAtlasSettingsProfileNameFont(CGFloat scale);
UIFont *WCAtlasSettingsProfileIdentityFont(CGFloat scale);

#pragma mark - Colors

UIColor *WCAtlasSettingsAccentColor(void);
UIColor *WCAtlasSettingsIconTintColor(void);
UIColor *WCAtlasSettingsValueColor(void);
UIColor *WCAtlasSettingsSectionTextColor(void);

#pragma mark - Shared primitives

/// Fixed size leading icon: the glyph is centred on a transparent canvas of
/// exactly WCAtlasSettingsIconColumnWidth, so every row reserves the same
/// leading width and all titles start together.
UIImage *WCAtlasSettingsIconImage(NSString *symbolName, CGFloat scale);

/// Disclosure chevron drawn at the shared size with the shared colour.
UIImageView *WCAtlasSettingsChevronView(NSString *symbolName, CGFloat scale);

/// Applies the shared page background, separator and height estimates.
void WCAtlasSettingsApplyTableStyle(UITableView *tableView, CGFloat scale);

/// Section header built from the shared tokens. Returns nil for an untitled
/// section so the caller can collapse it to WCAtlasSettingsUntitledSectionHeight.
UITableViewHeaderFooterView *WCAtlasSettingsSectionHeaderView(UITableView *tableView,
                                                              NSString *title,
                                                              CGFloat scale);

/// Matching height for WCAtlasSettingsSectionHeaderView.
CGFloat WCAtlasSettingsSectionHeaderHeight(NSString *title, CGFloat scale);

NS_ASSUME_NONNULL_END