#import "WCAtlasSettingsUI.h"
#import "WCAtlasIdentityBadge.h"
#import "WCAtlasAccount.h"
#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasSettingsTheme.h"
#import <math.h>

// The gap between the fixed icon column and the title. UIListContentConfiguration
// is expected to expose imageToTextPadding, but it is applied through KVC and
// only when the property is really there, so the tweak still builds and runs if a
// given SDK does not declare it. Losing it only shifts the separator a few
// points; the icon column itself stays exactly one width wide either way.
static void WCAtlasSettingsApplyIconTitleSpacing(UIListContentConfiguration *content, CGFloat spacing) {
    if ([content respondsToSelector:NSSelectorFromString(@"setImageToTextPadding:")]) {
        [content setValue:@(spacing) forKey:@"imageToTextPadding"];
    }
}

static UIView *WCAtlasSettingsDetailAccessory(NSString *valueText, CGFloat scale) {
    CGFloat spacing = valueText.length > 0 ? WCAtlasSettingsScale(WCAtlasSettingsAccessorySpacing, scale) : 0.0;
    CGFloat chevronWidth = WCAtlasSettingsScale(WCAtlasSettingsChevronSize, scale);
    UILabel *value = nil;
    CGFloat valueWidth = 0.0;
    CGFloat valueHeight = 0.0;
    if (valueText.length > 0) {
        value = [UILabel new];
        value.text = valueText;
        value.font = WCAtlasSettingsValueFont(scale);
        value.adjustsFontForContentSizeCategory = YES;
        value.textColor = WCAtlasSettingsValueColor();
        value.textAlignment = NSTextAlignmentRight;
        value.adjustsFontSizeToFitWidth = YES;
        value.minimumScaleFactor = 0.75;
        // Measure without a height bound. The old code clamped the measurement to
        // a fixed 32pt box, so a raised Dynamic Type size clipped the value.
        CGSize measured = [value sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        valueWidth = MIN(WCAtlasSettingsScale(WCAtlasSettingsValueMaxWidth, scale), ceil(measured.width));
        valueHeight = MAX(ceil(value.font.lineHeight), ceil(measured.height));
    }
    UIImageView *chevron = WCAtlasSettingsChevronView(@"chevron.right", scale);
    CGFloat chevronHeight = ceil(chevron.intrinsicContentSize.height);
    CGFloat height = MAX(valueHeight, MAX(chevronHeight, chevronWidth));
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                 valueWidth + spacing + chevronWidth,
                                                                 height)];
    if (value) {
        value.frame = CGRectMake(0.0, floor((height - valueHeight) * 0.5), valueWidth, valueHeight);
        [container addSubview:value];
    }
    chevron.frame = CGRectMake(valueWidth + spacing,
                               floor((height - chevronHeight) * 0.5),
                               chevronWidth,
                               chevronHeight);
    [container addSubview:chevron];
    return container;
}

static UIView *WCAtlasSettingsSwitchAccessory(UISwitch *toggle, BOOL expanded, BOOL hasChildren, CGFloat scale) {
    [toggle sizeToFit];
    CGFloat chevronWidth = WCAtlasSettingsScale(WCAtlasSettingsChevronSize, scale);
    CGFloat spacing = WCAtlasSettingsScale(WCAtlasSettingsAccessorySpacing, scale);
    CGFloat toggleWidth = toggle.bounds.size.width;
    CGFloat toggleHeight = toggle.bounds.size.height;
    CGFloat height = MAX(toggleHeight, chevronWidth);
    // The chevron slot is reserved for every switch row, not only expandable
    // ones, so all switches share one right edge. A row without children keeps
    // the slot at alpha 0 instead of omitting it.
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                 chevronWidth + spacing + toggleWidth,
                                                                 height)];
    UIImageView *chevron = WCAtlasSettingsChevronView(expanded ? @"chevron.down" : @"chevron.right", scale);
    chevron.alpha = hasChildren ? (toggle.isOn ? 1.0 : 0.3) : 0.0;
    chevron.frame = CGRectMake(0.0,
                               floor((height - chevron.intrinsicContentSize.height) * 0.5),
                               chevronWidth,
                               ceil(chevron.intrinsicContentSize.height));
    toggle.frame = CGRectMake(chevronWidth + spacing,
                              floor((height - toggleHeight) * 0.5),
                              toggleWidth,
                              toggleHeight);
    [container addSubview:chevron];
    [container addSubview:toggle];
    return container;
}

