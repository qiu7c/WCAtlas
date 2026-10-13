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

@interface WCAtlasPluginsViewController : UITableViewController
@end

@interface WCPPluginOrderEditorController : WCAtlasCardTableViewController
- (instancetype)initWithOwner:(WCAtlasPluginsViewController *)owner;
@end

FOUNDATION_EXPORT void WCAtlasInstallPluginManagerEntry(id moreViewController);
FOUNDATION_EXPORT void WCAtlasPushPluginManager(id sender);
/// Returns YES only when the external LazyCat WCPluginsMgr service is available.
FOUNDATION_EXPORT BOOL WCAtlasExternalPluginManagerAvailable(void);
/// Installs the shared `WCPluginsMgr` registration class for the built-in manager at runtime.
/// Returns YES when WCAtlas owns the runtime class. It is never installed while an external
/// manager owns the class name, and only installs when the built-in manager is enabled.
FOUNDATION_EXPORT BOOL WCAtlasInstallPluginRegistry(void);
/// Adds a direct WCAtlas row only when neither the external nor built-in plugin registry owns it.
/// Call after WeChat has built `NewSettingViewController`'s table model. The adapter does not reload
/// the visible table, allowing first-load hooks to inject the row before the initial presentation.
FOUNDATION_EXPORT void WCAtlasInstallSettingsFallbackEntry(id settingsController);
/// Pushes the WCAtlas settings controller from the native WeChat settings page.
/// Must be called on the main thread.
FOUNDATION_EXPORT void WCAtlasPushSettingsController(id sender);
FOUNDATION_EXPORT BOOL WCAtlasPluginManagerIsQuickSwitchRegistered(NSString *key);
FOUNDATION_EXPORT void WCAtlasPluginManagerSetQuickSwitchRegistered(NSString *key, NSString *title, BOOL registered);
FOUNDATION_EXPORT void WCAtlasPluginManagerRegisterSavedQuickSwitches(void);

NS_ASSUME_NONNULL_END
