#import "WCAtlasSendConfirmationViewController.h"
#import "WCAtlasSendConfirmation.h"
#import "WCAtlasAccount.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasPrivateAPI.h"
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

static BOOL WCAtlasSendConfirmationBooleanValue(id object, NSString *selectorName, BOOL *available) {
    if (available) *available = NO;
    SEL selector = NSSelectorFromString(selectorName);
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return NO;
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] != 'B' && returnType[0] != 'c') return NO;
    if (available) *available = YES;
    @try { return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { if (available) *available = NO; return NO; }
}

static UIView *WCAtlasSendConfirmationAvatarView(NSString *username, BOOL group) {
    id contact = WCAtlasPrivateContact(username);
    UIView *nativeView = WCAtlasPrivateContactAvatarView(contact, username, YES);
    if (nativeView) return nativeView;
    UIImage *fallbackImage = [UIImage systemImageNamed:
        group ? @"person.3.fill" : @"person.crop.circle.fill"];
    UIImageView *fallback = [[UIImageView alloc] initWithImage:fallbackImage];
    fallback.tintColor = UIColor.tertiaryLabelColor;
    fallback.contentMode = UIViewContentModeScaleAspectFill;
    return fallback;
}

static NSDictionary *WCAtlasSendConfirmationConversation(id candidate, BOOL groupHint) {
    NSString *username = [candidate isKindOfClass:NSString.class] ? candidate :
        WCAtlasPrivateContactUserName(candidate);
    id contact = [candidate isKindOfClass:NSString.class] ? WCAtlasPrivateContact(username) : candidate;
    if (username.length == 0) username = WCAtlasPrivateContactUserName(contact);
    if (username.length == 0 || [username isEqualToString:WCAtlasCurrentUserWXID()] || [username isEqualToString:@"filehelper"]) return nil;
    BOOL group = groupHint || [username hasSuffix:@"@chatroom"];
    BOOL chatroomCheckAvailable = NO;
    BOOL isChatroom = WCAtlasSendConfirmationBooleanValue(contact, @"isChatroom", &chatroomCheckAvailable);
    if (chatroomCheckAvailable) group = group || isChatroom;
    if (!group) {
        BOOL singleCheckAvailable = NO;
        BOOL isSingleContact = WCAtlasSendConfirmationBooleanValue(contact, @"isWeixinSingleConatct", &singleCheckAvailable);
        if (singleCheckAvailable && !isSingleContact) return nil;
    }
    NSString *displayName = WCAtlasPrivateContactDisplayName(contact, username);
    return @{ @"username": username, @"name": displayName, @"group": @(group) };
}

@interface WCAtlasSendConfirmationConversationCell : UITableViewCell
@property (nonatomic, strong) UIView *avatarContainer;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *usernameLabel;
- (void)configureWithUsername:(NSString *)username name:(NSString *)name group:(BOOL)group;
@end

@implementation WCAtlasSendConfirmationConversationCell

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        _avatarContainer = [UIView new];
        _avatarContainer.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarContainer.clipsToBounds = YES;
        _avatarContainer.layer.cornerRadius = 22.0;
        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _usernameLabel = [UILabel new];
        _usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _usernameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _usernameLabel.textColor = UIColor.secondaryLabelColor;
        [self.contentView addSubview:_avatarContainer];
        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_usernameLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_avatarContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_avatarContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarContainer.widthAnchor constraintEqualToConstant:44.0],
            [_avatarContainer.heightAnchor constraintEqualToConstant:44.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarContainer.trailingAnchor constant:12.0],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],
            [_nameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-1.0],
            [_usernameLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_usernameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],
            [_usernameLabel.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:2.0],
        ]];
    }
    return self;
}

- (void)configureWithUsername:(NSString *)username name:(NSString *)name group:(BOOL)group {
    for (UIView *view in self.avatarContainer.subviews) [view removeFromSuperview];
    UIView *avatar = WCAtlasSendConfirmationAvatarView(username, group);
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.avatarContainer addSubview:avatar];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.topAnchor constraintEqualToAnchor:self.avatarContainer.topAnchor],
        [avatar.bottomAnchor constraintEqualToAnchor:self.avatarContainer.bottomAnchor],
        [avatar.leadingAnchor constraintEqualToAnchor:self.avatarContainer.leadingAnchor],
        [avatar.trailingAnchor constraintEqualToAnchor:self.avatarContainer.trailingAnchor],
    ]];
    self.nameLabel.text = name;
    self.usernameLabel.text = username;
}