@interface WCAtlasSettingsCell ()
@property (nonatomic, strong) WCAtlasSettingItem *settingItem;
@property (nonatomic, copy) WCAtlasSettingsSwitchHandler switchHandler;
@end

@implementation WCAtlasSettingsCell

- (void)prepareForReuse {
    [super prepareForReuse];
    self.settingItem = nil;
    self.switchHandler = nil;
    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessibilityHint = nil;
}

- (void)toggleChanged:(UISwitch *)sender {
    if (self.switchHandler && self.settingItem) self.switchHandler(self.settingItem, sender.isOn);
}

- (void)configureWithItem:(WCAtlasSettingItem *)item
            masterEnabled:(BOOL)masterEnabled
                 expanded:(BOOL)expanded
                showsIcon:(BOOL)showsIcon
                     scale:(CGFloat)scale
            switchHandler:(WCAtlasSettingsSwitchHandler)switchHandler {
    self.settingItem = item;
    self.switchHandler = switchHandler;
    // Card colour and corner radius come from WCAtlasCardTableViewController's
    // willDisplayCell:, which runs after this call and clears the cell's own
    // background. Staying clear here keeps a single source for the card surface.
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessibilityHint = nil;

    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = item.title;
    content.secondaryText = item.subtitle;
    content.textProperties.font = WCAtlasSettingsTitleFont(scale);
    content.textProperties.adjustsFontForContentSizeCategory = YES;
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.font = WCAtlasSettingsSubtitleFont(scale);
    content.secondaryTextProperties.adjustsFontForContentSizeCategory = YES;
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    content.secondaryTextProperties.numberOfLines = 0;
    content.image = showsIcon ? WCAtlasSettingsIconImage(item.symbol, scale) : nil;
    content.imageProperties.tintColor = WCAtlasSettingsIconTintColor();
    CGSize iconColumn = CGSizeMake(WCAtlasSettingsScale(WCAtlasSettingsIconColumnWidth, scale),
                                   WCAtlasSettingsScale(WCAtlasSettingsIconColumnWidth, scale));
    content.imageProperties.maximumSize = iconColumn;
    WCAtlasSettingsApplyIconTitleSpacing(content, WCAtlasSettingsScale(WCAtlasSettingsIconTitleSpacing, scale));
    CGFloat leading = WCAtlasSettingsRowContentLeading(item.child, scale);
    CGFloat vertical = WCAtlasSettingsScale(WCAtlasSettingsRowVerticalPadding, scale);
    CGFloat trailing = WCAtlasSettingsScale(WCAtlasSettingsAccessoryTrailing, scale);
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(vertical, leading, vertical, trailing);
    self.contentConfiguration = content;
    // A row without an icon starts its text one icon column earlier, so the
    // separator has to be set per row rather than once on the table.
    self.separatorInset = UIEdgeInsetsMake(0.0,
                                           WCAtlasSettingsSeparatorInsetLeading(showsIcon, item.child, scale),
                                           0.0,
                                           trailing);
    WCAtlasSettingsApplyMinimumRowHeight(self, scale);

    if (item.kind == WCAtlasSettingRowKindSwitch) {
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = WCAtlasSettingsAccentColor();
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:item.defaultsKey];
        toggle.enabled = [item.defaultsKey isEqualToString:WCAtlasEnabledKey] || masterEnabled;
        toggle.accessibilityLabel = item.title;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        // Both branches reserve the same chevron slot, so switches of expandable
        // and plain rows share one right edge.
        self.accessoryView = WCAtlasSettingsSwitchAccessory(toggle, expanded, item.hasChildren, scale);
        if (item.hasChildren) {
            self.selectionStyle = toggle.isOn ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            self.accessibilityHint = toggle.isOn ? (expanded ? @"轻点收起子选项" : @"轻点展开子选项") : nil;
        } else {
            self.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (item.kind == WCAtlasSettingRowKindDetail) {
        self.accessoryView = WCAtlasSettingsDetailAccessory(item.value, scale);
    } else if (item.value.length > 0) {
        UILabel *value = [UILabel new];
        value.text = item.value;
        value.font = WCAtlasSettingsValueFont(scale);
        value.adjustsFontForContentSizeCategory = YES;
        value.textColor = WCAtlasSettingsValueColor();
        value.textAlignment = NSTextAlignmentRight;
        value.lineBreakMode = NSLineBreakByTruncatingTail;
        // A bare label as the accessory view right-aligns to the same trailing
        // inset as every other accessory.
        self.accessoryView = value;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
}

@end

@interface WCAtlasSettingsProfileHeaderView () <UIGestureRecognizerDelegate>
@property (nonatomic, copy, readwrite) NSString *wxid;
@property (nonatomic, strong) UIView *capsuleView;
@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIStackView *identityRow;
@property (nonatomic, strong) UITapGestureRecognizer *profileTapGesture;
@property (nonatomic, strong) UILabel *wxidLabel;
@property (nonatomic, strong) UIView *searchCapsuleView;
@property (nonatomic, weak) UISearchBar *embeddedSearchBar;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *searchBarConstraints;
// The card is laid out with stack views so its height comes from its content
// instead of the two magic totals (104 / 154) the previous version returned.
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *profileRow;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIView *avatarContentView;
@property (nonatomic, copy) NSString *appliedAvatarWXID;
@property (nonatomic, copy) NSString *appliedHeadURL;
- (void)applyProfileWithWXID:(nullable NSString *)wxid
                    nickname:(nullable NSString *)nickname
                     headURL:(nullable NSString *)headURL;
- (void)applyIdentityBadge:(nullable WCAtlasIdentityBadge *)badge;
@end

@interface WCAtlasIdentityBadgeLabel : UILabel
@end

@implementation WCAtlasIdentityBadgeLabel

- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(2.0, 6.0, 2.0, 6.0))];
}

