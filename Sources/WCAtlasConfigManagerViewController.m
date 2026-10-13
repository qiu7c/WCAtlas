#import "WCAtlasConfigManagerViewController.h"
#import "WCAtlasAntiRevoke.h"
#import "WCAtlasEnhancements.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const WCAtlasDefaultsPrefix = @"com.qiu7c.wcatlas.";
static BOOL WCAtlasIsManagedDefaultsKey(NSString *key) {
    if (![key hasPrefix:WCAtlasDefaultsPrefix]) return NO;
    if ([key hasPrefix:@"com.qiu7c.wcatlas.authorization."]) return NO;
    static NSSet<NSString *> *excludedKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        excludedKeys = [NSSet setWithArray:@[
            @"com.qiu7c.wcatlas.message.anti-revoke.archive",
            @"com.qiu7c.wcatlas.message.anti-revoke.local-prompt-contents",
            @"com.qiu7c.wcatlas.message.anti-revoke.side-records",
        ]];
    });
    return ![excludedKeys containsObject:key];
}

static BOOL WCAtlasDefaultsValuesHaveCompatibleTypes(id currentValue, id importedValue) {
    if (!currentValue || !importedValue) return YES;
    NSArray<Class> *valueClasses = @[
        [NSNumber class],
        [NSString class],
        [NSArray class],
        [NSDictionary class],
        [NSDate class],
        [NSData class],
    ];
    for (Class valueClass in valueClasses) {
        if ([currentValue isKindOfClass:valueClass]) return [importedValue isKindOfClass:valueClass];
    }
    return [importedValue isKindOfClass:[currentValue class]];
}

static id WCAtlasJSONValueFromDefaultsValue(id value) {
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]] ||
        [value isKindOfClass:[NSNull class]]) return value;
    if ([value isKindOfClass:[NSDate class]]) {
        return @{ @"$wcatlasType": @"date", @"value": @([(NSDate *)value timeIntervalSince1970]) };
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *values = [NSMutableArray array];
        for (id item in value) {
            id encoded = WCAtlasJSONValueFromDefaultsValue(item);
            if (!encoded) return nil;
            [values addObject:encoded];
        }
        return values;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            if (![key isKindOfClass:[NSString class]]) return nil;
            id encoded = WCAtlasJSONValueFromDefaultsValue(dictionary[key]);
            if (!encoded) return nil;
            values[key] = encoded;
        }
        return values;
    }
    return nil;
}

static id WCAtlasDefaultsValueFromJSONValue(id value) {
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *values = [NSMutableArray array];
        for (id item in value) {
            id decoded = WCAtlasDefaultsValueFromJSONValue(item);
            if (!decoded) return nil;
            [values addObject:decoded];
        }
        return values;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        if ([dictionary[@"$wcatlasType"] isEqualToString:@"date"] &&
            [dictionary[@"value"] isKindOfClass:[NSNumber class]] &&
            dictionary.count == 2) {
            return [NSDate dateWithTimeIntervalSince1970:[dictionary[@"value"] doubleValue]];
        }
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            if (![key isKindOfClass:[NSString class]]) return nil;
            id decoded = WCAtlasDefaultsValueFromJSONValue(dictionary[key]);
            if (!decoded) return nil;
            values[key] = decoded;
        }
        return values;
    }
    return nil;
}

@interface WCAtlasConfigManagerViewController () <UIDocumentPickerDelegate>
@end

@implementation WCAtlasConfigManagerViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"配置管理";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"备份与恢复" : nil;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"文件只包含 WCAtlas 自己的配置项，不读取或修改微信的其他设置。" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCAtlasConfig"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WCAtlasConfig"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.imageView.tintColor = UIColor.secondaryLabelColor;
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"导出配置";
        cell.detailTextLabel.text = @"生成 JSON 备份文件";
        cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"导入配置";
        cell.detailTextLabel.text = @"从 WCAtlas JSON 备份恢复";
        cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.down"];
    } else {
        cell.textLabel.text = @"重置 WCAtlas 配置";
        cell.detailTextLabel.text = @"清除全部插件设置";
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.counterclockwise"];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (NSDictionary *)persistentWCAtlasValues {
    NSString *domainName = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *domain = domainName.length > 0
        ? [[NSUserDefaults standardUserDefaults] persistentDomainForName:domainName]
        : nil;
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    [domain enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if (!WCAtlasIsManagedDefaultsKey(key)) return;
        id encoded = WCAtlasJSONValueFromDefaultsValue(value);
        if (encoded) values[key] = encoded;
    }];
    return values;
}

