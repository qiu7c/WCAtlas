#import "WCAtlasSettingsCatalog.h"
#import "WCAtlasAntiRevoke.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasLogging.h"
#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasMessageBlock.h"
#import "WCAtlasSendConfirmation.h"
#import "WCAtlasBackgroundKeeper.h"
#import "WCAtlasMomentsInteractionReminder.h"
#import "WCAtlasMomentsReminder.h"
#import "WCAtlasInAppNotification.h"
#import "WCAtlasPluginManager.h"
#import "WCAtlasMentionHighlight.h"
#import "WCAtlasHomeCategories.h"
#import "WCAtlasChatTTS.h"
#import <stdlib.h>

NSString *const WCAtlasEnabledKey = @"com.qiu7c.wcatlas.enabled";
NSString *const WCAtlasCollapsedFeaturesKey = @"com.qiu7c.wcatlas.ui.collapsed-features";
static NSString *const WCAtlasExpandedCategoriesKey = @"com.qiu7c.wcatlas.ui.expanded-categories";

NSString *const WCAtlasDisplayVersion = @"1.0.0";
static NSString *const WCAtlasChatGlassPseudoLiquid20MigrationKey = @"com.qiu7c.wcatlas.migration.chat-glass-pseudo-liquid-20-v1";

static WCAtlasSettingItem *WCAtlasItem(NSString *title, NSString *subtitle, NSString *symbol,
                                  WCAtlasSettingRowKind kind, NSString *key, NSString *value,
                                  WCAtlasSettingAction action) {
    NSString *identifier = key.length > 0 ? key : [NSString stringWithFormat:@"action-%ld", (long)action];
    return [WCAtlasSettingItem itemWithIdentifier:identifier title:title subtitle:subtitle symbol:symbol
                                           kind:kind key:key value:value action:action];
}

static void WCAtlasAddFeature(NSMutableArray<WCAtlasSettingItem *> *items,
                            WCAtlasSettingItem *parent,
                            NSArray<WCAtlasSettingItem *> *children,
                            NSUserDefaults *defaults,
                            NSSet<NSString *> *collapsedFeatureKeys) {
    parent.hasChildren = children.count > 0;
    [items addObject:parent];
    if (parent.defaultsKey.length > 0 && [defaults boolForKey:parent.defaultsKey] &&
        ![collapsedFeatureKeys containsObject:parent.defaultsKey]) {
        for (WCAtlasSettingItem *child in children) child.child = YES;
        [items addObjectsFromArray:children];
    }
}

static NSString *WCAtlasCountText(NSUInteger count) {
    return count > 0 ? [NSString stringWithFormat:@"%lu 项", (unsigned long)count] : @"设置";
}

static NSString *WCAtlasCurrentSelection(NSString *value) {
    return [NSString stringWithFormat:@"当前选择：%@", value ?: @"未设置"];
}

static NSString *WCAtlasSendConfirmationPauseDurationText(NSInteger seconds) {
    seconds = seconds > 0 ? seconds : 60;
    return seconds % 60 == 0 ? [NSString stringWithFormat:@"%ld 分钟", (long)(seconds / 60)] :
                               [NSString stringWithFormat:@"%ld 秒", (long)seconds];
}

static long long WCAtlasLongLongForKey(NSString *key) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return [value respondsToSelector:@selector(longLongValue)] ? [value longLongValue] : 0;
}

void WCAtlasSettingsRegenerateDailyStepTarget(NSUserDefaults *defaults) {
    WCAtlasStepMode mode = (WCAtlasStepMode)[defaults integerForKey:WCAtlasStepModeKey];
    NSInteger target = 0;
    if (mode == WCAtlasStepModeDailyRandom) {
        NSInteger minimum = MIN(100000, MAX(1, [defaults integerForKey:WCAtlasStepRandomMinimumKey]));
        NSInteger maximum = MIN(100000, MAX(minimum, [defaults integerForKey:WCAtlasStepRandomMaximumKey]));
        target = minimum + (NSInteger)arc4random_uniform((uint32_t)(maximum - minimum + 1));
    } else {
        target = MIN(100000, MAX(0, [defaults integerForKey:WCAtlasStepCountKey]));
    }
    if (target > 0) {
        [defaults setInteger:target forKey:WCAtlasStepDailyTargetKey];
        [defaults setObject:NSDate.date forKey:WCAtlasStepCountDateKey];
    } else {
        [defaults removeObjectForKey:WCAtlasStepDailyTargetKey];
        [defaults removeObjectForKey:WCAtlasStepCountDateKey];
    }
}