- (CGSize)intrinsicContentSize {
    CGSize size = super.intrinsicContentSize;
    return CGSizeMake(size.width + 12.0, size.height + 4.0);
}

@end

static UIColor *WCAtlasIdentityBadgeColor(NSString *code) {
    NSString *hex = [[code ?: @"" stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (hex.length == 3) {
        unichar characters[6];
        for (NSUInteger index = 0; index < 3; index++) {
            unichar value = [hex characterAtIndex:index];
            characters[index * 2] = value;
            characters[index * 2 + 1] = value;
        }
        hex = [NSString stringWithCharacters:characters length:6];
    }
    if (hex.length != 6 && hex.length != 8) return nil;
    unsigned long long value = 0;
    if (![[NSScanner scannerWithString:hex] scanHexLongLong:&value]) return nil;
    CGFloat red = ((value >> (hex.length == 8 ? 24 : 16)) & 0xFF) / 255.0;
    CGFloat green = ((value >> (hex.length == 8 ? 16 : 8)) & 0xFF) / 255.0;
    CGFloat blue = ((value >> (hex.length == 8 ? 8 : 0)) & 0xFF) / 255.0;
    CGFloat alpha = hex.length == 8 ? (value & 0xFF) / 255.0 : 1.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@implementation WCAtlasSettingsProfileHeaderView

static void WCAtlasHideSearchBarBackground(UIView *view) {
    NSString *className = NSStringFromClass(view.class);
    if ([className isEqualToString:@"UISearchBarBackground"] ||
        [className isEqualToString:@"_UISearchBarBackground"] ||
        [className isEqualToString:@"_UITextFieldImageBackgroundView"]) {
        view.hidden = YES;
        view.alpha = 0.0;
        view.backgroundColor = UIColor.clearColor;
    }
    for (UIView *subview in view.subviews) WCAtlasHideSearchBarBackground(subview);
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    _capsuleView = [UIView new];
    _capsuleView.translatesAutoresizingMaskIntoConstraints = NO;
    _capsuleView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    _capsuleView.layer.cornerRadius = WCAtlasSettingsCornerRadius;
    _capsuleView.layer.cornerCurve = kCACornerCurveContinuous;
    _capsuleView.userInteractionEnabled = YES;
    [self addSubview:_capsuleView];

    _profileTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(profileAreaTapped)];
    _profileTapGesture.delegate = self;
    [_capsuleView addGestureRecognizer:_profileTapGesture];

    _nicknameLabel = [UILabel new];
    _nicknameLabel.font = WCAtlasSettingsProfileNameFont(1.0);
    _nicknameLabel.adjustsFontForContentSizeCategory = YES;
    _nicknameLabel.numberOfLines = 1;
    _nicknameLabel.textAlignment = NSTextAlignmentLeft;
    _nicknameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _badgeLabel = [WCAtlasIdentityBadgeLabel new];
    _badgeLabel.font = WCAtlasSettingsBadgeFont(1.0);
    _badgeLabel.adjustsFontForContentSizeCategory = YES;
    _badgeLabel.layer.cornerRadius = WCAtlasSettingsBadgeCornerRadius;
    _badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    _badgeLabel.layer.masksToBounds = YES;
    _badgeLabel.hidden = YES;
    _badgeLabel.userInteractionEnabled = YES;
    [_badgeLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(badgeTapped)]];
    [_badgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisHorizontal];
    // The badge must never stretch: it stays exactly as wide as its own text.
    [_badgeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                   forAxis:UILayoutConstraintAxisHorizontal];
    [_nicknameLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                      forAxis:UILayoutConstraintAxisHorizontal];

    // This spacer absorbs the slack of the fill aligned column above. Without it
    // that slack is handed to whichever arranged subview hugs least, which pushed
    // the badge to the far right and stretched it.
    UIView *identitySpacer = [UIView new];
    [identitySpacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [identitySpacer setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisHorizontal];

    _identityRow = [[UIStackView alloc] initWithArrangedSubviews:@[_nicknameLabel, _badgeLabel, identitySpacer]];
    _identityRow.axis = UILayoutConstraintAxisHorizontal;
    _identityRow.alignment = UIStackViewAlignmentCenter;
    _identityRow.spacing = WCAtlasSettingsAccessorySpacing;

    _wxidLabel = [UILabel new];
    _wxidLabel.font = WCAtlasSettingsProfileIdentityFont(1.0);
    _wxidLabel.adjustsFontForContentSizeCategory = YES;
    _wxidLabel.textColor = UIColor.secondaryLabelColor;
    _wxidLabel.textAlignment = NSTextAlignmentLeft;
    _wxidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    // The avatar container exists from the start, so the row never has to be
    // rebuilt when account values arrive; only its content image is swapped.
    _avatarView = [UIView new];
    _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = WCAtlasSettingsAvatarCornerRadius;
    _avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    [_avatarView.widthAnchor constraintEqualToConstant:WCAtlasSettingsAvatarSize].active = YES;
    [_avatarView.heightAnchor constraintEqualToConstant:WCAtlasSettingsAvatarSize].active = YES;

    _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_identityRow, _wxidLabel]];
    _textStack.translatesAutoresizingMaskIntoConstraints = NO;
    _textStack.axis = UILayoutConstraintAxisVertical;
    // Fill rather than leading: the identity line stretches to the column width
    // and truncates, instead of its intrinsic width pushing the card wider.
    _textStack.alignment = UIStackViewAlignmentFill;
    _textStack.spacing = WCAtlasSettingsProfileTextSpacing;

    _profileRow = [[UIStackView alloc] initWithArrangedSubviews:@[_avatarView, _textStack]];
    _profileRow.axis = UILayoutConstraintAxisHorizontal;
    _profileRow.alignment = UIStackViewAlignmentCenter;
    _profileRow.spacing = WCAtlasSettingsProfileRowSpacing;

    _contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[_profileRow]];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.spacing = WCAtlasSettingsProfileSearchSpacing;
    [_capsuleView addSubview:_contentStack];

    CGFloat inset = WCAtlasSettingsCardInsetH;
    CGFloat margin = WCAtlasSettingsCardVerticalMargin;
    [NSLayoutConstraint activateConstraints:@[
        [_capsuleView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset],
        [_capsuleView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset],
        [_capsuleView.topAnchor constraintEqualToAnchor:self.topAnchor constant:margin],
        [_capsuleView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-margin],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_capsuleView.leadingAnchor constant:inset],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_capsuleView.trailingAnchor constant:-inset],
        [_contentStack.topAnchor constraintEqualToAnchor:_capsuleView.topAnchor constant:inset],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_capsuleView.bottomAnchor constant:-inset],
    ]];

    // Account values are persisted. Apply them before the header first appears
    // so it never renders an empty placeholder frame.
    [self refreshProfile];
    return self;
}

