#import "WCAtlasAutomationViewController.h"
#import "WCAtlasAutomation.h"
#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasSendConfirmationViewController.h"

static NSString *WCAtlasAutomationSourceName(WCAtlasAutomationSourceType type) {
    switch (type) {
        case WCAtlasAutomationSourceTypeLibraryText: return @"消息库";
        case WCAtlasAutomationSourceTypeJavaScript: return @"JavaScript";
        default: return @"固定文字";
    }
}

@interface WCAtlasAutomationLibraryPicker : UITableViewController
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyItem *> *items;
@property (nonatomic, copy) void (^selectionHandler)(WCAtlasQuickReplyItem *item);
- (instancetype)initWithSelectionHandler:(void (^)(WCAtlasQuickReplyItem *item))handler;
@end

@implementation WCAtlasAutomationLibraryPicker

- (instancetype)initWithSelectionHandler:(void (^)(WCAtlasQuickReplyItem *))handler {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    _selectionHandler = [handler copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择消息库素材";
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(WCAtlasQuickReplyItem *item,
                                                                     NSDictionary *bindings) {
        (void)bindings;
        return item.type == WCAtlasQuickReplyTypeText || item.type == WCAtlasQuickReplyTypeImage ||
            item.type == WCAtlasQuickReplyTypeVideo || item.type == WCAtlasQuickReplyTypeVoice ||
            item.type == WCAtlasQuickReplyTypeJavaScript;
    }];
    self.items = [[WCAtlasQuickReplyStore.sharedStore.items filteredArrayUsingPredicate:predicate]
        sortedArrayUsingComparator:^NSComparisonResult(WCAtlasQuickReplyItem *first,
                                                         WCAtlasQuickReplyItem *second) {
        return [first.title localizedStandardCompare:second.title];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return MAX((NSInteger)self.items.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.items.count ? @"支持文字、图片、视频、语音和 JS 脚本。" : @"消息库中暂无可用素材。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"automation-library"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                             reuseIdentifier:@"automation-library"];
    if (self.items.count == 0) {
        cell.textLabel.text = @"暂无可用素材";
        cell.detailTextLabel.text = @"请先在消息库添加内容";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    WCAtlasQuickReplyItem *item = self.items[indexPath.row];
    NSString *fallback = item.type == WCAtlasQuickReplyTypeJavaScript ? @"JS 脚本" :
        (item.type == WCAtlasQuickReplyTypeImage ? @"图片素材" :
         (item.type == WCAtlasQuickReplyTypeVideo ? @"视频素材" :
          (item.type == WCAtlasQuickReplyTypeVoice ? @"语音素材" : @"文字素材")));
    cell.textLabel.text = item.title.length ? item.title : fallback;
    cell.detailTextLabel.text = item.type == WCAtlasQuickReplyTypeText ? item.text : fallback;
    cell.detailTextLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.items.count) return;
    if (self.selectionHandler) self.selectionHandler(self.items[indexPath.row]);
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@interface WCAtlasAutomationEditorViewController : UITableViewController <UITextFieldDelegate, UITextViewDelegate>
@property (nonatomic, strong) WCAtlasAutomationTask *task;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *selectedTargets;
@property (nonatomic, strong) UISegmentedControl *sourceControl;
@property (nonatomic, strong) UITextView *contentView;
@property (nonatomic, strong) UISegmentedControl *repeatControl;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UITextField *keywordField;
@property (nonatomic, strong) UISegmentedControl *keywordScopeControl;
@property (nonatomic, assign) WCAtlasAutomationTriggerMode triggerMode;
@property (nonatomic, assign) WCAtlasAutomationSourceType displayedSource;
@property (nonatomic, copy) void (^saveHandler)(WCAtlasAutomationTask *task);
- (instancetype)initWithTask:(WCAtlasAutomationTask *)task
                  triggerMode:(WCAtlasAutomationTriggerMode)triggerMode
                  saveHandler:(void (^)(WCAtlasAutomationTask *task))saveHandler;
@end

@implementation WCAtlasAutomationEditorViewController

- (instancetype)initWithTask:(WCAtlasAutomationTask *)task
                  triggerMode:(WCAtlasAutomationTriggerMode)triggerMode
                  saveHandler:(void (^)(WCAtlasAutomationTask *))saveHandler {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    _task = task.copy;
    _triggerMode = triggerMode;
    _task.triggerMode = triggerMode;
    _saveHandler = [saveHandler copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"关键词回复" : @"定时消息";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTask)];

    self.enabledSwitch = [UISwitch new];
    self.enabledSwitch.on = self.task.isEnabled;
    self.nameField = [self fieldWithPlaceholder:@"任务名称" text:self.task.name];
    NSArray *savedTargets = self.task.targetUserNames.count ? self.task.targetUserNames :
        (self.task.targetUserName.length ? @[self.task.targetUserName] : @[]);
    self.selectedTargets = [NSMutableOrderedSet orderedSetWithArray:savedTargets];
    self.sourceControl = [[UISegmentedControl alloc] initWithItems:@[@"固定文字", @"消息库", @"JS"]];
    self.sourceControl.selectedSegmentIndex = self.task.sourceType;
    self.displayedSource = self.task.sourceType;
    [self.sourceControl addTarget:self action:@selector(sourceChanged:) forControlEvents:UIControlEventValueChanged];
    self.contentView = [UITextView new];
    self.contentView.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.contentView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.contentView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.contentView.delegate = self;
    self.repeatControl = [[UISegmentedControl alloc] initWithItems:@[@"仅一次", @"每天"]];
    self.repeatControl.selectedSegmentIndex = self.task.repeatMode;
    self.keywordField = [self fieldWithPlaceholder:@"收到消息包含的关键词" text:self.task.triggerKeyword];
    self.keywordScopeControl = [[UISegmentedControl alloc] initWithItems:@[@"白名单", @"黑名单"]];
    self.keywordScopeControl.selectedSegmentIndex = self.task.keywordScopeMode;
    [self.keywordScopeControl addTarget:self action:@selector(keywordScopeChanged:) forControlEvents:UIControlEventValueChanged];
    self.datePicker = [UIDatePicker new];
    self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 13.4, *)) self.datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    self.datePicker.date = self.task.nextFireDate ?: [NSDate dateWithTimeIntervalSinceNow:300];
    [self updateContentForSource];
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.text = text;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    return field;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 5; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) return 2;
    if (section == 2) return 2;
    if (section == 3) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (section == 2) return self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"回复内容" : @"发送内容";
    return @[@"状态", @"任务与会话范围", @"", @"触发设置", @"说明"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) {
        if (self.triggerMode != WCAtlasAutomationTriggerModeKeyword)
            return @"可同时选择多个好友或群聊；脚本不能更改发送对象。";
        return self.keywordScopeControl.selectedSegmentIndex == WCAtlasAutomationKeywordScopeModeWhitelist
            ? @"白名单：只回复所选好友或群聊，至少选择一个会话。"
            : @"黑名单：回复未选中的会话；不选择表示不排除任何会话。";
    }
    if (section == 2 && self.sourceControl.selectedSegmentIndex == WCAtlasAutomationSourceTypeJavaScript)
        return @"main(input) 可返回文字，或 {type:'text|image|video|voice', text/url/path}；URL 可直接指向 PHP 等媒体响应。";
    if (section == 3) return self.triggerMode == WCAtlasAutomationTriggerModeKeyword
        ? @"匹配收到的普通文字消息，并自动忽略本人消息与重复回调。好友与群聊统一按黑白名单判断。"
        : @"微信被系统挂起或结束后无法保证整点执行；恢复运行时会补跑逾期任务。";
    if (section == 4) return self.triggerMode == WCAtlasAutomationTriggerModeKeyword
        ? @"关键词回复与定时消息独立保存、独立启用；两项功能可以同时工作。"
        : @"启用任务后会自动复用“保持后台运行”。单次任务完成后自动关闭。";
    return nil;
}

