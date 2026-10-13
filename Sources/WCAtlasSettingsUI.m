#import "WCAtlasSettingsUI.h"
#import "WCAtlasIdentityBadge.h"
#import "WCAtlasAccount.h"
#import "WCAtlasSettingsCatalog.h"
#import <math.h>

static UIImage *WCAtlasSettingsSymbol(NSString *name) {
    UIImage *image = [UIImage systemImageNamed:name];
    return image ?: [UIImage systemImageNamed:@"circle.grid.2x2"];
}

static UIImageView *WCAtlasSettingsChevron(NSString *name, CGFloat scale) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:12.0 * scale
                                                                                                  weight:UIImageSymbolWeightSemibold];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:name] imageWithConfiguration:configuration]];
    chevron.tintColor = UIColor.tertiaryLabelColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    return chevron;
}

static UIView *WCAtlasSettingsDetailAccessory(NSString *valueText, CGFloat scale) {
    CGFloat height = 32.0 * scale;
    CGFloat chevronWidth = 9.0 * scale;
    CGFloat spacing = valueText.length > 0 ? 7.0 * scale : 0.0;
    UILabel *value = nil;
    CGFloat valueWidth = 0.0;
    if (valueText.length > 0) {
        value = [UILabel new];
        value.text = valueText;
        value.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
            scaledFontForFont:[UIFont systemFontOfSize:15.0 * scale]];
        value.adjustsFontForContentSizeCategory = YES;
        value.textColor = UIColor.tertiaryLabelColor;
        value.textAlignment = NSTextAlignmentRight;
        value.adjustsFontSizeToFitWidth = YES;
        value.minimumScaleFactor = 0.75;
        valueWidth = MIN(132.0 * scale, [value sizeThatFits:CGSizeMake(CGFLOAT_MAX, height)].width);
    }
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                 valueWidth + spacing + chevronWidth,
                                                                 height)];
    if (value) {
        value.frame = CGRectMake(0.0, 0.0, valueWidth, height);
        [container addSubview:value];
    }
    UIImageView *chevron = WCAtlasSettingsChevron(@"chevron.right", scale);
    chevron.frame = CGRectMake(valueWidth + spacing, 0.0, chevronWidth, height);
    [container addSubview:chevron];
    return container;
}

