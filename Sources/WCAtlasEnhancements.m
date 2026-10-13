#import "WCAtlasEnhancements.h"
#import <math.h>

NSString *const WCAtlasAutoDeviceLoginKey = @"com.qiu7c.wcatlas.enhance.auto-device-login";
NSString *const WCAtlasAutoGameAuthorizeKey = @"com.qiu7c.wcatlas.enhance.auto-game-authorize";
NSString *const WCAtlasMomentsDoubleTapLikeKey = @"com.qiu7c.wcatlas.moments.double-tap-like";
NSString *const WCAtlasMomentsLikeHapticEnabledKey = @"com.qiu7c.wcatlas.moments.like-haptic";
NSString *const WCAtlasMomentsLikeHapticIntensityKey = @"com.qiu7c.wcatlas.moments.like-haptic-intensity";
NSString *const WCAtlasMomentsQuickCommentKey = @"com.qiu7c.wcatlas.moments.quick-comment";
NSString *const WCAtlasMomentsForwardEnabledKey = @"com.qiu7c.wcatlas.moments.forward";
NSString *const WCAtlasMomentsSaveImagesEnabledKey = @"com.qiu7c.wcatlas.moments.save-images";
NSString *const WCAtlasMomentsOriginalMediaPostEnabledKey = @"com.qiu7c.wcatlas.moments.original-media-post";
NSString *const WCAtlasMomentsTailEnabledKey = @"com.qiu7c.wcatlas.moments.tail.enabled";
NSString *const WCAtlasMomentsTailAppIDKey = @"com.qiu7c.wcatlas.moments.tail.app-id";
NSString *const WCAtlasMomentsQuickPermissionsKey = @"com.qiu7c.wcatlas.moments.quick-permissions";
NSString *const WCAtlasMomentsPreciseTimeKey = @"com.qiu7c.wcatlas.moments.precise-time";
NSString *const WCAtlasMomentsPreciseTimeFormatKey = @"com.qiu7c.wcatlas.moments.precise-time-format";
NSString *const WCAtlasMomentsPreciseTimeDefaultFormat = @"yyyy-MM-dd HH:mm:ss";
NSString *const WCAtlasBackgroundKeepAliveEnabledKey = @"com.qiu7c.wcatlas.background.keep-alive";
NSString *const WCAtlasMomentsInteractionReminderEnabledKey = @"com.qiu7c.wcatlas.moments.interaction-reminder";
NSString *const WCAtlasMomentsInteractionReminderDetailsEnabledKey = @"com.qiu7c.wcatlas.moments.interaction-reminder.details";
NSString *const WCAtlasMomentsCommentAntiDeleteEnabledKey = @"com.qiu7c.wcatlas.moments.comment-anti-delete";
NSString *const WCAtlasMomentsCommentAntiDeleteTextKey = @"com.qiu7c.wcatlas.moments.comment-anti-delete.text";
NSString *const WCAtlasMomentsCommentAntiDeleteFontSizeKey = @"com.qiu7c.wcatlas.moments.comment-anti-delete.font-size";
NSString *const WCAtlasMomentsCommentAntiDeleteColorKey = @"com.qiu7c.wcatlas.moments.comment-anti-delete.color";
NSString *const WCAtlasMomentsReminderEnabledKey = @"com.qiu7c.wcatlas.moments.reminder";
NSString *const WCAtlasMomentsReminderUsersKey = @"com.qiu7c.wcatlas.moments.reminder.users";
NSString *const WCAtlasMomentsReminderIntervalKey = @"com.qiu7c.wcatlas.moments.reminder.interval";
NSString *const WCAtlasMomentsReminderForwardEnabledKey = @"com.qiu7c.wcatlas.moments.reminder.forward";
NSString *const WCAtlasMomentsReminderForwardTargetKey = @"com.qiu7c.wcatlas.moments.reminder.forward-target";
NSString *const WCAtlasMomentsReminderForwardImagesKey = @"com.qiu7c.wcatlas.moments.reminder.forward-images";
NSString *const WCAtlasMomentsReminderForwardVideosKey = @"com.qiu7c.wcatlas.moments.reminder.forward-videos";
NSString *const WCAtlasGameSelectorKey = @"com.qiu7c.wcatlas.enhance.game-selector";
NSString *const WCAtlasChatJokerEnabledKey = @"com.qiu7c.wcatlas.enhance.chat-joker";
NSString *const WCAtlasEmoticonToSelfieEnabledKey = @"com.qiu7c.wcatlas.enhance.emoticon-to-selfie";
NSString *const WCAtlasReplySwipeEnabledKey = @"com.qiu7c.wcatlas.chat.reply-swipe";
NSString *const WCAtlasReplySwipeSelfActionKey = @"com.qiu7c.wcatlas.chat.reply-swipe.self-action";
NSString *const WCAtlasReplySwipeOtherActionKey = @"com.qiu7c.wcatlas.chat.reply-swipe.other-action";
NSString *const WCAtlasReplySwipeRightSelfActionKey = @"com.qiu7c.wcatlas.chat.reply-swipe.right.self-action";
NSString *const WCAtlasReplySwipeRightOtherActionKey = @"com.qiu7c.wcatlas.chat.reply-swipe.right.other-action";
NSString *const WCAtlasReplySwipeTriggerDistanceKey = @"com.qiu7c.wcatlas.chat.reply-swipe.trigger-distance";
NSString *const WCAtlasMessageDoubleTapSelfActionKey = @"com.qiu7c.wcatlas.chat.message-gesture.double-tap.self-action";
NSString *const WCAtlasMessageDoubleTapOtherActionKey = @"com.qiu7c.wcatlas.chat.message-gesture.double-tap.other-action";
NSString *const WCAtlasMessageTripleTapSelfActionKey = @"com.qiu7c.wcatlas.chat.message-gesture.triple-tap.self-action";
NSString *const WCAtlasMessageTripleTapOtherActionKey = @"com.qiu7c.wcatlas.chat.message-gesture.triple-tap.other-action";
NSString *const WCAtlasAvatarQuickMenuGestureKey = @"com.qiu7c.wcatlas.chat.avatar-quick-menu.gesture";
NSString *const WCAtlasChatMessageTimeEnabledKey = @"com.qiu7c.wcatlas.chat.message-time";
NSString *const WCAtlasChatMessageTimeBelowAvatarKey = @"com.qiu7c.wcatlas.chat.message-time.below-avatar";
NSString *const WCAtlasChatMessageTimeBubbleSideKey = @"com.qiu7c.wcatlas.chat.message-time.bubble-side";
NSString *const WCAtlasChatMessageTimeFormatKey = @"com.qiu7c.wcatlas.chat.message-time.format";
NSString *const WCAtlasChatMessageTimeFontSizeKey = @"com.qiu7c.wcatlas.chat.message-time.font-size";
NSString *const WCAtlasChatMessageTimeColorKey = @"com.qiu7c.wcatlas.chat.message-time.color";
NSString *const WCAtlasChatMessageTimeLightColorKey = @"com.qiu7c.wcatlas.chat.message-time.color.light";
NSString *const WCAtlasChatMessageTimeDarkColorKey = @"com.qiu7c.wcatlas.chat.message-time.color.dark";
NSString *const WCAtlasChatMessageTimeBubbleVerticalPositionKey = @"com.qiu7c.wcatlas.chat.message-time.bubble-vertical-position";
NSString *const WCAtlasChatMessageTimeAvatarSpacingKey = @"com.qiu7c.wcatlas.chat.message-time.avatar-spacing";
NSString *const WCAtlasChatMessageTimeBoldKey = @"com.qiu7c.wcatlas.chat.message-time.bold";
NSString *const WCAtlasQuoteJumpEnabledKey = @"com.qiu7c.wcatlas.chat.quote-jump";
NSString *const WCAtlasQuoteJumpImageEnabledKey = @"com.qiu7c.wcatlas.chat.quote-jump.image";
NSString *const WCAtlasQuoteJumpVideoEnabledKey = @"com.qiu7c.wcatlas.chat.quote-jump.video";
NSString *const WCAtlasChatSearchButtonEnabledKey = @"com.qiu7c.wcatlas.chat.search-button";
NSString *const WCAtlasChatTopBarCapsuleEnabledKey = @"com.qiu7c.wcatlas.chat.top-bar-capsule";
NSString *const WCAtlasChatGlassStyleKey = @"com.qiu7c.wcatlas.chat.capsule-glass.style";
NSString *const WCAtlasChatGlassBlurIntensityKey = @"com.qiu7c.wcatlas.chat.capsule-glass.blur-intensity";
NSString *const WCAtlasChatTopBarAvatarSizeKey = @"com.qiu7c.wcatlas.chat.top-bar-capsule.avatar-size";
NSString *const WCAtlasChatTopBarNicknameSizeKey = @"com.qiu7c.wcatlas.chat.top-bar-capsule.nickname-size";
NSString *const WCAtlasMessageBlockEnabledKey = @"com.qiu7c.wcatlas.message.block";
NSString *const WCAtlasMessageBlockUsersKey = @"com.qiu7c.wcatlas.message.block.users";
NSString *const WCAtlasMessageBlockKeywordsKey = @"com.qiu7c.wcatlas.message.block.keywords";
NSString *const WCAtlasMessageBlockRulesKey = @"com.qiu7c.wcatlas.message.block.rules";
NSString *const WCAtlasMessageBlockProfileSwitchEnabledKey = @"com.qiu7c.wcatlas.message.block.profile-switch";
NSString *const WCAtlasSendConfirmationProfileSwitchEnabledKey = @"com.qiu7c.wcatlas.send-confirmation.profile-switch";
NSString *const WCAtlasMessageRepeatMenuEnabledKey = @"com.qiu7c.wcatlas.chat.message-repeat-menu";
NSString *const WCAtlasLongPressMenuEnabledKey = @"com.qiu7c.wcatlas.chat.long-press-menu";
NSString *const WCAtlasLongPressMenuHiddenTitlesKey = @"com.qiu7c.wcatlas.chat.long-press-menu.hidden";
NSString *const WCAtlasLongPressMenuPreferredOrderKey = @"com.qiu7c.wcatlas.chat.long-press-menu.order";
NSString *const WCAtlasLongPressMenuTitleMapKey = @"com.qiu7c.wcatlas.chat.long-press-menu.rename";
NSString *const WCAtlasLongPressMenuKnownTitlesKey = @"com.qiu7c.wcatlas.chat.long-press-menu.known";
NSString *const WCAtlasLongPressMenuManualTitlesKey = @"com.qiu7c.wcatlas.chat.long-press-menu.manual";
NSString *const WCAtlasHideSeparatorLinesKey = @"com.qiu7c.wcatlas.interface.hide-separator-lines";
NSString *const WCAtlasScrollHighRefreshRateEnabledKey = @"com.qiu7c.wcatlas.interface.scroll-high-refresh-rate";
NSString *const WCAtlasGroupMemberReminderEnabledKey = @"com.qiu7c.wcatlas.message.group-member-reminder";
NSString *const WCAtlasRedEnvelopeDetailEnabledKey = @"com.qiu7c.wcatlas.chat.red-envelope-detail";
NSString *const WCAtlasRedEnvelopeDetailCenterKey = @"com.qiu7c.wcatlas.chat.red-envelope-detail.center";
NSString *const WCAtlasRedEnvelopeDetailFontSizeKey = @"com.qiu7c.wcatlas.chat.red-envelope-detail.font-size";
NSString *const WCAtlasCallConfirmEnabledKey = @"com.qiu7c.wcatlas.chat.call-confirm";
NSString *const WCAtlasAutoSpeakerphoneEnabledKey = @"com.qiu7c.wcatlas.chat.auto-speakerphone";
NSString *const WCAtlasCallRecordingEnabledKey = @"com.qiu7c.wcatlas.chat.call-recording";
NSString *const WCAtlasCallVoiceDisguiseEnabledKey = @"com.qiu7c.wcatlas.chat.call-voice-disguise";
NSString *const WCAtlasCallVoiceModeKey = @"com.qiu7c.wcatlas.chat.call-voice-mode";
NSString *const WCAtlasCallRealtimeVoiceEffectEnabledKey = @"com.qiu7c.wcatlas.chat.call-realtime-voice-effect";
NSString *const WCAtlasCallRealtimeVoiceEffectPresetKey = @"com.qiu7c.wcatlas.chat.call-realtime-voice-effect.preset";
NSString *const WCAtlasQRCodeCameraSourceEnabledKey = @"com.qiu7c.wcatlas.enhance.qrcode-camera-source";
NSString *const WCAtlasAutoOriginalImageEnabledKey = @"com.qiu7c.wcatlas.enhance.auto-original-image";
NSString *const WCAtlasAutoCombineSendEnabledKey = @"com.qiu7c.wcatlas.enhance.auto-combine-send";
NSString *const WCAtlasNotificationDirectChatEnabledKey = @"com.qiu7c.wcatlas.enhance.notification-direct-chat";
NSString *const WCAtlasWalletBalanceEnabledKey = @"com.qiu7c.wcatlas.enhance.wallet-balance";
NSString *const WCAtlasWalletBalanceFenKey = @"com.qiu7c.wcatlas.enhance.wallet-balance-fen";
NSString *const WCAtlasContactsCountEnabledKey = @"com.qiu7c.wcatlas.enhance.contacts-count";
NSString *const WCAtlasContactsCountKey = @"com.qiu7c.wcatlas.enhance.contacts-count-value";
NSString *const WCAtlasStepOverrideEnabledKey = @"com.qiu7c.wcatlas.enhance.step-override";
NSString *const WCAtlasStepCountKey = @"com.qiu7c.wcatlas.enhance.step-count";
NSString *const WCAtlasStepCountDateKey = @"com.qiu7c.wcatlas.enhance.step-count-date";
NSString *const WCAtlasStepModeKey = @"com.qiu7c.wcatlas.enhance.step-mode";
NSString *const WCAtlasStepRandomMinimumKey = @"com.qiu7c.wcatlas.enhance.step-random-minimum";
NSString *const WCAtlasStepRandomMaximumKey = @"com.qiu7c.wcatlas.enhance.step-random-maximum";
NSString *const WCAtlasStepGradualEnabledKey = @"com.qiu7c.wcatlas.enhance.step-gradual";
NSString *const WCAtlasStepDailyTargetKey = @"com.qiu7c.wcatlas.enhance.step-daily-target";
NSString *const WCAtlasMeMenuKnownTitlesKey = @"com.qiu7c.wcatlas.interface.me-menu-known";
NSString *const WCAtlasMeMenuHiddenTitlesKey = @"com.qiu7c.wcatlas.interface.me-menu-hidden";
NSString *const WCAtlasAutoVoiceTranscriptionEnabledKey = @"com.qiu7c.wcatlas.chat.auto-voice-transcription";
NSString *const WCAtlasVoiceForwardEnabledKey = @"com.qiu7c.wcatlas.chat.voice-forward";
NSString *const WCAtlasMediaToVoiceEnabledKey = @"com.qiu7c.wcatlas.chat.media-to-voice";
NSString *const WCAtlasAudioFileToVoiceEnabledKey = @"com.qiu7c.wcatlas.chat.media-to-voice.audio-file";
NSString *const WCAtlasVideoToVoiceEnabledKey = @"com.qiu7c.wcatlas.chat.media-to-voice.video";
NSString *const WCAtlasMusicToVoiceEnabledKey = @"com.qiu7c.wcatlas.chat.media-to-voice.music";
NSString *const WCAtlasAutoVoiceTranscriptionIgnoreGroupKey = @"com.qiu7c.wcatlas.chat.auto-voice-transcription.ignore-group";
NSString *const WCAtlasAutoVoiceTranscriptionIgnorePrivateKey = @"com.qiu7c.wcatlas.chat.auto-voice-transcription.ignore-private";
NSString *const WCAtlasAutoVoiceTranscriptionIgnoreSelfKey = @"com.qiu7c.wcatlas.chat.auto-voice-transcription.ignore-self";
NSString *const WCAtlasHideScreenshotForwardKey = @"com.qiu7c.wcatlas.interface.hide-screenshot-forward";
NSString *const WCAtlasMultiSelectLimitEnabledKey = @"com.qiu7c.wcatlas.enhance.multi-select-limit";
NSString *const WCAtlasShowRawContactIDEnabledKey = @"com.qiu7c.wcatlas.enhance.show-raw-contact-id";
NSString *const WCAtlasHomeSwipeActionsEnabledKey = @"com.qiu7c.wcatlas.enhance.home-swipe-actions";
NSString *const WCAtlasPageScaleEnabledKey = @"com.qiu7c.wcatlas.interface.page-scale";
NSString *const WCAtlasPageScaleGlobalPercentKey = @"com.qiu7c.wcatlas.interface.page-scale.global-percent";
NSString *const WCAtlasSettingsPageScalePercentKey = @"com.qiu7c.wcatlas.interface.page-scale.settings-percent";
NSString *const WCAtlasAdBlockerKey = @"com.qiu7c.wcatlas.enhance.ad-blocker";
NSString *const WCAtlasAntiRevokeKey = @"com.qiu7c.wcatlas.message.anti-revoke";
NSString *const WCAtlasAntiRevokeNotifySenderKey = @"com.qiu7c.wcatlas.message.anti-revoke.notify-sender";
NSString *const WCAtlasAntiRevokeLocalTemplateKey = @"com.qiu7c.wcatlas.message.anti-revoke.local-template";
NSString *const WCAtlasAntiRevokeReplyTemplateKey = @"com.qiu7c.wcatlas.message.anti-revoke.reply-template";
NSString *const WCAtlasAntiRevokeTimeFilterKey = @"com.qiu7c.wcatlas.message.anti-revoke.time-filter";
NSString *const WCAtlasAntiRevokePromptStyleKey = @"com.qiu7c.wcatlas.message.anti-revoke.prompt-style";
NSString *const WCAtlasAntiRevokeSideTextKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-text";
NSString *const WCAtlasAntiRevokeSideOffsetXKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-offset-x";
NSString *const WCAtlasAntiRevokeSideOffsetYKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-offset-y";
NSString *const WCAtlasAntiRevokeLocalTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.local-text-color";
NSString *const WCAtlasAntiRevokeSideTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-text-color";
NSString *const WCAtlasAntiRevokeLocalLightTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.local-text-color.light";
NSString *const WCAtlasAntiRevokeLocalDarkTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.local-text-color.dark";
NSString *const WCAtlasAntiRevokeSideLightTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-text-color.light";
NSString *const WCAtlasAntiRevokeSideDarkTextColorKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-text-color.dark";
NSString *const WCAtlasAntiRevokePersistRecordsKey = @"com.qiu7c.wcatlas.message.anti-revoke.persist-records";
NSString *const WCAtlasImageEditQuickSendEnabledKey = @"com.qiu7c.wcatlas.enhance.image-edit-quick-send";
NSString *const WCAtlasInputSwipeActionsEnabledKey = @"com.qiu7c.wcatlas.chat.input-swipe-actions";
NSString *const WCAtlasQuickReplyEnabledKey = @"com.qiu7c.wcatlas.chat.quick-reply-library";
NSString *const WCAtlasQuickReplyInstantSendEnabledKey = @"com.qiu7c.wcatlas.chat.quick-reply-library.instant-send";
NSString *const WCAtlasChatTTSEnabledKey = @"com.qiu7c.wcatlas.chat.tts";
NSString *const WCAtlasChatTTSTriggerEnabledKey = @"com.qiu7c.wcatlas.chat.tts.trigger-enabled";
NSString *const WCAtlasChatTTSTriggerPrefixKey = @"com.qiu7c.wcatlas.chat.tts.trigger-prefix";
NSString *const WCAtlasSendConfirmationEnabledKey = @"com.qiu7c.wcatlas.chat.send-confirmation";
NSString *const WCAtlasSendConfirmationUsersKey = @"com.qiu7c.wcatlas.chat.send-confirmation.users";
NSString *const WCAtlasSendConfirmationPauseSecondsKey = @"com.qiu7c.wcatlas.chat.send-confirmation.pause-seconds";
NSString *const WCAtlasMultiSelectExportEnabledKey = @"com.qiu7c.wcatlas.enhance.multi-select-export";
NSString *const WCAtlasMultiSelectExportTextKey = @"com.qiu7c.wcatlas.enhance.multi-select-export.text";
NSString *const WCAtlasMultiSelectSaveImagesKey = @"com.qiu7c.wcatlas.enhance.multi-select-export.images";
NSString *const WCAtlasMultiSelectShareCardKey = @"com.qiu7c.wcatlas.enhance.multi-select-export.share-card";
NSString *const WCAtlasEnhancementDidChangeNotification = @"WCAtlasEnhancementDidChangeNotification";

