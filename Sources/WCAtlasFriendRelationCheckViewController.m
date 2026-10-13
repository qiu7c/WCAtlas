#import "WCAtlasFriendRelationCheckViewController.h"
#import "WCAtlasFriendRelationChecker.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasSendConfirmationViewController.h"

static UIColor *WCAtlasFriendRelationSecondaryColor(void) {
    if (@available(iOS 13.0, *)) return UIColor.secondaryLabelColor;
    return UIColor.grayColor;
}

static UIView *WCAtlasFriendRelationAvatarView(NSString *userName) {
    if (userName.length == 0) return nil;
    UIView *avatar = WCAtlasPrivateContactAvatarView(WCAtlasPrivateContact(userName), userName, NO);
    if (!avatar) return nil;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 40.0, 40.0)];
    container.userInteractionEnabled = NO;
    container.clipsToBounds = YES;
    container.layer.cornerRadius = 20.0;
    container.backgroundColor = UIColor.tertiarySystemFillColor;
    avatar.frame = container.bounds;
    avatar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:avatar];
    return container;
}

static BOOL WCAtlasFriendRelationOpenProfile(UIViewController *source, NSString *userName) {
    return WCAtlasPushPrivateContactProfile(source, userName);
}

@interface WCAtlasFriendRelationResultCell : UITableViewCell
@property(nonatomic, strong) UIView *nativeAvatarView;
@property(nonatomic, copy) NSString *avatarUserName;
- (void)configureAvatarForUserName:(NSString *)userName;
@end

@implementation WCAtlasFriendRelationResultCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
        self.imageView.tintColor = WCAtlasFriendRelationSecondaryColor();
    }
    return self;
}

- (void)configureAvatarForUserName:(NSString *)userName {
    if ([self.avatarUserName isEqualToString:userName] && self.nativeAvatarView) return;
    [self.nativeAvatarView removeFromSuperview];
    self.nativeAvatarView = WCAtlasFriendRelationAvatarView(userName);
    self.avatarUserName = [userName copy];
    if (self.nativeAvatarView) [self.contentView addSubview:self.nativeAvatarView];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = 48.0;
    CGRect frame = CGRectMake(self.layoutMargins.left,
                              floor((CGRectGetHeight(self.contentView.bounds) - side) * 0.5),
                              side, side);
    self.nativeAvatarView.frame = frame;
    self.nativeAvatarView.layer.cornerRadius = side * 0.5;
    self.imageView.hidden = self.nativeAvatarView != nil;
    if (self.nativeAvatarView) {
        CGFloat labelX = CGRectGetMaxX(frame) + 12.0;
        CGFloat trailing = self.accessoryType == UITableViewCellAccessoryNone ? 16.0 : 38.0;
        CGFloat labelWidth = MAX(0.0, CGRectGetWidth(self.contentView.bounds) - labelX - trailing);
        CGRect textFrame = self.textLabel.frame;
        textFrame.origin.x = labelX;
        textFrame.size.width = labelWidth;
        self.textLabel.frame = textFrame;
        CGRect detailFrame = self.detailTextLabel.frame;
        detailFrame.origin.x = labelX;
        detailFrame.size.width = labelWidth;
        self.detailTextLabel.frame = detailFrame;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.nativeAvatarView removeFromSuperview];
    self.nativeAvatarView = nil;
    self.avatarUserName = nil;
    self.imageView.hidden = NO;
}

@end

@interface WCAtlasFriendRelationResultViewController : UITableViewController
@property(nonatomic, copy) NSString *verdict;
@property(nonatomic, copy) NSString *pageTitle;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, strong) NSMutableSet<NSString *> *selectedUserNames;
@property(nonatomic, assign) BOOL openedToolbar;
@end

@implementation WCAtlasFriendRelationResultViewController

- (instancetype)initWithVerdict:(NSString *)verdict title:(NSString *)title {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _verdict = [verdict copy];
        _pageTitle = [title copy];
        _items = @[];
        _selectedUserNames = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.pageTitle;
    self.tableView.rowHeight = 68.0;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self updateNavigationButtons];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reloadItems)
                                               name:WCAtlasFriendRelationCheckDidUpdateNotification object:nil];
    [self reloadItems];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.tableView.isEditing && self.navigationController.toolbarHidden) {
        self.openedToolbar = YES;
        [self.navigationController setToolbarHidden:NO animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.openedToolbar) {
        [self.navigationController setToolbarHidden:YES animated:NO];
        self.openedToolbar = NO;
    }
}

