#import "WCAtlasCardTableViewController.h"

#import <QuartzCore/QuartzCore.h>

@implementation WCAtlasCardTableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    (void)style;
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorColor = UIColor.separatorColor;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger rows = [tableView.dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
    BOOL first = indexPath.row == 0;
    BOOL last = indexPath.row == rows - 1;

    UIView *cardBackground = cell.backgroundView;
    if (!cardBackground) {
        cardBackground = [UIView new];
        cell.backgroundView = cardBackground;
    }
    cardBackground.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cardBackground.layer.cornerCurve = kCACornerCurveContinuous;
    cardBackground.layer.cornerRadius = (first || last) ? 14.0 : 0.0;
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    if (first && last) {
        cardBackground.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner |
                                             kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (first) {
        cardBackground.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    } else if (last) {
        cardBackground.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }
    cardBackground.layer.masksToBounds = first || last;

    UIView *selectedBackground = cell.selectedBackgroundView;
    if (!selectedBackground) {
        selectedBackground = [UIView new];
        cell.selectedBackgroundView = selectedBackground;
    }
    selectedBackground.backgroundColor = UIColor.secondarySystemFillColor;
    selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    selectedBackground.layer.cornerRadius = cardBackground.layer.cornerRadius;
    selectedBackground.layer.maskedCorners = cardBackground.layer.maskedCorners;
    selectedBackground.layer.masksToBounds = cardBackground.layer.masksToBounds;
}

@end
