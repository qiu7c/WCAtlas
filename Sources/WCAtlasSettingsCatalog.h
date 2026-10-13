#import "WCAtlasSettingsModels.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const WCAtlasEnabledKey;
FOUNDATION_EXPORT NSString *const WCAtlasCollapsedFeaturesKey;
FOUNDATION_EXPORT NSString *const WCAtlasDisplayVersion;

FOUNDATION_EXPORT void WCAtlasSettingsRegisterDefaults(void);
FOUNDATION_EXPORT void WCAtlasSettingsRegenerateDailyStepTarget(NSUserDefaults *defaults);
FOUNDATION_EXPORT void WCAtlasSettingsHandleSwitchChange(NSString *key, BOOL enabled);
FOUNDATION_EXPORT NSArray<WCAtlasSettingSection *> *WCAtlasSettingsBuildSections(WCAtlasSettingsCategory category,
                                                                            NSSet<NSString *> *collapsedFeatureKeys);

NS_ASSUME_NONNULL_END
