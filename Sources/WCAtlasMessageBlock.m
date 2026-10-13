#import "WCAtlasMessageBlock.h"
#import "WCAtlasAccount.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasSendConfirmation.h"
#import "WCAtlasSendConfirmationViewController.h"
#import <objc/message.h>

static NSString *const WCAtlasMessageBlockAllType = @"all";

static NSArray<NSDictionary *> *WCAtlasMessageBlockTypeOptions(void) {
    return @[
        @{ @"id": @"text", @"title": @"文字" },
        @{ @"id": @"image", @"title": @"图片" },
        @{ @"id": @"video", @"title": @"视频" },
        @{ @"id": @"voice", @"title": @"语音" },
        @{ @"id": @"emoticon", @"title": @"表情" },
        @{ @"id": @"file_link", @"title": @"文件与链接" },
        @{ @"id": @"system", @"title": @"系统通知及其他" },
    ];
}

static NSDictionary<NSString *, NSArray<NSString *> *> *WCAtlasMessageBlockStoredRules(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasMessageBlockRulesKey];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSArray<NSString *> *WCAtlasMessageBlockedConversations(void) {
    NSMutableOrderedSet<NSString *> *usernames = [NSMutableOrderedSet orderedSet];
    for (id username in WCAtlasMessageBlockStoredRules().allKeys) {
        if ([username isKindOfClass:NSString.class] && [username length] > 0) [usernames addObject:username];
    }
    for (id username in [NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasMessageBlockUsersKey] ?: @[]) {
        if ([username isKindOfClass:NSString.class] && [username length] > 0) [usernames addObject:username];
    }
    return usernames.array;
}

NSArray<NSString *> *WCAtlasMessageBlockTypesForConversation(NSString *username) {
    if (username.length == 0) return @[];
    id stored = WCAtlasMessageBlockStoredRules()[username];
    if ([stored isKindOfClass:NSArray.class] && [stored count] > 0) return stored;
    return [[NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasMessageBlockUsersKey] containsObject:username]
        ? @[WCAtlasMessageBlockAllType] : @[];
}

static NSString *WCAtlasMessageBlockIdentifierForType(NSUInteger messageType) {
    switch (messageType) {
        case 1: return @"text";
        case 3: return @"image";
        case 34: return @"voice";
        case 43:
        case 62: return @"video";
        case 47: return @"emoticon";
        case 49: return @"file_link";
        default: return @"system";
    }
}

BOOL WCAtlasMessageBlockConversationMatchesType(NSString *username, NSUInteger messageType) {
    NSArray<NSString *> *types = WCAtlasMessageBlockTypesForConversation(username);
    return [types containsObject:WCAtlasMessageBlockAllType] ||
           [types containsObject:WCAtlasMessageBlockIdentifierForType(messageType)];
}

void WCAtlasMessageBlockSetTypesForConversation(NSString *username, NSArray<NSString *> *types) {
    if (username.length == 0) return;
    NSMutableOrderedSet<NSString *> *normalized = [NSMutableOrderedSet orderedSet];
    NSSet *known = [NSSet setWithArray:[WCAtlasMessageBlockTypeOptions() valueForKey:@"id"]];
    for (id type in types) {
        if ([type isEqual:WCAtlasMessageBlockAllType] || [known containsObject:type]) [normalized addObject:type];
    }
    if ([normalized containsObject:WCAtlasMessageBlockAllType]) {
        [normalized removeAllObjects];
        [normalized addObject:WCAtlasMessageBlockAllType];
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *rules = [WCAtlasMessageBlockStoredRules() mutableCopy];
    NSMutableOrderedSet *legacy = [NSMutableOrderedSet orderedSetWithArray:
                                   [defaults arrayForKey:WCAtlasMessageBlockUsersKey] ?: @[]];
    if (normalized.count > 0) {
        rules[username] = normalized.array;
        [legacy addObject:username];
        [defaults setBool:YES forKey:WCAtlasMessageBlockEnabledKey];
    } else {
        [rules removeObjectForKey:username];
        [legacy removeObject:username];
    }
    [defaults setObject:rules forKey:WCAtlasMessageBlockRulesKey];
    [defaults setObject:legacy.array forKey:WCAtlasMessageBlockUsersKey];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                       object:WCAtlasMessageBlockRulesKey];
}