CGFloat WCAtlasScalePercentForDefaultsKey(NSString *key, CGFloat defaultValue) {
    id stored = key.length > 0 ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    CGFloat value = [stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : defaultValue;
    if (!isfinite(value)) value = defaultValue;
    return MIN(100.0, MAX(70.0, value));
}

NSString *WCAtlasNormalizedMomentsDateFormat(NSString *format) {
    if (![format isKindOfClass:[NSString class]]) return nil;
    NSString *normalized = [format stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    if (normalized.length == 0 || normalized.length > 64) return nil;

    static NSArray<NSString *> *tokens;
    static NSCharacterSet *letters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tokens = @[@"yyyy", @"MM", @"dd", @"E", @"HH", @"mm", @"ss"];
        letters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"];
    });

    NSUInteger index = 0;
    while (index < normalized.length) {
        if ([normalized characterAtIndex:index] == '\\' &&
            index + 1 < normalized.length &&
            [normalized characterAtIndex:index + 1] == 'n') {
            index += 2;
            continue;
        }
        NSRange characterRange = [normalized rangeOfComposedCharacterSequenceAtIndex:index];
        NSString *character = [normalized substringWithRange:characterRange];
        if ([character rangeOfCharacterFromSet:letters].location == NSNotFound) {
            index = NSMaxRange(characterRange);
            continue;
        }
        BOOL matched = NO;
        for (NSString *token in tokens) {
            if (index + token.length <= normalized.length &&
                [[normalized substringWithRange:NSMakeRange(index, token.length)] isEqualToString:token]) {
                index += token.length;
                matched = YES;
                break;
            }
        }
        if (!matched) return nil;
    }
    return normalized;
}