- (UITableViewCell *)controlCell:(UIView *)control identifier:(NSString *)identifier {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:identifier];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:control];
    [NSLayoutConstraint activateConstraints:@[
        [control.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
        [control.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
        [control.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
        [control.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
    ]];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"enabled"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"enabled"];
        cell.textLabel.text = @"启用任务";
        cell.accessoryView = self.enabledSwitch;
        return cell;
    }
    if (indexPath.section == 1 && indexPath.row == 0) return [self controlCell:self.nameField identifier:@"name"];
    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"targets"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"targets"];
        cell.textLabel.text = self.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
            self.keywordScopeControl.selectedSegmentIndex == WCAtlasAutomationKeywordScopeModeBlacklist
            ? @"选择要排除的会话" : @"选择好友或群聊";
        BOOL blacklist = self.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
            self.keywordScopeControl.selectedSegmentIndex == WCAtlasAutomationKeywordScopeModeBlacklist;
        if (self.selectedTargets.count) {
            cell.detailTextLabel.text = blacklist
                ? [NSString stringWithFormat:@"已排除 %lu 个", (unsigned long)self.selectedTargets.count]
                : [NSString stringWithFormat:@"已选 %lu 个", (unsigned long)self.selectedTargets.count];
        } else {
            cell.detailTextLabel.text = blacklist ? @"不排除会话" : @"未选择";
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (indexPath.section == 2 && indexPath.row == 0)
        return [self controlCell:self.sourceControl identifier:@"source"];
    if (indexPath.section == 2) {
        if (self.sourceControl.selectedSegmentIndex == WCAtlasAutomationSourceTypeLibraryText) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"library"];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"library"];
            cell.textLabel.text = @"选择消息库素材";
            cell.detailTextLabel.text = [self selectedLibraryTitle];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        return [self controlCell:self.contentView identifier:@"content"];
    }
    if (indexPath.section == 3 && self.triggerMode == WCAtlasAutomationTriggerModeKeyword) {
        if (indexPath.row == 0) return [self controlCell:self.keywordField identifier:@"keyword"];
        return [self controlCell:self.keywordScopeControl identifier:@"keyword-scope"];
    }
    if (indexPath.section == 3)
        return [self controlCell:indexPath.row == 0 ? self.repeatControl : self.datePicker
                       identifier:indexPath.row == 0 ? @"repeat" : @"date"];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"notice"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"notice"];
    cell.textLabel.text = self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"收到消息时触发" : @"进程内定时调度";
    cell.detailTextLabel.text = self.triggerMode == WCAtlasAutomationTriggerModeKeyword
        ? @"只处理微信传入的普通文字消息，不会根据历史消息补发。"
        : @"不会建立系统级定时任务，也不会绕过 iOS 后台限制。";
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.section == 2 && indexPath.row == 1 &&
        self.sourceControl.selectedSegmentIndex != WCAtlasAutomationSourceTypeLibraryText) return 190;
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 1) { [self presentTargetPicker]; return; }
    if (indexPath.section != 2 || indexPath.row != 1 ||
        self.sourceControl.selectedSegmentIndex != WCAtlasAutomationSourceTypeLibraryText) return;
    __weak typeof(self) weakSelf = self;
    WCAtlasAutomationLibraryPicker *picker = [[WCAtlasAutomationLibraryPicker alloc]
        initWithSelectionHandler:^(WCAtlasQuickReplyItem *item) {
        weakSelf.task.libraryItemIdentifier = item.identifier;
        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                          withRowAnimation:UITableViewRowAnimationNone];
    }];
    [self.navigationController pushViewController:picker animated:YES];
}