void WCAtlasSettingsHandleSwitchChange(NSString *key, BOOL enabled) {
    if (key.length == 0) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([key isEqualToString:WCAtlasPluginManagerEnabledKey] && enabled) {
        if (WCAtlasExternalPluginManagerAvailable()) {
            [defaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
            return;
        }
        if (!WCAtlasInstallPluginRegistry()) {
            [defaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
            return;
        }
        Class managerClass = NSClassFromString(@"WCPluginsMgr");
        WCAtlasPluginsMgr *manager = managerClass ? [managerClass sharedInstance] : nil;
        if (!manager) {
            [defaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
            return;
        }
        [manager registerControllerWithTitle:@"WCAtlas"
                                      version:WCAtlasDisplayVersion
                                   controller:@"WCAtlasSettingsViewController"];
        WCAtlasPluginManagerRegisterSavedQuickSwitches();
    }
    if ([key isEqualToString:WCAtlasStepOverrideEnabledKey] && enabled) {
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
    }
    if ([key isEqualToString:WCAtlasAntiRevokePersistRecordsKey]) {
        WCAtlasAntiRevokeSetPersistenceEnabled(enabled);
    }
    if ([key hasPrefix:@"com.qiu7c.wcatlas."]) {
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasEnhancementDidChangeNotification object:key];
    }
    if ([key isEqualToString:WCAtlasAntiRevokeKey]) {
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
    }
    if ([key isEqualToString:WCAtlasBackgroundKeepAliveEnabledKey]) {
        WCAtlasBackgroundKeeperSettingsDidChange();
    }
    if ([key isEqualToString:WCAtlasMomentsInteractionReminderEnabledKey]) {
        WCAtlasMomentsInteractionReminderSettingsDidChange();
    }
    if ([key isEqualToString:WCAtlasMomentsReminderEnabledKey] ||
        [key isEqualToString:WCAtlasMomentsReminderUsersKey] ||
        [key isEqualToString:WCAtlasMomentsReminderIntervalKey] ||
        [key isEqualToString:WCAtlasMomentsReminderForwardEnabledKey] ||
        [key isEqualToString:WCAtlasMomentsReminderForwardTargetKey] ||
        [key isEqualToString:WCAtlasMomentsReminderForwardImagesKey] ||
        [key isEqualToString:WCAtlasMomentsReminderForwardVideosKey]) {
        WCAtlasMomentsReminderSettingsDidChange();
    }
}

void WCAtlasSettingsRegisterDefaults(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:@"com.qiu7c.wcatlas.chat.top-bar-capsule.effect-style"];
    [defaults registerDefaults:@{
        WCAtlasEnabledKey: @YES,
        WCAtlasAntiRevokeKey: @YES,
        WCAtlasAntiRevokeNotifySenderKey: @NO,
        WCAtlasAntiRevokeTimeFilterKey: @300.0,
        WCAtlasAntiRevokePromptStyleKey: @0,
        WCAtlasAntiRevokeSideTextKey: @"已拦截撤回",
        WCAtlasAntiRevokeSideOffsetXKey: @0.0,
        WCAtlasAntiRevokeSideOffsetYKey: @10.0,
        WCAtlasAntiRevokePersistRecordsKey: @NO,
        WCAtlasImageEditQuickSendEnabledKey: @NO,
        WCAtlasMediaToVoiceEnabledKey: @YES,
        WCAtlasAudioFileToVoiceEnabledKey: @YES,
        WCAtlasVideoToVoiceEnabledKey: @YES,
        WCAtlasMusicToVoiceEnabledKey: @YES,
        WCAtlasChatJokerEnabledKey: @NO,
        WCAtlasChatMessageTimeEnabledKey: @NO,
        WCAtlasChatMessageTimeBelowAvatarKey: @YES,
        WCAtlasChatMessageTimeBubbleSideKey: @NO,
        WCAtlasChatMessageTimeFormatKey: @"MM-dd HH:mm:ss",
        WCAtlasChatMessageTimeFontSizeKey: @10.0,
        WCAtlasChatMessageTimeColorKey: @"#8E8E93FF",
        WCAtlasChatMessageTimeBubbleVerticalPositionKey: @2,
        WCAtlasChatMessageTimeAvatarSpacingKey: @-2.0,
        WCAtlasChatMessageTimeBoldKey: @NO,
        WCAtlasEmoticonToSelfieEnabledKey: @NO,
        WCAtlasMomentsForwardEnabledKey: @NO,
        WCAtlasMomentsSaveImagesEnabledKey: @NO,
        WCAtlasMomentsOriginalMediaPostEnabledKey: @NO,
        WCAtlasMomentsTailEnabledKey: @NO,
        WCAtlasReplySwipeEnabledKey: @NO,
        WCAtlasReplySwipeSelfActionKey: @(WCAtlasReplySwipeActionQuote),
        WCAtlasReplySwipeOtherActionKey: @(WCAtlasReplySwipeActionQuote),
        WCAtlasReplySwipeRightSelfActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasReplySwipeRightOtherActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasReplySwipeTriggerDistanceKey: @56.0,
        WCAtlasMessageDoubleTapSelfActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasMessageDoubleTapOtherActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasMessageTripleTapSelfActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasMessageTripleTapOtherActionKey: @(WCAtlasReplySwipeActionNone),
        WCAtlasAvatarQuickMenuGestureKey: @(WCAtlasAvatarQuickMenuGestureOff),
        WCAtlasQuoteJumpEnabledKey: @NO,
        WCAtlasMentionHighlightEnabledKey: @NO,
        WCAtlasHomeCategoriesEnabledKey: @NO,
        WCAtlasHomeCategoriesDataKey: @[],
        WCAtlasQuoteJumpImageEnabledKey: @YES,
        WCAtlasQuoteJumpVideoEnabledKey: @YES,
        WCAtlasChatSearchButtonEnabledKey: @NO,
        WCAtlasChatTopBarCapsuleEnabledKey: @NO,
        WCAtlasChatGlassStyleKey: @1,
        WCAtlasChatGlassBlurIntensityKey: @20.0,
        WCAtlasChatTopBarAvatarSizeKey: @30.0,
        WCAtlasChatTopBarNicknameSizeKey: @15.0,
        WCAtlasMessageBlockEnabledKey: @NO,
        WCAtlasMessageBlockUsersKey: @[],
        WCAtlasMessageBlockKeywordsKey: @[],
        WCAtlasMessageBlockRulesKey: @{},
        WCAtlasMessageBlockProfileSwitchEnabledKey: @YES,
        WCAtlasSendConfirmationProfileSwitchEnabledKey: @YES,
        WCAtlasMessageRepeatMenuEnabledKey: @NO,
        WCAtlasLongPressMenuEnabledKey: @NO,
        WCAtlasLongPressMenuHiddenTitlesKey: @[],
        WCAtlasLongPressMenuPreferredOrderKey: @[],
        WCAtlasLongPressMenuTitleMapKey: @{},
        WCAtlasLongPressMenuManualTitlesKey: @[],
        WCAtlasGroupMemberReminderEnabledKey: @NO,
        WCAtlasRedEnvelopeDetailEnabledKey: @NO,
        WCAtlasRedEnvelopeDetailCenterKey: @NO,
        WCAtlasRedEnvelopeDetailFontSizeKey: @14.0,
        WCAtlasCallConfirmEnabledKey: @NO,
        WCAtlasAutoSpeakerphoneEnabledKey: @NO,
        WCAtlasCallRecordingEnabledKey: @NO,
        WCAtlasCallVoiceDisguiseEnabledKey: @NO,
        WCAtlasCallVoiceModeKey: @0,
        WCAtlasCallRealtimeVoiceEffectEnabledKey: @NO,
        WCAtlasCallRealtimeVoiceEffectPresetKey: @1,
        WCAtlasQRCodeCameraSourceEnabledKey: @NO,
        WCAtlasAutoOriginalImageEnabledKey: @NO,
        WCAtlasAutoCombineSendEnabledKey: @NO,
        WCAtlasNotificationDirectChatEnabledKey: @NO,
        WCAtlasWalletBalanceEnabledKey: @NO,
        WCAtlasWalletBalanceFenKey: @0,
        WCAtlasContactsCountEnabledKey: @NO,
        WCAtlasContactsCountKey: @0,
        WCAtlasStepModeKey: @(WCAtlasStepModeDailyFixed),
        WCAtlasStepRandomMinimumKey: @5000,
        WCAtlasStepRandomMaximumKey: @10000,
        WCAtlasStepGradualEnabledKey: @NO,
        WCAtlasStepDailyTargetKey: @0,
        WCAtlasMeMenuKnownTitlesKey: @[],
        WCAtlasMeMenuHiddenTitlesKey: @[],
        WCAtlasAutoVoiceTranscriptionEnabledKey: @NO,
        WCAtlasVoiceForwardEnabledKey: @NO,
        WCAtlasAutoVoiceTranscriptionIgnoreGroupKey: @NO,
        WCAtlasAutoVoiceTranscriptionIgnorePrivateKey: @NO,
        WCAtlasAutoVoiceTranscriptionIgnoreSelfKey: @YES,
        WCAtlasMultiSelectLimitEnabledKey: @NO,
        WCAtlasShowRawContactIDEnabledKey: @NO,
        WCAtlasHomeSwipeActionsEnabledKey: @NO,
        WCAtlasHideScreenshotForwardKey: @NO,
        WCAtlasInputSwipeActionsEnabledKey: @NO,
        WCAtlasQuickReplyEnabledKey: @NO,
        WCAtlasQuickReplyInstantSendEnabledKey: @NO,
        WCAtlasChatTTSEnabledKey: @NO,
        WCAtlasChatTTSTriggerEnabledKey: @NO,
        WCAtlasChatTTSTriggerPrefixKey: @"转语音",
        WCAtlasSendConfirmationEnabledKey: @NO,
        WCAtlasSendConfirmationUsersKey: @{},
        WCAtlasSendConfirmationPauseSecondsKey: @60,
        WCAtlasMomentsLikeHapticEnabledKey: @NO,
        WCAtlasMomentsLikeHapticIntensityKey: @0.65,
        WCAtlasMomentsQuickPermissionsKey: @NO,
        WCAtlasMomentsPreciseTimeKey: @NO,
        WCAtlasMomentsPreciseTimeFormatKey: WCAtlasMomentsPreciseTimeDefaultFormat,
        WCAtlasBackgroundKeepAliveEnabledKey: @NO,
        WCAtlasMomentsInteractionReminderEnabledKey: @NO,
        WCAtlasMomentsInteractionReminderDetailsEnabledKey: @YES,
        WCAtlasMomentsCommentAntiDeleteEnabledKey: @NO,
        WCAtlasMomentsCommentAntiDeleteTextKey: @"←该评论已删除",
        WCAtlasMomentsCommentAntiDeleteFontSizeKey: @12.0,
        WCAtlasMomentsCommentAntiDeleteColorKey: @"#8E8E93FF",
        WCAtlasMomentsReminderEnabledKey: @NO,
        WCAtlasMomentsReminderUsersKey: @[],
        WCAtlasMomentsReminderIntervalKey: @60,
        WCAtlasMomentsReminderForwardEnabledKey: @NO,
        WCAtlasMomentsReminderForwardTargetKey: @0,
        WCAtlasMomentsReminderForwardImagesKey: @NO,
        WCAtlasMomentsReminderForwardVideosKey: @NO,
        WCAtlasPageScaleEnabledKey: @NO,
        WCAtlasPageScaleGlobalPercentKey: @100.0,
        WCAtlasSettingsPageScalePercentKey: @100.0,
        WCAtlasMultiSelectExportEnabledKey: @NO,
        WCAtlasMultiSelectExportTextKey: @YES,
        WCAtlasMultiSelectSaveImagesKey: @YES,
        WCAtlasMultiSelectShareCardKey: @YES,
        WCAtlasLoggingEnabledKey: @YES,
        WCAtlasPluginManagerEnabledKey: @NO,
        WCAtlasChatInputRoundingEnabledKey: @NO,
        WCAtlasChatInputInnerRoundingKey: @YES,
        WCAtlasChatInputOuterRoundingKey: @YES,
        WCAtlasChatInputInnerRadiusKey: @18.0,
        WCAtlasChatInputOuterRadiusKey: @22.0,
        WCAtlasHideChatMuteIconKey: @NO,
        WCAtlasScrollHighRefreshRateEnabledKey: @NO,
        WCAtlasGlobalAvatarRoundingEnabledKey: @NO,
        WCAtlasGlobalAvatarCornerPercentKey: @100.0,
        WCAtlasInAppNotificationSymbolKey: @"automatic",
        WCAtlasInAppNotificationHeightKey: @60.0,
        WCAtlasInAppNotificationBlurIntensityKey: @0.85,
        WCAtlasExpandedCategoriesKey: @[@"messages"],
        WCAtlasCollapsedFeaturesKey: @[],
    }];
    if (![defaults boolForKey:WCAtlasChatGlassPseudoLiquid20MigrationKey]) {
        [defaults setInteger:1 forKey:WCAtlasChatGlassStyleKey];
        [defaults setDouble:20.0 forKey:WCAtlasChatGlassBlurIntensityKey];
        [defaults setBool:YES forKey:WCAtlasChatGlassPseudoLiquid20MigrationKey];
    }
}

static NSArray<WCAtlasSettingSection *> *WCAtlasRootSections(void) {
    return @[
        [WCAtlasSettingSection sectionWithIdentifier:@"master" title:nil
                                             footer:@"关闭后仅保留设置入口，所有增强功能停止生效。"
                                              items:@[WCAtlasItem(@"启用 WCAtlas", @"插件功能总开关", @"power", WCAtlasSettingRowKindSwitch, WCAtlasEnabledKey, nil, WCAtlasSettingActionNone)]],
        [WCAtlasSettingSection sectionWithIdentifier:@"categories" title:@"功能"
                                             footer:nil items:@[
            WCAtlasItem(@"聊天增强", @"消息、编辑、提醒与导出", @"bubble.left.and.bubble.right", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenMessages),
            WCAtlasItem(@"朋友圈增强", @"提醒、互动、发布和媒体操作", @"photo.on.rectangle.angled", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenMoments),
            WCAtlasItem(@"界面禁用", @"隐藏不需要的界面元素和广告", @"eye.slash", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenInterfaceDisabled),
            WCAtlasItem(@"界面优化", @"头像、胶囊、缩放与输入栏样式", @"paintbrush", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenInterface),
            WCAtlasItem(@"常用增强", @"自动化、扫码、资料和本地显示", @"bolt", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenEnhancements),
            WCAtlasItem(@"插件设置", @"通知样式、日志、配置与插件入口", @"gearshape.2", WCAtlasSettingRowKindDetail, nil, nil, WCAtlasSettingActionOpenPlugin),
        ]],
        [WCAtlasSettingSection sectionWithIdentifier:@"about" title:@"关于"
                                             footer:[NSString stringWithFormat:@"WCAtlas · %@", WCAtlasDisplayVersion]
                                              items:@[
            WCAtlasItem(@"官方 Telegram 群", @"加入公告、反馈与交流频道", @"paperplane.fill", WCAtlasSettingRowKindDetail, nil, @"打开", WCAtlasSettingActionOfficialTelegram),
            WCAtlasItem(@"版本介绍", @"WCAtlas 首个正式版本", @"shippingbox", WCAtlasSettingRowKindDetail, nil, WCAtlasDisplayVersion, WCAtlasSettingActionReleaseNotes),
        ]],
    ];
}

static NSArray<WCAtlasSettingSection *> *WCAtlasMessageSections(NSUserDefaults *defaults, NSSet<NSString *> *collapsed) {
    NSMutableArray *protection = [NSMutableArray array];
    NSInteger promptStyleValue = [defaults integerForKey:WCAtlasAntiRevokePromptStyleKey];
    NSString *promptStyle = promptStyleValue == 1 ? @"气泡旁" : @"消息下方";
    NSTimeInterval filter = [defaults doubleForKey:WCAtlasAntiRevokeTimeFilterKey];
    NSString *filterValue = @"不限制";
    if (filter >= 86400) filterValue = @"24 小时"; else if (filter >= 3600) filterValue = @"1 小时";
    else if (filter >= 1800) filterValue = @"30 分钟"; else if (filter >= 300) filterValue = @"5 分钟"; else if (filter >= 60) filterValue = @"1 分钟";
    NSMutableArray *revokeChildren = [NSMutableArray arrayWithObjects:
        WCAtlasItem(@"防撤回提示方案", @"选择提示显示在消息下方或气泡旁", @"text.bubble", WCAtlasSettingRowKindDetail, nil, WCAtlasCurrentSelection(promptStyle), WCAtlasSettingActionRevokePromptStyle),
        promptStyleValue == 1
            ? WCAtlasItem(@"提示外观预览", @"调整文字、颜色和 X / Y 位置", @"cursorarrow.motionlines", WCAtlasSettingRowKindDetail, nil, @"编辑", WCAtlasSettingActionRevokeAppearance)
            : WCAtlasItem(@"本地提示模板", @"编辑完整提示内容；浅色和深色颜色分别设置", @"text.quote", WCAtlasSettingRowKindDetail, nil, @"编辑", WCAtlasSettingActionRevokeLocalTemplate),
        nil];
    if (promptStyleValue == 1) {
        NSString *light = [defaults stringForKey:WCAtlasAntiRevokeSideLightTextColorKey] ?: @"#8E8E93FF";
        NSString *dark = [defaults stringForKey:WCAtlasAntiRevokeSideDarkTextColorKey] ?: @"#98989DFF";
        [revokeChildren addObject:WCAtlasItem(@"浅色模式提示颜色", @"气泡旁提示在浅色模式下使用", @"sun.max",
                                              WCAtlasSettingRowKindDetail, WCAtlasAntiRevokeSideLightTextColorKey,
                                              light.uppercaseString, WCAtlasSettingActionMessageTimeColor)];
        [revokeChildren addObject:WCAtlasItem(@"深色模式提示颜色", @"气泡旁提示在深色模式下使用", @"moon",
                                              WCAtlasSettingRowKindDetail, WCAtlasAntiRevokeSideDarkTextColorKey,
                                              dark.uppercaseString, WCAtlasSettingActionMessageTimeColor)];
    } else {
        NSString *light = [defaults stringForKey:WCAtlasAntiRevokeLocalLightTextColorKey] ?: @"#8E8E93FF";
        NSString *dark = [defaults stringForKey:WCAtlasAntiRevokeLocalDarkTextColorKey] ?: @"#98989DFF";
        [revokeChildren addObject:WCAtlasItem(@"浅色模式提示颜色", @"消息下方提示在浅色模式下使用", @"sun.max",
                                              WCAtlasSettingRowKindDetail, WCAtlasAntiRevokeLocalLightTextColorKey,
                                              light.uppercaseString, WCAtlasSettingActionMessageTimeColor)];
        [revokeChildren addObject:WCAtlasItem(@"深色模式提示颜色", @"消息下方提示在深色模式下使用", @"moon",
                                              WCAtlasSettingRowKindDetail, WCAtlasAntiRevokeLocalDarkTextColorKey,
                                              dark.uppercaseString, WCAtlasSettingActionMessageTimeColor)];
    }
    WCAtlasSettingItem *notify = WCAtlasItem(@"回复撤回者", @"自动发送提示，默认关闭", @"paperplane", WCAtlasSettingRowKindSwitch, WCAtlasAntiRevokeNotifySenderKey, nil, WCAtlasSettingActionNone);
    NSArray *notifyChildren = @[
        WCAtlasItem(@"回复时间限制", @"避免响应很久以前的撤回事件", @"timer", WCAtlasSettingRowKindDetail, nil, WCAtlasCurrentSelection(filterValue), WCAtlasSettingActionRevokeFilter),
        WCAtlasItem(@"回复消息模板", @"设置发送给撤回者的提示", @"text.quote", WCAtlasSettingRowKindDetail, nil, @"编辑", WCAtlasSettingActionRevokeReplyTemplate),
    ];
    notify.hasChildren = YES;
    [revokeChildren addObject:notify];
    if ([defaults boolForKey:WCAtlasAntiRevokeNotifySenderKey] && ![collapsed containsObject:WCAtlasAntiRevokeNotifySenderKey]) [revokeChildren addObjectsFromArray:notifyChildren];
    [revokeChildren addObjectsFromArray:@[
        WCAtlasItem(@"防撤回记录中心", @"搜索本次运行期间拦截的撤回消息", @"tray.full", WCAtlasSettingRowKindDetail, nil, @"查看", WCAtlasSettingActionRevokeRecords),
        WCAtlasItem(@"本地保存撤回记录", @"仅保存摘要和分类", @"internaldrive", WCAtlasSettingRowKindSwitch, WCAtlasAntiRevokePersistRecordsKey, nil, WCAtlasSettingActionNone),
    ]];
    WCAtlasAddFeature(protection, WCAtlasItem(@"防撤回", @"保留好友撤回的消息并显示提示", @"arrow.uturn.backward.circle", WCAtlasSettingRowKindSwitch, WCAtlasAntiRevokeKey, nil, WCAtlasSettingActionNone), revokeChildren, defaults, collapsed);

    NSArray *blockChildren = @[
        WCAtlasItem(@"管理屏蔽会话", @"按好友或群聊选择需要屏蔽的消息类型", @"person.crop.circle.badge.xmark", WCAtlasSettingRowKindDetail, nil, WCAtlasCountText(WCAtlasMessageBlockedConversations().count), WCAtlasSettingActionBlockUsers),
        WCAtlasItem(@"屏蔽关键词", @"命中后不加入本地聊天记录", @"text.badge.xmark", WCAtlasSettingRowKindDetail, nil, WCAtlasCountText([defaults arrayForKey:WCAtlasMessageBlockKeywordsKey].count), WCAtlasSettingActionBlockKeywords),
        WCAtlasItem(@"资料页显示屏蔽开关", @"好友、非好友和群聊资料页均可快速设置", @"person.text.rectangle", WCAtlasSettingRowKindSwitch, WCAtlasMessageBlockProfileSwitchEnabledKey, nil, WCAtlasSettingActionNone),
    ];
    WCAtlasAddFeature(protection, WCAtlasItem(@"消息屏蔽", @"账号屏蔽全部收到的消息，关键词只匹配文字", @"eye.slash", WCAtlasSettingRowKindSwitch, WCAtlasMessageBlockEnabledKey, nil, WCAtlasSettingActionNone), blockChildren, defaults, collapsed);
    WCAtlasAddFeature(protection,
                    WCAtlasItem(@"发送前确认", @"仅保护指定会话，默认关闭", @"checkmark.shield", WCAtlasSettingRowKindSwitch, WCAtlasSendConfirmationEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
                        WCAtlasItem(@"临时暂停时长", @"确认后可暂时放行当前会话", @"timer", WCAtlasSettingRowKindDetail, nil,
                                  WCAtlasSendConfirmationPauseDurationText([defaults integerForKey:WCAtlasSendConfirmationPauseSecondsKey]),
                                  WCAtlasSettingActionSendConfirmationPauseDuration),
                        WCAtlasItem(@"资料页显示确认开关", @"好友、非好友和群聊资料页均可快速设置", @"person.text.rectangle",
                                  WCAtlasSettingRowKindSwitch, WCAtlasSendConfirmationProfileSwitchEnabledKey, nil,
                                  WCAtlasSettingActionNone),
                        WCAtlasItem(@"管理受保护会话", @"只保存 username，名称运行时读取", @"person.crop.circle.badge.checkmark", WCAtlasSettingRowKindDetail, nil,
                                  WCAtlasCountText(WCAtlasSendConfirmationProtectedConversations().count), WCAtlasSettingActionSendConfirmationConversations),
                    ],
                    defaults,
                    collapsed);
    NSMutableSet *menuTitles = [NSMutableSet setWithArray:[defaults arrayForKey:WCAtlasLongPressMenuKnownTitlesKey] ?: @[]];
    [menuTitles addObjectsFromArray:[defaults arrayForKey:WCAtlasLongPressMenuManualTitlesKey] ?: @[]];
    WCAtlasAddFeature(protection, WCAtlasItem(@"长按菜单管理", @"管理聊天消息的长按菜单", @"list.bullet.rectangle", WCAtlasSettingRowKindSwitch, WCAtlasLongPressMenuEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"管理已发现菜单", @"隐藏、排序和重命名已发现菜单", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil, WCAtlasCountText(menuTitles.count), WCAtlasSettingActionLongPressMenus)
    ], defaults, collapsed);

    NSMutableArray *interaction = [NSMutableArray arrayWithArray:@[
        WCAtlasItem(@"聊天记录搜索", @"在聊天顶栏打开微信原生聊天记录搜索", @"magnifyingglass", WCAtlasSettingRowKindSwitch, WCAtlasChatSearchButtonEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"小游戏结果选择", @"支持骰子与猜拳跨类型彩蛋", @"die.face.5", WCAtlasSettingRowKindSwitch, WCAtlasGameSelectorKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"聊天记录小丑", @"长按消息，仅修改当前页面本机显示", @"square.and.pencil", WCAtlasSettingRowKindSwitch, WCAtlasChatJokerEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"消息 +1", @"在可复读消息的长按菜单中加入 +1", @"plus.message", WCAtlasSettingRowKindSwitch, WCAtlasMessageRepeatMenuEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"表情存入自拍", @"在表情菜单中存入自拍表情", @"camera", WCAtlasSettingRowKindSwitch, WCAtlasEmoticonToSelfieEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"语音转发", @"在语音长按菜单中显示转发", @"waveform.badge.plus", WCAtlasSettingRowKindSwitch, WCAtlasVoiceForwardEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"群聊 @ 高亮", @"高亮消息中的 @ 对象，点击打开联系人资料", @"at", WCAtlasSettingRowKindSwitch, WCAtlasMentionHighlightEnabledKey, nil, WCAtlasSettingActionNone),
    ]];
    WCAtlasAddFeature(interaction,
                    WCAtlasItem(@"媒体转语音", @"把音频文件、聊天视频和音乐卡片转成真正的微信语音", @"waveform", WCAtlasSettingRowKindSwitch, WCAtlasMediaToVoiceEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
                        WCAtlasItem(@"音频文件转语音", @"音频文件下载完成后，长按转为语音发送", @"doc", WCAtlasSettingRowKindSwitch, WCAtlasAudioFileToVoiceEnabledKey, nil, WCAtlasSettingActionNone),
                        WCAtlasItem(@"视频转语音", @"视频下载完成后，长按提取音轨并发送", @"video", WCAtlasSettingRowKindSwitch, WCAtlasVideoToVoiceEnabledKey, nil, WCAtlasSettingActionNone),
                        WCAtlasItem(@"音乐转语音", @"长按音乐卡片，下载播放音频后转为语音发送", @"music.note", WCAtlasSettingRowKindSwitch, WCAtlasMusicToVoiceEnabledKey, nil, WCAtlasSettingActionNone),
                    ],
                    defaults,
                    collapsed);
    WCAtlasAddFeature(interaction,
                    WCAtlasItem(@"快捷回复", @"长按聊天“+”使用文字、图片、视频和语音消息", @"tray.full", WCAtlasSettingRowKindSwitch, WCAtlasQuickReplyEnabledKey, nil, WCAtlasSettingActionNone),
                    @[WCAtlasItem(@"点击秒发送", @"开启后点击直接发送，长按进入编辑或预览", @"bolt.fill", WCAtlasSettingRowKindSwitch, WCAtlasQuickReplyInstantSendEnabledKey, nil, WCAtlasSettingActionNone),
                      WCAtlasItem(@"管理消息库", @"全账号共享，支持文件夹、搜索、编辑、置顶和清理", @"square.grid.2x2", WCAtlasSettingRowKindDetail, nil,
                                WCAtlasCountText(WCAtlasQuickReplyStore.sharedStore.items.count), WCAtlasSettingActionQuickReplyLibrary)],
                    defaults,
                    collapsed);
    [interaction addObject:WCAtlasItem(@"聊天 TTS", @"长按输入栏麦克风按钮；支持音色选择和文字前缀触发", @"waveform.and.mic", WCAtlasSettingRowKindSwitch, WCAtlasChatTTSEnabledKey, nil, WCAtlasSettingActionNone)];
    WCAtlasAddFeature(interaction, WCAtlasItem(@"语音自动转文字", @"收到语音后自动转成文字", @"waveform.and.mic", WCAtlasSettingRowKindSwitch, WCAtlasAutoVoiceTranscriptionEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"忽略群聊语音", @"群聊中的语音保持原样", @"person.3", WCAtlasSettingRowKindSwitch, WCAtlasAutoVoiceTranscriptionIgnoreGroupKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"忽略私聊语音", @"私聊中的语音保持原样", @"person", WCAtlasSettingRowKindSwitch, WCAtlasAutoVoiceTranscriptionIgnorePrivateKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"忽略自己发送", @"不转换自己发出的语音", @"person.crop.circle", WCAtlasSettingRowKindSwitch, WCAtlasAutoVoiceTranscriptionIgnoreSelfKey, nil, WCAtlasSettingActionNone),
    ], defaults, collapsed);
    NSInteger avatarGesture = [defaults integerForKey:WCAtlasAvatarQuickMenuGestureKey];
    NSString *avatarGestureName = avatarGesture == WCAtlasAvatarQuickMenuGestureDoubleTap
        ? @"双击头像"
        : (avatarGesture == WCAtlasAvatarQuickMenuGestureLongPress ? @"长按头像" : @"关闭");
    [interaction addObject:WCAtlasItem(@"头像快捷面板",
                                     [NSString stringWithFormat:@"呼出方式：%@", avatarGestureName],
                                     @"person.crop.circle.badge.ellipsis",
                                     WCAtlasSettingRowKindDetail,
                                     WCAtlasAvatarQuickMenuGestureKey,
                                     avatarGestureName,
                                     WCAtlasSettingActionAvatarQuickMenuGesture)];
    NSString *messageTimeFormat = [defaults stringForKey:WCAtlasChatMessageTimeFormatKey];
    if (messageTimeFormat.length == 0) messageTimeFormat = @"MM-dd HH:mm:ss";
    BOOL messageTimeBubbleMode = [defaults boolForKey:WCAtlasChatMessageTimeBubbleSideKey];
    NSInteger messageTimePosition = MIN(2, MAX(0, [defaults integerForKey:WCAtlasChatMessageTimeBubbleVerticalPositionKey]));
    NSArray<NSString *> *messageTimePositionNames = @[@"顶部", @"中间", @"底部"];
    NSString *messageTimeLightColor = [defaults stringForKey:WCAtlasChatMessageTimeLightColorKey] ?: @"#8E8E93FF";
    NSString *messageTimeDarkColor = [defaults stringForKey:WCAtlasChatMessageTimeDarkColorKey] ?: @"#98989DFF";
    NSString *messageTimeModeName = messageTimeBubbleMode ? @"消息右侧" : @"头像下方";
    NSMutableArray<WCAtlasSettingItem *> *messageTimeChildren = [NSMutableArray arrayWithObject:
        WCAtlasItem(@"时间显示位置", @"头像下方与消息右侧严格二选一", @"rectangle.2.swap", WCAtlasSettingRowKindDetail, nil, messageTimeModeName, WCAtlasSettingActionMessageTimeMode)];
    if (messageTimeBubbleMode) {
        [messageTimeChildren addObject:WCAtlasItem(@"消息旁垂直位置", @"调整时间位于消息顶部、中间或底部", @"arrow.up.and.down.text.horizontal", WCAtlasSettingRowKindDetail, nil, messageTimePositionNames[messageTimePosition], WCAtlasSettingActionMessageTimePosition)];
    } else {
        [messageTimeChildren addObject:WCAtlasItem(@"头像时间间距", @"负值向上、正值向下，范围 -6 到 8", @"arrow.up.and.down", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatMessageTimeAvatarSpacingKey]], WCAtlasSettingActionMessageTimeAvatarSpacing)];
    }
    [messageTimeChildren addObjectsFromArray:@[
        WCAtlasItem(@"时间格式", @"支持 yyyy、MM、dd、E、HH、mm、ss", @"textformat", WCAtlasSettingRowKindDetail, nil, messageTimeFormat, WCAtlasSettingActionMessageTimeFormat),
        WCAtlasItem(@"时间字号", @"限制在 8 到 18 点", @"textformat.size", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatMessageTimeFontSizeKey]], WCAtlasSettingActionMessageTimeFontSize),
        WCAtlasItem(@"时间文字加粗", @"头像下方与消息右侧共同生效", @"bold", WCAtlasSettingRowKindSwitch, WCAtlasChatMessageTimeBoldKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"浅色模式时间颜色", @"仅在浅色模式下使用", @"sun.max", WCAtlasSettingRowKindDetail, WCAtlasChatMessageTimeLightColorKey, messageTimeLightColor.uppercaseString, WCAtlasSettingActionMessageTimeColor),
        WCAtlasItem(@"深色模式时间颜色", @"仅在深色模式下使用", @"moon", WCAtlasSettingRowKindDetail, WCAtlasChatMessageTimeDarkColorKey, messageTimeDarkColor.uppercaseString, WCAtlasSettingActionMessageTimeColor),
    ]];
    WCAtlasAddFeature(interaction, WCAtlasItem(@"消息时间显示", [NSString stringWithFormat:@"当前：%@", messageTimeModeName], @"clock", WCAtlasSettingRowKindSwitch, WCAtlasChatMessageTimeEnabledKey, nil, WCAtlasSettingActionNone), messageTimeChildren, defaults, collapsed);
    NSInteger selfSwipeAction = [defaults integerForKey:WCAtlasReplySwipeSelfActionKey];
    NSInteger otherSwipeAction = [defaults integerForKey:WCAtlasReplySwipeOtherActionKey];
    NSInteger selfRightSwipeAction = [defaults integerForKey:WCAtlasReplySwipeRightSelfActionKey];
    NSInteger otherRightSwipeAction = [defaults integerForKey:WCAtlasReplySwipeRightOtherActionKey];
    NSArray<NSString *> *swipeActionNames = @[@"不设置", @"引用", @"撤回", @"复制", @"删除", @"复读"];
    NSString *(^gestureActionName)(NSInteger, BOOL) = ^NSString *(NSInteger action, BOOL selfMessage) {
        if (action < 0 || action >= (NSInteger)swipeActionNames.count || (!selfMessage && action == WCAtlasReplySwipeActionRevoke)) return @"不设置";
        return swipeActionNames[action];
    };
    NSString *selfSwipeName = gestureActionName(selfSwipeAction, YES);
    NSString *otherSwipeName = gestureActionName(otherSwipeAction, NO);
    NSString *selfRightSwipeName = gestureActionName(selfRightSwipeAction, YES);
    NSString *otherRightSwipeName = gestureActionName(otherRightSwipeAction, NO);
    NSInteger selfDoubleAction = [defaults integerForKey:WCAtlasMessageDoubleTapSelfActionKey];
    NSInteger otherDoubleAction = [defaults integerForKey:WCAtlasMessageDoubleTapOtherActionKey];
    NSInteger selfTripleAction = [defaults integerForKey:WCAtlasMessageTripleTapSelfActionKey];
    NSInteger otherTripleAction = [defaults integerForKey:WCAtlasMessageTripleTapOtherActionKey];
    WCAtlasAddFeature(interaction,
                    WCAtlasItem(@"消息手势", [NSString stringWithFormat:@"左滑 %@/%@ · 右滑 %@/%@", selfSwipeName, otherSwipeName, selfRightSwipeName, otherRightSwipeName], @"hand.draw", WCAtlasSettingRowKindSwitch, WCAtlasReplySwipeEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
        WCAtlasItem(@"左滑 · 自己", [NSString stringWithFormat:@"当前状态：%@", selfSwipeName], @"arrow.left", WCAtlasSettingRowKindDetail, WCAtlasReplySwipeSelfActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"左滑 · 对方", [NSString stringWithFormat:@"当前状态：%@", otherSwipeName], @"arrow.left", WCAtlasSettingRowKindDetail, WCAtlasReplySwipeOtherActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"右滑 · 自己", [NSString stringWithFormat:@"当前状态：%@", selfRightSwipeName], @"arrow.right", WCAtlasSettingRowKindDetail, WCAtlasReplySwipeRightSelfActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"右滑 · 对方", [NSString stringWithFormat:@"当前状态：%@", otherRightSwipeName], @"arrow.right", WCAtlasSettingRowKindDetail, WCAtlasReplySwipeRightOtherActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"触发距离", @"限制在 36 到 100 点，越小越灵敏", @"arrow.left.and.right", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasReplySwipeTriggerDistanceKey]], WCAtlasSettingActionReplySwipeTriggerDistance),
        WCAtlasItem(@"双击 · 自己", [NSString stringWithFormat:@"当前状态：%@", gestureActionName(selfDoubleAction, YES)], @"hand.tap", WCAtlasSettingRowKindDetail, WCAtlasMessageDoubleTapSelfActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"双击 · 对方", [NSString stringWithFormat:@"当前状态：%@", gestureActionName(otherDoubleAction, NO)], @"hand.tap", WCAtlasSettingRowKindDetail, WCAtlasMessageDoubleTapOtherActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"三击 · 自己", [NSString stringWithFormat:@"当前状态：%@", gestureActionName(selfTripleAction, YES)], @"hand.tap", WCAtlasSettingRowKindDetail, WCAtlasMessageTripleTapSelfActionKey, nil, WCAtlasSettingActionMessageGestureAction),
        WCAtlasItem(@"三击 · 对方", [NSString stringWithFormat:@"当前状态：%@", gestureActionName(otherTripleAction, NO)], @"hand.tap", WCAtlasSettingRowKindDetail, WCAtlasMessageTripleTapOtherActionKey, nil, WCAtlasSettingActionMessageGestureAction),
    ], defaults, collapsed);
    WCAtlasAddFeature(interaction, WCAtlasItem(@"引用消息定位", @"点击引用定位原消息", @"arrow.up.and.down.text.horizontal", WCAtlasSettingRowKindSwitch, WCAtlasQuoteJumpEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"定位图片引用", @"允许点击图片引用定位", @"photo", WCAtlasSettingRowKindSwitch, WCAtlasQuoteJumpImageEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"定位视频引用", @"允许点击视频引用定位", @"video", WCAtlasSettingRowKindSwitch, WCAtlasQuoteJumpVideoEnabledKey, nil, WCAtlasSettingActionNone),
    ], defaults, collapsed);
    [interaction addObject:WCAtlasItem(@"输入框滑动操作", @"左滑清空，右滑粘贴", @"hand.draw", WCAtlasSettingRowKindSwitch, WCAtlasInputSwipeActionsEnabledKey, nil, WCAtlasSettingActionNone)];

    NSMutableArray *reminders = [NSMutableArray arrayWithArray:@[
        WCAtlasItem(@"群成员进退群提醒", @"根据群成员列表变化显示本地提醒", @"person.2.badge.gearshape", WCAtlasSettingRowKindSwitch, WCAtlasGroupMemberReminderEnabledKey, nil, WCAtlasSettingActionNone)
    ]];
    WCAtlasAddFeature(reminders, WCAtlasItem(@"红包详情显示", @"显示总额、领取和剩余统计", @"envelope.open", WCAtlasSettingRowKindSwitch, WCAtlasRedEnvelopeDetailEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"红包详情居中", @"将补充统计信息居中显示", @"text.aligncenter", WCAtlasSettingRowKindSwitch, WCAtlasRedEnvelopeDetailCenterKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"红包详情字号", @"输入 10 到 24", @"textformat.size", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasRedEnvelopeDetailFontSizeKey]], WCAtlasSettingActionRedEnvelopeFontSize)
    ], defaults, collapsed);
    [reminders addObjectsFromArray:@[
        WCAtlasItem(@"通话二次确认", @"发起语音或视频通话前确认", @"phone.badge.checkmark", WCAtlasSettingRowKindSwitch, WCAtlasCallConfirmEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"通话自动免提", @"通话音频设备启动成功后自动切换扬声器", @"speaker.wave.2", WCAtlasSettingRowKindSwitch, WCAtlasAutoSpeakerphoneEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"通话录音", @"开启后每次通话自动录制并保存本地、对端和双方混合音轨", @"record.circle", WCAtlasSettingRowKindSwitch, WCAtlasCallRecordingEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"已保存的通话录音", @"查看、试听或删除本地录音文件", @"waveform", WCAtlasSettingRowKindDetail, nil, @"查看", WCAtlasSettingActionCallRecordings),
        WCAtlasItem(@"通话语音伪装", @"在通话页面从消息库选择语音素材，替换上行麦克风输入", @"waveform.badge.mic", WCAtlasSettingRowKindSwitch, WCAtlasCallVoiceDisguiseEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"语音包混合麦克风", @"开启后保留部分现场麦克风声音；关闭时完全替换", @"slider.horizontal.3", WCAtlasSettingRowKindSwitch, WCAtlasCallVoiceModeKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"实时通话变声", @"在麦克风上行 PCM 中低延迟处理，不影响对端下行声音", @"waveform.badge.mic", WCAtlasSettingRowKindSwitch, WCAtlasCallRealtimeVoiceEffectEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"实时变声效果", @"选择原声、明亮女声、低沉男声、机器人或电音", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil,
                  WCAtlasCurrentSelection(@[@"原声", @"明亮女声", @"低沉男声", @"机器人", @"电音"][MIN(4, MAX(0, [defaults integerForKey:WCAtlasCallRealtimeVoiceEffectPresetKey]))]),
                  WCAtlasSettingActionCallVoiceEffect),
        WCAtlasItem(@"通知直达聊天", @"点击通知后进入对应会话", @"bubble.left.and.arrow.forward", WCAtlasSettingRowKindSwitch, WCAtlasNotificationDirectChatEnabledKey, nil, WCAtlasSettingActionNone),
    ]];

    NSMutableArray *media = [NSMutableArray arrayWithArray:@[
        WCAtlasItem(@"图片编辑快捷发送", @"编辑图片后可发送到当前聊天", @"photo.badge.arrow.down", WCAtlasSettingRowKindSwitch, WCAtlasImageEditQuickSendEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"自动选择原图", @"选择和预览照片、视频时自动勾选原图", @"photo.badge.checkmark", WCAtlasSettingRowKindSwitch, WCAtlasAutoOriginalImageEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"自动勾选合并发送", @"开启自动选择原图后，多选达到要求时自动勾选", @"rectangle.3.group", WCAtlasSettingRowKindSwitch, WCAtlasAutoCombineSendEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"突破多选限制", @"放宽消息、转发目标与拍摄视频限制", @"checklist.unchecked", WCAtlasSettingRowKindSwitch, WCAtlasMultiSelectLimitEnabledKey, nil, WCAtlasSettingActionNone),
    ]];
    WCAtlasAddFeature(media, WCAtlasItem(@"多选消息导出", @"控制复制、保存和分享功能", @"square.and.arrow.up.on.square", WCAtlasSettingRowKindSwitch, WCAtlasMultiSelectExportEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"复制纯文本", @"只复制消息正文", @"doc.on.clipboard", WCAtlasSettingRowKindSwitch, WCAtlasMultiSelectExportTextKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"批量保存图片", @"保存已下载到本机的图片", @"photo.on.rectangle.angled", WCAtlasSettingRowKindSwitch, WCAtlasMultiSelectSaveImagesKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"生成分享卡片", @"极简、对话或深色样式", @"rectangle.on.rectangle", WCAtlasSettingRowKindSwitch, WCAtlasMultiSelectShareCardKey, nil, WCAtlasSettingActionNone),
    ], defaults, collapsed);

    return @[
        [WCAtlasSettingSection sectionWithIdentifier:@"message-protection" title:@"消息保护" footer:nil items:protection],
        [WCAtlasSettingSection sectionWithIdentifier:@"chat-interaction" title:@"聊天操作" footer:nil items:interaction],
        [WCAtlasSettingSection sectionWithIdentifier:@"message-reminders" title:@"提醒与详情" footer:nil items:reminders],
        [WCAtlasSettingSection sectionWithIdentifier:@"media-export" title:@"图片与导出" footer:@"快捷发送会先显示微信确认页，不影响普通转发。" items:media],
    ];
}