UIColor *WCAtlasColorForDefaultsKey(NSString *key, UIColor *fallbackColor) {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (![hex isKindOfClass:[NSString class]]) return fallbackColor;
    NSString *value = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (value.length != 6 && value.length != 8) return fallbackColor;
    unsigned long long rgba = 0;
    if (![[NSScanner scannerWithString:value] scanHexLongLong:&rgba]) return fallbackColor;
    CGFloat red = ((rgba >> (value.length == 8 ? 24 : 16)) & 0xFF) / 255.0;
    CGFloat green = ((rgba >> (value.length == 8 ? 16 : 8)) & 0xFF) / 255.0;
    CGFloat blue = ((rgba >> (value.length == 8 ? 8 : 0)) & 0xFF) / 255.0;
    CGFloat alpha = value.length == 8 ? (rgba & 0xFF) / 255.0 : 1.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

NSString *WCAtlasHexStringFromColor(UIColor *color) {
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return @"#8E8E93FF";
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)lround(red * 255.0), (int)lround(green * 255.0),
            (int)lround(blue * 255.0), (int)lround(alpha * 255.0)];
}

BOOL WCAtlasEnhancementEnabled(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id masterValue = [defaults objectForKey:@"com.qiu7c.wcatlas.enabled"];
    BOOL masterEnabled = masterValue ? [masterValue boolValue] : YES;
    id featureValue = [defaults objectForKey:key];
    BOOL featureEnabled = featureValue ? [featureValue boolValue] : [key isEqualToString:WCAtlasAntiRevokeKey];
    return masterEnabled && featureEnabled;
}

UIColor *WCAtlasDynamicColorForDefaultsKeys(NSString *lightKey,
                                          NSString *darkKey,
                                          NSString *legacyKey,
                                          UIColor *lightFallbackColor,
                                          UIColor *darkFallbackColor) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *legacyHex = legacyKey.length > 0 ? [defaults stringForKey:legacyKey] : nil;
    UIColor *legacyFallback = legacyHex.length > 0
        ? WCAtlasColorForDefaultsKey(legacyKey, lightFallbackColor)
        : nil;
    UIColor *lightColor = WCAtlasColorForDefaultsKey(lightKey, legacyFallback ?: lightFallbackColor);
    UIColor *darkColor = WCAtlasColorForDefaultsKey(darkKey, legacyFallback ?: darkFallbackColor);
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
}