- (NSString *)selectedLibraryTitle {
    for (WCAtlasQuickReplyItem *item in WCAtlasQuickReplyStore.sharedStore.items) {
        if ([item.identifier isEqualToString:self.task.libraryItemIdentifier])
            return item.title.length ? item.title : @"未命名素材";
    }
    return @"未选择";
}

- (void)presentTargetPicker {
    __weak typeof(self) weakSelf = self;
    __block UIViewController *picker = nil;
    BOOL blacklist = self.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
        self.keywordScopeControl.selectedSegmentIndex == WCAtlasAutomationKeywordScopeModeBlacklist;
    picker = WCAtlasCreateConversationPicker(blacklist ? @"选择排除会话" : @"选择接收会话",
        blacklist ? @"所选好友或群聊不会触发此关键词回复。" : @"可多选好友和群聊，完成后返回任务编辑页。",
        ^BOOL(NSString *userName) { return [weakSelf.selectedTargets containsObject:userName]; },
        ^(NSString *userName) {
            if ([weakSelf.selectedTargets containsObject:userName]) [weakSelf.selectedTargets removeObject:userName];
            else if (userName.length) [weakSelf.selectedTargets addObject:userName];
        });
    __weak UIViewController *weakPicker = picker;
    WCAtlasConfigureConversationPickerCompletion(picker, ^{
        [weakPicker.navigationController popViewControllerAnimated:YES];
        [weakSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:1]]
                                  withRowAnimation:UITableViewRowAnimationNone];
    });
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)keywordScopeChanged:(UISegmentedControl *)sender {
    (void)sender;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationFade];
}

