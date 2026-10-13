#import "WCAtlasLongPressMenuViewController.h"

#import "WCAtlasEnhancements.h"

#import <objc/runtime.h>

static char WCAtlasLongPressMenuTitleAssociationKey;

@interface WCAtlasLongPressMenuViewController ()
@property (nonatomic, copy) NSArray<NSString *> *titles;
@end

@implementation WCAtlasLongPressMenuViewController

- (instancetype)init { return [self initWithStyle:UITableViewStyleInsetGrouped]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"长按菜单";
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self
                                                                             action:@selector(addMenuTitle)];
    self.navigationItem.rightBarButtonItems = @[self.editButtonItem, addItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTitles)
                                                 name:WCAtlasEnhancementDidChangeNotification
                                               object:nil];
    [self reloadTitles];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)reloadTitles {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *known = [defaults arrayForKey:WCAtlasLongPressMenuKnownTitlesKey] ?: @[];
    NSArray<NSString *> *manual = [defaults arrayForKey:WCAtlasLongPressMenuManualTitlesKey] ?: @[];
    NSArray<NSString *> *preferred = [defaults arrayForKey:WCAtlasLongPressMenuPreferredOrderKey] ?: @[];
    NSMutableArray<NSString *> *all = [NSMutableArray arrayWithArray:known];
    for (NSString *title in manual) if (![all containsObject:title]) [all addObject:title];
    NSMutableArray<NSString *> *ordered = [NSMutableArray arrayWithCapacity:all.count];
    for (NSString *title in preferred) if ([all containsObject:title] && ![ordered containsObject:title]) [ordered addObject:title];
    for (NSString *title in known) if (![ordered containsObject:title]) [ordered addObject:title];
    for (NSString *title in manual) if (![ordered containsObject:title]) [ordered addObject:title];
    self.titles = ordered;
    [self.tableView reloadData];
}

- (void)addMenuTitle {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"手动添加菜单"
                                                                   message:@"填写微信菜单显示的原名称；该项目出现时即可隐藏、排序或重命名。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"例如：复制";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *title = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (title.length == 0) return;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableArray<NSString *> *manual = [[defaults arrayForKey:WCAtlasLongPressMenuManualTitlesKey] mutableCopy] ?: [NSMutableArray array];
        NSArray<NSString *> *known = [defaults arrayForKey:WCAtlasLongPressMenuKnownTitlesKey] ?: @[];
        if (![known containsObject:title] && ![manual containsObject:title]) [manual addObject:title];
        [defaults setObject:manual forKey:WCAtlasLongPressMenuManualTitlesKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                            object:WCAtlasLongPressMenuManualTitlesKey];
        [weakSelf reloadTitles];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.titles.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"菜单项目"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.titles.count > 0
        ? @"关闭“显示”可隐藏菜单项；点按可重命名，编辑状态下可拖动排序。右上角可手动补充未获取到的原名称。"
        : @"请长按不同类型的消息自动获取菜单，或点右上角“+”手动添加原名称。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"menu-item"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"menu-item"];
    NSString *sourceTitle = self.titles[indexPath.row];
    NSDictionary *mapping = [[NSUserDefaults standardUserDefaults] dictionaryForKey:WCAtlasLongPressMenuTitleMapKey];
    NSString *renamedTitle = mapping[sourceTitle];
    BOOL manuallyAdded = [[[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasLongPressMenuManualTitlesKey] containsObject:sourceTitle];
    cell.textLabel.text = renamedTitle.length > 0 ? renamedTitle : sourceTitle;
    cell.detailTextLabel.text = renamedTitle.length > 0
        ? [@"原名称：" stringByAppendingString:sourceTitle]
        : (manuallyAdded ? @"手动添加的原名称" : @"自动获取的原名称");
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = UIColor.systemBlueColor;
    toggle.on = ![[[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasLongPressMenuHiddenTitlesKey] containsObject:sourceTitle];
    objc_setAssociatedObject(toggle, &WCAtlasLongPressMenuTitleAssociationKey, sourceTitle, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [toggle addTarget:self action:@selector(visibilityChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.showsReorderControl = YES;
    return cell;
}

- (void)visibilityChanged:(UISwitch *)sender {
    NSString *title = objc_getAssociatedObject(sender, &WCAtlasLongPressMenuTitleAssociationKey);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *hidden = [[defaults arrayForKey:WCAtlasLongPressMenuHiddenTitlesKey] mutableCopy] ?: [NSMutableArray array];
    if (sender.isOn) [hidden removeObject:title];
    else if (title.length > 0 && ![hidden containsObject:title]) [hidden addObject:title];
    [defaults setObject:hidden forKey:WCAtlasLongPressMenuHiddenTitlesKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasLongPressMenuHiddenTitlesKey];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    NSString *title = self.titles[indexPath.row];
    NSArray<NSString *> *manual = [[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasLongPressMenuManualTitlesKey] ?: @[];
    if (![manual containsObject:title]) return nil;

    __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                          title:@"删除"
                                                                        handler:^(__unused UIContextualAction *action,
                                                                                  __unused UIView *sourceView,
                                                                                  void (^completionHandler)(BOOL)) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableArray *manualTitles = [[defaults arrayForKey:WCAtlasLongPressMenuManualTitlesKey] mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *hiddenTitles = [[defaults arrayForKey:WCAtlasLongPressMenuHiddenTitlesKey] mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *order = [[defaults arrayForKey:WCAtlasLongPressMenuPreferredOrderKey] mutableCopy] ?: [NSMutableArray array];
        NSMutableDictionary *mapping = [[defaults dictionaryForKey:WCAtlasLongPressMenuTitleMapKey] mutableCopy] ?: [NSMutableDictionary dictionary];
        [manualTitles removeObject:title];
        [hiddenTitles removeObject:title];
        [order removeObject:title];
        [mapping removeObjectForKey:title];
        [defaults setObject:manualTitles forKey:WCAtlasLongPressMenuManualTitlesKey];
        [defaults setObject:hiddenTitles forKey:WCAtlasLongPressMenuHiddenTitlesKey];
        [defaults setObject:order forKey:WCAtlasLongPressMenuPreferredOrderKey];
        [defaults setObject:mapping forKey:WCAtlasLongPressMenuTitleMapKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                            object:WCAtlasLongPressMenuManualTitlesKey];
        [weakSelf reloadTitles];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
      toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSMutableArray *titles = [self.titles mutableCopy];
    NSString *title = titles[sourceIndexPath.row];
    [titles removeObjectAtIndex:sourceIndexPath.row];
    [titles insertObject:title atIndex:destinationIndexPath.row];
    self.titles = titles;
    [[NSUserDefaults standardUserDefaults] setObject:titles forKey:WCAtlasLongPressMenuPreferredOrderKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasLongPressMenuPreferredOrderKey];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *sourceTitle = self.titles[indexPath.row];
    NSMutableDictionary *mapping = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:WCAtlasLongPressMenuTitleMapKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名菜单"
                                                                   message:sourceTitle
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = mapping[sourceTitle];
        field.placeholder = @"留空恢复微信原名称";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *value = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) mapping[sourceTitle] = value;
        else [mapping removeObjectForKey:sourceTitle];
        [[NSUserDefaults standardUserDefaults] setObject:mapping forKey:WCAtlasLongPressMenuTitleMapKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasLongPressMenuTitleMapKey];
        [weakSelf reloadTitles];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
