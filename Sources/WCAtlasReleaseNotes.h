#import <UIKit/UIKit.h>
#import "WCAtlasCardTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface WCAtlasReleaseNoteItem : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *detail;
+ (instancetype)itemWithTitle:(NSString *)title detail:(NSString *)detail;
@end

@interface WCAtlasReleaseNote : NSObject
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, copy, readonly) NSString *headline;
@property (nonatomic, copy, readonly) NSArray<WCAtlasReleaseNoteItem *> *items;
+ (instancetype)noteWithVersion:(NSString *)version
                       headline:(NSString *)headline
                          items:(NSArray<WCAtlasReleaseNoteItem *> *)items;
@end

FOUNDATION_EXPORT NSArray<WCAtlasReleaseNote *> *WCAtlasReleaseNotes(void);
FOUNDATION_EXPORT BOOL WCAtlasShouldPresentCurrentReleaseNotes(void);
FOUNDATION_EXPORT void WCAtlasMarkCurrentReleaseNotesPresented(void);

@interface WCAtlasReleaseNotesViewController : UIViewController
@end

@interface WCAtlasReleaseNotesHistoryViewController : WCAtlasCardTableViewController
@end

NS_ASSUME_NONNULL_END
