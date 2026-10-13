#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void WCAtlasMomentsInteractionObserveUnreadCount(id manager, unsigned int count);
FOUNDATION_EXPORT void WCAtlasMomentsInteractionObserveLastUnreadMessage(id manager, id _Nullable message);
FOUNDATION_EXPORT void WCAtlasMomentsInteractionReminderTick(void);
FOUNDATION_EXPORT void WCAtlasMomentsInteractionReminderSettingsDidChange(void);

NS_ASSUME_NONNULL_END