@end

@interface WCAtlasSendConfirmationConversationPicker : WCAtlasCardTableViewController <UISearchBarDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *allItems;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleFriends;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleGroups;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *pickerTitle;
@property (nonatomic, copy) NSString *pickerFooter;
@property (nonatomic, copy) WCAtlasConversationPickerSelectedBlock selectedBlock;
@property (nonatomic, copy) WCAtlasConversationPickerToggleBlock toggleBlock;
@property (nonatomic, copy, nullable) dispatch_block_t selectAllBlock;
@property (nonatomic, copy, nullable) dispatch_block_t invertSelectionBlock;
@property (nonatomic, copy, nullable) dispatch_block_t completionBlock;
@property (nonatomic, assign) BOOL groupsOnly;
@property (nonatomic, assign) BOOL friendsOnly;
- (instancetype)initWithTitle:(NSString *)title
                       footer:(NSString *)footer
                     selected:(WCAtlasConversationPickerSelectedBlock)selected
                       toggle:(WCAtlasConversationPickerToggleBlock)toggle;
@end

@implementation WCAtlasSendConfirmationConversationPicker

- (instancetype)initWithTitle:(NSString *)title
                       footer:(NSString *)footer
                     selected:(WCAtlasConversationPickerSelectedBlock)selected
                       toggle:(WCAtlasConversationPickerToggleBlock)toggle {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _pickerTitle = [title copy];
        _pickerFooter = [footer copy];
        _selectedBlock = [selected copy];
        _toggleBlock = [toggle copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.pickerTitle.length > 0 ? self.pickerTitle :
        (self.groupsOnly ? @"选择群聊" : (self.friendsOnly ? @"选择好友" : @"选择好友或群聊"));
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 60.0;
    if (self.selectAllBlock || self.invertSelectionBlock) {
        NSMutableArray<UIBarButtonItem *> *bulkItems = [NSMutableArray array];
        if (self.selectAllBlock) {
            [bulkItems addObject:[[UIBarButtonItem alloc] initWithTitle:@"全选"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(selectAllTapped)]];
        }
        if (self.invertSelectionBlock) {
            [bulkItems addObject:[[UIBarButtonItem alloc] initWithTitle:@"反选"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(invertSelectionTapped)]];
        }
        self.navigationItem.rightBarButtonItems = bulkItems;
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    }
    self.searchBar = [UISearchBar new];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = self.groupsOnly ? @"搜索群聊或 username" :
        (self.friendsOnly ? @"搜索好友或 username" : @"搜索好友、群聊或 username");
    WCAtlasInstallSearchBarInTableView(self.searchBar, self.tableView);
    [self loadConversations];
}

- (void)done {
    if (self.completionBlock) self.completionBlock();
    else [self.navigationController popViewControllerAnimated:YES];
}

- (void)selectAllTapped {
    if (self.selectAllBlock) self.selectAllBlock();
    [self.tableView reloadData];
}

- (void)invertSelectionTapped {
    if (self.invertSelectionBlock) self.invertSelectionBlock();
    [self.tableView reloadData];
}

- (void)loadConversations {
    NSArray *friends = WCAtlasPrivateContactList();
    NSArray *groups = WCAtlasPrivateGroupContactList();
    NSMutableDictionary<NSString *, NSDictionary *> *deduplicated = [NSMutableDictionary dictionary];
    if (!self.groupsOnly) {
        for (id candidate in friends) {
            NSDictionary *item = WCAtlasSendConfirmationConversation(candidate, NO);
            if (item) deduplicated[item[@"username"]] = item;
        }
    }
    if (!self.friendsOnly) {
        for (id candidate in groups) {
            NSDictionary *item = WCAtlasSendConfirmationConversation(candidate, YES);
            if (item) deduplicated[item[@"username"]] = item;
        }
    }
    self.allItems = [deduplicated.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        BOOL leftGroup = [left[@"group"] boolValue], rightGroup = [right[@"group"] boolValue];
        if (leftGroup != rightGroup) return leftGroup ? NSOrderedDescending : NSOrderedAscending;
        return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];
    [self applyQuery:self.searchBar.text];
}

- (void)applyQuery:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray *matches = trimmed.length == 0 ? self.allItems : [self.allItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        (void)bindings;
        return [item[@"name"] localizedCaseInsensitiveContainsString:trimmed] ||
               [item[@"username"] localizedCaseInsensitiveContainsString:trimmed];
    }]];
    self.visibleFriends = [matches filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, __unused NSDictionary *bindings) {
        return ![item[@"group"] boolValue];
    }]];
    self.visibleGroups = [matches filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, __unused NSDictionary *bindings) {
        return [item[@"group"] boolValue];
    }]];
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { (void)searchBar; [self applyQuery:searchText]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return (self.groupsOnly || self.friendsOnly) ? 1 : 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (self.groupsOnly) return self.visibleGroups.count;
    if (self.friendsOnly) return self.visibleFriends.count;
    return section == 0 ? self.visibleFriends.count : self.visibleGroups.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) return nil;
    if (self.groupsOnly) return @"群聊";
    if (self.friendsOnly) return @"好友";
    return section == 0 ? @"好友" : @"群聊";
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView numberOfRowsInSection:section] == 0 ? 0.01 : UITableViewAutomaticDimension;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    NSInteger footerSection = (self.groupsOnly || self.friendsOnly) ? 0 : 1;
    if (section != footerSection) return nil;
    NSString *emptyText = self.groupsOnly ? @"微信尚未返回可用的群聊列表。" :
        (self.friendsOnly ? @"微信尚未返回可用的好友列表。" : @"微信尚未返回可用的好友或群聊列表。");
    return self.allItems.count > 0 ? (self.pickerFooter ?: @"点击选择或取消会话。") : emptyText;
}
- (NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *items = self.groupsOnly ? self.visibleGroups :
        (self.friendsOnly ? self.visibleFriends : (indexPath.section == 0 ? self.visibleFriends : self.visibleGroups));
    return indexPath.row < (NSInteger)items.count ? items[indexPath.row] : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCAtlasSendConfirmationConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationPicker"];
    if (!cell) cell = [[WCAtlasSendConfirmationConversationCell alloc] initWithReuseIdentifier:@"ConversationPicker"];
    NSDictionary *item = [self itemAtIndexPath:indexPath];
    NSString *username = item[@"username"];
    [cell configureWithUsername:username name:item[@"name"] group:[item[@"group"] boolValue]];
    cell.accessoryType = self.selectedBlock && self.selectedBlock(username) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *username = [self itemAtIndexPath:indexPath][@"username"];
    if (self.toggleBlock) self.toggleBlock(username);
    [tableView reloadData];
}