static NSArray<WCAtlasSettingSection *> *WCAtlasEnhancementSections(NSUserDefaults *defaults,
                                                                 NSSet<NSString *> *collapsed,
                                                                 BOOL momentsOnly) {
    NSMutableArray *automation = [NSMutableArray arrayWithArray:@[
        WCAtlasItem(@"定时消息", @"按指定时间发送文字、消息库素材或 HTTP/JS 处理结果", @"clock.badge.checkmark", WCAtlasSettingRowKindDetail, nil, @"管理", WCAtlasSettingActionAutomations),
        WCAtlasItem(@"关键词回复", @"按关键词自动回复，支持好友和群聊黑白名单", @"text.bubble", WCAtlasSettingRowKindDetail, nil, @"管理", WCAtlasSettingActionKeywordReplies),
        WCAtlasItem(@"保持后台运行", @"尽量维持微信后台活跃，供朋友圈提醒等周期功能使用", @"moon.zzz", WCAtlasSettingRowKindSwitch, WCAtlasBackgroundKeepAliveEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"设备扫码自动登录", @"自动确认电脑、平板等设备登录", @"desktopcomputer", WCAtlasSettingRowKindSwitch, WCAtlasAutoDeviceLoginKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"游戏授权自动允许", @"自动确认游戏扫码授权", @"gamecontroller", WCAtlasSettingRowKindSwitch, WCAtlasAutoGameAuthorizeKey, nil, WCAtlasSettingActionNone),
    ]];
    NSArray<WCAtlasSettingItem *> *scan = @[
        WCAtlasItem(@"伪装扫码来源", @"将相册识别结果按相机扫码处理", @"qrcode.viewfinder", WCAtlasSettingRowKindSwitch, WCAtlasQRCodeCameraSourceEnabledKey, nil, WCAtlasSettingActionNone),
    ];
    NSMutableArray *moments = [NSMutableArray array];
    NSUInteger reminderUserCount = [[defaults arrayForKey:WCAtlasMomentsReminderUsersKey] count];
    NSInteger reminderInterval = MAX(30, MIN(3600, [defaults integerForKey:WCAtlasMomentsReminderIntervalKey]));
    BOOL backgroundEnabled = [defaults boolForKey:WCAtlasBackgroundKeepAliveEnabledKey];
    NSString *forwardTarget = [defaults integerForKey:WCAtlasMomentsReminderForwardTargetKey] == 1
        ? @"文件传输助手" : @"自己的聊天框";
    NSString *reminderSubtitle = backgroundEnabled
        ? @"周期检测特别关注好友的新朋友圈"
        : @"建议开启“保持后台运行”，否则可能只在前台检测";
    NSString *interactionSubtitle = backgroundEnabled
        ? @"检测新的朋友圈点赞或评论并发送提醒"
        : @"建议开启“保持后台运行”，否则可能只在前台检测";
    WCAtlasSettingItem *forwardToChat = WCAtlasItem(@"转发到聊天", @"开启后默认只转发文字", @"paperplane",
                                                WCAtlasSettingRowKindSwitch, WCAtlasMomentsReminderForwardEnabledKey,
                                                nil, WCAtlasSettingActionNone);
    forwardToChat.hasChildren = YES;
    NSMutableArray<WCAtlasSettingItem *> *reminderChildren = [NSMutableArray arrayWithArray:@[
        WCAtlasItem(@"特别关注好友", @"选择需要检测朋友圈更新的好友", @"person.crop.circle.badge.checkmark", WCAtlasSettingRowKindDetail, nil,
                  reminderUserCount > 0 ? [NSString stringWithFormat:@"%lu 位", (unsigned long)reminderUserCount] : @"未选择",
                  WCAtlasSettingActionMomentsReminderUsers),
        WCAtlasItem(@"检测间隔", @"支持 30–3600 秒；间隔越短耗电越高", @"timer", WCAtlasSettingRowKindDetail, nil,
                  [NSString stringWithFormat:@"%ld 秒", (long)reminderInterval], WCAtlasSettingActionMomentsReminderInterval),
        forwardToChat,
    ]];
    if ([defaults boolForKey:WCAtlasMomentsReminderForwardEnabledKey] &&
        ![collapsed containsObject:WCAtlasMomentsReminderForwardEnabledKey]) {
        [reminderChildren addObjectsFromArray:@[
            WCAtlasItem(@"转发目标", @"选择接收朋友圈内容的会话", @"person.crop.circle.badge.arrow.forward", WCAtlasSettingRowKindDetail, nil,
                      forwardTarget, WCAtlasSettingActionMomentsReminderForwardTarget),
            WCAtlasItem(@"同时转发图片", @"默认关闭，开启后下载并发送朋友圈图片", @"photo", WCAtlasSettingRowKindSwitch,
                      WCAtlasMomentsReminderForwardImagesKey, nil, WCAtlasSettingActionNone),
            WCAtlasItem(@"同时转发视频", @"默认关闭，开启后下载并发送朋友圈视频", @"video", WCAtlasSettingRowKindSwitch,
                      WCAtlasMomentsReminderForwardVideosKey, nil, WCAtlasSettingActionNone),
        ]];
    }
    WCAtlasAddFeature(moments,
                    WCAtlasItem(@"朋友圈提醒", reminderSubtitle, @"bell.badge", WCAtlasSettingRowKindSwitch, WCAtlasMomentsReminderEnabledKey, nil, WCAtlasSettingActionNone),
                    reminderChildren, defaults, collapsed);
    NSMutableArray<WCAtlasSettingItem *> *interactionRows = [NSMutableArray array];
    WCAtlasAddFeature(interactionRows,
                    WCAtlasItem(@"朋友圈互动提醒", interactionSubtitle, @"bubble.left.and.exclamationmark.bubble.right",
                              WCAtlasSettingRowKindSwitch, WCAtlasMomentsInteractionReminderEnabledKey,
                              nil, WCAtlasSettingActionNone),
                    @[
                        WCAtlasItem(@"显示详细信息", @"关闭后仅提示收到新的评论或点赞", @"text.bubble",
                                  WCAtlasSettingRowKindSwitch, WCAtlasMomentsInteractionReminderDetailsEnabledKey,
                                  nil, WCAtlasSettingActionNone),
                    ], defaults, collapsed);
    [moments insertObjects:interactionRows
                 atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, interactionRows.count)]];
    NSString *antiDeleteText = [defaults stringForKey:WCAtlasMomentsCommentAntiDeleteTextKey] ?: @"←该评论已删除";
    CGFloat antiDeleteFontSize = [defaults doubleForKey:WCAtlasMomentsCommentAntiDeleteFontSizeKey];
    antiDeleteFontSize = MIN(24.0, MAX(6.0, antiDeleteFontSize > 0.0 ? antiDeleteFontSize : 12.0));
    NSString *antiDeleteColor = [defaults stringForKey:WCAtlasMomentsCommentAntiDeleteColorKey] ?: @"#8E8E93FF";
    WCAtlasAddFeature(moments,
                    WCAtlasItem(@"朋友圈评论防删除", @"保留本次微信运行中已加载后被删除的评论", @"bubble.left.and.text.bubble.right",
                              WCAtlasSettingRowKindSwitch, WCAtlasMomentsCommentAntiDeleteEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
                        WCAtlasItem(@"删除标识文字", @"追加在已删除评论末尾", @"textformat", WCAtlasSettingRowKindDetail,
                                  nil, antiDeleteText, WCAtlasSettingActionMomentsCommentAntiDeleteText),
                        WCAtlasItem(@"删除标识字号", @"限制在 6 到 24 之间", @"textformat.size", WCAtlasSettingRowKindDetail,
                                  nil, [NSString stringWithFormat:@"%.0f", antiDeleteFontSize], WCAtlasSettingActionMomentsCommentAntiDeleteFontSize),
                        WCAtlasItem(@"删除标识颜色", @"只改变追加标识的颜色", @"paintpalette", WCAtlasSettingRowKindDetail,
                                  WCAtlasMomentsCommentAntiDeleteColorKey, antiDeleteColor.uppercaseString, WCAtlasSettingActionMessageTimeColor),
                    ], defaults, collapsed);
    CGFloat intensity = [defaults doubleForKey:WCAtlasMomentsLikeHapticIntensityKey];
    NSString *intensityText = intensity < 0.34 ? @"轻" : (intensity < 0.75 ? @"中" : @"强");
    WCAtlasSettingItem *haptic = WCAtlasItem(@"点赞震动", @"点赞成功时提供触感反馈", @"waveform", WCAtlasSettingRowKindSwitch, WCAtlasMomentsLikeHapticEnabledKey, nil, WCAtlasSettingActionNone);
    haptic.hasChildren = YES;
    NSMutableArray *likeChildren = [NSMutableArray arrayWithObject:haptic];
    if ([defaults boolForKey:WCAtlasMomentsLikeHapticEnabledKey] && ![collapsed containsObject:WCAtlasMomentsLikeHapticEnabledKey]) {
        [likeChildren addObject:WCAtlasItem(@"点赞震动力度", @"调整双击点赞时的震动反馈", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil, WCAtlasCurrentSelection(intensityText), WCAtlasSettingActionHapticIntensity)];
    }
    WCAtlasAddFeature(moments, WCAtlasItem(@"朋友圈双击点赞", @"双击好友朋友圈内容直接点赞", @"hand.thumbsup", WCAtlasSettingRowKindSwitch, WCAtlasMomentsDoubleTapLikeKey, nil, WCAtlasSettingActionNone), likeChildren, defaults, collapsed);
    [moments addObjectsFromArray:@[
        WCAtlasItem(@"朋友圈操作按钮替换为评论", @"点击后直接进入评论", @"bubble.middle.bottom", WCAtlasSettingRowKindSwitch, WCAtlasMomentsQuickCommentKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"朋友圈转发", @"点击进入朋友圈转发发布页", @"arrowshape.turn.up.right", WCAtlasSettingRowKindSwitch, WCAtlasMomentsForwardEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"保存朋友圈媒体", @"在朋友圈操作菜单中保存图片、视频和实况照片", @"square.and.arrow.down", WCAtlasSettingRowKindSwitch, WCAtlasMomentsSaveImagesEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"朋友圈高清发送", @"从相机菜单选择高清图片或原视频", @"photo.badge.checkmark", WCAtlasSettingRowKindSwitch, WCAtlasMomentsOriginalMediaPostEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"朋友圈小尾巴", @"通过 WCAppInfo 设置来源应用尾巴，不修改正文或设备型号", @"tag", WCAtlasSettingRowKindSwitch, WCAtlasMomentsTailEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"默认发圈尾巴", @"选择已注册 AppID；发布时仍可为单条朋友圈更改", @"app.badge", WCAtlasSettingRowKindDetail, nil,
                  WCAtlasCurrentSelection([defaults stringForKey:WCAtlasMomentsTailAppIDKey] ?: @"无小尾巴"),
                  WCAtlasSettingActionMomentsTailPicker),
        WCAtlasItem(@"朋友圈头像快捷权限", @"长按头像切换朋友权限", @"person.crop.circle.badge.checkmark", WCAtlasSettingRowKindSwitch, WCAtlasMomentsQuickPermissionsKey, nil, WCAtlasSettingActionNone),
    ]];
    NSString *dateFormat = WCAtlasNormalizedMomentsDateFormat([defaults stringForKey:WCAtlasMomentsPreciseTimeFormatKey]) ?: WCAtlasMomentsPreciseTimeDefaultFormat;
    WCAtlasAddFeature(moments, WCAtlasItem(@"朋友圈精确发布时间", @"显示完整发布时间", @"calendar.badge.clock", WCAtlasSettingRowKindSwitch, WCAtlasMomentsPreciseTimeKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"朋友圈日期格式", @"支持 yyyy、MM、dd、E、HH、mm、ss", @"textformat", WCAtlasSettingRowKindDetail, nil, dateFormat, WCAtlasSettingActionMomentsDateFormat)
    ], defaults, collapsed);

    NSMutableArray *local = [NSMutableArray array];
    [local addObject:WCAtlasItem(@"查找好友", @"输入微信号或初始账号打开指定账号资料", @"person.crop.circle.badge.magnifyingglass", WCAtlasSettingRowKindDetail, nil, @"查找", WCAtlasSettingActionFindFriend)];
    [local addObject:WCAtlasItem(@"按 ID 打开聊天", @"原样输入单聊内部 ID 或群聊 ID，测试微信能否直接跳转", @"rectangle.and.pencil.and.ellipsis", WCAtlasSettingRowKindDetail, nil, @"测试", WCAtlasSettingActionOpenChatByID)];
    [local addObject:WCAtlasItem(@"检测单删好友", @"通过微信支付前置接口串行检测，并区分疑似单删与网络异常", @"person.crop.circle.badge.questionmark", WCAtlasSettingRowKindDetail, nil, @"检测", WCAtlasSettingActionFriendRelationCheck)];
    [local addObject:WCAtlasItem(@"显示信息卡片", @"在好友、群聊和群成员资料中集中显示账号信息", @"person.text.rectangle", WCAtlasSettingRowKindSwitch, WCAtlasShowRawContactIDEnabledKey, nil, WCAtlasSettingActionNone)];
    WCAtlasStepMode stepMode = [defaults integerForKey:WCAtlasStepModeKey] == WCAtlasStepModeDailyRandom ? WCAtlasStepModeDailyRandom : WCAtlasStepModeDailyFixed;
    NSInteger configuredSteps = MIN(100000, MAX(0, [defaults integerForKey:WCAtlasStepCountKey]));
    NSInteger effectiveSteps = [defaults integerForKey:WCAtlasStepDailyTargetKey];
    NSDate *stepDate = [defaults objectForKey:WCAtlasStepCountDateKey];
    BOOL today = effectiveSteps > 0 && [stepDate isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:stepDate];
    if ([defaults boolForKey:WCAtlasStepOverrideEnabledKey] && !today) {
        WCAtlasSettingsRegenerateDailyStepTarget(defaults);
        effectiveSteps = [defaults integerForKey:WCAtlasStepDailyTargetKey];
        stepDate = [defaults objectForKey:WCAtlasStepCountDateKey];
        today = effectiveSteps > 0 && [stepDate isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:stepDate];
    }
    NSString *modeText = stepMode == WCAtlasStepModeDailyRandom ? @"每日随机" : @"固定步数";
    NSMutableArray *stepChildren = [NSMutableArray arrayWithObject:WCAtlasItem(@"步数模式", @"选择固定数值，或每天随机生成一次", @"arrow.triangle.2.circlepath", WCAtlasSettingRowKindDetail, nil, WCAtlasCurrentSelection(modeText), WCAtlasSettingActionStepMode)];
    if (stepMode == WCAtlasStepModeDailyRandom) {
        NSInteger minimum = MAX(1, [defaults integerForKey:WCAtlasStepRandomMinimumKey]);
        NSInteger maximum = MAX(minimum, [defaults integerForKey:WCAtlasStepRandomMaximumKey]);
        [stepChildren addObject:WCAtlasItem(@"随机步数范围", @"每天首次使用时在范围内生成一次", @"dice", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%ld–%ld 步", (long)minimum, (long)maximum], WCAtlasSettingActionRandomStepRange)];
        [stepChildren addObject:WCAtlasItem(@"今日随机结果", @"当天保持不变；点击可重新生成", @"figure.walk.motion", WCAtlasSettingRowKindDetail, nil, today ? [NSString stringWithFormat:@"%ld 步", (long)effectiveSteps] : @"尚未生成", WCAtlasSettingActionRegenerateRandomSteps)];
    } else {
        [stepChildren addObject:WCAtlasItem(@"固定步数", @"点击输入每天固定显示的步数", @"number", WCAtlasSettingRowKindDetail, nil, configuredSteps > 0 ? [NSString stringWithFormat:@"已设置：%ld 步", (long)configuredSteps] : @"尚未设置", WCAtlasSettingActionFixedSteps)];
    }
    [stepChildren addObject:WCAtlasItem(@"分时段阶段递增", @"每天分阶段更新，18:30 完成今日目标", @"chart.line.uptrend.xyaxis", WCAtlasSettingRowKindSwitch, WCAtlasStepGradualEnabledKey, nil, WCAtlasSettingActionNone)];
    NSString *stepSummary = stepMode == WCAtlasStepModeDailyRandom
        ? (today ? [NSString stringWithFormat:@"今日随机：%ld 步", (long)effectiveSteps] : @"每日随机，尚未生成")
        : (configuredSteps > 0 ? [NSString stringWithFormat:@"固定：%ld 步", (long)configuredSteps] : @"固定模式，请先设置步数");
    WCAtlasAddFeature(local, WCAtlasItem(@"自定义微信运动步数", stepSummary, @"figure.walk", WCAtlasSettingRowKindSwitch, WCAtlasStepOverrideEnabledKey, nil, WCAtlasSettingActionNone), stepChildren, defaults, collapsed);
    WCAtlasAddFeature(local, WCAtlasItem(@"钱包余额本地显示", @"仅修改本机钱包余额文字", @"creditcard", WCAtlasSettingRowKindSwitch, WCAtlasWalletBalanceEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"设置钱包余额", @"金额按分保存，仅作用于钱包余额组件", @"number", WCAtlasSettingRowKindDetail, nil, WCAtlasLongLongForKey(WCAtlasWalletBalanceFenKey) > 0 ? @"已设置" : @"设置", WCAtlasSettingActionWalletBalance)
    ], defaults, collapsed);
    NSInteger contacts = [defaults integerForKey:WCAtlasContactsCountKey];
    WCAtlasAddFeature(local, WCAtlasItem(@"好友数量本地显示", @"替换明确的好友数量文案", @"person.2", WCAtlasSettingRowKindSwitch, WCAtlasContactsCountEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"设置好友数量", @"输入本机显示的好友数量", @"number", WCAtlasSettingRowKindDetail, nil, contacts > 0 ? [NSString stringWithFormat:@"%ld 个", (long)contacts] : @"设置", WCAtlasSettingActionContactsCount)
    ], defaults, collapsed);
    if (momentsOnly) {
        return @[[WCAtlasSettingSection sectionWithIdentifier:@"moments" title:nil footer:nil items:moments]];
    }
    return @[
        [WCAtlasSettingSection sectionWithIdentifier:@"automation" title:@"自动化" footer:@"保持后台运行可能增加耗电；自动登录和授权会跳过手动确认，请只在可信环境开启。" items:automation],
        [WCAtlasSettingSection sectionWithIdentifier:@"scan" title:@"扫码增强" footer:nil items:scan],
        [WCAtlasSettingSection sectionWithIdentifier:@"local-display" title:@"资料、运动与本地显示" footer:@"钱包余额和好友数量只修改本机显示。" items:local],
    ];
}

