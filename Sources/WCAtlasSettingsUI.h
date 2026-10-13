#import <UIKit/UIKit.h>
#import "WCAtlasSettingsModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasSettingsSwitchHandler)(WCAtlasSettingItem *item, BOOL enabled);

@interface WCAtlasSettingsCell : UITableViewCell
- (void)configureWithItem:(WCAtlasSettingItem *)item
            masterEnabled:(BOOL)masterEnabled
                 expanded:(BOOL)expanded
                     scale:(CGFloat)scale
            switchHandler:(WCAtlasSettingsSwitchHandler)switchHandler;
@end

@interface WCAtlasSettingsProfileHeaderView : UIControl
@property (nonatomic, copy, readonly, nullable) NSString *wxid;
- (void)embedSearchBar:(UISearchBar *)searchBar;
- (void)refreshProfile;
- (void)showCopyConfirmation;
- (CGFloat)preferredHeightForWidth:(CGFloat)width scale:(CGFloat)scale;
@end

NS_ASSUME_NONNULL_END
