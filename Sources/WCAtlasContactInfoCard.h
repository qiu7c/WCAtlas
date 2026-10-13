#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasContactInfoCardSwitchHandler)(BOOL enabled);
typedef void (^WCAtlasContactInfoCardRowSelectionHandler)(UIViewController *presenter);

@interface WCAtlasContactInfoCardViewController : WCAtlasCardTableViewController
- (instancetype)initWithTitle:(NSString *)title
                       avatar:(nullable UIImage *)avatar
                         name:(NSString *)name
                     userName:(NSString *)userName
                         rows:(NSArray<NSDictionary<NSString *, NSString *> *> *)rows;
- (void)updateRows:(NSArray<NSDictionary<NSString *, NSString *> *> *)rows;
- (void)configureRowActionWithTitle:(NSString *)title
                            handler:(nullable WCAtlasContactInfoCardRowSelectionHandler)handler;
- (void)configureMessageBlockSwitchWithTitle:(NSString *)title
                                      enabled:(BOOL)enabled
                                      handler:(nullable WCAtlasContactInfoCardSwitchHandler)handler;
- (void)configureSendConfirmationSwitchWithTitle:(NSString *)title
                                          enabled:(BOOL)enabled
                                          handler:(nullable WCAtlasContactInfoCardSwitchHandler)handler;
@end

NS_ASSUME_NONNULL_END
