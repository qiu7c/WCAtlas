#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void WCAtlasBackgroundKeeperEnterBackground(void);
FOUNDATION_EXPORT void WCAtlasBackgroundKeeperWillEnterForeground(void);
FOUNDATION_EXPORT void WCAtlasBackgroundKeeperSettingsDidChange(void);

/// Marks background execution as required by enabled automation tasks.
/// @param required YES while at least one scheduled task is enabled; NO otherwise.
/// @discussion May be called from any thread. The existing user setting remains an
/// independent reason to keep running. When both reasons are absent, resources are
/// released; when required while already backgrounded, keep-alive starts immediately.
FOUNDATION_EXPORT void WCAtlasBackgroundKeeperSetAutomationRequired(BOOL required);

NS_ASSUME_NONNULL_END