static NSArray<WCAtlasSettingSection *> *WCAtlasInterfaceSections(NSUserDefaults *defaults,
                                                               NSSet<NSString *> *collapsed,
                                                               BOOL disabledOnly) {
    NSMutableArray *display = [NSMutableArray array];
    NSMutableArray *disabled = [NSMutableArray array];
    WCAtlasAddFeature(display,
                    WCAtlasItem(@"全局头像圆角", @"统一调整微信头像组件的圆角", @"person.crop.square", WCAtlasSettingRowKindSwitch, WCAtlasGlobalAvatarRoundingEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
        WCAtlasItem(@"头像圆角程度", @"0% 为直角，100% 为圆形", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil,
                  [NSString stringWithFormat:@"%.0f%%", [defaults doubleForKey:WCAtlasGlobalAvatarCornerPercentKey]],
                  WCAtlasSettingActionGlobalAvatarCornerPercent),
    ], defaults, collapsed);
    CGFloat globalScale = WCAtlasScalePercentForDefaultsKey(WCAtlasPageScaleGlobalPercentKey, 100.0);
    CGFloat settingsScale = WCAtlasScalePercentForDefaultsKey(WCAtlasSettingsPageScalePercentKey, 100.0);
    WCAtlasAddFeature(display, WCAtlasItem(@"页面缩放", @"调整页面中的文字大小", @"textformat.size", WCAtlasSettingRowKindSwitch, WCAtlasPageScaleEnabledKey, nil, WCAtlasSettingActionNone), @[
        WCAtlasItem(@"全局页面缩放比例", @"同时调整应用界面和网页文字", @"rectangle.compress.vertical", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f%%", globalScale], WCAtlasSettingActionGlobalScale),
        WCAtlasItem(@"WCAtlas 设置页缩放比例", @"仅调整本设置页", @"list.bullet.rectangle", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f%%", settingsScale], WCAtlasSettingActionSettingsScale),
    ], defaults, collapsed);
    [disabled addObjectsFromArray:@[
        WCAtlasItem(@"隐藏群标题尾部", @"隐藏群人数和免打扰标记并居中群名", @"bell.slash", WCAtlasSettingRowKindSwitch, WCAtlasHideChatMuteIconKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"隐藏截屏分享按钮", @"不显示右下角截图转发浮层", @"rectangle.on.rectangle.slash", WCAtlasSettingRowKindSwitch, WCAtlasHideScreenshotForwardKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"隐藏页面分割线", @"不显示列表和页面中的细分割线", @"rectangle.split.1x2", WCAtlasSettingRowKindSwitch, WCAtlasHideSeparatorLinesKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"广告精简", @"精简朋友圈、视频号、广告推送与小程序启动广告", @"rectangle.badge.xmark", WCAtlasSettingRowKindSwitch, WCAtlasAdBlockerKey, nil, WCAtlasSettingActionNone),
    ]];
    [display addObject:WCAtlasItem(@"开启强制高刷", @"前台锁定为设备支持的最高刷新率", @"speedometer", WCAtlasSettingRowKindSwitch, WCAtlasScrollHighRefreshRateEnabledKey, nil, WCAtlasSettingActionNone)];
    [display addObject:WCAtlasItem(@"主页右滑扩展", @"增加备注、朋友圈、折叠群聊、勿扰与置顶操作", @"rectangle.and.hand.point.up.left", WCAtlasSettingRowKindSwitch, WCAtlasHomeSwipeActionsEnabledKey, nil, WCAtlasSettingActionNone)];
    WCAtlasAddFeature(display,
                     WCAtlasItem(@"首页会话归类", @"将好友或群聊归入首页分类，并可在分类内继续建立文件夹", @"rectangle.3.group", WCAtlasSettingRowKindSwitch, WCAtlasHomeCategoriesEnabledKey, nil, WCAtlasSettingActionNone),
                     @[WCAtlasItem(@"管理分类与文件夹", @"添加分类、文件夹并选择好友或群聊", @"folder.badge.gearshape", WCAtlasSettingRowKindDetail, nil, @"管理", WCAtlasSettingActionHomeCategories)],
                     defaults,
                     collapsed);
    NSMutableArray *chatCapsules = [NSMutableArray array];
    NSInteger glassStyle = [defaults integerForKey:WCAtlasChatGlassStyleKey];
    NSString *glassStyleName = glassStyle == 1 ? @"伪液态" : @"磨砂玻璃";
    WCAtlasAddFeature(chatCapsules,
                    WCAtlasItem(@"胶囊顶栏", @"隐藏整条顶栏背景，左右使用玻璃胶囊", @"capsule", WCAtlasSettingRowKindSwitch, WCAtlasChatTopBarCapsuleEnabledKey, nil, WCAtlasSettingActionNone),
                    @[
        WCAtlasItem(@"头像大小", @"限制在 24 到 34 之间", @"person.crop.circle", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatTopBarAvatarSizeKey]], WCAtlasSettingActionChatTopAvatarSize),
        WCAtlasItem(@"昵称字号", @"限制在 12 到 18 之间", @"textformat.size", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatTopBarNicknameSizeKey]], WCAtlasSettingActionChatTopNicknameSize),
        WCAtlasItem(@"玻璃样式", @"磨砂玻璃或独立的伪液态效果", @"circle.hexagongrid.fill", WCAtlasSettingRowKindDetail, WCAtlasChatGlassStyleKey, glassStyleName, WCAtlasSettingActionChatGlassStyle),
        WCAtlasItem(@"模糊强度", @"限制在 20% 到 100%", @"drop.halffull", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f%%", [defaults doubleForKey:WCAtlasChatGlassBlurIntensityKey]], WCAtlasSettingActionChatGlassBlurIntensity),
    ], defaults, collapsed);
    NSMutableArray *input = [NSMutableArray array];
    NSMutableArray *roundingChildren = [NSMutableArray array];
    WCAtlasSettingItem *inner = WCAtlasItem(@"输入框内部圆角", @"调整文字输入区域", @"text.cursor", WCAtlasSettingRowKindSwitch, WCAtlasChatInputInnerRoundingKey, nil, WCAtlasSettingActionNone);
    inner.hasChildren = YES;
    [roundingChildren addObject:inner];
    if ([defaults boolForKey:WCAtlasChatInputInnerRoundingKey] && ![collapsed containsObject:WCAtlasChatInputInnerRoundingKey]) [roundingChildren addObject:WCAtlasItem(@"内部圆角程度", @"输入 0 到 40", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatInputInnerRadiusKey]], WCAtlasSettingActionInnerRadius)];
    WCAtlasSettingItem *outer = WCAtlasItem(@"外部工具栏圆角", @"调整聊天底部工具栏", @"rectangle.bottomhalf.filled", WCAtlasSettingRowKindSwitch, WCAtlasChatInputOuterRoundingKey, nil, WCAtlasSettingActionNone);
    outer.hasChildren = YES;
    [roundingChildren addObject:outer];
    if ([defaults boolForKey:WCAtlasChatInputOuterRoundingKey] && ![collapsed containsObject:WCAtlasChatInputOuterRoundingKey]) [roundingChildren addObject:WCAtlasItem(@"外部圆角程度", @"输入 0 到 40", @"slider.horizontal.3", WCAtlasSettingRowKindDetail, nil, [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCAtlasChatInputOuterRadiusKey]], WCAtlasSettingActionOuterRadius)];
    WCAtlasAddFeature(input, WCAtlasItem(@"聊天输入栏圆角", @"分别控制输入框与外部工具栏", @"rectangle.roundedtop", WCAtlasSettingRowKindSwitch, WCAtlasChatInputRoundingEnabledKey, nil, WCAtlasSettingActionNone), roundingChildren, defaults, collapsed);
    NSUInteger hiddenMeCount = [defaults arrayForKey:WCAtlasMeMenuHiddenTitlesKey].count;
    [disabled addObject:WCAtlasItem(@"我的页面入口管理", @"隐藏作品、小店与卡包或表情入口", @"person.crop.rectangle.stack", WCAtlasSettingRowKindDetail, nil, WCAtlasCountText(hiddenMeCount), WCAtlasSettingActionMeMenu)];
    if (disabledOnly) {
        return @[[WCAtlasSettingSection sectionWithIdentifier:@"interface-disabled" title:nil
                                                     footer:@"关闭对应开关后恢复微信原始界面。" items:disabled]];
    }
    return @[
        [WCAtlasSettingSection sectionWithIdentifier:@"display" title:@"显示" footer:@"关闭后恢复微信原始样式。" items:display],
        [WCAtlasSettingSection sectionWithIdentifier:@"chat-capsules" title:@"聊天顶栏" footer:@"左右顶栏使用所选玻璃样式；置顶消息固定使用磨砂玻璃并跟随模糊强度，避免展开时背景溢出。" items:chatCapsules],
        [WCAtlasSettingSection sectionWithIdentifier:@"input" title:@"输入栏" footer:nil items:input],
    ];
}