- (void)embedSearchBar:(UISearchBar *)searchBar {
    if (!searchBar || self.embeddedSearchBar == searchBar) return;
    [NSLayoutConstraint deactivateConstraints:self.searchBarConstraints ?: @[]];
    [self.embeddedSearchBar removeFromSuperview];
    self.embeddedSearchBar = searchBar;
    searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.backgroundColor = UIColor.clearColor;
    searchBar.barTintColor = UIColor.clearColor;
    searchBar.backgroundImage = [UIImage new];
    if (@available(iOS 13.0, *)) {
        UITextField *textField = searchBar.searchTextField;
        textField.background = nil;
        textField.backgroundColor = UIColor.clearColor;
        textField.borderStyle = UITextBorderStyleNone;
        textField.layer.backgroundColor = UIColor.clearColor.CGColor;
    }

    if (!self.searchCapsuleView) {
        // The search field lives inside the profile card, so the card simply
        // grows by one arranged subview instead of a second card being
        // positioned underneath it with a hard coded height.
        self.searchCapsuleView = [UIView new];
        self.searchCapsuleView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.searchCapsuleView.layer.cornerRadius = WCAtlasSettingsInnerCornerRadius;
        self.searchCapsuleView.layer.cornerCurve = kCACornerCurveContinuous;
        self.searchCapsuleView.layer.masksToBounds = YES;
        [self.searchCapsuleView.heightAnchor
            constraintEqualToConstant:WCAtlasSettingsSearchFieldHeight].active = YES;
        [self.contentStack addArrangedSubview:self.searchCapsuleView];
        self.contentStack.spacing = WCAtlasSettingsProfileSearchSpacing;
    }
    [self.searchCapsuleView addSubview:searchBar];
    self.searchBarConstraints = @[
        [searchBar.leadingAnchor constraintEqualToAnchor:self.searchCapsuleView.leadingAnchor constant:8.0],
        [searchBar.trailingAnchor constraintEqualToAnchor:self.searchCapsuleView.trailingAnchor constant:-8.0],
        [searchBar.topAnchor constraintEqualToAnchor:self.searchCapsuleView.topAnchor constant:2.0],
        [searchBar.bottomAnchor constraintEqualToAnchor:self.searchCapsuleView.bottomAnchor constant:-2.0],
    ];
    [NSLayoutConstraint activateConstraints:self.searchBarConstraints];
    WCAtlasHideSearchBarBackground(searchBar);
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.embeddedSearchBar) {
        if (@available(iOS 13.0, *)) {
            UITextField *textField = self.embeddedSearchBar.searchTextField;
            textField.background = nil;
            textField.backgroundColor = UIColor.clearColor;
            textField.borderStyle = UITextBorderStyleNone;
        }
        WCAtlasHideSearchBarBackground(self.embeddedSearchBar);
    }
}

