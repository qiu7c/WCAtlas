#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<NSString *> *WCAtlasMomentsReminderUsers(void);
FOUNDATION_EXPORT void WCAtlasMomentsReminderSetUserSelected(NSString *username, BOOL selected);
FOUNDATION_EXPORT void WCAtlasMomentsReminderTick(void);
FOUNDATION_EXPORT void WCAtlasMomentsReminderSettingsDidChange(void);

NS_ASSUME_NONNULL_END