@end

UIViewController *WCAtlasCreateConversationPicker(NSString *title,
                                                NSString *footer,
                                                WCAtlasConversationPickerSelectedBlock selected,
                                                WCAtlasConversationPickerToggleBlock toggle) {
    return [[WCAtlasSendConfirmationConversationPicker alloc] initWithTitle:title
                                                                   footer:footer
                                                                 selected:selected
                                                                   toggle:toggle];
}

UIViewController *WCAtlasCreateGroupPicker(NSString *title,
                                         NSString *footer,
                                         WCAtlasConversationPickerSelectedBlock selected,
                                         WCAtlasConversationPickerToggleBlock toggle) {
    WCAtlasSendConfirmationConversationPicker *picker = [[WCAtlasSendConfirmationConversationPicker alloc] initWithTitle:title
                                                                                                                 footer:footer
                                                                                                               selected:selected
                                                                                                                 toggle:toggle];
    picker.groupsOnly = YES;
    return picker;
}

UIViewController *WCAtlasCreateFriendPicker(NSString *title,
                                          NSString *footer,
                                          WCAtlasConversationPickerSelectedBlock selected,
                                          WCAtlasConversationPickerToggleBlock toggle) {
    WCAtlasSendConfirmationConversationPicker *picker = [[WCAtlasSendConfirmationConversationPicker alloc] initWithTitle:title
                                                                                                                 footer:footer
                                                                                                               selected:selected
                                                                                                                 toggle:toggle];
    picker.friendsOnly = YES;
    return picker;
}

