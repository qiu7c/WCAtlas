#import "WCAtlasCardTableViewController.h"
#import "WCAtlasSettingsTheme.h"
#import "WCAtlasNavigationAppearance.h"

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
    // Every page on this base gets the same row rhythm, which is why a page no
    // longer needs to state a row height of its own.
    WCAtlasSettingsApplyRowMetrics(self.tableView, 1.0);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Every page on this base shows only our black chevron, never the blue
    // system back title of the page it was pushed from.
    WCAtlasApplyBackButtonStyle(self.navigationController.navigationBar, self.navigationItem);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // The bar can belong to WeChat, so hand the system chevron back on the way
    // out rather than leaving ours behind for its own pages.
    WCAtlasRestoreBackButtonStyle(self.navigationController.navigationBar);
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger rows = [tableView.dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
    BOOL first = indexPath.row == 0;
    BOOL last = indexPath.row == rows - 1;

    WCAtlasSettingsApplyMinimumRowHeight(cell, 1.0);

    UIView *cardBackground = cell.backgroundView;
    if (!cardBackground) {
        cardBackground = [UIView new];
        cell.backgroundView = cardBackground;
    }
    cardBackground.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cardBackground.layer.cornerCurve = kCACornerCurveContinuous;
    // Card radius comes from the shared token, so a page that decorates its own
    // cells cannot drift from this one (the plugin page used 16.0 before).
    cardBackground.layer.cornerRadius = (first || last) ? WCAtlasSettingsCornerRadius : 0.0;
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
