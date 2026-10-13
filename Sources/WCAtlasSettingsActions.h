#import <UIKit/UIKit.h>
#import "WCAtlasSettingsModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasSettingsReloadHandler)(BOOL applyScale);

@interface WCAtlasSettingsActions : NSObject
- (instancetype)initWithViewController:(UIViewController *)viewController
                         reloadHandler:(WCAtlasSettingsReloadHandler)reloadHandler;
- (void)performActionForItem:(WCAtlasSettingItem *)item;
@end

NS_ASSUME_NONNULL_END