NSString *WCAtlasMessageBlockSummaryForConversation(NSString *username) {
    NSArray<NSString *> *types = WCAtlasMessageBlockTypesForConversation(username);
    if ([types containsObject:WCAtlasMessageBlockAllType]) return @"全部消息";
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSDictionary *option in WCAtlasMessageBlockTypeOptions()) {
        if ([types containsObject:option[@"id"]]) [titles addObject:option[@"title"]];
    }
    return titles.count > 0 ? [titles componentsJoinedByString:@"、"] : @"未启用";
}

static UIView *WCAtlasMessageBlockAvatar(NSString *username) {
    id contact = WCAtlasPrivateContact(username);
    UIView *nativeAvatar = WCAtlasPrivateContactAvatarView(contact, username, YES);
    if (nativeAvatar) return nativeAvatar;
    UIImageView *fallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:
        [username hasSuffix:@"@chatroom"] ? @"person.3.fill" : @"person.crop.circle.fill"]];
    fallback.tintColor = UIColor.tertiaryLabelColor;
    fallback.contentMode = UIViewContentModeScaleAspectFill;
    return fallback;
}

@interface WCAtlasMessageBlockConversationCell : UITableViewCell
@property (nonatomic, strong) UIView *avatarContainer;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
- (void)configureUsername:(NSString *)username;
@end

@implementation WCAtlasMessageBlockConversationCell
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        _avatarContainer = [UIView new];
        _avatarContainer.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarContainer.clipsToBounds = YES;
        _avatarContainer.layer.cornerRadius = 10.0;
        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _summaryLabel = [UILabel new];
        _summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _summaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _summaryLabel.textColor = UIColor.secondaryLabelColor;
        [self.contentView addSubview:_avatarContainer];
        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_summaryLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_avatarContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_avatarContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarContainer.widthAnchor constraintEqualToConstant:44.0],
            [_avatarContainer.heightAnchor constraintEqualToConstant:44.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarContainer.trailingAnchor constant:12.0],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-34.0],
            [_nameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-1.0],
            [_summaryLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_summaryLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-34.0],
            [_summaryLabel.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:2.0],
        ]];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}
- (void)configureUsername:(NSString *)username {
    for (UIView *view in self.avatarContainer.subviews) [view removeFromSuperview];
    UIView *avatar = WCAtlasMessageBlockAvatar(username);
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.avatarContainer addSubview:avatar];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.topAnchor constraintEqualToAnchor:self.avatarContainer.topAnchor],
        [avatar.bottomAnchor constraintEqualToAnchor:self.avatarContainer.bottomAnchor],
        [avatar.leadingAnchor constraintEqualToAnchor:self.avatarContainer.leadingAnchor],
        [avatar.trailingAnchor constraintEqualToAnchor:self.avatarContainer.trailingAnchor],
    ]];
    self.nameLabel.text = WCAtlasSendConfirmationDisplayName(username);
    self.summaryLabel.text = WCAtlasMessageBlockSummaryForConversation(username);
}
@end

@interface WCAtlasMessageBlockTypeViewController : WCAtlasCardTableViewController
@property (nonatomic, copy) NSString *username;
- (instancetype)initWithUsername:(NSString *)username;
@end


@implementation WCAtlasMessageBlockTypeViewController
- (instancetype)initWithUsername:(NSString *)username {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) _username = [username copy];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"屏蔽消息类型"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return 1 + WCAtlasMessageBlockTypeOptions().count;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section; return @"取消全部选项会移除此会话的屏蔽规则。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockType"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BlockType"];
    NSArray *selected = WCAtlasMessageBlockTypesForConversation(self.username);
    NSString *identifier = indexPath.row == 0 ? WCAtlasMessageBlockAllType : WCAtlasMessageBlockTypeOptions()[indexPath.row - 1][@"id"];
    cell.textLabel.text = indexPath.row == 0 ? @"全部消息" : WCAtlasMessageBlockTypeOptions()[indexPath.row - 1][@"title"];
    cell.accessoryType = [selected containsObject:identifier] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.textLabel.textColor = indexPath.row > 0 && [selected containsObject:WCAtlasMessageBlockAllType]
        ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSMutableOrderedSet *selected = [NSMutableOrderedSet orderedSetWithArray:WCAtlasMessageBlockTypesForConversation(self.username)];
    if (indexPath.row == 0) {
        if ([selected containsObject:WCAtlasMessageBlockAllType]) [selected removeAllObjects];
        else { [selected removeAllObjects]; [selected addObject:WCAtlasMessageBlockAllType]; }
    } else {
        NSString *identifier = WCAtlasMessageBlockTypeOptions()[indexPath.row - 1][@"id"];
        [selected removeObject:WCAtlasMessageBlockAllType];
        if ([selected containsObject:identifier]) [selected removeObject:identifier];
        else [selected addObject:identifier];
    }
    WCAtlasMessageBlockSetTypesForConversation(self.username, selected.array);
    [tableView reloadData];
}
@end

