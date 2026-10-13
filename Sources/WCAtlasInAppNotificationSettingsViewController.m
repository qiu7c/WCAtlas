#import "WCAtlasInAppNotificationSettingsViewController.h"
#import "WCAtlasInAppNotification.h"
#import <math.h>

@interface WCAtlasInAppNotificationSliderCell : UITableViewCell
@property (nonatomic, strong) UILabel *settingLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UISlider *slider;
@end

@implementation WCAtlasInAppNotificationSliderCell

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.settingLabel = [UILabel new];
    self.settingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.settingLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:self.settingLabel];

    self.valueLabel = [UILabel new];
    self.valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.valueLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.valueLabel.adjustsFontForContentSizeCategory = YES;
    self.valueLabel.textColor = UIColor.secondaryLabelColor;
    self.valueLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.valueLabel];

    self.slider = [UISlider new];
    self.slider.translatesAutoresizingMaskIntoConstraints = NO;
    self.slider.minimumTrackTintColor = [UIColor colorWithRed:0.12 green:0.72 blue:0.32 alpha:1.0];
    [self.contentView addSubview:self.slider];

    [NSLayoutConstraint activateConstraints:@[
        [self.settingLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.settingLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
        [self.valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.settingLabel.trailingAnchor constant:8.0],
        [self.valueLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.valueLabel.centerYAnchor constraintEqualToAnchor:self.settingLabel.centerYAnchor],
        [self.slider.leadingAnchor constraintEqualToAnchor:self.settingLabel.leadingAnchor],
        [self.slider.trailingAnchor constraintEqualToAnchor:self.valueLabel.trailingAnchor],
        [self.slider.topAnchor constraintEqualToAnchor:self.settingLabel.bottomAnchor constant:5.0],
        [self.slider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8.0],
    ]];
    return self;
}

@end

@interface WCAtlasInAppNotificationSettingsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *iconOptions;
- (void)sliderChanged:(UISlider *)slider;
- (void)showPreview;
@end

@implementation WCAtlasInAppNotificationSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"应用内通知样式";
    self.iconOptions = @[
        @{ @"title": @"跟随提醒类型", @"symbol": @"automatic", @"preview": @"square.grid.2x2" },
        @{ @"title": @"朋友圈", @"symbol": @"circle.grid.3x3", @"preview": @"circle.grid.3x3" },
        @{ @"title": @"铃铛", @"symbol": @"bell.fill", @"preview": @"bell.fill" },
        @{ @"title": @"爱心", @"symbol": @"heart.fill", @"preview": @"heart.fill" },
        @{ @"title": @"评论", @"symbol": @"bubble.left.fill", @"preview": @"bubble.left.fill" },
        @{ @"title": @"星标", @"symbol": @"star.fill", @"preview": @"star.fill" },
    ];
    self.tableView.estimatedRowHeight = 50.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) return self.iconOptions.count;
    if (section == 2) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) return @"左侧图标";
    if (section == 2) return @"尺寸与玻璃效果";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return @"预览使用当前保存的图标、高度和模糊度。";
    if (section == 1) return @"“跟随提醒类型”会分别使用朋友圈、点赞和评论图标。";
    if (section == 2) {
        return [NSString stringWithFormat:@"高度最低 %.0f pt；系统大字体需要更多空间时会自动增高。",
                                          WCAtlasInAppNotificationMinimumHeight];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    return indexPath.section == 2 ? 78.0 : 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        NSString *reuseIdentifier = @"WCAtlasInAppNotificationSliderCell";
        WCAtlasInAppNotificationSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
        if (!cell) cell = [[WCAtlasInAppNotificationSliderCell alloc] initWithReuseIdentifier:reuseIdentifier];
        [cell.slider removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        cell.slider.tag = indexPath.row;
        if (indexPath.row == 0) {
            cell.settingLabel.text = @"横幅高度";
            cell.valueLabel.text = [NSString stringWithFormat:@"%.0f pt", WCAtlasInAppNotificationPreferredHeight()];
            cell.slider.minimumValue = WCAtlasInAppNotificationMinimumHeight;
            cell.slider.maximumValue = WCAtlasInAppNotificationMaximumHeight;
            cell.slider.value = WCAtlasInAppNotificationPreferredHeight();
        } else {
            cell.settingLabel.text = @"背景模糊度";
            cell.valueLabel.text = [NSString stringWithFormat:@"%.0f%%", WCAtlasInAppNotificationBlurIntensity() * 100.0];
            cell.slider.minimumValue = 20.0f;
            cell.slider.maximumValue = 100.0f;
            cell.slider.value = WCAtlasInAppNotificationBlurIntensity() * 100.0;
        }
        [cell.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        return cell;
    }

    NSString *reuseIdentifier = @"WCAtlasInAppNotificationSettingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        cell.textLabel.text = @"预览通知";
        cell.imageView.image = [UIImage systemImageNamed:@"play.rectangle"];
        cell.imageView.tintColor = UIColor.systemGreenColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        NSDictionary<NSString *, NSString *> *option = self.iconOptions[indexPath.row];
        cell.textLabel.text = option[@"title"];
        cell.imageView.image = [UIImage systemImageNamed:option[@"preview"]];
        cell.imageView.tintColor = UIColor.systemGreenColor;
        NSString *selected = [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasInAppNotificationSymbolKey] ?: @"automatic";
        cell.accessoryType = [selected isEqualToString:option[@"symbol"]]
            ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = @"恢复默认样式";
        cell.textLabel.textColor = UIColor.systemRedColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (indexPath.section == 0) {
        [self showPreview];
    } else if (indexPath.section == 1) {
        [defaults setObject:self.iconOptions[indexPath.row][@"symbol"] forKey:WCAtlasInAppNotificationSymbolKey];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
        [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    } else if (indexPath.section == 3) {
        [defaults removeObjectForKey:WCAtlasInAppNotificationSymbolKey];
        [defaults removeObjectForKey:WCAtlasInAppNotificationHeightKey];
        [defaults removeObjectForKey:WCAtlasInAppNotificationBlurIntensityKey];
        [tableView reloadData];
        [self showPreview];
    }
}

- (void)sliderChanged:(UISlider *)slider {
    CGPoint point = [slider convertPoint:CGPointMake(CGRectGetMidX(slider.bounds), CGRectGetMidY(slider.bounds))
                                  toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
    WCAtlasInAppNotificationSliderCell *cell = indexPath
        ? (WCAtlasInAppNotificationSliderCell *)[self.tableView cellForRowAtIndexPath:indexPath] : nil;
    if (slider.tag == 0) {
        CGFloat height = roundf(slider.value);
        slider.value = height;
        [NSUserDefaults.standardUserDefaults setDouble:height forKey:WCAtlasInAppNotificationHeightKey];
        cell.valueLabel.text = [NSString stringWithFormat:@"%.0f pt", height];
    } else {
        CGFloat percent = roundf(slider.value);
        slider.value = percent;
        [NSUserDefaults.standardUserDefaults setDouble:percent / 100.0
                                                forKey:WCAtlasInAppNotificationBlurIntensityKey];
        cell.valueLabel.text = [NSString stringWithFormat:@"%.0f%%", percent];
    }
}

- (void)showPreview {
    WCAtlasDismissInAppNotifications();
    WCAtlasShowInAppNotification(@"应用内通知预览",
                               @"这是一条朋友圈提醒的样式预览",
                               NSUUID.UUID.UUIDString,
                               @"circle.grid.3x3",
                               nil);
}

@end