- (void)reloadItems {
    self.items = [[WCAtlasFriendRelationChecker sharedChecker] itemsWithVerdict:self.verdict];
    NSSet *available = [NSSet setWithArray:[self.items valueForKey:@"userName"]];
    [self.selectedUserNames intersectSet:available];
    [self updateNavigationButtons];
    [self.tableView reloadData];
}

- (NSArray<NSString *> *)selectedNames {
    if (self.selectedUserNames.count == 0) return @[];
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *item in self.items) {
        NSString *userName = item[@"userName"];
        if ([self.selectedUserNames containsObject:userName]) [names addObject:userName];
    }
    return names;
}

- (void)updateNavigationButtons {
    if (!self.tableView.isEditing) {
        UIBarButtonItem *recheck = [[UIBarButtonItem alloc] initWithTitle:@"全部复检"
            style:UIBarButtonItemStylePlain target:self action:@selector(recheckAll)];
        UIBarButtonItem *select = [[UIBarButtonItem alloc] initWithTitle:@"选择"
            style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditing)];
        recheck.enabled = self.items.count > 0;
        select.enabled = self.items.count > 0;
        self.navigationItem.rightBarButtonItems = @[select, recheck];
        return;
    }
    NSString *selectTitle = self.selectedUserNames.count == self.items.count ? @"取消全选" : @"全选";
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
            target:self action:@selector(toggleEditing)],
        [[UIBarButtonItem alloc] initWithTitle:selectTitle style:UIBarButtonItemStylePlain
            target:self action:@selector(toggleSelectAll)]
    ];
    [self refreshToolbar];
}

- (void)toggleEditing {
    BOOL editing = !self.tableView.isEditing;
    [self.tableView setEditing:editing animated:YES];
    if (editing) {
        self.openedToolbar = self.navigationController.toolbarHidden;
        [self.navigationController setToolbarHidden:NO animated:YES];
    } else {
        [self.selectedUserNames removeAllObjects];
        if (self.openedToolbar) [self.navigationController setToolbarHidden:YES animated:YES];
        self.openedToolbar = NO;
    }
    [self.tableView reloadData];
    [self updateNavigationButtons];
}

