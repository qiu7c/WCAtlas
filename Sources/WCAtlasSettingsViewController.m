#import "WCAtlasSettingsViewController.h"
#import "WCAtlasAccount.h"
#import "WCAtlasSettingsActions.h"
#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasSettingsModels.h"
#import "WCAtlasSettingsUI.h"
#import "WCAtlasAntiRevoke.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasPluginManager.h"
#import "WCAtlasReleaseNotes.h"
#import <math.h>

@interface WCAtlasSettingsViewController () <UISearchBarDelegate>
@property (nonatomic, assign) WCAtlasSettingsCategory category;
@property (nonatomic, copy) NSArray<WCAtlasSettingSection *> *sections;
@property (nonatomic, copy) NSArray<WCAtlasSettingSection *> *searchSections;
@property (nonatomic, strong) UISearchBar *functionSearchBar;
@property (nonatomic, strong) NSMutableSet<NSString *> *collapsedFeatureKeys;
@property (nonatomic, strong) WCAtlasSettingsActions *actions;
@property (nonatomic, strong) WCAtlasSettingsProfileHeaderView *profileHeader;
@property (nonatomic, assign) BOOL attemptedReleaseNotes;
- (instancetype)initWithCategory:(WCAtlasSettingsCategory)category;
- (void)presentReleaseNotesIfNeeded;
- (void)quickSwitchLongPressed:(UILongPressGestureRecognizer *)gesture;
- (void)showQuickSwitchToast:(NSString *)message;
- (NSArray<WCAtlasSettingSection *> *)visibleSections;
- (void)rebuildFunctionSearchResults:(NSString *)query;
@end

@implementation WCAtlasSettingsViewController

- (instancetype)init {
    return [self initWithCategory:WCAtlasSettingsCategoryRoot];
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    (void)style;
    return [self initWithCategory:WCAtlasSettingsCategoryRoot];
}

- (instancetype)initWithCategory:(WCAtlasSettingsCategory)category {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) _category = category;
    return self;
}

- (NSString *)titleForCategory:(WCAtlasSettingsCategory)category {
    switch (category) {
        case WCAtlasSettingsCategoryMessages: return @"聊天增强";
        case WCAtlasSettingsCategoryMoments: return @"朋友圈增强";
        case WCAtlasSettingsCategoryInterfaceDisabled: return @"界面禁用";
        case WCAtlasSettingsCategoryEnhancements: return @"常用增强";
        case WCAtlasSettingsCategoryInterface: return @"界面优化";
        case WCAtlasSettingsCategoryPlugin: return @"插件设置";
        case WCAtlasSettingsCategoryRoot:
        default: return @"WCAtlas";
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    WCAtlasSettingsRegisterDefaults();
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSSet<NSString *> *supportedMeTitles = [NSSet setWithArray:@[@"作品", @"小店与卡包", @"表情"]];
    NSArray<NSString *> *hiddenMeTitles = [defaults arrayForKey:WCAtlasMeMenuHiddenTitlesKey] ?: @[];
    NSArray<NSString *> *filteredMeTitles = [hiddenMeTitles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *title, NSDictionary *bindings) {
        (void)bindings;
        return [supportedMeTitles containsObject:title];
    }]];
    if (![filteredMeTitles isEqualToArray:hiddenMeTitles]) [defaults setObject:filteredMeTitles forKey:WCAtlasMeMenuHiddenTitlesKey];
    [self collapseFeaturesForInitialEntry];
    self.title = [self titleForCategory:self.category];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56.0;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0.0;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    [self.tableView registerClass:WCAtlasSettingsCell.class forCellReuseIdentifier:@"WCAtlasSettingsCell"];
    UILongPressGestureRecognizer *quickSwitchGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(quickSwitchLongPressed:)];
    quickSwitchGesture.minimumPressDuration = 0.55;
    [self.tableView addGestureRecognizer:quickSwitchGesture];

    __weak typeof(self) weakSelf = self;
    self.actions = [[WCAtlasSettingsActions alloc] initWithViewController:self reloadHandler:^(BOOL applyScale) {
        [weakSelf reloadSettingsPreservingPositionApplyScale:applyScale];
    }];
    if (self.category == WCAtlasSettingsCategoryRoot) {
        self.profileHeader = [[WCAtlasSettingsProfileHeaderView alloc] initWithFrame:CGRectZero];
        [self.profileHeader addTarget:self action:@selector(profileHeaderTapped) forControlEvents:UIControlEventTouchUpInside];
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = UIColor.systemGroupedBackgroundColor;
        appearance.shadowColor = UIColor.clearColor;
        self.navigationItem.standardAppearance = appearance;
        self.navigationItem.scrollEdgeAppearance = appearance;
        self.navigationItem.compactAppearance = appearance;
        self.functionSearchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
        self.functionSearchBar.delegate = self;
        self.functionSearchBar.placeholder = @"搜索功能开关";
        self.functionSearchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.functionSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        [self.profileHeader embedSearchBar:self.functionSearchBar];
    }
    [self applySettingsPageScale];
    [self rebuildSections];
}

