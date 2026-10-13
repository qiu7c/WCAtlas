#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WCAtlasIdentityBadge : NSObject
@property (nonatomic, copy, readonly) NSString *text;
@property (nonatomic, copy, readonly) NSString *colorCode;
- (instancetype)initWithText:(NSString *)text colorCode:(NSString *)colorCode;
@end

/// Resolves the badge for one exact wxid from the fixed WCAtlas service.
/// The request is asynchronous, refreshes its complete cache at most once every seven days,
/// and never sends the wxid.
/// Completion runs on the main thread. A nil badge means no mapping, invalid data, or failure.
FOUNDATION_EXPORT void WCAtlasFetchIdentityBadge(NSString *wxid,
                                                void (^completion)(WCAtlasIdentityBadge * _Nullable badge));

/// Bypasses the seven-day age check and refreshes the complete badge cache immediately.
/// Completion and failure semantics match `WCAtlasFetchIdentityBadge`.
FOUNDATION_EXPORT void WCAtlasRefreshIdentityBadge(NSString *wxid,
                                                  void (^completion)(WCAtlasIdentityBadge * _Nullable badge));

NS_ASSUME_NONNULL_END