- (void)sourceChanged:(UISegmentedControl *)sender {
    if (self.displayedSource == WCAtlasAutomationSourceTypeFixedText)
        self.task.fixedText = self.contentView.text ?: @"";
    else if (self.displayedSource == WCAtlasAutomationSourceTypeJavaScript)
        self.task.script = self.contentView.text ?: @"";
    self.displayedSource = sender.selectedSegmentIndex;
    [self updateContentForSource];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                  withRowAnimation:UITableViewRowAnimationFade];
}

- (void)updateContentForSource {
    if (self.sourceControl.selectedSegmentIndex == WCAtlasAutomationSourceTypeJavaScript)
        self.contentView.text = self.task.script;
    else if (self.sourceControl.selectedSegmentIndex == WCAtlasAutomationSourceTypeFixedText)
        self.contentView.text = self.task.fixedText;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法保存" message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveTask {
    NSString *(^trim)(NSString *) = ^NSString *(NSString *value) {
        return [value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    };
    BOOL keywordWhitelist = self.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
        self.keywordScopeControl.selectedSegmentIndex == WCAtlasAutomationKeywordScopeModeWhitelist;
    if (self.selectedTargets.count == 0 &&
        (self.triggerMode == WCAtlasAutomationTriggerModeScheduled || keywordWhitelist)) {
        [self showError:@"请至少选择一个好友或群聊。"]; return;
    }
    WCAtlasAutomationSourceType source = self.sourceControl.selectedSegmentIndex;
    if (source == WCAtlasAutomationSourceTypeLibraryText && self.task.libraryItemIdentifier.length == 0) {
        [self showError:@"请选择消息库素材。"]; return;
    }
    if (self.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
        trim(self.keywordField.text).length == 0) { [self showError:@"触发关键词不能为空。"]; return; }
    if (source != WCAtlasAutomationSourceTypeLibraryText && trim(self.contentView.text).length == 0) {
        [self showError:source == WCAtlasAutomationSourceTypeJavaScript ? @"JS 脚本不能为空。" : @"发送文字不能为空。"]; return;
    }
    self.task.name = trim(self.nameField.text).length ? trim(self.nameField.text) :
        (self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"关键词回复" : @"定时消息");
    self.task.targetUserNames = self.selectedTargets.array;
    self.task.targetUserName = self.selectedTargets.array.firstObject ?: @"";
    self.task.enabled = self.enabledSwitch.isOn;
    self.task.sourceType = source;
    if (source == WCAtlasAutomationSourceTypeFixedText) self.task.fixedText = self.contentView.text ?: @"";
    if (source == WCAtlasAutomationSourceTypeJavaScript) self.task.script = self.contentView.text ?: @"";
    self.task.repeatMode = self.repeatControl.selectedSegmentIndex;
    self.task.nextFireDate = self.datePicker.date;
    self.task.triggerMode = self.triggerMode;
    self.task.triggerKeyword = trim(self.keywordField.text);
    self.task.keywordScopeMode = self.keywordScopeControl.selectedSegmentIndex;
    if (self.saveHandler) self.saveHandler(self.task);
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@interface WCAtlasAutomationViewController ()
@property (nonatomic, copy) NSArray<WCAtlasAutomationTask *> *tasks;
@property (nonatomic, assign) WCAtlasAutomationTriggerMode triggerMode;
- (instancetype)initWithTriggerMode:(WCAtlasAutomationTriggerMode)triggerMode;
@end

@implementation WCAtlasAutomationViewController

- (instancetype)init { return [self initWithTriggerMode:WCAtlasAutomationTriggerModeScheduled]; }

- (instancetype)initWithTriggerMode:(WCAtlasAutomationTriggerMode)triggerMode {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    _triggerMode = triggerMode;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"关键词回复" : @"定时消息";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTask)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadTasks];
}