- (void)exportConfiguration {
    NSDictionary *payload = @{
        @"format": @"WCAtlasConfig",
        @"version": @1,
        @"values": [self persistentWCAtlasValues],
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || error) {
        [self showMessage:@"导出失败" detail:error.localizedDescription ?: @"无法生成配置文件"];
        return;
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"WCAtlas-Config-%@.json", [formatter stringFromDate:[NSDate date]]];
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:fileName];
    if (![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
        [self showMessage:@"导出失败" detail:error.localizedDescription ?: @"无法写入配置文件"];
        return;
    }

    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    UIPopoverPresentationController *popover = activity.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), 44.0, 1.0, 1.0);
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)importConfiguration {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeJSON, UTTypeData]
                            asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(__unused UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    NSDictionary *payload = [root isKindOfClass:[NSDictionary class]] ? root : nil;
    NSDictionary *rawValues = [payload[@"values"] isKindOfClass:[NSDictionary class]] ? payload[@"values"] : nil;
    if (!rawValues || ![payload[@"format"] isEqualToString:@"WCAtlasConfig"]) {
        [self showMessage:@"无法导入" detail:error.localizedDescription ?: @"这不是有效的 WCAtlas 配置文件"];
        return;
    }

    NSMutableDictionary *decodedValues = [NSMutableDictionary dictionary];
    __block BOOL invalid = NO;
    [rawValues enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (![key isKindOfClass:[NSString class]] || !WCAtlasIsManagedDefaultsKey(key)) return;
        id decoded = WCAtlasDefaultsValueFromJSONValue(value);
        if (!decoded) {
            invalid = YES;
            *stop = YES;
            return;
        }
        id currentValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if (!WCAtlasDefaultsValuesHaveCompatibleTypes(currentValue, decoded)) {
            invalid = YES;
            *stop = YES;
            return;
        }
        decodedValues[key] = decoded;
    }];
    if (invalid) {
        [self showMessage:@"无法导入" detail:@"配置中包含不支持的数据类型"];
        return;
    }

    NSString *domainName = NSBundle.mainBundle.bundleIdentifier;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *currentDomain = domainName.length > 0 ? [defaults persistentDomainForName:domainName] : nil;
    for (NSString *key in currentDomain) {
        if (WCAtlasIsManagedDefaultsKey(key)) [defaults removeObjectForKey:key];
    }
    [decodedValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [defaults setObject:value forKey:key];
    }];
    [self notifyConfigurationChanged];
    [self showMessage:@"导入完成" detail:[NSString stringWithFormat:@"已恢复 %lu 项 WCAtlas 配置", (unsigned long)decodedValues.count]];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置 WCAtlas 配置"
                                                                   message:@"所有 WCAtlas 开关、名单和界面设置都会恢复默认值。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSString *domainName = NSBundle.mainBundle.bundleIdentifier;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *domain = domainName.length > 0 ? [defaults persistentDomainForName:domainName] : nil;
        for (NSString *key in domain) {
            if (WCAtlasIsManagedDefaultsKey(key)) [defaults removeObjectForKey:key];
        }
        [self notifyConfigurationChanged];
        [self showMessage:@"已重置" detail:@"WCAtlas 配置已恢复默认值"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds), 1.0, 1.0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)notifyConfigurationChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
}

- (void)showMessage:(NSString *)title detail:(NSString *)detail {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:detail
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self exportConfiguration];
    } else if (indexPath.section == 0) {
        [self importConfiguration];
    } else {
        [self confirmReset];
    }
}

@end