- (CGFloat)settingsPageScale {
    if (!WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey)) return 1.0;
    return WCAtlasScalePercentForDefaultsKey(WCAtlasSettingsPageScalePercentKey, 100.0) / 100.0;
}

- (void)applySettingsPageScale {
    CGFloat scale = [self settingsPageScale];
    self.tableView.estimatedRowHeight = MAX(48.0, 56.0 * scale);
    self.tableView.estimatedSectionHeaderHeight = MAX(28.0, 36.0 * scale);
    self.tableView.estimatedSectionFooterHeight = MAX(28.0, 36.0 * scale);
    if (self.profileHeader) {
        CGFloat width = CGRectGetWidth(self.tableView.bounds);
        CGFloat height = [self.profileHeader preferredHeightForWidth:width scale:scale];
        self.profileHeader.frame = CGRectMake(0.0, 0.0, width, height);
        self.tableView.tableHeaderView = self.profileHeader;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSettingsPreservingPositionApplyScale:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.category == WCAtlasSettingsCategoryRoot) WCAtlasRefreshCachedCurrentUserContact();
    [self.profileHeader refreshProfile];
    if (self.category != WCAtlasSettingsCategoryRoot) return;
    [self presentReleaseNotesIfNeeded];
}

- (void)presentReleaseNotesIfNeeded {
    if (self.attemptedReleaseNotes || self.category != WCAtlasSettingsCategoryRoot || !self.view.window) return;
    self.attemptedReleaseNotes = YES;
    if (!WCAtlasShouldPresentCurrentReleaseNotes()) return;
    [self presentViewController:[WCAtlasReleaseNotesViewController new]
                       animated:NO
                     completion:^{ WCAtlasMarkCurrentReleaseNotesPresented(); }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.profileHeader) return;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (fabs(CGRectGetWidth(self.profileHeader.frame) - width) < 0.5) return;
    CGFloat height = [self.profileHeader preferredHeightForWidth:width scale:[self settingsPageScale]];
    self.profileHeader.frame = CGRectMake(0.0, 0.0, width, height);
    self.tableView.tableHeaderView = self.profileHeader;
}

- (void)rebuildSections {
    self.sections = WCAtlasSettingsBuildSections(self.category, self.collapsedFeatureKeys);
    if (self.functionSearchBar.text.length > 0) {
        [self rebuildFunctionSearchResults:self.functionSearchBar.text ?: @""];
    }
}