- (void)toggleSelectAll {
    if (self.selectedUserNames.count == self.items.count) {
        [self.selectedUserNames removeAllObjects];
        for (NSIndexPath *path in self.tableView.indexPathsForSelectedRows ?: @[]) {
            [self.tableView deselectRowAtIndexPath:path animated:NO];
        }
    } else {
        [self.selectedUserNames removeAllObjects];
        for (NSUInteger row = 0; row < self.items.count; row++) {
            NSString *userName = self.items[row][@"userName"];
            if (userName.length > 0) [self.selectedUserNames addObject:userName];
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
                                        animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self updateNavigationButtons];
}

- (void)refreshToolbar {
    BOOL enabled = self.selectedUserNames.count > 0;
    UIBarButtonItem *recheck = [[UIBarButtonItem alloc] initWithTitle:@"复检" style:UIBarButtonItemStylePlain
        target:self action:@selector(recheckSelected)];
    UIBarButtonItem *remove = [[UIBarButtonItem alloc] initWithTitle:@"移出结果" style:UIBarButtonItemStylePlain
        target:self action:@selector(removeSelected)];
    recheck.enabled = enabled;
    remove.enabled = enabled;
    NSMutableArray *items = [NSMutableArray arrayWithObjects:recheck,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        remove, nil];
    if ([self.verdict isEqualToString:WCAtlasFriendRelationVerdictSuspected]) {
        UIBarButtonItem *delete = [[UIBarButtonItem alloc] initWithTitle:@"删除好友"
            style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelected)];
        delete.tintColor = UIColor.systemRedColor;
        delete.enabled = enabled;
        [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [items addObject:delete];
    }
    self.toolbarItems = items;
}

- (void)recheckAll {
    NSArray *userNames = [self.items valueForKey:@"userName"];
    if (userNames.count == 0) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重新检测"
        message:[NSString stringWithFormat:@"将再次通过微信支付前置接口逐个检测 %lu 位好友。",
                 (unsigned long)userNames.count]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"开始复检" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            [[WCAtlasFriendRelationChecker sharedChecker] startRecheckWithUserNames:userNames];
            [self.navigationController popViewControllerAnimated:YES];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)recheckSelected {
    NSArray *names = [self selectedNames];
    if (names.count == 0) return;
    [[WCAtlasFriendRelationChecker sharedChecker] startRecheckWithUserNames:names];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)removeSelected {
    NSArray *names = [self selectedNames];
    if (names.count == 0) return;
    [[WCAtlasFriendRelationChecker sharedChecker] removeResultUserNames:names];
    [self.selectedUserNames removeAllObjects];
    [self reloadItems];
}

- (void)deleteSelected {
    NSArray *names = [self selectedNames];
    if (names.count == 0) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除好友"
        message:[NSString stringWithFormat:@"将从通讯录永久删除所选 %lu 位疑似单删好友，聊天记录会保留。",
                 (unsigned long)names.count]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    void (^deleteHandler)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSDictionary *result = [[WCAtlasFriendRelationChecker sharedChecker]
            deleteUserNames:names retainChatHistory:YES];
        NSUInteger deleted = [result[@"deleted"] count];
        NSUInteger failed = [result[@"failed"] count];
        [self.selectedUserNames removeAllObjects];
        [self reloadItems];
        UIAlertController *summary = [UIAlertController alertControllerWithTitle:@"删除完成"
            message:[NSString stringWithFormat:@"成功 %lu 位，失败 %lu 位。",
                     (unsigned long)deleted, (unsigned long)failed]
            preferredStyle:UIAlertControllerStyleAlert];
        [summary addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:summary animated:YES completion:nil];
    };
    [alert addAction:[UIAlertAction actionWithTitle:@"确认删除"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { deleteHandler(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.items.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    if ([self.verdict isEqualToString:WCAtlasFriendRelationVerdictUncertain]) {
        return @"待核查不代表对方已删除你；对方未实名、未开通相关支付能力、网络异常或接口无完整结果，都可能进入此页。";
    }
    if ([self.verdict isEqualToString:WCAtlasFriendRelationVerdictSuspected]) {
        return @"删除好友会真实修改微信通讯录，请核对资料后再使用批量删除。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"WCAtlasFriendRelationResultCell";
    WCAtlasFriendRelationResultCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[WCAtlasFriendRelationResultCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *item = self.items[indexPath.row];
    cell.textLabel.text = item[@"displayName"] ?: item[@"userName"];
    NSString *message = item[@"retmsg"];
    NSString *maskedName = [[WCAtlasFriendRelationChecker sharedChecker]
        maskedRealNameForUserName:item[@"userName"]];
    if (maskedName.length > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"脱敏姓名 %@ · %@",
                                     maskedName, item[@"userName"] ?: @""];
    } else {
        cell.detailTextLabel.text = message.length > 0 ? message : item[@"userName"];
    }
    cell.detailTextLabel.textColor = WCAtlasFriendRelationSecondaryColor();
    cell.accessoryType = self.tableView.isEditing ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    [cell configureAvatarForUserName:item[@"userName"]];
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(__unused UITableView *)tableView
       trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    NSString *userName = item[@"userName"];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:@"移出结果" handler:^(__unused UIContextualAction *action, __unused UIView *view,
                                    void (^completionHandler)(BOOL)) {
            [[WCAtlasFriendRelationChecker sharedChecker] removeResultUserNames:userName ? @[userName] : @[]];
            completionHandler(YES);
        }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (void)tableView:(__unused UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *userName = self.items[indexPath.row][@"userName"];
    if (tableView.isEditing) {
        if (userName.length > 0) [self.selectedUserNames addObject:userName];
        [self updateNavigationButtons];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!WCAtlasFriendRelationOpenProfile(self, userName)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开资料页"
            message:@"当前微信版本不支持该资料页入口。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!tableView.isEditing) return;
    NSString *userName = self.items[indexPath.row][@"userName"];
    if (userName.length > 0) [self.selectedUserNames removeObject:userName];
    [self updateNavigationButtons];
}

@end

@interface WCAtlasFriendRelationCheckViewController ()
@property(nonatomic, strong) UIView *progressHeader;
@property(nonatomic, strong) UILabel *progressNameLabel;
@property(nonatomic, strong) UIProgressView *progressBar;
@property(nonatomic, strong) UILabel *progressCountLabel;
@end

@implementation WCAtlasFriendRelationCheckViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"检测单删好友";
    self.tableView.rowHeight = 52.0;
    [self buildProgressHeader];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(checkerDidUpdate)
                                               name:WCAtlasFriendRelationCheckDidUpdateNotification object:nil];
    [self updateProgressHeader];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateProgressHeader];
    [self.tableView reloadData];
}

- (void)buildProgressHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 126.0)];
    UILabel *nameLabel = [UILabel new];
    nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    nameLabel.numberOfLines = 2;
    UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    bar.progressTintColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.32 alpha:1.0];
    UILabel *countLabel = [UILabel new];
    countLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    countLabel.textColor = WCAtlasFriendRelationSecondaryColor();
    for (UIView *view in @[nameLabel, bar, countLabel]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [nameLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20.0],
        [nameLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:24.0],
        [bar.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
        [bar.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:18.0],
        [countLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [countLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
        [countLabel.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:12.0],
    ]];
    self.progressHeader = header;
    self.progressNameLabel = nameLabel;
    self.progressBar = bar;
    self.progressCountLabel = countLabel;
    self.tableView.tableHeaderView = header;
}

- (void)checkerDidUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgressHeader];
        [self.tableView reloadData];
    });
}

