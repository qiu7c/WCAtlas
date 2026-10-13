#import <UIKit/UIKit.h>
#import "WCAtlasSettingsModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasSettingsSwitchHandler)(WCAtlasSettingItem *item, BOOL enabled);

@interface WCAtlasSettingsCell : UITableViewCell
/// showsIcon is NO for nested rows and for the sub category pages, which render
/// without an icon column, and YES for the root page's top level rows.
- (void)configureWithItem:(WCAtlasSettingItem *)item
            masterEnabled:(BOOL)masterEnabled
                 expanded:(BOOL)expanded
                showsIcon:(BOOL)showsIcon
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