- (NSArray<WCAtlasSettingSection *> *)visibleSections {
    NSString *query = [self.functionSearchBar.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return query.length > 0
        ? (self.searchSections ?: @[]) : self.sections;
}

- (void)rebuildFunctionSearchResults:(NSString *)query {
    NSString *needle = [[query stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (needle.length == 0) {
        self.searchSections = @[];
        return;
    }
    NSMutableArray<WCAtlasSettingSection *> *results = [NSMutableArray array];
    NSArray<NSNumber *> *categories = @[
        @(WCAtlasSettingsCategoryMessages), @(WCAtlasSettingsCategoryMoments),
        @(WCAtlasSettingsCategoryInterfaceDisabled), @(WCAtlasSettingsCategoryEnhancements),
        @(WCAtlasSettingsCategoryInterface), @(WCAtlasSettingsCategoryPlugin)
    ];
    for (NSNumber *categoryValue in categories) {
        WCAtlasSettingsCategory category = (WCAtlasSettingsCategory)categoryValue.integerValue;
        NSMutableArray<WCAtlasSettingItem *> *matches = [NSMutableArray array];
        for (WCAtlasSettingSection *section in WCAtlasSettingsBuildSections(category, [NSSet set])) {
            for (WCAtlasSettingItem *item in section.items) {
                // Search is intentionally limited to top-level feature switches.
                // Child/detail/value rows remain available only in their normal pages.
                if (item.kind != WCAtlasSettingRowKindSwitch || item.child ||
                    item.defaultsKey.length == 0 ||
                    [item.defaultsKey isEqualToString:WCAtlasEnabledKey]) continue;
                NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                    item.title ?: @"", item.subtitle ?: @""] lowercaseString];
                if ([haystack containsString:needle]) [matches addObject:item];
            }
        }
        if (matches.count > 0) {
            [results addObject:[WCAtlasSettingSection
                sectionWithIdentifier:[NSString stringWithFormat:@"search-%ld", (long)category]
                title:[self titleForCategory:category] footer:nil items:matches]];
        }
    }
    self.searchSections = results;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    (void)searchBar;
    [self rebuildFunctionSearchResults:searchText ?: @""];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)reloadSettingsPreservingPositionApplyScale:(BOOL)applyScale {
    CGPoint offset = self.tableView.contentOffset;
    if (applyScale) [self applySettingsPageScale];
    [self rebuildSections];
    [UIView performWithoutAnimation:^{
        [self.tableView reloadData];
        [self.tableView setContentOffset:offset animated:NO];
    }];
}

- (void)collapseFeaturesForInitialEntry {
    NSMutableSet<NSString *> *collapsedKeys = [NSMutableSet set];
    NSArray<WCAtlasSettingSection *> *expandedSections = WCAtlasSettingsBuildSections(self.category, [NSSet set]);
    for (WCAtlasSettingSection *section in expandedSections) {
        for (WCAtlasSettingItem *item in section.items) {
            if (item.hasChildren && item.defaultsKey.length > 0) [collapsedKeys addObject:item.defaultsKey];
        }
    }
    self.collapsedFeatureKeys = collapsedKeys;
}

- (void)saveCollapsedFeatureKeys {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray<NSString *> *savedKeys = [self.collapsedFeatureKeys.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [defaults setObject:savedKeys forKey:WCAtlasCollapsedFeaturesKey];
}

- (WCAtlasSettingItem *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<WCAtlasSettingSection *> *sections = [self visibleSections];
    if (indexPath.section < 0 || indexPath.section >= sections.count) return nil;
    NSArray *items = sections[indexPath.section].items;
    return indexPath.row >= 0 && indexPath.row < items.count ? items[indexPath.row] : nil;
}

- (void)profileHeaderTapped {
    if (self.profileHeader.wxid.length == 0) return;
    UIPasteboard.generalPasteboard.string = self.profileHeader.wxid;
    [self.profileHeader showCopyConfirmation];
}

- (void)toggleFeature:(WCAtlasSettingItem *)item {
    if (!item.hasChildren || ![NSUserDefaults.standardUserDefaults boolForKey:item.defaultsKey]) return;
    if ([self.collapsedFeatureKeys containsObject:item.defaultsKey]) {
        [self.collapsedFeatureKeys removeObject:item.defaultsKey];
    } else {
        [self.collapsedFeatureKeys addObject:item.defaultsKey];
    }
    [self saveCollapsedFeatureKeys];
    [self reloadSettingsPreservingPositionApplyScale:NO];
}

- (void)switchItem:(WCAtlasSettingItem *)item changedTo:(BOOL)enabled {
    if (item.defaultsKey.length == 0) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (enabled && [item.defaultsKey isEqualToString:WCAtlasPluginManagerEnabledKey] &&
        WCAtlasExternalPluginManagerAvailable()) {
        [defaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"不兼容"
                                                                        message:@"检测到懒猫插件管理。WCAtlas 内置插件管理不能与其同时启用，请先卸载懒猫插件后再开启。"
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSettingsPreservingPositionApplyScale:NO];
        return;
    }
    [defaults setBool:enabled forKey:item.defaultsKey];
    if (enabled && item.hasChildren) {
        [self.collapsedFeatureKeys removeObject:item.defaultsKey];
        [self saveCollapsedFeatureKeys];
    }
    WCAtlasSettingsHandleSwitchChange(item.defaultsKey, enabled);
    BOOL momentsReminderNeedsBackground = [item.defaultsKey isEqualToString:WCAtlasMomentsReminderEnabledKey] ||
        [item.defaultsKey isEqualToString:WCAtlasMomentsInteractionReminderEnabledKey];
    if (enabled && momentsReminderNeedsBackground &&
        ![defaults boolForKey:WCAtlasBackgroundKeepAliveEnabledKey]) {
        UIAlertController *recommendation = [UIAlertController alertControllerWithTitle:@"建议开启保持后台运行"
                                                                                 message:@"未开启时，朋友圈提醒可能只有在微信前台活跃期间才能检测。两个功能保持独立，可暂不启用后台保持。"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [recommendation addAction:[UIAlertAction actionWithTitle:@"暂不开启" style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [recommendation addAction:[UIAlertAction actionWithTitle:@"开启后台保持" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setBool:YES forKey:WCAtlasBackgroundKeepAliveEnabledKey];
            WCAtlasSettingsHandleSwitchChange(WCAtlasBackgroundKeepAliveEnabledKey, YES);
            [weakSelf reloadSettingsPreservingPositionApplyScale:NO];
        }]];
        [self presentViewController:recommendation animated:YES completion:nil];
    }
    BOOL applyScale = [item.defaultsKey isEqualToString:WCAtlasPageScaleEnabledKey];
    if (item.hasChildren || [item.defaultsKey isEqualToString:WCAtlasEnabledKey] || applyScale) {
        [self reloadSettingsPreservingPositionApplyScale:applyScale];
    }
}

- (void)quickSwitchLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    WCAtlasSettingItem *item = indexPath ? [self itemAtIndexPath:indexPath] : nil;
    if (item.kind != WCAtlasSettingRowKindSwitch || item.defaultsKey.length == 0 ||
        [item.defaultsKey isEqualToString:WCAtlasEnabledKey]) return;

    BOOL registered = WCAtlasPluginManagerIsQuickSwitchRegistered(item.defaultsKey);
    NSString *actionTitle = registered ? @"从插件管理移除" : @"添加到插件管理";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.title
                                                                    message:@"快捷开关与设置页使用同一配置"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:actionTitle
                                             style:registered ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        WCAtlasPluginManagerSetQuickSwitchRegistered(item.defaultsKey, item.title, !registered);
        UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
        [self showQuickSwitchToast:registered ? @"已从插件管理移除" : @"已添加到插件管理"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        popover.sourceView = cell ?: self.tableView;
        popover.sourceRect = (cell ?: self.tableView).bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showQuickSwitchToast:(NSString *)message {
    if (message.length == 0) return;
    const NSInteger toastTag = 0x4E575154;
    [[self.view viewWithTag:toastTag] removeFromSuperview];

    UILabel *toast = [UILabel new];
    toast.tag = toastTag;
    toast.text = message;
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    toast.adjustsFontForContentSizeCategory = YES;
    toast.textColor = UIColor.whiteColor;
    toast.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
    toast.layer.cornerRadius = 12.0;
    toast.layer.cornerCurve = kCACornerCurveContinuous;
    toast.layer.masksToBounds = YES;
    toast.userInteractionEnabled = NO;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.alpha = 0.0;
    toast.transform = CGAffineTransformMakeTranslation(0.0, 6.0);
    [self.view addSubview:toast];
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-22.0],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:36.0],
        [toast.widthAnchor constraintGreaterThanOrEqualToConstant:132.0],
        [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [toast.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
    ]];

    [UIView animateWithDuration:0.18 animations:^{
        toast.alpha = 1.0;
        toast.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{
                toast.alpha = 0.0;
                toast.transform = CGAffineTransformMakeTranslation(0.0, 5.0);
            } completion:^(__unused BOOL hidden) {
                [toast removeFromSuperview];
            }];
        });
    }];
}

