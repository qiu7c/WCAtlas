#import "WCAtlasSettingsModels.h"

@implementation WCAtlasSettingItem

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                              title:(NSString *)title
                           subtitle:(NSString *)subtitle
                             symbol:(NSString *)symbol
                               kind:(WCAtlasSettingRowKind)kind
                                key:(NSString *)key
                              value:(NSString *)value
                             action:(WCAtlasSettingAction)action {
    WCAtlasSettingItem *item = [self new];
    item.identifier = identifier;
    item.title = title;
    item.subtitle = subtitle;
    item.symbol = symbol;
    item.kind = kind;
    item.defaultsKey = key;
    item.value = value;
    item.action = action;
    return item;
}

@end

@implementation WCAtlasSettingSection

+ (instancetype)sectionWithIdentifier:(NSString *)identifier
                                  title:(NSString *)title
                                 footer:(NSString *)footer
                                  items:(NSArray<WCAtlasSettingItem *> *)items {
    WCAtlasSettingSection *section = [self new];
    section.identifier = identifier;
    section.title = title;
    section.footer = footer;
    section.items = items;
    return section;
}

@end
