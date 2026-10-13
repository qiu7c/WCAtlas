#import "WCAtlasSettingsActions.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasAntiRevoke.h"
#import "WCAtlasAntiRevokeTemplateEditor.h"
#import "WCAtlasConfigManagerViewController.h"
#import "WCAtlasLogViewController.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasListEditorViewController.h"
#import "WCAtlasLongPressMenuViewController.h"
#import "WCAtlasMeMenuViewController.h"
#import "WCAtlasMessageBlock.h"
#import "WCAtlasPluginManager.h"
#import "WCAtlasInAppNotificationSettingsViewController.h"
#import "WCAtlasReleaseNotes.h"
#import "WCAtlasQuickReplyViewController.h"
#import "WCAtlasFriendRelationCheckViewController.h"
#import "WCAtlasSendConfirmationViewController.h"
#import "WCAtlasMomentsReminder.h"
#import "WCAtlasMomentsTail.h"
#import "WCAtlasCallRecordingsViewController.h"
#import "WCAtlasCallAudio.h"
#import "WCAtlasAutomationViewController.h"
#import "WCAtlasHomeCategories.h"
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char WCAtlasContactSearchLogicKey;

@interface WCAtlasSettingsActions () <UIColorPickerViewControllerDelegate>
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) WCAtlasSettingsReloadHandler reloadHandler;
@property (nonatomic, copy) NSString *activeColorDefaultsKey;
@end


@implementation WCAtlasSettingsActions

- (instancetype)initWithViewController:(UIViewController *)viewController
                         reloadHandler:(WCAtlasSettingsReloadHandler)reloadHandler {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _reloadHandler = [reloadHandler copy];
    }
    return self;
}

- (void)reload {
    if (self.reloadHandler) self.reloadHandler(NO);
}

- (void)presentSheet:(UIAlertController *)sheet {
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.viewController.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.viewController.view.bounds), CGRectGetMaxY(self.viewController.view.bounds) - 1.0, 1.0, 1.0);
    }
    [self.viewController presentViewController:sheet animated:YES completion:nil];
}

- (void)push:(UIViewController *)controller {
    if (controller) [self.viewController.navigationController pushViewController:controller animated:YES];
}

- (void)openProfileForUserName:(NSString *)requestedUserName {
    UIViewController *sourceController = self.viewController;
    NSString *userName = [requestedUserName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!sourceController || userName.length == 0) return;

    if (WCAtlasPushPrivateContactProfile(sourceController, userName)) return;

    Class searchClass = NSClassFromString(@"GetA8KeyLogic");
    SEL initializer = NSSelectorFromString(@"initWithViewController:delegate:");
    SEL searchSelector = NSSelectorFromString(@"doSearchContact:FromScene:SearchScene:picUrl:");
    id searchLogic = searchClass && [searchClass instancesRespondToSelector:initializer]
        ? ((id (*)(id, SEL, id, id))objc_msgSend)([searchClass alloc], initializer, sourceController, nil)
        : nil;
    if (searchLogic && [searchLogic respondsToSelector:searchSelector]) {
        objc_setAssociatedObject(sourceController, &WCAtlasContactSearchLogicKey,
                                 searchLogic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, id, NSUInteger, NSUInteger, id))objc_msgSend)(searchLogic,
                                                                          searchSelector,
                                                                          userName,
                                                                          0,
                                                                          0,
                                                                          nil);
        return;
    }

    NSString *URLString = [NSString stringWithFormat:@"weixin://contacts/profile/%@", userName];
    NSURL *URL = [NSURL URLWithString:URLString];
    UIApplication *application = UIApplication.sharedApplication;
    if (URL && [application canOpenURL:URL]) {
        [application openURL:URL options:@{} completionHandler:nil];
        return;
    }

    UIPasteboard.generalPasteboard.string = userName;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"暂时无法打开资料页"
                                                                   message:@"账号已复制，可在微信中继续搜索。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [sourceController presentViewController:alert animated:YES completion:nil];
}

- (void)openOfficialTelegram {
    NSURL *URL = [NSURL URLWithString:@"https://t.me/WCAtlas"];
    UIApplication *application = UIApplication.sharedApplication;
    if (!URL || ![application canOpenURL:URL]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开 Telegram"
                                                                       message:@"请稍后重试，或在浏览器中访问 t.me/WCAtlas。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self.viewController presentViewController:alert animated:YES completion:nil];
        return;
    }
    [application openURL:URL options:@{} completionHandler:nil];
}

