#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, WCAtlasListEditorMode) {
    WCAtlasListEditorModeList,
    WCAtlasListEditorModeMapping,
};

@interface WCAtlasListEditorViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                  defaultsKey:(NSString *)defaultsKey
                         mode:(WCAtlasListEditorMode)mode;

@end
