#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasInfoListSelectionHandler)(UIViewController *presenter,
                                               NSDictionary<NSString *, id> *row);

@interface WCAtlasInfoListViewController : WCAtlasCardTableViewController
- (instancetype)initWithTitle:(NSString *)title
                         rows:(NSArray<NSDictionary<NSString *, id> *> *)rows;
- (void)configureSelectionHandler:(nullable WCAtlasInfoListSelectionHandler)handler;
@end

NS_ASSUME_NONNULL_END