- (UIView *)makeAvatarViewWithWXID:(NSString *)wxid headURL:(NSString *)headURL {
    (void)wxid;
    UIImageView *fallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    fallback.tintColor = UIColor.tertiaryLabelColor;
    fallback.contentMode = UIViewContentModeScaleAspectFill;
    fallback.clipsToBounds = YES;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *cachedURL = [defaults stringForKey:@"com.qiu7c.wcatlas.ui.cached-avatar-url"];
    NSData *cachedImageData = [defaults dataForKey:@"com.qiu7c.wcatlas.ui.cached-avatar-data"];
    if (headURL.length > 0 && [cachedURL isEqualToString:headURL] && cachedImageData.length > 0) {
        UIImage *cachedImage = [UIImage imageWithData:cachedImageData];
        if (cachedImage) fallback.image = cachedImage;
    }
    NSURL *URL = headURL.length > 0 ? [NSURL URLWithString:headURL] : nil;
    if (URL) {
        __weak UIImageView *weakImageView = fallback;
        [[[NSURLSession sharedSession] dataTaskWithURL:URL completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
            UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
            if (!image) return;
            [NSUserDefaults.standardUserDefaults setObject:headURL forKey:@"com.qiu7c.wcatlas.ui.cached-avatar-url"];
            [NSUserDefaults.standardUserDefaults setObject:data forKey:@"com.qiu7c.wcatlas.ui.cached-avatar-data"];
            dispatch_async(dispatch_get_main_queue(), ^{ weakImageView.image = image; });
        }] resume];
    }
    return fallback;
}