UIViewController *WCAtlasMessageBlockTypeController(NSString *username) {
    return [[WCAtlasMessageBlockTypeViewController alloc] initWithUsername:username];
}

@interface WCAtlasMessageBlockViewController () <UISearchBarDelegate>
@property (nonatomic, copy) NSArray<NSString *> *allUsernames;
@property (nonatomic, copy) NSArray<NSString *> *friendUsernames;
@property (nonatomic, copy) NSArray<NSString *> *groupUsernames;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation WCAtlasMessageBlockViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"屏蔽会话";
    self.tableView.rowHeight = 62.0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addConversation)];
    self.searchBar = [UISearchBar new];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索名称或 username";
    WCAtlasInstallSearchBarInTableView(self.searchBar, self.tableView);
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadRules]; }
- (void)reloadRules {
    self.allUsernames = [WCAtlasMessageBlockedConversations() sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        return [WCAtlasSendConfirmationDisplayName(left) localizedCaseInsensitiveCompare:
                WCAtlasSendConfirmationDisplayName(right)];
    }];
    [self applyQuery:self.searchBar.text];
}
- (void)applyQuery:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray *visible = trimmed.length == 0 ? self.allUsernames : [self.allUsernames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *username, __unused NSDictionary *bindings) {
        return [username localizedCaseInsensitiveContainsString:trimmed] ||
               [WCAtlasSendConfirmationDisplayName(username) localizedCaseInsensitiveContainsString:trimmed];
    }]];
    self.friendUsernames = [visible filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *username, __unused NSDictionary *bindings) { return ![username hasSuffix:@"@chatroom"]; }]];
    self.groupUsernames = [visible filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *username, __unused NSDictionary *bindings) { return [username hasSuffix:@"@chatroom"]; }]];
    [self.tableView reloadData];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { (void)searchBar; [self applyQuery:searchText]; }
- (void)addConversation {
    UIViewController *picker = WCAtlasCreateConversationPicker(@"添加屏蔽会话", @"新选择的会话默认屏蔽全部消息，再次点击可移除。", ^BOOL(NSString *username) {
        return WCAtlasMessageBlockTypesForConversation(username).count > 0;
    }, ^(NSString *username) {
        BOOL exists = WCAtlasMessageBlockTypesForConversation(username).count > 0;
        WCAtlasMessageBlockSetTypesForConversation(username, exists ? @[] : @[WCAtlasMessageBlockAllType]);
    });
    [self.navigationController pushViewController:picker animated:YES];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section == 0 ? self.friendUsernames.count : self.groupUsernames.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) return nil;
    return section == 0 ? @"好友" : @"群聊";
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView numberOfRowsInSection:section] == 0 ? 0.01 : UITableViewAutomaticDimension;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section != 1) return nil;
    return self.allUsernames.count > 0 ? @"点击会话选择屏蔽类型，左滑可移除。" : @"尚未添加屏蔽会话。";
}
- (NSString *)usernameAtIndexPath:(NSIndexPath *)indexPath { NSArray *items = indexPath.section == 0 ? self.friendUsernames : self.groupUsernames; return indexPath.row < (NSInteger)items.count ? items[indexPath.row] : nil; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCAtlasMessageBlockConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockedConversation"];
    if (!cell) cell = [[WCAtlasMessageBlockConversationCell alloc] initWithReuseIdentifier:@"BlockedConversation"];
    [cell configureUsername:[self usernameAtIndexPath:indexPath]];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController pushViewController:WCAtlasMessageBlockTypeController([self usernameAtIndexPath:indexPath]) animated:YES];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; NSString *username = [self usernameAtIndexPath:indexPath]; __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"移除" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completion)(BOOL)) {
        WCAtlasMessageBlockSetTypesForConversation(username, @[]); [weakSelf reloadRules]; completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
@end
