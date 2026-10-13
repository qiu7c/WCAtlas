#import "WCAtlasLogging.h"

NSString *const WCAtlasLoggingEnabledKey = @"com.qiu7c.wcatlas.logging.enabled";
NSNotificationName const WCAtlasLogDidChangeNotification = @"WCAtlasLogDidChangeNotification";

static NSMutableArray<NSString *> *WCAtlasMutableLogEntries(void) {
    static NSMutableArray<NSString *> *entries;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ entries = [NSMutableArray array]; });
    return entries;
}

static NSDateFormatter *WCAtlasLogDateFormatter(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = @"HH:mm:ss.SSS";
    });
    return formatter;
}

static void WCAtlasWriteLog(NSString *format, va_list arguments, BOOL force) {
    if (format.length == 0) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (!force && [defaults objectForKey:WCAtlasLoggingEnabledKey] &&
        ![defaults boolForKey:WCAtlasLoggingEnabledKey]) return;
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    NSLog(@"[WCAtlas] %@", message);
    NSDateFormatter *formatter = WCAtlasLogDateFormatter();
    NSString *timestamp = nil;
    @synchronized (formatter) { timestamp = [formatter stringFromDate:NSDate.date]; }
    NSString *entry = [NSString stringWithFormat:@"[%@] %@", timestamp, message];
    NSMutableArray<NSString *> *entries = WCAtlasMutableLogEntries();
    @synchronized (entries) {
        [entries addObject:entry];
        if (entries.count > 500) [entries removeObjectsInRange:NSMakeRange(0, entries.count - 500)];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasLogDidChangeNotification object:nil];
    });
}

void WCAtlasLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    WCAtlasWriteLog(format, arguments, NO);
    va_end(arguments);
}

void WCAtlasLogAlways(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    WCAtlasWriteLog(format, arguments, YES);
    va_end(arguments);
}

NSArray<NSString *> *WCAtlasLogEntries(void) {
    NSMutableArray<NSString *> *entries = WCAtlasMutableLogEntries();
    @synchronized (entries) { return [entries copy]; }
}

void WCAtlasClearLogEntries(void) {
    NSMutableArray<NSString *> *entries = WCAtlasMutableLogEntries();
    @synchronized (entries) { [entries removeAllObjects]; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasLogDidChangeNotification object:nil];
    });
}