static NSArray<WCAtlasSettingSection *> *WCAtlasPluginSections(NSUserDefaults *defaults) {
    if (WCAtlasExternalPluginManagerAvailable() &&
        [defaults boolForKey:WCAtlasPluginManagerEnabledKey]) {
        [defaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
    }
    NSString *notificationSymbol = [defaults stringForKey:WCAtlasInAppNotificationSymbolKey] ?: @"automatic";
    NSString *notificationValue = [notificationSymbol isEqualToString:@"automatic"]
        ? @"跟随类型" : @"自定义";
    NSArray<WCAtlasSettingItem *> *notifications = @[
        WCAtlasItem(@"应用内通知样式", @"调整左侧图标、横幅高度和背景模糊度", @"bell.fill",
                  WCAtlasSettingRowKindDetail, nil, notificationValue,
                  WCAtlasSettingActionInAppNotificationAppearance),
    ];
    NSArray<WCAtlasSettingItem *> *logging = @[
        WCAtlasItem(@"记录运行日志", @"关闭后停止新增普通日志，最多保留本次运行 500 条", @"text.alignleft", WCAtlasSettingRowKindSwitch, WCAtlasLoggingEnabledKey, nil, WCAtlasSettingActionNone),
        WCAtlasItem(@"查看运行日志", @"查看、复制或清空本次微信运行记录", @"doc.text.magnifyingglass", WCAtlasSettingRowKindDetail, nil,
                  WCAtlasCountText(WCAtlasLogEntries().count), WCAtlasSettingActionLogRecords),
    ];
    NSMutableArray<WCAtlasSettingItem *> *management = [NSMutableArray arrayWithObject:
        WCAtlasItem(@"配置管理", @"导入、导出或重置 WCAtlas 配置", @"externaldrive", WCAtlasSettingRowKindDetail, nil, @"管理", WCAtlasSettingActionConfigManager)];
    WCAtlasAddFeature(management,
        WCAtlasItem(@"内置插件管理", @"与懒猫插件管理不兼容；开启后重启微信以收录其他插件", @"square.stack.3d.up", WCAtlasSettingRowKindSwitch, WCAtlasPluginManagerEnabledKey, nil, WCAtlasSettingActionNone),
        @[WCAtlasItem(@"打开内置插件管理", @"管理分类、排序与快捷开关", @"rectangle.stack", WCAtlasSettingRowKindDetail, nil, @"打开", WCAtlasSettingActionPluginManager)],
        defaults, [NSSet setWithArray:[defaults arrayForKey:WCAtlasCollapsedFeaturesKey] ?: @[]]);
    return @[
        [WCAtlasSettingSection sectionWithIdentifier:@"in-app-notifications" title:@"通知" footer:@"仅影响 WCAtlas 在微信前台显示的自绘提醒。" items:notifications],
        [WCAtlasSettingSection sectionWithIdentifier:@"logging" title:@"日志" footer:@"运行日志只保存在内存中，退出微信后自动清空。" items:logging],
        [WCAtlasSettingSection sectionWithIdentifier:@"plugin-management" title:@"配置与入口" footer:nil items:management],
    ];
}

NSArray<WCAtlasSettingSection *> *WCAtlasSettingsBuildSections(WCAtlasSettingsCategory category,
                                                           NSSet<NSString *> *collapsedFeatureKeys) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSSet *collapsed = collapsedFeatureKeys ?: [NSSet set];
    switch (category) {
        case WCAtlasSettingsCategoryMessages: return WCAtlasMessageSections(defaults, collapsed);
        case WCAtlasSettingsCategoryMoments: return WCAtlasEnhancementSections(defaults, collapsed, YES);
        case WCAtlasSettingsCategoryInterfaceDisabled: return WCAtlasInterfaceSections(defaults, collapsed, YES);
        case WCAtlasSettingsCategoryEnhancements: return WCAtlasEnhancementSections(defaults, collapsed, NO);
        case WCAtlasSettingsCategoryInterface: return WCAtlasInterfaceSections(defaults, collapsed, NO);
        case WCAtlasSettingsCategoryPlugin: return WCAtlasPluginSections(defaults);
        case WCAtlasSettingsCategoryRoot:
        default: return WCAtlasRootSections();
    }
}
