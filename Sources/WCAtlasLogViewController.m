#import "WCAtlasLogViewController.h"
#import "WCAtlasLogging.h"

@interface WCAtlasLogViewController ()
@property (nonatomic, copy) NSArray<NSString *> *entries;
@end

@implementation WCAtlasLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"运行日志";
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain target:self action:@selector(copyLogs)],
        [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearLogs)],
    ];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadLogs:)
                                               name:WCAtlasLogDidChangeNotification
                                             object:nil];
    [self reloadLogs:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)reloadLogs:(__unused NSNotification *)notification {
    self.entries = WCAtlasLogEntries();
    [self.tableView reloadData];
}

- (void)copyLogs {
    UIPasteboard.generalPasteboard.string = [self.entries componentsJoinedByString:@"\n"] ?: @"";
}

- (void)clearLogs {
    WCAtlasClearLogEntries();
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return MAX((NSInteger)self.entries.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCAtlasLogCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"WCAtlasLogCell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.textColor = self.entries.count ? UIColor.labelColor : UIColor.secondaryLabelColor;
    cell.textLabel.text = self.entries.count ? self.entries[indexPath.row] : @"本次运行暂无日志";
    return cell;
}

@end