void WCAtlasConfigureConversationPickerBulkActions(UIViewController *picker,
                                                  dispatch_block_t selectAll,
                                                  dispatch_block_t invertSelection) {
    if (![picker isKindOfClass:WCAtlasSendConfirmationConversationPicker.class]) return;
    WCAtlasSendConfirmationConversationPicker *conversationPicker =
        (WCAtlasSendConfirmationConversationPicker *)picker;
    conversationPicker.selectAllBlock = selectAll;
    conversationPicker.invertSelectionBlock = invertSelection;
}

void WCAtlasConfigureConversationPickerCompletion(UIViewController *picker,
                                                 dispatch_block_t completion) {
    if (![picker isKindOfClass:WCAtlasSendConfirmationConversationPicker.class]) return;
    ((WCAtlasSendConfirmationConversationPicker *)picker).completionBlock = completion;
}

@interface WCAtlasSendConfirmationViewController ()
@property (nonatomic, copy) NSArray<NSString *> *usernames;
@property (nonatomic, copy) NSArray<NSString *> *friendUsernames;
@property (nonatomic, copy) NSArray<NSString *> *groupUsernames;
@end

@implementation WCAtlasSendConfirmationViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"发送前确认";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 60.0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addConversation)];
    [self reloadConversations];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadConversations];
}

- (void)reloadConversations {
    self.usernames = WCAtlasSendConfirmationProtectedConversations();
    self.friendUsernames = [self.usernames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *username, __unused NSDictionary *bindings) {
        return ![username hasSuffix:@"@chatroom"];
    }]];
    self.groupUsernames = [self.usernames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *username, __unused NSDictionary *bindings) {
        return [username hasSuffix:@"@chatroom"];
    }]];
    [self.tableView reloadData];
}

- (void)addConversation {
    if (WCAtlasCurrentUserWXID().length == 0) {
        [self showMessage:@"尚未识别当前微信账号，请返回 WCAtlas 设置后重试。" title:@"无法添加"];
        return;
    }
    UIViewController *picker = WCAtlasCreateConversationPicker(@"选择好友或群聊",
                                                              @"勾选的会话会立即开启发送前确认；再次点击可取消。",
                                                              ^BOOL(NSString *username) {
        return [WCAtlasSendConfirmationProtectedConversations() containsObject:username];
    }, ^(NSString *username) {
        BOOL protectedConversation = [WCAtlasSendConfirmationProtectedConversations() containsObject:username];
        WCAtlasSendConfirmationSetProtected(username, !protectedConversation);
    });
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? self.friendUsernames.count : self.groupUsernames.count;
}

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
    return self.usernames.count > 0
        ? @"只保存会话 username；显示名称在运行时读取。点击右上角可继续勾选，左滑可移除。"
        : @"尚未设置受保护会话。点击右上角，从好友和群聊列表中勾选。";
}

- (NSString *)usernameAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *usernames = indexPath.section == 0 ? self.friendUsernames : self.groupUsernames;
    return indexPath.row < (NSInteger)usernames.count ? usernames[indexPath.row] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier = @"SendConfirmationConversation";
    WCAtlasSendConfirmationConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) cell = [[WCAtlasSendConfirmationConversationCell alloc] initWithReuseIdentifier:reuseIdentifier];
    NSString *username = [self usernameAtIndexPath:indexPath];
    [cell configureWithUsername:username name:WCAtlasSendConfirmationDisplayName(username) group:[username hasSuffix:@"@chatroom"]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    NSString *username = [self usernameAtIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                          title:@"移除"
                                                                        handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        WCAtlasSendConfirmationSetProtected(username, NO);
        [weakSelf reloadConversations];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

@end
