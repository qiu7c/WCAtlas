#import "WCAtlasSettingsTheme.h"

#pragma mark - Layout

const CGFloat WCAtlasSettingsCornerRadius = 14.0;
const CGFloat WCAtlasSettingsInnerCornerRadius = 12.0;
const CGFloat WCAtlasSettingsBadgeCornerRadius = 8.0;
const CGFloat WCAtlasSettingsCardInsetH = 16.0;
const CGFloat WCAtlasSettingsIconColumnWidth = 24.0;
const CGFloat WCAtlasSettingsIconSize = 17.0;
const CGFloat WCAtlasSettingsIconTitleSpacing = 12.0;
const CGFloat WCAtlasSettingsRowInsetH = 12.0;
const CGFloat WCAtlasSettingsChildIndent = 16.0;
const CGFloat WCAtlasSettingsRowVerticalPadding = 9.0;
const CGFloat WCAtlasSettingsRowMinHeight = 48.0;
const CGFloat WCAtlasSettingsAccessoryTrailing = 16.0;
const CGFloat WCAtlasSettingsAccessorySpacing = 8.0;
const CGFloat WCAtlasSettingsChevronSize = 12.0;
const CGFloat WCAtlasSettingsValueMaxWidth = 132.0;
const CGFloat WCAtlasSettingsSeparatorInsetLeading = 48.0;
const CGFloat WCAtlasSettingsEstimatedRowHeight = 56.0;
const CGFloat WCAtlasSettingsEstimatedSectionHeight = 36.0;
const CGFloat WCAtlasSettingsSectionTopPadding = 16.0;
const CGFloat WCAtlasSettingsSectionBottomPadding = 6.0;
const CGFloat WCAtlasSettingsUntitledSectionHeight = 8.0;
const CGFloat WCAtlasSettingsAvatarSize = 64.0;
const CGFloat WCAtlasSettingsAvatarCornerRadius = 16.0;
const CGFloat WCAtlasSettingsSearchFieldHeight = 44.0;
const CGFloat WCAtlasSettingsCardVerticalMargin = 12.0;
const CGFloat WCAtlasSettingsProfileRowSpacing = 14.0;
const CGFloat WCAtlasSettingsProfileTextSpacing = 4.0;
const CGFloat WCAtlasSettingsProfileSearchSpacing = 12.0;

CGFloat WCAtlasSettingsScale(CGFloat value, CGFloat scale) {
    return value * (scale > 0.0 ? scale : 1.0);
}

#pragma mark - Typography

static UIFont *WCAtlasSettingsFont(UIFontTextStyle style, CGFloat size, CGFloat weight, CGFloat scale) {
    return [[UIFontMetrics metricsForTextStyle:style]
        scaledFontForFont:[UIFont systemFontOfSize:WCAtlasSettingsScale(size, scale) weight:weight]];
}

UIFont *WCAtlasSettingsTitleFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleBody, 17.0, UIFontWeightRegular, scale);
}

UIFont *WCAtlasSettingsSubtitleFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleFootnote, 13.0, UIFontWeightRegular, scale);
}

UIFont *WCAtlasSettingsValueFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleSubheadline, 15.0, UIFontWeightRegular, scale);
}

UIFont *WCAtlasSettingsSectionFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleFootnote, 13.0, UIFontWeightSemibold, scale);
}

UIFont *WCAtlasSettingsBadgeFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleCaption1, 11.0, UIFontWeightSemibold, scale);
}

UIFont *WCAtlasSettingsProfileNameFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleTitle2, 18.0, UIFontWeightSemibold, scale);
}

UIFont *WCAtlasSettingsProfileIdentityFont(CGFloat scale) {
    return WCAtlasSettingsFont(UIFontTextStyleBody, 13.0, UIFontWeightRegular, scale);
}

#pragma mark - Colors

UIColor *WCAtlasSettingsAccentColor(void) {
    // 微信绿 #07C160. One green for switches, primary buttons, sliders and
    // progress instead of the three near-identical literals used before.
    return [UIColor colorWithRed:(7.0 / 255.0) green:(193.0 / 255.0) blue:(96.0 / 255.0) alpha:1.0];
}

UIColor *WCAtlasSettingsIconTintColor(void) {
    return UIColor.secondaryLabelColor;
}

UIColor *WCAtlasSettingsValueColor(void) {
    return UIColor.secondaryLabelColor;
}

UIColor *WCAtlasSettingsSectionTextColor(void) {
    return UIColor.secondaryLabelColor;
}

#pragma mark - Shared primitives

static NSCache<NSString *, UIImage *> *WCAtlasSettingsIconCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSCache new]; });
    return cache;
}