- (void)refreshProfile {
    [self applyProfileWithWXID:WCAtlasCurrentUserWXID()
                      nickname:WCAtlasCurrentUserNickname()
                       headURL:WCAtlasCurrentUserHeadImageURL()];
}

- (void)applyProfileWithWXID:(NSString *)wxid
                    nickname:(NSString *)nickname
                     headURL:(NSString *)headURL {
    self.wxid = wxid;
    NSString *displayNickname = nickname.length > 0 ? nickname : @"微信用户";
    self.nicknameLabel.attributedText = nil;
    self.nicknameLabel.textColor = UIColor.labelColor;
    self.nicknameLabel.text = displayNickname;
    self.wxidLabel.text = self.wxid.length > 0 ? self.wxid : @"wxid 未获取";
    self.badgeLabel.hidden = YES;
    self.badgeLabel.text = nil;
    if (self.wxid.length) {
        [self applyIdentityBadge:nil];
        NSString *requestedWXID = self.wxid;
        __weak typeof(self) weakSelf = self;
        WCAtlasFetchIdentityBadge(requestedWXID, ^(WCAtlasIdentityBadge *badge) {
            WCAtlasSettingsProfileHeaderView *strongSelf = weakSelf;
            if (!strongSelf || ![strongSelf.wxid isEqualToString:requestedWXID] || !badge) return;
            [strongSelf applyIdentityBadge:badge];
        });
    }
    self.accessibilityLabel = self.wxid.length
        ? [NSString stringWithFormat:@"%@，普通用户，%@", displayNickname, self.wxidLabel.text]
        : [NSString stringWithFormat:@"%@，%@", displayNickname, self.wxidLabel.text];
    self.accessibilityHint = self.wxid.length > 0 ? @"轻点复制 wxid" : nil;

    BOOL avatarNeedsUpdate = !self.avatarContentView ||
        ![(self.appliedAvatarWXID ?: @"") isEqualToString:(self.wxid ?: @"")] ||
        ![(self.appliedHeadURL ?: @"") isEqualToString:(headURL ?: @"")];
    if (!avatarNeedsUpdate) return;
    self.appliedAvatarWXID = self.wxid ?: @"";
    self.appliedHeadURL = headURL ?: @"";
    // Only the image inside the fixed container is replaced. The container's
    // size and position come from the stack view, so no constraints are rebuilt.
    [self.avatarContentView removeFromSuperview];
    UIView *avatarContent = [self makeAvatarViewWithWXID:self.wxid headURL:headURL];
    avatarContent.translatesAutoresizingMaskIntoConstraints = NO;
    avatarContent.clipsToBounds = YES;
    avatarContent.layer.cornerRadius = WCAtlasSettingsAvatarCornerRadius;
    avatarContent.layer.cornerCurve = kCACornerCurveContinuous;
    [self.avatarView addSubview:avatarContent];
    [NSLayoutConstraint activateConstraints:@[
        [avatarContent.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [avatarContent.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [avatarContent.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [avatarContent.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],
    ]];
    self.avatarContentView = avatarContent;
}

- (void)applyIdentityBadge:(WCAtlasIdentityBadge *)badge {
    NSString *text = badge.text.length ? badge.text : @"普通用户";
    UIColor *backgroundColor = WCAtlasIdentityBadgeColor(
        badge.colorCode.length ? badge.colorCode : @"#8E8E93");
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
    CGFloat luminance = 0.299 * red + 0.587 * green + 0.114 * blue;
    self.badgeLabel.text = text;
    self.badgeLabel.backgroundColor = backgroundColor;
    self.badgeLabel.textColor = luminance > 0.68 ? UIColor.blackColor : UIColor.whiteColor;
    self.badgeLabel.hidden = NO;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@，%@，%@",
        self.nicknameLabel.text ?: @"微信用户", text, self.wxidLabel.text ?: @"wxid 未获取"];
}

- (void)profileAreaTapped {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)badgeTapped {
    if (!self.wxid.length) return;
    NSString *requestedWXID = self.wxid;
    self.badgeLabel.text = @"刷新中…";
    __weak typeof(self) weakSelf = self;
    WCAtlasRefreshIdentityBadge(requestedWXID, ^(WCAtlasIdentityBadge *badge) {
        WCAtlasSettingsProfileHeaderView *strongSelf = weakSelf;
        if (!strongSelf || ![strongSelf.wxid isEqualToString:requestedWXID]) return;
        [strongSelf applyIdentityBadge:badge];
    });
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer != self.profileTapGesture) return YES;
    UIView *view = touch.view;
    while (view && view != self.capsuleView) {
        // The badge and the search field now live inside the card, so their whole
        // subtree has to be excluded and not just the top level view.
        if (view == self.badgeLabel || view == self.searchCapsuleView) return NO;
        view = view.superview;
    }
    return YES;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width scale:(CGFloat)scale {
    (void)scale;
    if (width <= 0.0) return 0.0;
    // Measure the card from its own constraints instead of returning one of two
    // hard coded totals, so a larger Dynamic Type size widens the card by itself.
    CGSize fitted = [self systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                        withHorizontalFittingPriority:UILayoutPriorityRequired
                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return ceil(fitted.height);
}

- (void)showCopyConfirmation {
    self.wxidLabel.text = @"wxid 已复制";
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WCAtlasSettingsProfileHeaderView *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.wxidLabel.text = strongSelf.wxid.length > 0 ? strongSelf.wxid : @"wxid 未获取";
    });
}

@end
