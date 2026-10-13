#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const WCAtlasLoggingEnabledKey;
FOUNDATION_EXPORT NSNotificationName const WCAtlasLogDidChangeNotification;
FOUNDATION_EXPORT void WCAtlasLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT void WCAtlasLogAlways(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT NSArray<NSString *> *WCAtlasLogEntries(void);
FOUNDATION_EXPORT void WCAtlasClearLogEntries(void);