static UIView *WCAtlasSettingsExpandableSwitchAccessory(UISwitch *toggle, BOOL expanded, CGFloat scale) {
    [toggle sizeToFit];
    CGFloat chevronWidth = 10.0 * scale;
    CGFloat spacing = 8.0 * scale;
    CGFloat height = MAX(toggle.bounds.size.height, 32.0 * scale);
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                 chevronWidth + spacing + toggle.bounds.size.width,
                                                                 height)];
    UIImageView *chevron = WCAtlasSettingsChevron(expanded ? @"chevron.down" : @"chevron.right", scale);
    chevron.alpha = toggle.isOn ? 1.0 : 0.3;
    chevron.frame = CGRectMake(0.0, 0.0, chevronWidth, height);
    toggle.frame = CGRectMake(chevronWidth + spacing,
                              (height - toggle.bounds.size.height) * 0.5,
                              toggle.bounds.size.width,
                              toggle.bounds.size.height);
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
                     scale:(CGFloat)scale
            switchHandler:(WCAtlasSettingsSwitchHandler)switchHandler {
    self.settingItem = item;
    self.switchHandler = switchHandler;
    self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessibilityHint = nil;

    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = item.title;
    content.secondaryText = item.subtitle;
    UIFontMetrics *bodyMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    UIFontMetrics *footnoteMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote];
    content.textProperties.font = [bodyMetrics scaledFontForFont:[UIFont systemFontOfSize:17.0 * scale]];
    content.textProperties.adjustsFontForContentSizeCategory = YES;
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.font = [footnoteMetrics scaledFontForFont:[UIFont systemFontOfSize:13.0 * scale]];
    content.secondaryTextProperties.adjustsFontForContentSizeCategory = YES;
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    content.secondaryTextProperties.numberOfLines = 0;
    content.image = WCAtlasSettingsSymbol(item.symbol);
    content.imageProperties.tintColor = UIColor.secondaryLabelColor;
    content.imageProperties.maximumSize = CGSizeMake(20.0 * scale, 20.0 * scale);
    CGFloat leading = (item.child ? 28.0 : 12.0) * scale;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(6.0 * scale, leading, 6.0 * scale, 12.0 * scale);
    self.contentConfiguration = content;

    if (item.kind == WCAtlasSettingRowKindSwitch) {
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:item.defaultsKey];
        toggle.enabled = [item.defaultsKey isEqualToString:WCAtlasEnabledKey] || masterEnabled;
        toggle.accessibilityLabel = item.title;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        if (item.hasChildren) {
            self.accessoryView = WCAtlasSettingsExpandableSwitchAccessory(toggle, expanded, scale);
            self.selectionStyle = toggle.isOn ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            self.accessibilityHint = toggle.isOn ? (expanded ? @"轻点收起子选项" : @"轻点展开子选项") : nil;
        } else {
            self.accessoryView = toggle;
            self.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (item.kind == WCAtlasSettingRowKindDetail) {
        self.accessoryView = WCAtlasSettingsDetailAccessory(item.value, scale);
    } else if (item.value.length > 0) {
        UILabel *value = [UILabel new];
        value.text = item.value;
        value.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:15.0 * scale]];
        value.adjustsFontForContentSizeCategory = YES;
        value.textColor = UIColor.secondaryLabelColor;
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
@property (nonatomic, strong) NSLayoutConstraint *capsuleBottomConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *avatarConstraints;
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
    _capsuleView.layer.cornerRadius = 20.0;
    _capsuleView.layer.cornerCurve = kCACornerCurveContinuous;
    _capsuleView.userInteractionEnabled = YES;
    [self addSubview:_capsuleView];

    _profileTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(profileAreaTapped)];
    _profileTapGesture.delegate = self;
    [_capsuleView addGestureRecognizer:_profileTapGesture];

    _nicknameLabel = [UILabel new];
    _nicknameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nicknameLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2]
        scaledFontForFont:[UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold]];
    _nicknameLabel.adjustsFontForContentSizeCategory = YES;
    _nicknameLabel.numberOfLines = 1;
    _nicknameLabel.textAlignment = NSTextAlignmentLeft;
    _nicknameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _badgeLabel = [WCAtlasIdentityBadgeLabel new];
    _badgeLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
        scaledFontForFont:[UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]];
    _badgeLabel.adjustsFontForContentSizeCategory = YES;
    _badgeLabel.layer.cornerRadius = 6.0;
    _badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    _badgeLabel.layer.masksToBounds = YES;
    _badgeLabel.hidden = YES;
    _badgeLabel.userInteractionEnabled = YES;
    [_badgeLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(badgeTapped)]];
    [_badgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisHorizontal];

    _identityRow = [[UIStackView alloc] initWithArrangedSubviews:@[_nicknameLabel, _badgeLabel]];
    _identityRow.translatesAutoresizingMaskIntoConstraints = NO;
    _identityRow.axis = UILayoutConstraintAxisHorizontal;
    _identityRow.alignment = UIStackViewAlignmentCenter;
    _identityRow.spacing = 8.0;
    [_capsuleView addSubview:_identityRow];

    _wxidLabel = [UILabel new];
    _wxidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _wxidLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular]];
    _wxidLabel.adjustsFontForContentSizeCategory = YES;
    _wxidLabel.textColor = UIColor.secondaryLabelColor;
    _wxidLabel.textAlignment = NSTextAlignmentLeft;
    _wxidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_capsuleView addSubview:_wxidLabel];

    _capsuleBottomConstraint = [_capsuleView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12.0];
    [NSLayoutConstraint activateConstraints:@[
        [_capsuleView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [_capsuleView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [_capsuleView.topAnchor constraintEqualToAnchor:self.topAnchor constant:12.0],
        _capsuleBottomConstraint,
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

    [self.capsuleBottomConstraint setActive:NO];
    if (!self.searchCapsuleView) {
        self.searchCapsuleView = [UIView new];
        self.searchCapsuleView.translatesAutoresizingMaskIntoConstraints = NO;
        self.searchCapsuleView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.searchCapsuleView.layer.cornerRadius = 17.0;
        self.searchCapsuleView.layer.cornerCurve = kCACornerCurveContinuous;
        self.searchCapsuleView.layer.masksToBounds = YES;
        [self addSubview:self.searchCapsuleView];
    }
    [self.searchCapsuleView addSubview:searchBar];
    self.searchBarConstraints = @[
        [self.capsuleView.heightAnchor constraintEqualToConstant:80.0],
        [self.searchCapsuleView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [self.searchCapsuleView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [self.searchCapsuleView.topAnchor constraintEqualToAnchor:self.capsuleView.bottomAnchor constant:12.0],
        [self.searchCapsuleView.heightAnchor constraintEqualToConstant:46.0],
        [self.searchCapsuleView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [searchBar.centerXAnchor constraintEqualToAnchor:self.searchCapsuleView.centerXAnchor],
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

    BOOL avatarNeedsUpdate = !self.avatarView ||
        ![(self.appliedAvatarWXID ?: @"") isEqualToString:(self.wxid ?: @"")] ||
        ![(self.appliedHeadURL ?: @"") isEqualToString:(headURL ?: @"")];
    if (!avatarNeedsUpdate) return;
    self.appliedAvatarWXID = self.wxid ?: @"";
    self.appliedHeadURL = headURL ?: @"";
    [NSLayoutConstraint deactivateConstraints:self.avatarConstraints ?: @[]];
    [self.avatarView removeFromSuperview];
    UIView *avatarContent = [self makeAvatarViewWithWXID:self.wxid headURL:headURL];
    avatarContent.translatesAutoresizingMaskIntoConstraints = NO;
    avatarContent.clipsToBounds = YES;
    avatarContent.layer.cornerRadius = 16.0;
    avatarContent.layer.cornerCurve = kCACornerCurveContinuous;

    self.avatarView = [UIView new];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.cornerRadius = 16.0;
    self.avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.avatarView addSubview:avatarContent];
    [self.capsuleView addSubview:self.avatarView];
    self.avatarConstraints = @[
        [self.avatarView.leadingAnchor constraintEqualToAnchor:self.capsuleView.leadingAnchor constant:16.0],
        [self.avatarView.topAnchor constraintEqualToAnchor:self.capsuleView.topAnchor constant:14.0],
        [self.avatarView.widthAnchor constraintEqualToConstant:64.0],
        [self.avatarView.heightAnchor constraintEqualToConstant:64.0],
        [avatarContent.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [avatarContent.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [avatarContent.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [avatarContent.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],
        [self.identityRow.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:14.0],
        [self.identityRow.trailingAnchor constraintLessThanOrEqualToAnchor:self.capsuleView.trailingAnchor constant:-16.0],
        [self.identityRow.bottomAnchor constraintEqualToAnchor:self.capsuleView.centerYAnchor constant:-2.0],
        [self.wxidLabel.leadingAnchor constraintEqualToAnchor:self.identityRow.leadingAnchor],
        [self.wxidLabel.trailingAnchor constraintEqualToAnchor:self.capsuleView.trailingAnchor constant:-16.0],
        [self.wxidLabel.topAnchor constraintEqualToAnchor:self.identityRow.bottomAnchor constant:4.0],
    ];
    [NSLayoutConstraint activateConstraints:self.avatarConstraints];
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
        if (view == self.badgeLabel || view == self.embeddedSearchBar) return NO;
        view = view.superview;
    }
    return YES;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width scale:(CGFloat)scale {
    (void)width;
    (void)scale;
    return self.embeddedSearchBar ? 154.0 : 104.0;
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
