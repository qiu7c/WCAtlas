#import "WCAtlasChatTTS.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasSilkEncoder.h"
#import "WCAtlasTTSGenerator.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

static NSMutableSet<NSString *> *WCAtlasChatTTSActiveSessions(void) {
    static NSMutableSet<NSString *> *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

static NSString *WCAtlasChatTTSTrim(id value) {
    return [value isKindOfClass:NSString.class]
        ? [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
}

static NSString *WCAtlasChatTTSVoiceName(void) {
    NSString *selected = WCAtlasFishAudioReferenceID();
    if (selected.length == 0) return @"默认音色";
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        if ([preset[@"referenceID"] isEqualToString:selected]) return preset[@"name"] ?: @"自定义音色";
    }
    return @"自定义音色";
}

static NSString *WCAtlasChatTTSReferenceIDFromInput(NSString *input) {
    NSString *value = WCAtlasChatTTSTrim(input);
    if (value.length == 0) return @"";
    NSURLComponents *components = [NSURLComponents componentsWithString:value];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if ([item.name isEqualToString:@"modelId"] && item.value.length > 0) return item.value;
    }
    NSArray<NSString *> *parts = components.URL.pathComponents;
    NSUInteger marker = [parts indexOfObject:@"m"];
    if (marker != NSNotFound && marker + 1 < parts.count) return parts[marker + 1];
    return value;
}

static void WCAtlasChatTTSReport(WCAtlasChatTTSStatusHandler status,
                                 NSString *message, BOOL success) {
    WCAtlasLog(@"聊天 TTS：%@", message ?: @"");
    if (status) status(message ?: @"", success);
}

static BOOL WCAtlasChatTTSStillInConversation(UIViewController *presenter, NSString *userName) {
    if (userName.length == 0) return NO;
    // A presented settings sheet can temporarily make WeChat's "current chat"
    // resolver return nil.  Nil is not evidence that the user changed chats;
    // only reject when a different, non-empty chat identifier is observed.
    NSString *presenterUserName = WCAtlasPrivateChatUserName(presenter);
    if (presenterUserName.length > 0) return [presenterUserName isEqualToString:userName];
    Class chatControllerClass = NSClassFromString(@"BaseMsgContentViewController");
    if (chatControllerClass && [presenter isKindOfClass:chatControllerClass]) return YES;
    UIViewController *current = WCAtlasPrivateCurrentChatController();
    NSString *currentUserName = WCAtlasPrivateChatUserName(current);
    return currentUserName.length == 0 || [currentUserName isEqualToString:userName];
}

static void WCAtlasChatTTSConvertAndSend(UIViewController *presenter,
                                         NSString *target,
                                         NSURL *outputURL,
                                         dispatch_block_t didSubmit,
                                         WCAtlasChatTTSStatusHandler status) {
    __weak UIViewController *weakPresenter = presenter;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *silkPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"WCAtlas-chat-tts-%@.silk", NSUUID.UUID.UUIDString]];
        NSUInteger duration = 0;
        NSError *conversionError = nil;
        BOOL converted = WCAtlasEncodeAudioFileToSilk(outputURL.path, silkPath, &duration, &conversionError);
        [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [WCAtlasChatTTSActiveSessions() removeObject:target];
            UIViewController *strongPresenter = weakPresenter;
            if (!converted) {
                [NSFileManager.defaultManager removeItemAtPath:silkPath error:nil];
                WCAtlasChatTTSReport(status, conversionError.localizedDescription ?: @"TTS 音频转码失败", NO);
                return;
            }
            if (!WCAtlasChatTTSStillInConversation(strongPresenter, target)) {
                [NSFileManager.defaultManager removeItemAtPath:silkPath error:nil];
                WCAtlasChatTTSReport(status, @"生成完成，但当前聊天已经变化，未发送", NO);
                return;
            }
            BOOL submitted = WCAtlasPrivateSendVoiceMessage(target, silkPath, duration, 4);
            [NSFileManager.defaultManager removeItemAtPath:silkPath error:nil];
            if (!submitted) {
                WCAtlasChatTTSReport(status, @"微信语音上传接口不可用，未发送", NO);
                return;
            }
            if (didSubmit) didSubmit();
        });
    });
}

static void WCAtlasChatTTSGenerateAndSend(UIViewController *presenter,
                                         NSString *userName,
                                         NSString *text,
                                         dispatch_block_t didSubmit,
                                         WCAtlasChatTTSStatusHandler status) {
    NSCAssert(NSThread.isMainThread, @"Chat TTS must start on the main thread");
    NSString *target = WCAtlasChatTTSTrim(userName);
    NSString *content = WCAtlasChatTTSTrim(text);
    if (target.length == 0 || !WCAtlasChatTTSStillInConversation(presenter, target)) {
        WCAtlasChatTTSReport(status, @"当前聊天已经变化，未发送", NO);
        return;
    }
    if (content.length == 0) {
        WCAtlasChatTTSReport(status, @"请输入需要转成语音的内容", NO);
        return;
    }
    NSMutableSet<NSString *> *active = WCAtlasChatTTSActiveSessions();
    if ([active containsObject:target]) {
        WCAtlasChatTTSReport(status, @"当前聊天已有一条 TTS 正在生成", NO);
        return;
    }
    [active addObject:target];
    WCAtlasChatTTSReport(status, @"正在请求 Fish Audio…", YES);
    __weak UIViewController *weakPresenter = presenter;
    WCAtlasGenerateFishAudioSpeech(content, ^(NSURL *outputURL, NSError *generationError) {
        if (generationError || !outputURL) {
            [active removeObject:target];
            WCAtlasChatTTSReport(status, generationError.localizedDescription ?: @"TTS 生成失败", NO);
            return;
        }
        WCAtlasChatTTSConvertAndSend(weakPresenter, target, outputURL, didSubmit, status);
    });
}

