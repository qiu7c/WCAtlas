#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const WCAtlasPluginManagerEnabledKey;

@interface WCAtlasPluginModel : NSObject
@property (nonatomic, assign) BOOL isController;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *controller;
@property (nonatomic, copy) NSString *key;
@end

@interface WCAtlasPluginsMgr : NSObject
@property (nonatomic, strong) NSMutableArray<WCAtlasPluginModel *> *plugins;
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(nullable NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
- (void)removeSwitchWithKey:(NSString *)key;
@end

/// Injects the WCAtlas row into LazyCat's plugin list, pointing at our own settings page.
FOUNDATION_EXPORT void WCAtlasInstallPluginManagerEntry(id moreViewController);
/// Returns YES only when the external LazyCat WCPluginsMgr service is available.
FOUNDATION_EXPORT BOOL WCAtlasExternalPluginManagerAvailable(void);
/// Installs the shared `WCPluginsMgr` registration class at runtime.
/// Returns YES when WCAtlas owns the runtime class. It is never installed while an
/// external manager owns the class name.
FOUNDATION_EXPORT BOOL WCAtlasInstallPluginRegistry(void);
/// Adds a direct WCAtlas row to WeChat's settings page when no registry owns the entry.
FOUNDATION_EXPORT void WCAtlasInstallSettingsFallbackEntry(id settingsController);
/// Pushes the WCAtlas settings controller. Must be called on the main thread.
FOUNDATION_EXPORT void WCAtlasPushSettingsController(id sender);
FOUNDATION_EXPORT BOOL WCAtlasPluginManagerIsQuickSwitchRegistered(NSString *key);
FOUNDATION_EXPORT void WCAtlasPluginManagerSetQuickSwitchRegistered(NSString *key, NSString *title, BOOL registered);
FOUNDATION_EXPORT void WCAtlasPluginManagerRegisterSavedQuickSwitches(void);

NS_ASSUME_NONNULL_END