UIImage *WCAtlasSettingsIconImage(NSString *symbolName, CGFloat scale) {
    if (symbolName.length == 0) symbolName = @"circle.grid.2x2";
    CGFloat column = WCAtlasSettingsScale(WCAtlasSettingsIconColumnWidth, scale);
    NSString *key = [NSString stringWithFormat:@"%@|%.2f", symbolName, column];
    UIImage *cached = [WCAtlasSettingsIconCache() objectForKey:key];
    if (cached) return cached;

    // The canvas is exactly the column width and the glyph is centred inside it.
    // SF Symbols have different intrinsic widths (gearshape vs rectangle.3.group),
    // which is what used to make the titles of neighbouring rows drift apart.
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration
        configurationWithPointSize:WCAtlasSettingsScale(WCAtlasSettingsIconSize, scale)
                            weight:UIImageSymbolWeightRegular];
    UIImage *glyph = [UIImage systemImageNamed:symbolName];
    if (!glyph) glyph = [UIImage systemImageNamed:@"circle.grid.2x2"];
    UIImage *tinted = [[glyph imageWithConfiguration:configuration]
        imageWithTintColor:WCAtlasSettingsIconTintColor()
             renderingMode:UIImageRenderingModeAlwaysOriginal];

    CGSize canvas = CGSizeMake(column, column);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvas format:format];
    UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        CGSize glyphSize = tinted.size;
        // Never let a wide glyph exceed the column, otherwise it would be clipped
        // and the shared column width would stop being shared.
        CGFloat fit = MIN(1.0, MIN(canvas.width / MAX(glyphSize.width, 1.0),
                                    canvas.height / MAX(glyphSize.height, 1.0)));
        CGSize drawSize = CGSizeMake(glyphSize.width * fit, glyphSize.height * fit);
        [tinted drawInRect:CGRectMake((canvas.width - drawSize.width) * 0.5,
                                      (canvas.height - drawSize.height) * 0.5,
                                      drawSize.width,
                                      drawSize.height)];
    }];
    if (image) [WCAtlasSettingsIconCache() setObject:image forKey:key];
    return image ?: [UIImage new];
}

UIImageView *WCAtlasSettingsChevronView(NSString *symbolName, CGFloat scale) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration
        configurationWithPointSize:WCAtlasSettingsScale(WCAtlasSettingsChevronSize, scale)
                            weight:UIImageSymbolWeightSemibold];
    UIImageView *chevron = [[UIImageView alloc]
        initWithImage:[[UIImage systemImageNamed:symbolName] imageWithConfiguration:configuration]];
    chevron.tintColor = UIColor.tertiaryLabelColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    return chevron;
}

void WCAtlasSettingsApplyTableStyle(UITableView *tableView, CGFloat scale) {
    if (!tableView) return;
    tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    tableView.separatorColor = UIColor.separatorColor;
    tableView.separatorInset = UIEdgeInsetsMake(0.0,
                                                WCAtlasSettingsScale(WCAtlasSettingsSeparatorInsetLeading, scale),
                                                0.0,
                                                WCAtlasSettingsScale(WCAtlasSettingsAccessoryTrailing, scale));
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = WCAtlasSettingsScale(WCAtlasSettingsEstimatedRowHeight, scale);
    tableView.estimatedSectionHeaderHeight = WCAtlasSettingsScale(WCAtlasSettingsEstimatedSectionHeight, scale);
    tableView.estimatedSectionFooterHeight = WCAtlasSettingsScale(WCAtlasSettingsEstimatedSectionHeight, scale);
    tableView.cellLayoutMarginsFollowReadableWidth = NO;
}

// A header that lays its title out from the shared tokens. It deliberately uses
// only long standing API (a plain label inside contentView) and set frames in
// -layoutSubviews, so the padding can follow the settings page scale without
// rebuilding constraints.
@interface WCAtlasSettingsSectionHeader : UITableViewHeaderFooterView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGFloat scale;
@end

@implementation WCAtlasSettingsSectionHeader

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        // Stay transparent so the page background shows through, as the system
        // header did before this one replaced it.
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        _titleLabel = [UILabel new];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = WCAtlasSettingsScale(WCAtlasSettingsCardInsetH, self.scale);
    CGFloat top = WCAtlasSettingsScale(WCAtlasSettingsSectionTopPadding, self.scale);
    CGFloat height = ceil(self.titleLabel.font.lineHeight);
    CGFloat width = MAX(0.0, self.contentView.bounds.size.width - inset * 2.0);
    self.titleLabel.frame = CGRectMake(inset, top, width, height);
}

- (void)setScale:(CGFloat)scale {
    _scale = scale;
    [self setNeedsLayout];
}

@end

UITableViewHeaderFooterView *WCAtlasSettingsSectionHeaderView(UITableView *tableView,
                                                              NSString *title,
                                                              CGFloat scale) {
    if (title.length == 0) return nil;
    static NSString *const identifier = @"WCAtlasSettingsSectionHeader";
    WCAtlasSettingsSectionHeader *header =
        (WCAtlasSettingsSectionHeader *)[tableView dequeueReusableHeaderFooterViewWithIdentifier:identifier];
    if (!header) header = [[WCAtlasSettingsSectionHeader alloc] initWithReuseIdentifier:identifier];
    header.scale = scale;
    header.titleLabel.font = WCAtlasSettingsSectionFont(scale);
    header.titleLabel.textColor = WCAtlasSettingsSectionTextColor();
    header.titleLabel.text = title;
    [header setNeedsLayout];
    return header;
}

CGFloat WCAtlasSettingsSectionHeaderHeight(NSString *title, CGFloat scale) {
    if (title.length == 0) return WCAtlasSettingsScale(WCAtlasSettingsUntitledSectionHeight, scale);
    CGFloat lineHeight = ceil(WCAtlasSettingsSectionFont(scale).lineHeight);
    return lineHeight +
        WCAtlasSettingsScale(WCAtlasSettingsSectionTopPadding, scale) +
        WCAtlasSettingsScale(WCAtlasSettingsSectionBottomPadding, scale);
}