- (void)updateProgressHeader {
    WCAtlasFriendRelationChecker *checker = WCAtlasFriendRelationChecker.sharedChecker;
    self.progressNameLabel.text = checker.progressTitle;
    [self.progressBar setProgress:checker.progress animated:YES];
    self.progressCountLabel.text = [NSString stringWithFormat:@"正常 %lu · 疑似 %lu · 待核查 %lu",
        (unsigned long)checker.normalCount, (unsigned long)checker.suspectedCount,
        (unsigned long)checker.uncertainCount];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return 4; }

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 1;
    if (section == 2) return 3;
    return 1;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"检测范围";
    if (section == 1) return @"运行";
    if (section == 2) return @"检测结果";
    return @"说明";
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"检测开始后范围会固定；暂停后可继续未完成部分。";
    if (section == 2) return @"“疑似单删”来自支付接口的明确非好友响应；网络、解析异常，以及对方可能未实名或未开通相关支付能力，只进入待核查。";
    return nil;
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail accessory:(BOOL)accessory {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.accessoryType = accessory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (NSString *)runActionTitle {
    NSString *status = WCAtlasFriendRelationChecker.sharedChecker.status;
    if ([status isEqualToString:WCAtlasFriendRelationStatusRunning]) return @"暂停检测";
    if ([status isEqualToString:WCAtlasFriendRelationStatusPaused]) return @"继续检测";
    if ([status isEqualToString:WCAtlasFriendRelationStatusCompleted]) return @"重新检测";
    return @"开始检测";
}

- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCAtlasFriendRelationChecker *checker = WCAtlasFriendRelationChecker.sharedChecker;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            NSString *detail = checker.pendingUserNames.count > 0
                ? [NSString stringWithFormat:@"%lu 人", (unsigned long)checker.pendingUserNames.count] : @"未选择";
            return [self cellWithTitle:@"选择好友" detail:detail accessory:YES];
        }
        return [self cellWithTitle:@"使用全部好友" detail:nil accessory:NO];
    }
    if (indexPath.section == 1) {
        UITableViewCell *cell = [self cellWithTitle:[self runActionTitle] detail:nil accessory:NO];
        cell.textLabel.textColor = [checker.status isEqualToString:WCAtlasFriendRelationStatusRunning]
            ? UIColor.systemOrangeColor : [UIColor colorWithRed:0.10 green:0.70 blue:0.30 alpha:1.0];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
    if (indexPath.section == 2) {
        NSArray *titles = @[@"正常好友", @"疑似单删", @"待核查"];
        NSArray *counts = @[@(checker.normalCount), @(checker.suspectedCount), @(checker.uncertainCount)];
        return [self cellWithTitle:titles[indexPath.row]
                            detail:[NSString stringWithFormat:@"%@ 人", counts[indexPath.row]] accessory:YES];
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = @"本功能逐个调用微信支付前置接口进行网络检测，不会发送聊天消息或自动删除联系人。批量请求仍可能存在账号风险，请控制使用频率。";
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.textLabel.textColor = WCAtlasFriendRelationSecondaryColor();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 3 ? 92.0 : 52.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self selectFriends];
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        [self selectAllFriends];
    } else if (indexPath.section == 1) {
        [self toggleRun];
    } else if (indexPath.section == 2) {
        NSArray *verdicts = @[WCAtlasFriendRelationVerdictNormal,
                              WCAtlasFriendRelationVerdictSuspected,
                              WCAtlasFriendRelationVerdictUncertain];
        NSArray *titles = @[@"正常好友", @"疑似单删", @"待核查"];
        WCAtlasFriendRelationResultViewController *controller =
            [[WCAtlasFriendRelationResultViewController alloc] initWithVerdict:verdicts[indexPath.row]
                                                                        title:titles[indexPath.row]];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)selectFriends {
    WCAtlasFriendRelationChecker *checker = WCAtlasFriendRelationChecker.sharedChecker;
    if ([checker.status isEqualToString:WCAtlasFriendRelationStatusRunning] ||
        [checker.status isEqualToString:WCAtlasFriendRelationStatusPaused]) {
        [self showRangeLockedMessage];
        return;
    }
    __weak typeof(self) weakSelf = self;
    UIViewController *picker = WCAtlasCreateFriendPicker(@"选择检测好友",
        @"仅选择真实好友；支持全选和反选，每次变更都会立即保存检测范围。",
        ^BOOL(NSString *userName) {
            return [WCAtlasFriendRelationChecker.sharedChecker.pendingUserNames containsObject:userName];
        }, ^(NSString *userName) {
            WCAtlasFriendRelationChecker *strongChecker = WCAtlasFriendRelationChecker.sharedChecker;
            NSMutableOrderedSet *selection = [NSMutableOrderedSet orderedSetWithArray:strongChecker.pendingUserNames];
            if ([selection containsObject:userName]) [selection removeObject:userName];
            else [selection addObject:userName];
            [strongChecker setPendingUserNames:selection.array sourceTitle:@"自选好友"];
            [weakSelf.tableView reloadData];
        });
    WCAtlasConfigureConversationPickerBulkActions(picker, ^{
        WCAtlasFriendRelationChecker *strongChecker = WCAtlasFriendRelationChecker.sharedChecker;
        NSArray *allUserNames = [[strongChecker allFriendCandidates] valueForKey:@"userName"];
        [strongChecker setPendingUserNames:allUserNames sourceTitle:@"全部好友"];
        [weakSelf.tableView reloadData];
    }, ^{
        WCAtlasFriendRelationChecker *strongChecker = WCAtlasFriendRelationChecker.sharedChecker;
        NSSet<NSString *> *selected = [NSSet setWithArray:strongChecker.pendingUserNames];
        NSMutableArray<NSString *> *inverted = [NSMutableArray array];
        for (NSDictionary *candidate in [strongChecker allFriendCandidates]) {
            NSString *userName = candidate[@"userName"];
            if (userName.length > 0 && ![selected containsObject:userName]) [inverted addObject:userName];
        }
        [strongChecker setPendingUserNames:inverted sourceTitle:@"反选好友"];
        [weakSelf.tableView reloadData];
    });
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)selectAllFriends {
    WCAtlasFriendRelationChecker *checker = WCAtlasFriendRelationChecker.sharedChecker;
    if ([checker.status isEqualToString:WCAtlasFriendRelationStatusRunning] ||
        [checker.status isEqualToString:WCAtlasFriendRelationStatusPaused]) {
        [self showRangeLockedMessage];
        return;
    }
    NSArray *candidates = [checker allFriendCandidates];
    if (candidates.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未获取到好友"
            message:@"当前微信版本的联系人接口不可用，或通讯录尚未加载完成。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [checker setPendingUserNames:[candidates valueForKey:@"userName"] sourceTitle:@"全部好友"];
}

- (void)showRangeLockedMessage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"检测范围已固定"
        message:@"请先完成当前检测；暂停状态可继续未完成部分。重新检测时可以重新选择范围。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleRun {
    WCAtlasFriendRelationChecker *checker = WCAtlasFriendRelationChecker.sharedChecker;
    if ([checker.status isEqualToString:WCAtlasFriendRelationStatusRunning]) {
        [checker pause];
        return;
    }
    if ([checker.status isEqualToString:WCAtlasFriendRelationStatusPaused]) {
        [checker resume];
        return;
    }
    NSUInteger count = checker.pendingUserNames.count;
    if (count == 0) count = [checker allFriendCandidates].count;
    if (count == 0) {
        [self selectAllFriends];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"开始检测单删好友？"
        message:[NSString stringWithFormat:@"将串行调用微信支付前置接口检测 %lu 位好友，并在每次请求之间随机等待。好友不会收到聊天消息，但请求对微信服务端可见，批量检测可能存在账号风险。",
                 (unsigned long)count]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认开始" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { [checker start]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