- (void)reloadTasks {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(WCAtlasAutomationTask *task,
                                                                     NSDictionary *bindings) {
        (void)bindings;
        return task.triggerMode == self.triggerMode;
    }];
    self.tasks = [WCAtlasAutomationManager.sharedManager.tasks filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return MAX((NSInteger)self.tasks.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.triggerMode == WCAtlasAutomationTriggerModeKeyword
        ? @"关键词回复与定时消息互相独立。右滑可试跑回复内容，左滑可删除。"
        : @"启用任务会自动请求微信后台保活。右滑可立即试跑，左滑可删除；示例模板删除后不会恢复。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"automation-task"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                             reuseIdentifier:@"automation-task"];
    if (self.tasks.count == 0) {
        cell.textLabel.text = @"暂无任务";
        cell.detailTextLabel.text = @"点按右上角 + 新建";
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    WCAtlasAutomationTask *task = self.tasks[indexPath.row];
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"MM-dd HH:mm";
    });
    cell.textLabel.text = task.name;
    NSString *schedule = task.triggerMode == WCAtlasAutomationTriggerModeKeyword
        ? [NSString stringWithFormat:@"%@：%@",
            task.keywordScopeMode == WCAtlasAutomationKeywordScopeModeBlacklist ? @"黑名单" : @"白名单",
            task.triggerKeyword.length ? task.triggerKeyword : @"未设置"]
        : (task.repeatMode == WCAtlasAutomationRepeatModeDaily
        ? [@"每天 " stringByAppendingString:[[formatter stringFromDate:task.nextFireDate] substringFromIndex:6]]
        : [formatter stringFromDate:task.nextFireDate]);
    NSUInteger targetCount = task.targetUserNames.count ?: (task.targetUserName.length ? 1 : 0);
    NSString *targetSummary = task.triggerMode == WCAtlasAutomationTriggerModeKeyword &&
        task.keywordScopeMode == WCAtlasAutomationKeywordScopeModeBlacklist
        ? [NSString stringWithFormat:@"排除 %lu 个会话", (unsigned long)targetCount]
        : [NSString stringWithFormat:@"%lu 个会话", (unsigned long)targetCount];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@%@", targetSummary,
        WCAtlasAutomationSourceName(task.sourceType), schedule,
        task.lastResult.length ? [@" · " stringByAppendingString:task.lastResult] : @""];
    cell.detailTextLabel.numberOfLines = 2;
    UISwitch *toggle = [UISwitch new];
    toggle.on = task.isEnabled;
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)addTask {
    WCAtlasAutomationTask *task = [WCAtlasAutomationTask new];
    task.triggerMode = self.triggerMode;
    task.name = self.triggerMode == WCAtlasAutomationTriggerModeKeyword ? @"关键词回复" : @"定时消息";
    [self editTask:task];
}

- (void)editTask:(WCAtlasAutomationTask *)task {
    __weak typeof(self) weakSelf = self;
    WCAtlasAutomationEditorViewController *editor = [[WCAtlasAutomationEditorViewController alloc]
        initWithTask:task triggerMode:self.triggerMode saveHandler:^(WCAtlasAutomationTask *saved) {
        [WCAtlasAutomationManager.sharedManager saveTask:saved];
        [weakSelf reloadTasks];
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < self.tasks.count) [self editTask:self.tasks[indexPath.row]];
}

- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag >= self.tasks.count) return;
    WCAtlasAutomationTask *task = self.tasks[sender.tag].copy;
    BOOL requiresTargets = task.triggerMode == WCAtlasAutomationTriggerModeScheduled ||
        task.keywordScopeMode == WCAtlasAutomationKeywordScopeModeWhitelist;
    if (sender.isOn && requiresTargets && task.targetUserNames.count == 0 && task.targetUserName.length == 0) {
        sender.on = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"请先编辑任务"
            message:@"启用前需要至少选择一个好友或群聊。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    task.enabled = sender.isOn;
    [WCAtlasAutomationManager.sharedManager saveTask:task];
    [self reloadTasks];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.tasks.count) return nil;
    WCAtlasAutomationTask *task = self.tasks[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:@"删除" handler:^(UIContextualAction *action, UIView *sourceView, void (^completion)(BOOL)) {
        (void)action; (void)sourceView;
        [WCAtlasAutomationManager.sharedManager deleteTaskWithIdentifier:task.identifier];
        [weakSelf reloadTasks];
        completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.tasks.count) return nil;
    WCAtlasAutomationTask *task = self.tasks[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *run = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
        title:@"试跑" handler:^(UIContextualAction *action, UIView *sourceView, void (^completion)(BOOL)) {
        (void)action; (void)sourceView;
        [WCAtlasAutomationManager.sharedManager runTaskNow:task];
        completion(YES);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [weakSelf reloadTasks]; });
    }];
    run.backgroundColor = UIColor.systemBlueColor;
    return [UISwipeActionsConfiguration configurationWithActions:@[run]];
}

@end

@implementation WCAtlasKeywordReplyViewController

- (instancetype)init { return [super initWithTriggerMode:WCAtlasAutomationTriggerModeKeyword]; }

@end
