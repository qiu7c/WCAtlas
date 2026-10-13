#import "WCAtlasInfoListViewController.h"

@interface WCAtlasInfoListViewController ()
@property (nonatomic, copy) NSString *listTitle;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *rows;
@property (nonatomic, copy, nullable) WCAtlasInfoListSelectionHandler selectionHandler;
- (void)copyRowAtLongPress:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation WCAtlasInfoListViewController

- (instancetype)initWithTitle:(NSString *)title
                         rows:(NSArray<NSDictionary<NSString *, id> *> *)rows {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _listTitle = [title copy] ?: @"详细名单";
        _rows = [rows copy] ?: @[];
    }
    return self;
}

- (void)configureSelectionHandler:(WCAtlasInfoListSelectionHandler _Nullable)handler {
    self.selectionHandler = [handler copy];
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.listTitle;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 58.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(copyRowAtLongPress:)];
    longPress.minimumPressDuration = 0.45;
    [self.tableView addGestureRecognizer:longPress];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"WCAtlasInfoListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary<NSString *, id> *row = self.rows[indexPath.row];
    cell.textLabel.text = row[@"title"] ?: @"未知联系人";
    cell.detailTextLabel.text = row[@"value"] ?: @"";
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    UIImage *avatar = [row[@"image"] isKindOfClass:UIImage.class] ? row[@"image"] : nil;
    cell.imageView.image = avatar;
    cell.imageView.layer.cornerRadius = 20.0;
    cell.imageView.layer.masksToBounds = YES;
    cell.accessoryType = self.selectionHandler ? UITableViewCellAccessoryDisclosureIndicator
                                               : UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, id> *row = self.rows[indexPath.row];
    if (self.selectionHandler) self.selectionHandler(self, row);
}

- (void)copyRowAtLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[recognizer locationInView:self.tableView]];
    if (!indexPath || indexPath.row >= self.rows.count) return;
    NSString *value = self.rows[indexPath.row][@"value"];
    if (![value isKindOfClass:NSString.class] || value.length == 0) return;
    UIPasteboard.generalPasteboard.string = value;
    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
}

@end
