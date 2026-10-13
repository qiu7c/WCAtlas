#import "WCAtlasCardTableViewController.h"

@interface WCAtlasSendConfirmationViewController : WCAtlasCardTableViewController
@end

typedef BOOL (^WCAtlasConversationPickerSelectedBlock)(NSString *username);
typedef void (^WCAtlasConversationPickerToggleBlock)(NSString *username);

FOUNDATION_EXPORT UIViewController *WCAtlasCreateConversationPicker(NSString *title,
                                                                  NSString *footer,
                                                                  WCAtlasConversationPickerSelectedBlock selected,
                                                                  WCAtlasConversationPickerToggleBlock toggle);
FOUNDATION_EXPORT UIViewController *WCAtlasCreateGroupPicker(NSString *title,
                                                           NSString *footer,
                                                           WCAtlasConversationPickerSelectedBlock selected,
                                                           WCAtlasConversationPickerToggleBlock toggle);
FOUNDATION_EXPORT UIViewController *WCAtlasCreateFriendPicker(NSString *title,
                                                            NSString *footer,
                                                            WCAtlasConversationPickerSelectedBlock selected,
                                                            WCAtlasConversationPickerToggleBlock toggle);
FOUNDATION_EXPORT void WCAtlasConfigureConversationPickerBulkActions(UIViewController *picker,
                                                                   dispatch_block_t selectAll,
                                                                   dispatch_block_t invertSelection);
FOUNDATION_EXPORT void WCAtlasConfigureConversationPickerCompletion(UIViewController *picker,
                                                                  dispatch_block_t completion);