- (void)openCategory:(WCAtlasSettingsCategory)category {
    [self.navigationController pushViewController:[[WCAtlasSettingsViewController alloc] initWithCategory:category] animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self visibleSections].count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self visibleSections][section].items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self visibleSections][section].title;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    (void)tableView;
    NSArray<WCAtlasSettingSection *> *sections = [self visibleSections];
    if (self.category == WCAtlasSettingsCategoryRoot && section == 0 &&
        section < sections.count && sections[section].title.length == 0) return 8.0;
    return UITableViewAutomaticDimension;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [self visibleSections][section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCAtlasSettingsCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCAtlasSettingsCell" forIndexPath:indexPath];
    WCAtlasSettingItem *item = [self itemAtIndexPath:indexPath];
    BOOL masterEnabled = [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasEnabledKey];
    BOOL expanded = item.defaultsKey.length == 0 || ![self.collapsedFeatureKeys containsObject:item.defaultsKey];
    __weak typeof(self) weakSelf = self;
    [cell configureWithItem:item masterEnabled:masterEnabled expanded:expanded scale:[self settingsPageScale] switchHandler:^(WCAtlasSettingItem *changedItem, BOOL enabled) {
        [weakSelf switchItem:changedItem changedTo:enabled];
    }];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WCAtlasSettingItem *item = [self itemAtIndexPath:indexPath];
    if (item.kind == WCAtlasSettingRowKindSwitch) {
        [self toggleFeature:item];
        return;
    }
    switch (item.action) {
        case WCAtlasSettingActionOpenMessages: [self openCategory:WCAtlasSettingsCategoryMessages]; break;
        case WCAtlasSettingActionOpenMoments: [self openCategory:WCAtlasSettingsCategoryMoments]; break;
        case WCAtlasSettingActionOpenInterfaceDisabled: [self openCategory:WCAtlasSettingsCategoryInterfaceDisabled]; break;
        case WCAtlasSettingActionOpenEnhancements: [self openCategory:WCAtlasSettingsCategoryEnhancements]; break;
        case WCAtlasSettingActionOpenInterface: [self openCategory:WCAtlasSettingsCategoryInterface]; break;
        case WCAtlasSettingActionOpenPlugin: [self openCategory:WCAtlasSettingsCategoryPlugin]; break;
        default: [self.actions performActionForItem:item]; break;
    }
}

@end
