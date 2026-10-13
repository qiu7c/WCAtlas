#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WCAtlasAvatarQuickAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)actionWithTitle:(NSString *)title
                     symbolName:(NSString *)symbolName
                        handler:(void (^)(void))handler;
@end

FOUNDATION_EXPORT void WCAtlasPresentAvatarQuickPanel(UIViewController *presenter,
                                                     UIImage * _Nullable avatar,
                                                     NSString *displayName,
                                                     NSString *userName,
                                                     NSString * _Nullable maskedRealName,
                                                     NSArray<WCAtlasAvatarQuickAction *> *actions,
                                                     void (^profileHandler)(void));

NS_ASSUME_NONNULL_END
