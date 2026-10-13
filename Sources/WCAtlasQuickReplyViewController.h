#import "WCAtlasCardTableViewController.h"

@class WCAtlasQuickReplyItem;

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasQuickReplySelectionHandler)(WCAtlasQuickReplyItem *item);
typedef void (^WCAtlasQuickReplyDirectSendHandler)(WCAtlasQuickReplyItem *item);

@interface WCAtlasQuickReplyViewController : WCAtlasCardTableViewController

- (instancetype)initWithSelectionHandler:(WCAtlasQuickReplySelectionHandler _Nullable)selectionHandler;
- (instancetype)initWithSelectionHandler:(WCAtlasQuickReplySelectionHandler _Nullable)selectionHandler
                        directSendHandler:(WCAtlasQuickReplyDirectSendHandler _Nullable)directSendHandler;

@end

NS_ASSUME_NONNULL_END