static void WCAtlasChatTTSPresentMainPanel(UIViewController *, NSString *, dispatch_block_t,
                                           WCAtlasChatTTSStatusHandler);

@interface WCAtlasChatTTSPanelController : UIViewController <UITextViewDelegate, AVAudioPlayerDelegate>
@property (nonatomic, copy) NSString *chatUserName;
@property (nonatomic, copy) dispatch_block_t didSubmit;
@property (nonatomic, copy) WCAtlasChatTTSStatusHandler statusHandler;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *speedValueLabel;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISwitch *triggerSwitch;
@property (nonatomic, strong) UITextField *triggerField;
@property (nonatomic, strong) UIButton *voiceButton;
@property (nonatomic, strong) UIButton *modelButton;
@property (nonatomic, strong) UIButton *toneButton;
@property (nonatomic, strong) UIButton *previewButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong, nullable) AVAudioPlayer *previewPlayer;
@property (nonatomic, strong, nullable) NSURL *previewURL;
@property (nonatomic, copy, nullable) NSString *previewText;
@property (nonatomic, assign) BOOL previewGenerating;
- (instancetype)initWithUserName:(NSString *)userName
                       didSubmit:(dispatch_block_t _Nullable)didSubmit
                           status:(WCAtlasChatTTSStatusHandler _Nullable)status;
@end

typedef void (^WCAtlasChatTTSOptionHandler)(NSString *value, NSString *title);

@interface WCAtlasChatTTSOptionPickerController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *pickerTitle;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *items;
@property (nonatomic, copy) NSString *selectedValue;
@property (nonatomic, copy) WCAtlasChatTTSOptionHandler selectionHandler;
@property (nonatomic, assign) BOOL destructive;
- (instancetype)initWithTitle:(NSString *)title
                         items:(NSArray<NSDictionary<NSString *, NSString *> *> *)items
                 selectedValue:(NSString *)selectedValue
                   destructive:(BOOL)destructive
                       handler:(WCAtlasChatTTSOptionHandler)handler;
@end

