#import "WCAtlasIdentityBadge.h"

static NSString *const WCAtlasIdentityBadgeURLString = @"https://ovoy.cc/wcatlas_badges.php";
static NSString *const WCAtlasIdentityBadgeRecordsKey = @"com.qiu7c.wcatlas.identity-badges.records";
static NSString *const WCAtlasIdentityBadgeFetchedAtKey = @"com.qiu7c.wcatlas.identity-badges.fetched-at";
static const NSUInteger WCAtlasIdentityBadgeMaximumResponseBytes = 512 * 1024;
static const NSTimeInterval WCAtlasIdentityBadgeRefreshInterval = 7.0 * 24.0 * 60.0 * 60.0;

@interface WCAtlasIdentityBadge ()
@property (nonatomic, copy, readwrite) NSString *text;
@property (nonatomic, copy, readwrite) NSString *colorCode;
@end

@implementation WCAtlasIdentityBadge

- (instancetype)initWithText:(NSString *)text colorCode:(NSString *)colorCode {
    self = [super init];
    if (!self) return nil;
    _text = [text copy];
    _colorCode = [colorCode copy];
    return self;
}

@end

static BOOL WCAtlasIdentityBadgeColorIsValid(NSString *value) {
    if (![value isKindOfClass:NSString.class]) return NO;
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"
        options:0 error:nil];
    return [expression numberOfMatchesInString:value options:0
                                         range:NSMakeRange(0, value.length)] == 1;
}

static NSDictionary *WCAtlasIdentityBadgeNormalizedRecords(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return @{};
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class] || ![object isKindOfClass:NSDictionary.class]) return;
        NSString *text = [object[@"text"] isKindOfClass:NSString.class]
            ? [object[@"text"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        NSString *color = [object[@"color"] isKindOfClass:NSString.class]
            ? [object[@"color"] uppercaseString] : @"";
        if (text.length == 0 || text.length > 24 || !WCAtlasIdentityBadgeColorIsValid(color)) return;
        records[key] = @{ @"text": text, @"color": color };
    }];
    return records.copy;
}

static WCAtlasIdentityBadge *WCAtlasIdentityBadgeFromRecords(NSDictionary *records, NSString *wxid) {
    NSDictionary *record = [records[wxid] isKindOfClass:NSDictionary.class] ? records[wxid] : nil;
    NSString *text = [record[@"text"] isKindOfClass:NSString.class] ? record[@"text"] : nil;
    NSString *color = [record[@"color"] isKindOfClass:NSString.class] ? record[@"color"] : nil;
    return text.length && color.length ? [[WCAtlasIdentityBadge alloc] initWithText:text colorCode:color] : nil;
}

static void WCAtlasResolveIdentityBadge(NSString *wxid, BOOL forceRefresh,
                                        void (^completion)(WCAtlasIdentityBadge *badge)) {
    if (![wxid isKindOfClass:NSString.class] || wxid.length == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *cached = WCAtlasIdentityBadgeNormalizedRecords(
        [defaults dictionaryForKey:WCAtlasIdentityBadgeRecordsKey]);
    NSTimeInterval fetchedAt = [defaults doubleForKey:WCAtlasIdentityBadgeFetchedAtKey];
    if (!forceRefresh && fetchedAt > 0 &&
        [NSDate.date timeIntervalSince1970] - fetchedAt < WCAtlasIdentityBadgeRefreshInterval) {
        WCAtlasIdentityBadge *badge = WCAtlasIdentityBadgeFromRecords(cached, wxid);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(badge); });
        return;
    }

    NSURL *URL = [NSURL URLWithString:WCAtlasIdentityBadgeURLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:12.0];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *records = cached;
        if (!error && data.length > 0 && data.length <= WCAtlasIdentityBadgeMaximumResponseBytes &&
            (![response isKindOfClass:NSHTTPURLResponse.class] ||
             (((NSHTTPURLResponse *)response).statusCode >= 200 &&
              ((NSHTTPURLResponse *)response).statusCode < 300))) {
            NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([JSON isKindOfClass:NSDictionary.class] && [JSON[@"success"] boolValue]) {
                records = WCAtlasIdentityBadgeNormalizedRecords(JSON[@"badges"]);
                [defaults setObject:records forKey:WCAtlasIdentityBadgeRecordsKey];
                [defaults setDouble:NSDate.date.timeIntervalSince1970 forKey:WCAtlasIdentityBadgeFetchedAtKey];
            }
        }
        WCAtlasIdentityBadge *badge = WCAtlasIdentityBadgeFromRecords(records, wxid);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(badge); });
    }] resume];
}

void WCAtlasFetchIdentityBadge(NSString *wxid,
                              void (^completion)(WCAtlasIdentityBadge *badge)) {
    WCAtlasResolveIdentityBadge(wxid, NO, completion);
}

void WCAtlasRefreshIdentityBadge(NSString *wxid,
                                void (^completion)(WCAtlasIdentityBadge *badge)) {
    WCAtlasResolveIdentityBadge(wxid, YES, completion);
}