- (void)presentFindFriend {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"查找好友"
                                                                   message:@"输入微信号或 wxid（初始账号），将使用微信原生联系人搜索链路。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"微信号 / wxid（初始账号）";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"查找" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf openProfileForUserName:alert.textFields.firstObject.text];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentOpenChatByID {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"按 ID 打开聊天"
                                                                   message:@"输入内容将原样交给微信聊天跳转接口，不校验账号或群聊格式。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"wxid_… 或 50631397390@chatroom";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"跳转"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *input = alert.textFields.firstObject.text;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf || WCAtlasPushPrivateChat(strongSelf.viewController, input, YES)) return;
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"跳转失败"
                                                                              message:@"微信未能使用该输入打开聊天。"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"确定"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil]];
            [strongSelf.viewController presentViewController:failure animated:YES completion:nil];
        });
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentRevokeFilterPicker {
    NSTimeInterval current = [NSUserDefaults.standardUserDefaults doubleForKey:WCAtlasAntiRevokeTimeFilterKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"回复时间限制" message:@"仅影响“回复撤回者”，不会影响本地防撤回" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@{@"title": @"不限制", @"value": @0}, @{@"title": @"1 分钟", @"value": @60}, @{@"title": @"5 分钟", @"value": @300}, @{@"title": @"30 分钟", @"value": @1800}, @{@"title": @"1 小时", @"value": @3600}, @{@"title": @"24 小时", @"value": @86400}];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        NSString *title = fabs([option[@"value"] doubleValue] - current) < 0.5
            ? [NSString stringWithFormat:@"✓  %@", option[@"title"]]
            : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setDouble:[option[@"value"] doubleValue] forKey:WCAtlasAntiRevokeTimeFilterKey];
            [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentRevokePromptStylePicker {
    NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasAntiRevokePromptStyleKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"防撤回提示方案" message:@"“消息下方”显示完整提示；“气泡旁”显示与气泡持平的小字" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@{@"title": current == 0 ? @"✓  消息下方" : @"消息下方", @"value": @0}, @{@"title": current == 1 ? @"✓  气泡旁" : @"气泡旁", @"value": @1}];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[@"title"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:[option[@"value"] integerValue] forKey:WCAtlasAntiRevokePromptStyleKey];
            [weakSelf reload];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentTemplateWithTitle:(NSString *)title key:(NSString *)key defaultValue:(NSString *)defaultValue {
    [self push:[[WCAtlasAntiRevokeTemplateEditorViewController alloc] initWithTitle:title defaultsKey:key defaultValue:defaultValue colorKey:nil]];
}

- (void)presentNumberEditorWithTitle:(NSString *)title message:(NSString *)message key:(NSString *)key minimum:(CGFloat)minimum maximum:(CGFloat)maximum notifyChange:(BOOL)notifyChange applyScale:(BOOL)applyScale {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = [NSString stringWithFormat:@"%.0f", [NSUserDefaults.standardUserDefaults doubleForKey:key]];
        field.keyboardType = minimum < 0.0 ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDecimalPad;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *raw = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        CGFloat fallback = minimum == 70.0 && maximum == 100.0 ? 100.0 : 0.0;
        if ([key isEqualToString:WCAtlasRedEnvelopeDetailFontSizeKey]) fallback = 14.0;
        if ([key isEqualToString:WCAtlasChatGlassBlurIntensityKey]) fallback = 100.0;
        CGFloat value = MIN(maximum, MAX(minimum, raw.length > 0 ? raw.doubleValue : fallback));
        [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];
        if (notifyChange) [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:key];
        if ([key isEqualToString:WCAtlasMomentsReminderIntervalKey]) WCAtlasMomentsReminderSettingsDidChange();
        if (weakSelf.reloadHandler) weakSelf.reloadHandler(applyScale);
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentSendConfirmationPauseDurationEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"临时暂停时长"
                                                                   message:@"输入暂停确认的秒数"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        NSInteger saved = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasSendConfirmationPauseSecondsKey];
        field.text = [NSString stringWithFormat:@"%ld", (long)(saved > 0 ? saved : 60)];
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *raw = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSInteger seconds = raw.integerValue;
        [NSUserDefaults.standardUserDefaults setInteger:seconds > 0 ? seconds : 60
                                                 forKey:WCAtlasSendConfirmationPauseSecondsKey];
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                           object:WCAtlasSendConfirmationPauseSecondsKey];
        if (weakSelf.reloadHandler) weakSelf.reloadHandler(NO);
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentMomentsDateFormatEditor {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *saved = WCAtlasNormalizedMomentsDateFormat([defaults stringForKey:WCAtlasMomentsPreciseTimeFormatKey]) ?: WCAtlasMomentsPreciseTimeDefaultFormat;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"朋友圈日期格式" message:@"仅支持 yyyy、MM、dd、E、HH、mm、ss，区分大小写；留空恢复默认格式" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = saved;
        field.placeholder = WCAtlasMomentsPreciseTimeDefaultFormat;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *raw = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *normalized = raw.length == 0 ? WCAtlasMomentsPreciseTimeDefaultFormat : WCAtlasNormalizedMomentsDateFormat(raw);
        if (!normalized) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController *error = [UIAlertController alertControllerWithTitle:@"日期格式不支持" message:@"格式最长 64 个字符，只能使用支持的日期符号及普通分隔文字。" preferredStyle:UIAlertControllerStyleAlert];
                [error addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf.viewController presentViewController:error animated:YES completion:nil];
            });
            return;
        }
        [defaults setObject:normalized forKey:WCAtlasMomentsPreciseTimeFormatKey];
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasMomentsPreciseTimeFormatKey];
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentMessageTimeFormatEditor {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *saved = [defaults stringForKey:WCAtlasChatMessageTimeFormatKey];
    if (saved.length == 0) saved = @"MM-dd HH:mm:ss";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"消息时间格式"
                                                                   message:@"仅支持 yyyy、MM、dd、E、HH、mm、ss，区分大小写；留空恢复默认格式"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = saved;
        field.placeholder = @"MM-dd HH:mm:ss";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *raw = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *normalized = raw.length == 0 ? @"MM-dd HH:mm:ss" : WCAtlasNormalizedMomentsDateFormat(raw);
        if (!normalized) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController *error = [UIAlertController alertControllerWithTitle:@"时间格式不支持"
                                                                                message:@"格式最长 64 个字符，只能使用支持的日期符号及普通分隔文字。"
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                [error addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf.viewController presentViewController:error animated:YES completion:nil];
            });
            return;
        }
        [defaults setObject:normalized forKey:WCAtlasChatMessageTimeFormatKey];
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasChatMessageTimeFormatKey];
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentMessageTimeModePicker {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL bubbleMode = [defaults boolForKey:WCAtlasChatMessageTimeBubbleSideKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"消息时间显示模式"
                                                                    message:@"两种模式互斥；头像模式紧贴头像底部，消息旁模式支持全部消息类型。"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"头像下方", @"bubble": @NO},
        @{@"title": @"消息右侧", @"bubble": @YES},
    ];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        BOOL value = [option[@"bubble"] boolValue];
        NSString *title = value == bubbleMode ? [NSString stringWithFormat:@"✓  %@", option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setBool:!value forKey:WCAtlasChatMessageTimeBelowAvatarKey];
            [defaults setBool:value forKey:WCAtlasChatMessageTimeBubbleSideKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasChatMessageTimeBubbleSideKey];
            [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentMessageTimePositionPicker {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger current = MIN(2, MAX(0, [defaults integerForKey:WCAtlasChatMessageTimeBubbleVerticalPositionKey]));
    NSArray<NSString *> *names = @[@"顶部", @"中间", @"底部"];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"消息旁时间位置"
                                                                    message:@"底部可避开默认位于中间的防撤回提示。"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, __unused BOOL *stop) {
        NSString *title = (NSInteger)index == current ? [NSString stringWithFormat:@"✓  %@", name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setInteger:(NSInteger)index forKey:WCAtlasChatMessageTimeBubbleVerticalPositionKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasChatMessageTimeBubbleVerticalPositionKey];
            [weakSelf reload];
        }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentMessageTimeColorPickerForKey:(NSString *)defaultsKey title:(NSString *)title {
    self.activeColorDefaultsKey = defaultsKey;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.title = title;
    picker.supportsAlpha = YES;
    picker.selectedColor = WCAtlasColorForDefaultsKey(defaultsKey, UIColor.secondaryLabelColor);
    picker.delegate = self;
    [self.viewController presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if (self.activeColorDefaultsKey.length == 0) return;
    UIColor *resolved = [viewController.selectedColor resolvedColorWithTraitCollection:self.viewController.traitCollection];
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (![resolved getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat white = 0.0;
        if ([resolved getWhite:&white alpha:&alpha]) red = green = blue = white;
    }
    NSString *hex = [NSString stringWithFormat:@"#%02X%02X%02X%02X",
                     (unsigned int)lrint(MIN(1.0, MAX(0.0, red)) * 255.0),
                     (unsigned int)lrint(MIN(1.0, MAX(0.0, green)) * 255.0),
                     (unsigned int)lrint(MIN(1.0, MAX(0.0, blue)) * 255.0),
                     (unsigned int)lrint(MIN(1.0, MAX(0.0, alpha)) * 255.0)];
    [NSUserDefaults.standardUserDefaults setObject:hex forKey:self.activeColorDefaultsKey];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:self.activeColorDefaultsKey];
    self.activeColorDefaultsKey = nil;
    [self reload];
}

- (void)presentHapticIntensityPicker {
    CGFloat current = [NSUserDefaults.standardUserDefaults doubleForKey:WCAtlasMomentsLikeHapticIntensityKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"点赞震动力度" message:@"选择双击点赞时的触感强度" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@{@"title": @"轻", @"value": @0.25}, @{@"title": @"中", @"value": @0.65}, @{@"title": @"强", @"value": @1.0}];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        CGFloat value = [option[@"value"] doubleValue];
        BOOL selected = (current < 0.34 && value < 0.34) ||
                        (current >= 0.34 && current < 0.75 && value >= 0.34 && value < 0.75) ||
                        (current >= 0.75 && value >= 0.75);
        NSString *title = selected ? [NSString stringWithFormat:@"✓  %@", option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults setDouble:[option[@"value"] doubleValue] forKey:WCAtlasMomentsLikeHapticIntensityKey];
        [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentStepModePicker {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger current = [defaults integerForKey:WCAtlasStepModeKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"步数模式" message:@"固定模式使用同一个数值；随机模式每天生成一次并显示当天结果。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@{@"title": @"固定步数", @"value": @(WCAtlasStepModeDailyFixed)}, @{@"title": @"每日随机", @"value": @(WCAtlasStepModeDailyRandom)}];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *title = value == current ? [NSString stringWithFormat:@"✓  %@", option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [defaults setInteger:value forKey:WCAtlasStepModeKey];
        [defaults setBool:YES forKey:WCAtlasStepOverrideEnabledKey];
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
        [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentFixedStepsEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置每日固定目标" message:@"请输入 1–100000 之间的数值" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasStepCountKey];
        field.text = value > 0 ? [NSString stringWithFormat:@"%ld", (long)value] : nil;
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.placeholder = @"步数";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults setInteger:MIN(100000, MAX(1, alert.textFields.firstObject.text.integerValue)) forKey:WCAtlasStepCountKey];
        [defaults setInteger:WCAtlasStepModeDailyFixed forKey:WCAtlasStepModeKey];
        [defaults setBool:YES forKey:WCAtlasStepOverrideEnabledKey];
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentRandomStepRangeEditor {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置每日随机目标" message:@"每天在最小值和最大值之间生成一次" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, [defaults integerForKey:WCAtlasStepRandomMinimumKey])]; field.keyboardType = UIKeyboardTypeNumberPad; field.placeholder = @"最小步数"; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, [defaults integerForKey:WCAtlasStepRandomMaximumKey])]; field.keyboardType = UIKeyboardTypeNumberPad; field.placeholder = @"最大步数"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSInteger minimum = MIN(100000, MAX(1, alert.textFields.firstObject.text.integerValue));
        NSInteger maximum = MIN(100000, MAX(1, alert.textFields.lastObject.text.integerValue));
        if (minimum > maximum) { NSInteger swap = minimum; minimum = maximum; maximum = swap; }
        [defaults setInteger:minimum forKey:WCAtlasStepRandomMinimumKey];
        [defaults setInteger:maximum forKey:WCAtlasStepRandomMaximumKey];
        [defaults setInteger:WCAtlasStepModeDailyRandom forKey:WCAtlasStepModeKey];
        [defaults setBool:YES forKey:WCAtlasStepOverrideEnabledKey];
        if ([defaults integerForKey:WCAtlasStepCountKey] <= 0) [defaults setInteger:minimum forKey:WCAtlasStepCountKey];
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentRegenerateRandomSteps {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger current = [defaults integerForKey:WCAtlasStepDailyTargetKey];
    NSString *message = current > 0
        ? [NSString stringWithFormat:@"当前结果为 %ld 步。重新生成后，今天将改用新结果。", (long)current]
        : @"今天尚未生成随机步数。";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"今日随机结果"
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"重新生成" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [defaults setInteger:WCAtlasStepModeDailyRandom forKey:WCAtlasStepModeKey];
        [defaults setBool:YES forKey:WCAtlasStepOverrideEnabledKey];
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
        [weakSelf reload];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentWalletEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置钱包余额" message:@"仅修改本机界面显示；留空或输入 0 可恢复真实显示" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        id stored = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasWalletBalanceFenKey];
        long long fen = [stored respondsToSelector:@selector(longLongValue)] ? [stored longLongValue] : 0;
        field.text = fen > 0 ? [NSString stringWithFormat:@"%.2f", fen / 100.0] : nil;
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.placeholder = @"例如 888.88";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *text = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        long long fen = text.length > 0 && text.doubleValue > 0 ? (long long)llround(text.doubleValue * 100.0) : 0;
        [NSUserDefaults.standardUserDefaults setObject:@(MAX(0LL, fen)) forKey:WCAtlasWalletBalanceFenKey];
        [NSUserDefaults.standardUserDefaults setBool:fen > 0 forKey:WCAtlasWalletBalanceEnabledKey];
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentContactsEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置好友数量" message:@"仅替换本机界面中的好友数量文案" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasContactsCountKey];
        field.text = value > 0 ? [NSString stringWithFormat:@"%ld", (long)value] : nil;
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.placeholder = @"好友数量";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSInteger value = MAX(0, alert.textFields.firstObject.text.integerValue);
        [NSUserDefaults.standardUserDefaults setInteger:value forKey:WCAtlasContactsCountKey];
        [NSUserDefaults.standardUserDefaults setBool:value > 0 forKey:WCAtlasContactsCountEnabledKey];
        [weakSelf reload];
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)presentMessageGestureActionPickerForItem:(WCAtlasSettingItem *)item {
    NSString *defaultsKey = item.defaultsKey;
    if (defaultsKey.length == 0) return;
    BOOL selfMessage = [defaultsKey isEqualToString:WCAtlasReplySwipeSelfActionKey] ||
                       [defaultsKey isEqualToString:WCAtlasReplySwipeRightSelfActionKey] ||
                       [defaultsKey isEqualToString:WCAtlasMessageDoubleTapSelfActionKey] ||
                       [defaultsKey isEqualToString:WCAtlasMessageTripleTapSelfActionKey];
    NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:defaultsKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.title
                                                                   message:selfMessage ? @"选择自己消息触发的动作" : @"选择对方消息触发的动作；不支持撤回"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = selfMessage
        ? @[
            @{@"title": @"不设置", @"value": @(WCAtlasReplySwipeActionNone)},
            @{@"title": @"引用", @"value": @(WCAtlasReplySwipeActionQuote)},
            @{@"title": @"撤回", @"value": @(WCAtlasReplySwipeActionRevoke)},
            @{@"title": @"复制", @"value": @(WCAtlasReplySwipeActionCopy)},
            @{@"title": @"删除", @"value": @(WCAtlasReplySwipeActionDelete)},
            @{@"title": @"复读", @"value": @(WCAtlasReplySwipeActionRepeat)},
        ]
        : @[
            @{@"title": @"不设置", @"value": @(WCAtlasReplySwipeActionNone)},
            @{@"title": @"引用", @"value": @(WCAtlasReplySwipeActionQuote)},
            @{@"title": @"复制", @"value": @(WCAtlasReplySwipeActionCopy)},
            @{@"title": @"删除", @"value": @(WCAtlasReplySwipeActionDelete)},
            @{@"title": @"复读", @"value": @(WCAtlasReplySwipeActionRepeat)},
        ];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *title = value == current ? [@"✓  " stringByAppendingString:option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:value forKey:defaultsKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:WCAtlasReplySwipeEnabledKey];
            [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentAvatarQuickMenuGesturePicker {
    NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasAvatarQuickMenuGestureKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"头像快捷面板"
                                                                   message:@"只启用一种头像手势，不影响消息气泡手势"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"关闭", @"value": @(WCAtlasAvatarQuickMenuGestureOff)},
        @{@"title": @"双击头像", @"value": @(WCAtlasAvatarQuickMenuGestureDoubleTap)},
        @{@"title": @"长按头像", @"value": @(WCAtlasAvatarQuickMenuGestureLongPress)},
    ];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *title = value == current ? [@"✓  " stringByAppendingString:option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:value forKey:WCAtlasAvatarQuickMenuGestureKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                               object:WCAtlasAvatarQuickMenuGestureKey];
            [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentChatGlassStylePicker {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger selected = [defaults integerForKey:WCAtlasChatGlassStyleKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"玻璃样式"
        message:@"磨砂玻璃保持纯模糊；伪液态额外加入贴合胶囊内部的柔和明暗和渐变高光边缘。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"磨砂玻璃", @"value": @0},
        @{@"title": @"伪液态", @"value": @1},
    ];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *title = option[@"title"];
        if (value == selected) title = [@"✓  " stringByAppendingString:title];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [defaults setInteger:value forKey:WCAtlasChatGlassStyleKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                               object:WCAtlasChatGlassStyleKey];
            [weakSelf reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)presentMomentsReminderForwardTargetPicker {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger selected = [defaults integerForKey:WCAtlasMomentsReminderForwardTargetKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"朋友圈转发目标"
                                                                    message:@"文字及已勾选的媒体会发送到所选会话"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = @[
        @{ @"title": @"自己的聊天框", @"value": @0 },
        @{ @"title": @"文件传输助手", @"value": @1 },
    ];
    for (NSDictionary *option in options) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *title = option[@"title"];
        if (value == selected) title = [title stringByAppendingString:@" ✓"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setInteger:value forKey:WCAtlasMomentsReminderForwardTargetKey];
            [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification
                                                               object:WCAtlasMomentsReminderForwardTargetKey];
            WCAtlasMomentsReminderSettingsDidChange();
            [self reload];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)performActionForItem:(WCAtlasSettingItem *)item {
    switch (item.action) {
        case WCAtlasSettingActionConfigManager: [self push:[WCAtlasConfigManagerViewController new]]; break;
        case WCAtlasSettingActionOfficialTelegram: [self openOfficialTelegram]; break;
        case WCAtlasSettingActionFindFriend: [self presentFindFriend]; break;
        case WCAtlasSettingActionOpenChatByID: [self presentOpenChatByID]; break;
        case WCAtlasSettingActionFriendRelationCheck: [self push:[WCAtlasFriendRelationCheckViewController new]]; break;
        case WCAtlasSettingActionReleaseNotes: [self push:[WCAtlasReleaseNotesHistoryViewController new]]; break;
        case WCAtlasSettingActionLogRecords: [self push:[WCAtlasLogViewController new]]; break;
        case WCAtlasSettingActionBlockUsers: [self push:[WCAtlasMessageBlockViewController new]]; break;
        case WCAtlasSettingActionBlockKeywords: [self push:[[WCAtlasListEditorViewController alloc] initWithTitle:item.title subtitle:@"仅匹配新收到的普通文字消息，每行填写一个关键词" defaultsKey:WCAtlasMessageBlockKeywordsKey mode:WCAtlasListEditorModeList]]; break;
        case WCAtlasSettingActionLongPressMenus: [self push:[WCAtlasLongPressMenuViewController new]]; break;
        case WCAtlasSettingActionMeMenu: [self push:[WCAtlasMeMenuViewController new]]; break;
        case WCAtlasSettingActionRevokePromptStyle: [self presentRevokePromptStylePicker]; break;
        case WCAtlasSettingActionRevokeAppearance: [self push:[WCAtlasAntiRevokeAppearanceViewController new]]; break;
        case WCAtlasSettingActionRevokeRecords: [self push:[WCAtlasAntiRevokeRecordsViewController new]]; break;
        case WCAtlasSettingActionRevokeFilter: [self presentRevokeFilterPicker]; break;
        case WCAtlasSettingActionRevokeLocalTemplate: [self presentTemplateWithTitle:item.title key:WCAtlasAntiRevokeLocalTemplateKey defaultValue:@"拦截到一条{用户名}撤回的消息\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n内容：{内容}"]; break;
        case WCAtlasSettingActionRevokeReplyTemplate: [self presentTemplateWithTitle:item.title key:WCAtlasAntiRevokeReplyTemplateKey defaultValue:@"【捕捉到一条撤回消息】\n操作用户：{用户名}\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n撤回内容：{内容}\n\n撤回无效，消息已保存"]; break;
        case WCAtlasSettingActionGlobalScale: [self presentNumberEditorWithTitle:item.title message:@"请输入 70 到 100 之间的百分比" key:WCAtlasPageScaleGlobalPercentKey minimum:70 maximum:100 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionSettingsScale: [self presentNumberEditorWithTitle:item.title message:@"请输入 70 到 100 之间的百分比" key:WCAtlasSettingsPageScalePercentKey minimum:70 maximum:100 notifyChange:YES applyScale:YES]; break;
        case WCAtlasSettingActionInnerRadius: [self presentNumberEditorWithTitle:item.title message:@"请输入 0 到 40 之间的数值；0 表示直角" key:WCAtlasChatInputInnerRadiusKey minimum:0 maximum:40 notifyChange:NO applyScale:NO]; break;
        case WCAtlasSettingActionOuterRadius: [self presentNumberEditorWithTitle:item.title message:@"请输入 0 到 40 之间的数值；0 表示直角" key:WCAtlasChatInputOuterRadiusKey minimum:0 maximum:40 notifyChange:NO applyScale:NO]; break;
        case WCAtlasSettingActionMomentsDateFormat: [self presentMomentsDateFormatEditor]; break;
        case WCAtlasSettingActionMomentsTailPicker: {
            __weak typeof(self) weakSelf = self;
            [self push:WCAtlasMomentsTailPicker(NO, ^{ [weakSelf reload]; })];
            break;
        }
        case WCAtlasSettingActionMessageTimeFormat: [self presentMessageTimeFormatEditor]; break;
        case WCAtlasSettingActionMessageTimeFontSize: [self presentNumberEditorWithTitle:item.title message:@"请输入 8 到 18 之间的字号" key:WCAtlasChatMessageTimeFontSizeKey minimum:8 maximum:18 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionMessageTimeMode: [self presentMessageTimeModePicker]; break;
        case WCAtlasSettingActionMessageTimeColor: [self presentMessageTimeColorPickerForKey:item.defaultsKey title:item.title]; break;
        case WCAtlasSettingActionMessageTimePosition: [self presentMessageTimePositionPicker]; break;
        case WCAtlasSettingActionMessageTimeAvatarSpacing: [self presentNumberEditorWithTitle:item.title message:@"请输入 -6 到 8 之间的数值；负值向上，正值向下" key:WCAtlasChatMessageTimeAvatarSpacingKey minimum:-6 maximum:8 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionPluginManager: [self push:[WCAtlasPluginsViewController new]]; break;
        case WCAtlasSettingActionInAppNotificationAppearance: [self push:[WCAtlasInAppNotificationSettingsViewController new]]; break;
        case WCAtlasSettingActionCallRecordings: [self push:[WCAtlasCallRecordingsViewController new]]; break;
        case WCAtlasSettingActionCallVoiceEffect: {
            __weak typeof(self) weakSelf = self;
            WCAtlasPresentCallVoiceEffectPicker(self.viewController, ^{ [weakSelf reload]; });
            break;
        }
        case WCAtlasSettingActionAutomations: [self push:[WCAtlasAutomationViewController new]]; break;
        case WCAtlasSettingActionKeywordReplies: [self push:[WCAtlasKeywordReplyViewController new]]; break;
        case WCAtlasSettingActionHomeCategories: [self push:[WCAtlasHomeCategoriesViewController new]]; break;
        case WCAtlasSettingActionHapticIntensity: [self presentHapticIntensityPicker]; break;
        case WCAtlasSettingActionStepMode: [self presentStepModePicker]; break;
        case WCAtlasSettingActionFixedSteps: [self presentFixedStepsEditor]; break;
        case WCAtlasSettingActionRandomStepRange: [self presentRandomStepRangeEditor]; break;
        case WCAtlasSettingActionRegenerateRandomSteps: [self presentRegenerateRandomSteps]; break;
        case WCAtlasSettingActionWalletBalance: [self presentWalletEditor]; break;
        case WCAtlasSettingActionContactsCount: [self presentContactsEditor]; break;
        case WCAtlasSettingActionRedEnvelopeFontSize: [self presentNumberEditorWithTitle:item.title message:@"请输入 10 到 24 之间的字号" key:WCAtlasRedEnvelopeDetailFontSizeKey minimum:10 maximum:24 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionChatTopAvatarSize: [self presentNumberEditorWithTitle:item.title message:@"请输入 24 到 34 之间的头像大小" key:WCAtlasChatTopBarAvatarSizeKey minimum:24 maximum:34 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionChatTopNicknameSize: [self presentNumberEditorWithTitle:item.title message:@"请输入 12 到 18 之间的昵称字号" key:WCAtlasChatTopBarNicknameSizeKey minimum:12 maximum:18 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionChatGlassStyle: [self presentChatGlassStylePicker]; break;
        case WCAtlasSettingActionChatGlassBlurIntensity: [self presentNumberEditorWithTitle:item.title message:@"请输入 20 到 100 之间的百分比" key:WCAtlasChatGlassBlurIntensityKey minimum:20 maximum:100 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionMessageGestureAction: [self presentMessageGestureActionPickerForItem:item]; break;
        case WCAtlasSettingActionAvatarQuickMenuGesture: [self presentAvatarQuickMenuGesturePicker]; break;
        case WCAtlasSettingActionReplySwipeTriggerDistance: [self presentNumberEditorWithTitle:item.title message:@"请输入 36 到 100 之间的触发距离；数值越小越容易触发" key:WCAtlasReplySwipeTriggerDistanceKey minimum:36 maximum:100 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionGlobalAvatarCornerPercent: [self presentNumberEditorWithTitle:item.title message:@"请输入 0 到 100 之间的百分比；0 为直角，100 为圆形" key:WCAtlasGlobalAvatarCornerPercentKey minimum:0 maximum:100 notifyChange:YES applyScale:NO]; break;
        case WCAtlasSettingActionQuickReplyLibrary: [self push:[[WCAtlasQuickReplyViewController alloc] initWithSelectionHandler:nil]]; break;
        case WCAtlasSettingActionSendConfirmationConversations: [self push:[WCAtlasSendConfirmationViewController new]]; break;
        case WCAtlasSettingActionSendConfirmationPauseDuration: [self presentSendConfirmationPauseDurationEditor]; break;
        case WCAtlasSettingActionMomentsReminderUsers: {
            UIViewController *picker = WCAtlasCreateFriendPicker(@"特别关注好友",
                                                               @"勾选后会建立当前朋友圈基线，只提醒后续检测到的新内容。",
                                                               ^BOOL(NSString *username) {
                return [WCAtlasMomentsReminderUsers() containsObject:username];
            }, ^(NSString *username) {
                BOOL selected = [WCAtlasMomentsReminderUsers() containsObject:username];
                WCAtlasMomentsReminderSetUserSelected(username, !selected);
                WCAtlasMomentsReminderSettingsDidChange();
            });
            [self push:picker];
            break;
        }
        case WCAtlasSettingActionMomentsReminderInterval:
            [self presentNumberEditorWithTitle:item.title
                                       message:@"请输入 30 到 3600 秒；后台检测频率仍会受 iOS 调度影响"
                                           key:WCAtlasMomentsReminderIntervalKey
                                       minimum:30
                                       maximum:3600
                                   notifyChange:YES
                                    applyScale:NO];
            break;
        case WCAtlasSettingActionMomentsReminderForwardTarget:
            [self presentMomentsReminderForwardTargetPicker];
            break;
        case WCAtlasSettingActionMomentsCommentAntiDeleteText:
            [self presentTemplateWithTitle:item.title key:WCAtlasMomentsCommentAntiDeleteTextKey defaultValue:@"←该评论已删除"];
            break;
        case WCAtlasSettingActionMomentsCommentAntiDeleteFontSize:
            [self presentNumberEditorWithTitle:item.title message:@"请输入 6 到 24 之间的字号"
                                            key:WCAtlasMomentsCommentAntiDeleteFontSizeKey minimum:6 maximum:24
                                   notifyChange:YES applyScale:NO];
            break;
        default: break;
    }
}

@end
