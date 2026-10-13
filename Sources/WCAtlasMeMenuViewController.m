#import "WCAtlasMeMenuViewController.h"

#import "WCAtlasEnhancements.h"

#import <objc/runtime.h>

static char WCAtlasMeMenuTitleAssociationKey;

@interface WCAtlasMeMenuViewController ()
@property (nonatomic, copy) NSArray<NSString *> *titles;
@end

@implementation WCAtlasMeMenuViewController

- (instancetype)init { return [self initWithStyle:UITableViewStyleInsetGrouped]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我的页面入口";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTitles)
                                                 name:WCAtlasEnhancementDidChangeNotification object:nil];
    [self reloadTitles];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)reloadTitles {
    self.titles = @[@"作品", @"小店与卡包", @"表情"];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.titles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return @"原生入口";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return @"关闭“显示”后，重新进入“我”页面生效。插件入口始终保留。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"me-menu-item"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"me-menu-item"];
    NSString *title = self.titles[indexPath.row];
    cell.textLabel.text = title;
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = UIColor.systemGreenColor;
    toggle.on = ![[[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasMeMenuHiddenTitlesKey] containsObject:title];
    objc_setAssociatedObject(toggle, &WCAtlasMeMenuTitleAssociationKey, title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [toggle addTarget:self action:@selector(visibilityChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)visibilityChanged:(UISwitch *)sender {
    NSString *title = objc_getAssociatedObject(sender, &WCAtlasMeMenuTitleAssociationKey);
    if (title.length == 0 || [title isEqualToString:@"插件"]) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *hidden = [[defaults arrayForKey:WCAtlasMeMenuHiddenTitlesKey] mutableCopy] ?: [NSMutableArray array];
    if (sender.isOn) [hidden removeObject:title];
    else if (![hidden containsObject:title]) [hidden addObject:title];
    [defaults setObject:hidden forKey:WCAtlasMeMenuHiddenTitlesKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                        object:WCAtlasMeMenuHiddenTitlesKey];
}

@end