static void __attribute__((unused)) WCAtlasChatTTSPresentModelPicker(UIViewController *presenter,
                                             NSString * __unused userName,
                                             dispatch_block_t __unused didSubmit,
                                             WCAtlasChatTTSStatusHandler status) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Fish Audio 模型"
        message:@"免费模型优先使用免费额度；付费模型需要账户余额。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *model in @[@"s2.1-pro-free", @"s2.1-pro", @"s2-pro"]) {
        NSString *title = [model isEqualToString:WCAtlasFishAudioModel()]
            ? [@"✓  " stringByAppendingString:model] : model;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioModel(model);
                WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"已选择模型：%@", model], YES);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
        CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentSpeedPicker(UIViewController *presenter,
                                             WCAtlasChatTTSStatusHandler status) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 TTS 语速"
        message:@"Fish Audio 支持 0.5x–2.0x；设置同时用于聊天和通话 TTS。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    double selected = WCAtlasFishAudioSpeechSpeed();
    for (NSNumber *value in @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0]) {
        double speed = value.doubleValue;
        NSString *name = speed == 1.0 ? @"正常（1.0x）" : [NSString stringWithFormat:@"%.2gx", speed];
        NSString *title = fabs(selected - speed) < 0.001 ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioSpeechSpeed(speed);
                WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"TTS 语速：%.2gx", speed], YES);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
        CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentTonePicker(UIViewController *presenter,
                                            WCAtlasChatTTSStatusHandler status) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 TTS 语调"
        message:@"语调通过 Fish Audio S2 的自然语言风格指令实现，实际效果会随音色变化。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *selected = WCAtlasFishAudioToneIdentifier();
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioTonePresets()) {
        NSString *identifier = preset[@"identifier"];
        NSString *name = preset[@"name"];
        NSString *title = [identifier isEqualToString:selected] ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioToneIdentifier(identifier);
                WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"TTS 语调：%@", name], YES);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
        CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void WCAtlasChatTTSPresentAddVoice(UIViewController *presenter,
                                          WCAtlasChatTTSStatusHandler status) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加音色"
        message:@"支持 reference_id、包含 modelId 的链接或 fish.audio/m/ 链接。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"音色名称"; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"音色 ID 或链接";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加并使用" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSString *name = WCAtlasChatTTSTrim(weakAlert.textFields.firstObject.text);
            NSString *input = weakAlert.textFields.count > 1 ? weakAlert.textFields[1].text : @"";
            NSString *referenceID = WCAtlasChatTTSReferenceIDFromInput(input);
            if (!WCAtlasAddFishAudioVoicePreset(name, referenceID)) {
                WCAtlasChatTTSReport(status, @"音色名称和 ID 不能为空", NO);
                return;
            }
            WCAtlasSetFishAudioReferenceID(referenceID);
            WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"已添加并选择音色：%@", name], YES);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentDeleteVoice(UIViewController *presenter,
                                             WCAtlasChatTTSStatusHandler status) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCAtlasFishAudioVoicePresets();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"删除音色预设"
        message:presets.count ? @"删除后不会自动恢复。" : @"当前没有可删除的音色。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary<NSString *, NSString *> *preset in presets) {
        NSString *name = preset[@"name"];
        NSString *referenceID = preset[@"referenceID"];
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDestructive
            handler:^(__unused UIAlertAction *action) {
                WCAtlasRemoveFishAudioVoicePreset(referenceID);
                WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"已删除音色：%@", name], YES);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
        CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentVoicePicker(UIViewController *presenter,
                                             WCAtlasChatTTSStatusHandler status) {
    NSString *selected = WCAtlasFishAudioReferenceID();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 TTS 音色"
        message:@"选择结果同时用于聊天 TTS 和通话 TTS。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:selected.length ? @"默认音色" : @"✓  默认音色"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WCAtlasSetFishAudioReferenceID(nil);
            WCAtlasChatTTSReport(status, @"已选择默认音色", YES);
        }]];
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        NSString *name = preset[@"name"];
        NSString *referenceID = preset[@"referenceID"];
        NSString *title = [referenceID isEqualToString:selected] ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioReferenceID(referenceID);
                WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"已选择音色：%@", name], YES);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"添加音色" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasChatTTSPresentAddVoice(presenter, status); });
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除音色" style:UIAlertActionStyleDestructive
        handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasChatTTSPresentDeleteVoice(presenter, status); });
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
        CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void WCAtlasChatTTSPresentAPISettings(UIViewController *presenter,
                                             WCAtlasChatTTSStatusHandler status) {
    BOOL hasKey = WCAtlasFishAudioAPIKey().length > 0;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Fish Audio 设置"
        message:[NSString stringWithFormat:@"当前模型：%@\nAPI Key 只保存在本机 Keychain。", WCAtlasFishAudioModel()]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = hasKey ? @"Key 已保存，留空保持不变" : @"Fish Audio API Key";
        field.secureTextEntry = YES;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"获取 Key" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSURL *URL = WCAtlasFishAudioAPIKeysURL();
            if (URL) [UIApplication.sharedApplication openURL:URL options:@{} completionHandler:nil];
        }]];
    if (hasKey) {
        [alert addAction:[UIAlertAction actionWithTitle:@"删除 Key" style:UIAlertActionStyleDestructive
            handler:^(__unused UIAlertAction *action) {
                NSError *error = nil;
                WCAtlasSetFishAudioAPIKey(@"", &error);
                WCAtlasChatTTSReport(status, error.localizedDescription ?: @"API Key 已删除", error == nil);
            }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSString *key = WCAtlasChatTTSTrim(weakAlert.textFields.firstObject.text);
            if (key.length == 0) {
                WCAtlasChatTTSReport(status, hasKey ? @"API Key 保持不变" : @"未填写 API Key", hasKey);
                return;
            }
            NSError *error = nil;
            BOOL saved = WCAtlasSetFishAudioAPIKey(key, &error);
            WCAtlasChatTTSReport(status, saved ? @"API Key 已保存" : (error.localizedDescription ?: @"API Key 保存失败"), saved);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentTriggerSettings(UIViewController *presenter,
                                                 WCAtlasChatTTSStatusHandler status) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults boolForKey:WCAtlasChatTTSTriggerEnabledKey];
    NSString *prefix = WCAtlasChatTTSTrim([defaults stringForKey:WCAtlasChatTTSTriggerPrefixKey]);
    if (prefix.length == 0) prefix = @"转语音";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文字触发转语音"
        message:[NSString stringWithFormat:@"当前：%@\n发送“%@你好”时，将拦截文字并发送 TTS 语音。",
                 enabled ? @"已开启" : @"已关闭", prefix]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"触发前缀，例如：转语音";
        field.text = prefix;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    void (^savePrefix)(void) = ^{
        NSString *newPrefix = WCAtlasChatTTSTrim(weakAlert.textFields.firstObject.text);
        if (newPrefix.length == 0) {
            WCAtlasChatTTSReport(status, @"触发前缀不能为空", NO);
            return;
        }
        [defaults setObject:newPrefix forKey:WCAtlasChatTTSTriggerPrefixKey];
        WCAtlasChatTTSReport(status,
            [NSString stringWithFormat:@"触发前缀已保存：%@（%@）", newPrefix,
             [defaults boolForKey:WCAtlasChatTTSTriggerEnabledKey] ? @"已开启" : @"已关闭"], YES);
    };
    [alert addAction:[UIAlertAction actionWithTitle:@"保存前缀"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            savePrefix();
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:enabled ? @"关闭触发" : @"开启触发"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSString *newPrefix = WCAtlasChatTTSTrim(weakAlert.textFields.firstObject.text);
            if (newPrefix.length == 0) {
                WCAtlasChatTTSReport(status, @"触发前缀不能为空", NO);
                return;
            }
            [defaults setObject:newPrefix forKey:WCAtlasChatTTSTriggerPrefixKey];
            [defaults setBool:!enabled forKey:WCAtlasChatTTSTriggerEnabledKey];
            WCAtlasChatTTSReport(status,
                [NSString stringWithFormat:@"文字触发已%@：%@", enabled ? @"关闭" : @"开启", newPrefix], YES);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void __attribute__((unused)) WCAtlasChatTTSPresentTextInput(UIViewController *presenter, NSString *userName,
                                           dispatch_block_t didSubmit,
                                           WCAtlasChatTTSStatusHandler status) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"发送 TTS 语音"
        message:[NSString stringWithFormat:@"%@ · %@\n语调：%@ · 语速：%.2gx · %@", WCAtlasFishAudioModel(),
                 WCAtlasChatTTSVoiceName(), WCAtlasFishAudioToneName(), WCAtlasFishAudioSpeechSpeed(),
                 WCAtlasFishAudioAPIKey().length ? @"Key 已配置" : @"未配置 Key"]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"输入要转换并发送的文字";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"生成并发送" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            WCAtlasChatTTSGenerateAndSend(presenter, userName,
                weakAlert.textFields.firstObject.text ?: @"", didSubmit, status);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@implementation WCAtlasChatTTSOptionPickerController

- (instancetype)initWithTitle:(NSString *)title
                         items:(NSArray<NSDictionary<NSString *,NSString *> *> *)items
                 selectedValue:(NSString *)selectedValue
                   destructive:(BOOL)destructive
                       handler:(WCAtlasChatTTSOptionHandler)handler {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _pickerTitle = [title copy];
        _items = [items copy] ?: @[];
        _selectedValue = [selectedValue copy] ?: @"";
        _selectionHandler = [handler copy];
        _destructive = destructive;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.18];
    UIControl *dismissArea = [UIControl new];
    dismissArea.translatesAutoresizingMaskIntoConstraints = NO;
    [dismissArea addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissArea];
    [NSLayoutConstraint activateConstraints:@[
        [dismissArea.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dismissArea.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dismissArea.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dismissArea.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.clipsToBounds = YES;
    [self.view addSubview:card];
    UIView *cardContent = card.contentView;
    cardContent.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.12];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = self.pickerTitle;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.textColor = UIColor.labelColor;
    [cardContent addSubview:title];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.secondaryLabelColor;
    [close addTarget:self action:@selector(closePicker) forControlEvents:UIControlEventTouchUpInside];
    [cardContent addSubview:close];
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.dataSource = self;
    table.delegate = self;
    table.rowHeight = 46;
    table.tableFooterView = [UIView new];
    table.backgroundColor = UIColor.clearColor;
    table.separatorColor = [UIColor.separatorColor colorWithAlphaComponent:0.28];
    [cardContent addSubview:table];

    CGFloat height = MIN(470.0, 58.0 + MAX(1, self.items.count) * 46.0);
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [card.heightAnchor constraintEqualToConstant:height],
        [title.leadingAnchor constraintEqualToAnchor:cardContent.leadingAnchor constant:16],
        [title.topAnchor constraintEqualToAnchor:cardContent.topAnchor constant:14],
        [close.trailingAnchor constraintEqualToAnchor:cardContent.trailingAnchor constant:-10],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:36],
        [close.heightAnchor constraintEqualToConstant:36],
        [table.leadingAnchor constraintEqualToAnchor:cardContent.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:cardContent.trailingAnchor],
        [table.topAnchor constraintEqualToAnchor:cardContent.topAnchor constant:52],
        [table.bottomAnchor constraintEqualToAnchor:cardContent.bottomAnchor]
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"WCAtlasChatTTSOption";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary<NSString *, NSString *> *item = self.items[(NSUInteger)indexPath.row];
    cell.textLabel.text = item[@"title"] ?: @"";
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.textColor = self.destructive ? UIColor.systemRedColor : UIColor.labelColor;
    cell.detailTextLabel.text = item[@"detail"];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = [item[@"value"] isEqualToString:self.selectedValue]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = self.destructive ? UIColor.systemRedColor : UIColor.systemBlueColor;
    cell.backgroundColor = UIColor.clearColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, NSString *> *item = self.items[(NSUInteger)indexPath.row];
    if (self.selectionHandler) self.selectionHandler(item[@"value"] ?: @"", item[@"title"] ?: @"");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)closePicker { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dismissKeyboard { [self.view endEditing:YES]; }

@end

@implementation WCAtlasChatTTSPanelController

static UILabel *WCAtlasChatTTSPanelLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

static UIButton *WCAtlasChatTTSPanelButton(NSString *title, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 11, 0, 11);
    button.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.58];
    button.layer.cornerRadius = 10;
    [button.heightAnchor constraintEqualToConstant:40].active = YES;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (instancetype)initWithUserName:(NSString *)userName
                       didSubmit:(dispatch_block_t)didSubmit
                           status:(WCAtlasChatTTSStatusHandler)status {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _chatUserName = [userName copy];
        _didSubmit = [didSubmit copy];
        _statusHandler = [status copy];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.18];

    UIControl *dismissArea = [UIControl new];
    dismissArea.translatesAutoresizingMaskIntoConstraints = NO;
    [dismissArea addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissArea];
    [NSLayoutConstraint activateConstraints:@[
        [dismissArea.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dismissArea.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dismissArea.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dismissArea.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = 24;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.clipsToBounds = YES;
    [self.view addSubview:card];
    UIView *cardContent = card.contentView;
    cardContent.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.10];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [cardContent addSubview:scrollView];
    UITapGestureRecognizer *keyboardTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(dismissKeyboard)];
    keyboardTap.cancelsTouchesInView = NO;
    [scrollView addGestureRecognizer:keyboardTap];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.layoutMargins = UIEdgeInsetsMake(14, 16, 34, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    [scrollView addSubview:stack];

    UIView *header = [UIView new];
    UILabel *title = WCAtlasChatTTSPanelLabel(@"TTS 语音", [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold],
                                               UIColor.labelColor);
    title.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.secondaryLabelColor;
    close.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.55];
    close.layer.cornerRadius = 14;
    [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    UIButton *APIButton = [UIButton buttonWithType:UIButtonTypeSystem];
    APIButton.translatesAutoresizingMaskIntoConstraints = NO;
    [APIButton setImage:[UIImage systemImageNamed:@"key.fill"] forState:UIControlStateNormal];
    APIButton.tintColor = UIColor.secondaryLabelColor;
    APIButton.accessibilityLabel = @"Fish Audio API Key";
    [APIButton addTarget:self action:@selector(configureAPI) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:title];
    [header addSubview:APIButton];
    [header addSubview:close];
    [NSLayoutConstraint activateConstraints:@[
        [header.heightAnchor constraintEqualToConstant:32],
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [APIButton.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-8],
        [APIButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [APIButton.widthAnchor constraintEqualToConstant:28],
        [APIButton.heightAnchor constraintEqualToConstant:28],
        [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [close.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:28],
        [close.heightAnchor constraintEqualToConstant:28]
    ]];
    [stack addArrangedSubview:header];

    self.summaryLabel = WCAtlasChatTTSPanelLabel(@"", [UIFont systemFontOfSize:11 weight:UIFontWeightMedium],
                                                 UIColor.secondaryLabelColor);
    [stack addArrangedSubview:self.summaryLabel];

    self.textView = [UITextView new];
    self.textView.font = [UIFont systemFontOfSize:15];
    self.textView.textContainerInset = UIEdgeInsetsMake(10, 9, 10, 9);
    self.textView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.58];
    self.textView.layer.cornerRadius = 11;
    self.textView.accessibilityLabel = @"需要转换为语音的文字";
    self.textView.delegate = self;
    [self.textView.heightAnchor constraintEqualToConstant:76].active = YES;
    [stack addArrangedSubview:self.textView];

    UIStackView *choiceRow = [[UIStackView alloc] init];
    choiceRow.axis = UILayoutConstraintAxisHorizontal;
    choiceRow.spacing = 8;
    choiceRow.distribution = UIStackViewDistributionFillEqually;
    self.voiceButton = WCAtlasChatTTSPanelButton(@"音色", self, @selector(selectVoice));
    self.modelButton = WCAtlasChatTTSPanelButton(@"模型", self, @selector(selectModel));
    self.toneButton = WCAtlasChatTTSPanelButton(@"语调", self, @selector(selectTone));
    for (UIButton *button in @[self.voiceButton, self.modelButton, self.toneButton]) {
        button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [choiceRow addArrangedSubview:button];
    }
    [stack addArrangedSubview:choiceRow];
    UIStackView *voiceManagementRow = [[UIStackView alloc] init];
    voiceManagementRow.axis = UILayoutConstraintAxisHorizontal;
    voiceManagementRow.spacing = 8;
    voiceManagementRow.distribution = UIStackViewDistributionFillEqually;
    UIButton *addVoice = WCAtlasChatTTSPanelButton(@"＋ 音色", self, @selector(addVoice));
    UIButton *deleteVoice = WCAtlasChatTTSPanelButton(@"删除", self, @selector(deleteVoice));
    addVoice.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    deleteVoice.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [deleteVoice setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    [voiceManagementRow addArrangedSubview:addVoice];
    [voiceManagementRow addArrangedSubview:deleteVoice];
    [stack addArrangedSubview:voiceManagementRow];

    UIView *speedHeader = [UIView new];
    UILabel *speedTitle = WCAtlasChatTTSPanelLabel(@"语速", [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold],
                                                   UIColor.labelColor);
    speedTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedValueLabel = WCAtlasChatTTSPanelLabel(@"1.00×", [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold],
                                                    UIColor.systemBlueColor);
    self.speedValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [speedHeader addSubview:speedTitle];
    [speedHeader addSubview:self.speedValueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [speedHeader.heightAnchor constraintEqualToConstant:20],
        [speedTitle.leadingAnchor constraintEqualToAnchor:speedHeader.leadingAnchor],
        [speedTitle.centerYAnchor constraintEqualToAnchor:speedHeader.centerYAnchor],
        [self.speedValueLabel.trailingAnchor constraintEqualToAnchor:speedHeader.trailingAnchor],
        [self.speedValueLabel.centerYAnchor constraintEqualToAnchor:speedHeader.centerYAnchor]
    ]];
    [stack addArrangedSubview:speedHeader];
    self.speedSlider = [UISlider new];
    self.speedSlider.minimumValue = 0.5f;
    self.speedSlider.maximumValue = 2.0f;
    self.speedSlider.continuous = YES;
    self.speedSlider.minimumTrackTintColor = UIColor.systemBlueColor;
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [self.speedSlider addTarget:self action:@selector(speedCommitted:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [stack addArrangedSubview:self.speedSlider];

    UIView *triggerRow = [UIView new];
    UILabel *triggerTitle = WCAtlasChatTTSPanelLabel(@"文字触发", [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold],
                                                     UIColor.labelColor);
    triggerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.triggerSwitch = [UISwitch new];
    self.triggerSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.triggerSwitch.transform = CGAffineTransformMakeScale(0.84, 0.84);
    [self.triggerSwitch addTarget:self action:@selector(triggerChanged:) forControlEvents:UIControlEventValueChanged];
    [triggerRow addSubview:triggerTitle];
    [triggerRow addSubview:self.triggerSwitch];
    [NSLayoutConstraint activateConstraints:@[
        [triggerRow.heightAnchor constraintEqualToConstant:30],
        [triggerTitle.leadingAnchor constraintEqualToAnchor:triggerRow.leadingAnchor],
        [triggerTitle.centerYAnchor constraintEqualToAnchor:triggerRow.centerYAnchor],
        [self.triggerSwitch.trailingAnchor constraintEqualToAnchor:triggerRow.trailingAnchor],
        [self.triggerSwitch.centerYAnchor constraintEqualToAnchor:triggerRow.centerYAnchor]
    ]];
    [stack addArrangedSubview:triggerRow];
    self.triggerField = [UITextField new];
    self.triggerField.placeholder = @"触发词，例如：转语音";
    self.triggerField.font = [UIFont systemFontOfSize:13];
    self.triggerField.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.58];
    self.triggerField.layer.cornerRadius = 10;
    self.triggerField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.triggerField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.triggerField.leftViewMode = UITextFieldViewModeAlways;
    [self.triggerField addTarget:self action:@selector(triggerPrefixCommitted:) forControlEvents:UIControlEventEditingDidEnd];
    [self.triggerField.heightAnchor constraintEqualToConstant:38].active = YES;
    [stack addArrangedSubview:self.triggerField];

    UIStackView *speechActions = [[UIStackView alloc] init];
    speechActions.axis = UILayoutConstraintAxisHorizontal;
    speechActions.spacing = 8;
    speechActions.distribution = UIStackViewDistributionFillEqually;
    self.previewButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.previewButton setTitle:@"生成预览" forState:UIControlStateNormal];
    self.previewButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.previewButton.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.68];
    self.previewButton.layer.cornerRadius = 11;
    [self.previewButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [self.previewButton addTarget:self action:@selector(previewSpeech) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.sendButton.backgroundColor = UIColor.systemBlueColor;
    self.sendButton.layer.cornerRadius = 11;
    [self.sendButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [self.sendButton addTarget:self action:@selector(sendSpeech) forControlEvents:UIControlEventTouchUpInside];
    [speechActions addArrangedSubview:self.previewButton];
    [speechActions addArrangedSubview:self.sendButton];
    [stack addArrangedSubview:speechActions];

    CGFloat maximumHeight = MIN(UIScreen.mainScreen.bounds.size.height - 32.0, 548.0);
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [card.heightAnchor constraintEqualToConstant:maximumHeight],
        [scrollView.leadingAnchor constraintEqualToAnchor:cardContent.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:cardContent.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:cardContent.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:cardContent.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];
    [self refreshValues];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshValues];
}

- (void)refreshValues {
    self.summaryLabel.text = WCAtlasFishAudioAPIKey().length ? @"● Fish Audio 已连接" : @"○ 未配置 API Key";
    [self.voiceButton setTitle:WCAtlasChatTTSVoiceName() forState:UIControlStateNormal];
    [self.modelButton setTitle:WCAtlasFishAudioModel() forState:UIControlStateNormal];
    [self.toneButton setTitle:WCAtlasFishAudioToneName() forState:UIControlStateNormal];
    self.speedSlider.value = (float)WCAtlasFishAudioSpeechSpeed();
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.2f×", self.speedSlider.value];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.triggerSwitch.on = [defaults boolForKey:WCAtlasChatTTSTriggerEnabledKey];
    NSString *prefix = WCAtlasChatTTSTrim([defaults stringForKey:WCAtlasChatTTSTriggerPrefixKey]);
    self.triggerField.text = prefix.length ? prefix : @"转语音";
}

- (void)report:(NSString *)message success:(BOOL)success {
    [self refreshValues];
    WCAtlasChatTTSReport(self.statusHandler, message, success);
}

- (void)clearPreview {
    [self.previewPlayer stop];
    self.previewPlayer.delegate = nil;
    self.previewPlayer = nil;
    if (self.previewURL) [NSFileManager.defaultManager removeItemAtURL:self.previewURL error:nil];
    self.previewURL = nil;
    self.previewText = nil;
    if (!self.previewGenerating) [self.previewButton setTitle:@"生成预览" forState:UIControlStateNormal];
}

- (void)closePanel {
    [self clearPreview];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (void)textViewDidChange:(__unused UITextView *)textView {
    if (self.previewURL) [self clearPreview];
}

- (void)audioPlayerDidFinishPlaying:(__unused AVAudioPlayer *)player
                       successfully:(__unused BOOL)flag {
    [self.previewButton setTitle:@"再次播放" forState:UIControlStateNormal];
}

- (void)speedChanged:(UISlider *)slider {
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.2f×", slider.value];
}

- (void)speedCommitted:(UISlider *)slider {
    [self clearPreview];
    WCAtlasSetFishAudioSpeechSpeed(slider.value);
    [self report:[NSString stringWithFormat:@"TTS 语速：%.2f×", slider.value] success:YES];
}

- (void)triggerChanged:(UISwitch *)sender {
    NSString *prefix = WCAtlasChatTTSTrim(self.triggerField.text);
    if (prefix.length == 0) prefix = @"转语音";
    [NSUserDefaults.standardUserDefaults setObject:prefix forKey:WCAtlasChatTTSTriggerPrefixKey];
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:WCAtlasChatTTSTriggerEnabledKey];
    [self report:[NSString stringWithFormat:@"文字触发已%@：%@", sender.isOn ? @"开启" : @"关闭", prefix]
           success:YES];
}

- (void)triggerPrefixCommitted:(UITextField *)field {
    NSString *prefix = WCAtlasChatTTSTrim(field.text);
    if (prefix.length == 0) prefix = @"转语音";
    field.text = prefix;
    [NSUserDefaults.standardUserDefaults setObject:prefix forKey:WCAtlasChatTTSTriggerPrefixKey];
}

- (WCAtlasChatTTSStatusHandler)nestedStatus {
    __weak typeof(self) weakSelf = self;
    return ^(NSString *message, BOOL success) { [weakSelf report:message success:success]; };
}

- (void)presentOptionsWithTitle:(NSString *)title
                           items:(NSArray<NSDictionary<NSString *, NSString *> *> *)items
                        selected:(NSString *)selected
                     destructive:(BOOL)destructive
                         handler:(WCAtlasChatTTSOptionHandler)handler {
    WCAtlasChatTTSOptionPickerController *picker = [[WCAtlasChatTTSOptionPickerController alloc]
        initWithTitle:title items:items selectedValue:selected destructive:destructive handler:handler];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)selectVoice {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *items = [NSMutableArray arrayWithObject:
        @{@"title": @"默认音色", @"value": @"", @"detail": @"使用 Fish Audio 默认声音"}];
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        [items addObject:@{@"title": preset[@"name"] ?: @"自定义音色",
                           @"value": preset[@"referenceID"] ?: @""}];
    }
    __weak typeof(self) weakSelf = self;
    [self presentOptionsWithTitle:@"选择音色" items:items selected:WCAtlasFishAudioReferenceID()
                      destructive:NO handler:^(NSString *value, NSString *title) {
        [weakSelf clearPreview];
        WCAtlasSetFishAudioReferenceID(value);
        [weakSelf report:[NSString stringWithFormat:@"已选择音色：%@", title] success:YES];
    }];
}

- (void)selectModel {
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *model in @[@"s2.1-pro-free", @"s2.1-pro", @"s2-pro"]) {
        [items addObject:@{@"title": model, @"value": model,
                           @"detail": [model hasSuffix:@"free"] ? @"优先使用免费额度" : @"需要账户余额"}];
    }
    __weak typeof(self) weakSelf = self;
    [self presentOptionsWithTitle:@"选择模型" items:items selected:WCAtlasFishAudioModel()
                      destructive:NO handler:^(NSString *value, NSString *title) {
        [weakSelf clearPreview];
        WCAtlasSetFishAudioModel(value);
        [weakSelf report:[NSString stringWithFormat:@"已选择模型：%@", title] success:YES];
    }];
}

- (void)selectTone {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioTonePresets()) {
        [items addObject:@{@"title": preset[@"name"] ?: @"自然",
                           @"value": preset[@"identifier"] ?: @"natural"}];
    }
    __weak typeof(self) weakSelf = self;
    [self presentOptionsWithTitle:@"选择语调" items:items selected:WCAtlasFishAudioToneIdentifier()
                      destructive:NO handler:^(NSString *value, NSString *title) {
        [weakSelf clearPreview];
        WCAtlasSetFishAudioToneIdentifier(value);
        [weakSelf report:[NSString stringWithFormat:@"TTS 语调：%@", title] success:YES];
    }];
}

- (void)addVoice {
    [self clearPreview];
    WCAtlasChatTTSPresentAddVoice(self, [self nestedStatus]);
}

- (void)deleteVoice {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        [items addObject:@{@"title": preset[@"name"] ?: @"自定义音色",
                           @"value": preset[@"referenceID"] ?: @""}];
    }
    if (items.count == 0) {
        [self report:@"当前没有可删除的音色" success:NO];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self presentOptionsWithTitle:@"删除音色" items:items selected:@"" destructive:YES
                          handler:^(NSString *value, NSString *title) {
        WCAtlasRemoveFishAudioVoicePreset(value);
        [weakSelf report:[NSString stringWithFormat:@"已删除音色：%@", title] success:YES];
    }];
}
- (void)configureAPI { WCAtlasChatTTSPresentAPISettings(self, [self nestedStatus]); }

- (void)dealloc {
    [self.previewPlayer stop];
    self.previewPlayer.delegate = nil;
    if (self.previewURL) [NSFileManager.defaultManager removeItemAtURL:self.previewURL error:nil];
}

- (void)previewSpeech {
    [self triggerPrefixCommitted:self.triggerField];
    NSString *text = WCAtlasChatTTSTrim(self.textView.text);
    if (text.length == 0) {
        [self report:@"请输入需要转成语音的内容" success:NO];
        return;
    }
    if (self.previewURL && [self.previewText isEqualToString:text] && self.previewPlayer) {
        if (self.previewPlayer.isPlaying) {
            [self.previewPlayer pause];
            [self.previewButton setTitle:@"继续播放" forState:UIControlStateNormal];
        } else {
            if (self.previewPlayer.currentTime >= self.previewPlayer.duration) self.previewPlayer.currentTime = 0;
            [self.previewPlayer play];
            [self.previewButton setTitle:@"暂停" forState:UIControlStateNormal];
        }
        return;
    }
    if (self.previewGenerating) return;
    NSMutableSet<NSString *> *active = WCAtlasChatTTSActiveSessions();
    if ([active containsObject:self.chatUserName]) {
        [self report:@"当前聊天已有一条 TTS 正在生成" success:NO];
        return;
    }
    [self clearPreview];
    self.previewGenerating = YES;
    self.previewButton.enabled = NO;
    self.sendButton.enabled = NO;
    [self.previewButton setTitle:@"生成中…" forState:UIControlStateNormal];
    NSString *target = [self.chatUserName copy];
    [active addObject:target];
    __weak typeof(self) weakSelf = self;
    WCAtlasGenerateFishAudioSpeech(text, ^(NSURL *outputURL, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        [active removeObject:target];
        if (!strongSelf) {
            if (outputURL) [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
            return;
        }
        strongSelf.previewGenerating = NO;
        strongSelf.previewButton.enabled = YES;
        strongSelf.sendButton.enabled = YES;
        if (error || !outputURL) {
            [strongSelf.previewButton setTitle:@"重新生成" forState:UIControlStateNormal];
            [strongSelf report:error.localizedDescription ?: @"TTS 生成失败" success:NO];
            return;
        }
        NSError *playerError = nil;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:outputURL error:&playerError];
        if (!player || playerError) {
            [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
            [strongSelf.previewButton setTitle:@"重新生成" forState:UIControlStateNormal];
            [strongSelf report:playerError.localizedDescription ?: @"无法预览生成的音频" success:NO];
            return;
        }
        strongSelf.previewURL = outputURL;
        strongSelf.previewText = text;
        strongSelf.previewPlayer = player;
        player.delegate = strongSelf;
        [player prepareToPlay];
        [player play];
        [strongSelf.previewButton setTitle:@"暂停" forState:UIControlStateNormal];
    });
}

- (void)sendSpeech {
    [self triggerPrefixCommitted:self.triggerField];
    NSString *text = WCAtlasChatTTSTrim(self.textView.text);
    if (text.length == 0) {
        [self report:@"请输入需要转成语音的内容" success:NO];
        return;
    }
    if (!WCAtlasChatTTSStillInConversation(self.presentingViewController, self.chatUserName)) {
        [self report:@"当前聊天已经变化，未发送" success:NO];
        return;
    }
    self.previewButton.enabled = NO;
    self.sendButton.enabled = NO;
    [self.sendButton setTitle:@"发送中…" forState:UIControlStateNormal];
    __weak typeof(self) weakSelf = self;
    UIViewController *chatPresenter = self.presentingViewController ?: self;
    WCAtlasChatTTSStatusHandler sendStatus = ^(NSString *message, BOOL success) {
        typeof(self) strongSelf = weakSelf;
        if (!success) {
            strongSelf.previewButton.enabled = YES;
            strongSelf.sendButton.enabled = YES;
            [strongSelf.sendButton setTitle:@"发送" forState:UIControlStateNormal];
        }
        [strongSelf report:message success:success];
    };

    dispatch_block_t submitted = ^{
        if (weakSelf.didSubmit) weakSelf.didSubmit();
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    if (self.previewURL && [self.previewText isEqualToString:text]) {
        NSMutableSet<NSString *> *active = WCAtlasChatTTSActiveSessions();
        if ([active containsObject:self.chatUserName]) {
            self.previewButton.enabled = YES;
            self.sendButton.enabled = YES;
            [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
            return;
        }
        [active addObject:self.chatUserName];
        [self.previewPlayer stop];
        self.previewPlayer.delegate = nil;
        self.previewPlayer = nil;
        NSURL *outputURL = self.previewURL;
        self.previewURL = nil;
        self.previewText = nil;
        WCAtlasChatTTSConvertAndSend(chatPresenter, self.chatUserName, outputURL,
                                     submitted, sendStatus);
        return;
    }
    WCAtlasChatTTSGenerateAndSend(chatPresenter, self.chatUserName, text,
                                  submitted, sendStatus);
}

@end

static void WCAtlasChatTTSPresentMainPanel(UIViewController *presenter, NSString *userName,
                                           dispatch_block_t didSubmit,
                                           WCAtlasChatTTSStatusHandler status) {
    if (!presenter.viewIfLoaded.window) return;
    WCAtlasChatTTSPanelController *panel = [[WCAtlasChatTTSPanelController alloc]
        initWithUserName:userName didSubmit:didSubmit status:status];
    [presenter presentViewController:panel animated:YES completion:nil];
}

void WCAtlasPresentChatTTSPanel(UIViewController *presenter, NSString *userName,
                                dispatch_block_t didSubmit, WCAtlasChatTTSStatusHandler status) {
    NSCAssert(NSThread.isMainThread, @"Chat TTS panel must be presented on the main thread");
    if (!presenter || userName.length == 0) {
        WCAtlasChatTTSReport(status, @"当前页面不是可用的聊天会话", NO);
        return;
    }
    WCAtlasChatTTSPresentMainPanel(presenter, userName, didSubmit, status);
}

BOOL WCAtlasChatTTSConsumeTriggeredText(UIViewController *presenter, NSString *userName,
                                        NSString *text, dispatch_block_t didSubmit,
                                        WCAtlasChatTTSStatusHandler status) {
    NSCAssert(NSThread.isMainThread, @"Chat TTS trigger must run on the main thread");
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults boolForKey:WCAtlasChatTTSTriggerEnabledKey]) return NO;
    NSString *prefix = WCAtlasChatTTSTrim([defaults stringForKey:WCAtlasChatTTSTriggerPrefixKey]);
    if (prefix.length == 0) prefix = @"转语音";
    if (![text isKindOfClass:NSString.class]) return NO;
    NSString *command = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![command hasPrefix:prefix]) return NO;
    NSString *content = [command substringFromIndex:prefix.length];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n:：+＋➕"];
    content = [content stringByTrimmingCharactersInSet:separators];
    if (content.length == 0) {
        WCAtlasChatTTSReport(status, [NSString stringWithFormat:@"请在“%@”后输入内容", prefix], NO);
        return YES;
    }
    WCAtlasChatTTSGenerateAndSend(presenter, userName, content, didSubmit, status);
    return YES;
}
