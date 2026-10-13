#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCAtlasSettingsCategory) {
    WCAtlasSettingsCategoryRoot,
    WCAtlasSettingsCategoryMessages,
    WCAtlasSettingsCategoryMoments,
    WCAtlasSettingsCategoryInterfaceDisabled,
    WCAtlasSettingsCategoryEnhancements,
    WCAtlasSettingsCategoryInterface,
    WCAtlasSettingsCategoryPlugin,
};

typedef NS_ENUM(NSInteger, WCAtlasSettingRowKind) {
    WCAtlasSettingRowKindSwitch,
    WCAtlasSettingRowKindDetail,
    WCAtlasSettingRowKindInfo,
    WCAtlasSettingRowKindCopy,
};

typedef NS_ENUM(NSInteger, WCAtlasSettingAction) {
    WCAtlasSettingActionNone,
    WCAtlasSettingActionOpenMessages,
    WCAtlasSettingActionOpenMoments,
    WCAtlasSettingActionOpenInterfaceDisabled,
    WCAtlasSettingActionOpenEnhancements,
    WCAtlasSettingActionOpenInterface,
    WCAtlasSettingActionOpenPlugin,
    WCAtlasSettingActionConfigManager,
    WCAtlasSettingActionOfficialTelegram,
    WCAtlasSettingActionFindFriend,
    WCAtlasSettingActionOpenChatByID,
    WCAtlasSettingActionFriendRelationCheck,
    WCAtlasSettingActionReleaseNotes,
    WCAtlasSettingActionLogRecords,
    WCAtlasSettingActionBlockUsers,
    WCAtlasSettingActionBlockKeywords,
    WCAtlasSettingActionLongPressMenus,
    WCAtlasSettingActionMeMenu,
    WCAtlasSettingActionRevokePromptStyle,
    WCAtlasSettingActionRevokeAppearance,
    WCAtlasSettingActionRevokeRecords,
    WCAtlasSettingActionRevokeFilter,
    WCAtlasSettingActionRevokeLocalTemplate,
    WCAtlasSettingActionRevokeReplyTemplate,
    WCAtlasSettingActionGlobalScale,
    WCAtlasSettingActionSettingsScale,
    WCAtlasSettingActionInnerRadius,
    WCAtlasSettingActionOuterRadius,
    WCAtlasSettingActionMomentsDateFormat,
    WCAtlasSettingActionMomentsTailPicker,
    WCAtlasSettingActionMessageTimeFormat,
    WCAtlasSettingActionMessageTimeFontSize,
    WCAtlasSettingActionMessageTimeMode,
    WCAtlasSettingActionMessageTimeColor,
    WCAtlasSettingActionMessageTimePosition,
    WCAtlasSettingActionMessageTimeAvatarSpacing,
    WCAtlasSettingActionPluginManager,
    WCAtlasSettingActionHapticIntensity,
    WCAtlasSettingActionStepMode,
    WCAtlasSettingActionFixedSteps,
    WCAtlasSettingActionRandomStepRange,
    WCAtlasSettingActionRegenerateRandomSteps,
    WCAtlasSettingActionWalletBalance,
    WCAtlasSettingActionContactsCount,
    WCAtlasSettingActionRedEnvelopeFontSize,
    WCAtlasSettingActionChatTopAvatarSize,
    WCAtlasSettingActionChatTopNicknameSize,
    WCAtlasSettingActionChatGlassStyle,
    WCAtlasSettingActionChatGlassBlurIntensity,
    WCAtlasSettingActionMessageGestureAction,
    WCAtlasSettingActionAvatarQuickMenuGesture,
    WCAtlasSettingActionReplySwipeTriggerDistance,
    WCAtlasSettingActionGlobalAvatarCornerPercent,
    WCAtlasSettingActionQuickReplyLibrary,
    WCAtlasSettingActionSendConfirmationConversations,
    WCAtlasSettingActionSendConfirmationPauseDuration,
    WCAtlasSettingActionMomentsReminderUsers,
    WCAtlasSettingActionMomentsReminderInterval,
    WCAtlasSettingActionMomentsReminderForwardTarget,
    WCAtlasSettingActionMomentsCommentAntiDeleteText,
    WCAtlasSettingActionMomentsCommentAntiDeleteFontSize,
    WCAtlasSettingActionInAppNotificationAppearance,
    WCAtlasSettingActionCallRecordings,
    WCAtlasSettingActionCallVoiceEffect,
    WCAtlasSettingActionAutomations,
    WCAtlasSettingActionKeywordReplies,
    WCAtlasSettingActionHomeCategories,
};

@interface WCAtlasSettingItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy, nullable) NSString *defaultsKey;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, assign) WCAtlasSettingRowKind kind;
@property (nonatomic, assign) WCAtlasSettingAction action;
@property (nonatomic, assign) BOOL hasChildren;
@property (nonatomic, assign) BOOL child;
+ (instancetype)itemWithIdentifier:(NSString *)identifier
                              title:(NSString *)title
                           subtitle:(nullable NSString *)subtitle
                             symbol:(NSString *)symbol
                               kind:(WCAtlasSettingRowKind)kind
                                key:(nullable NSString *)key
                              value:(nullable NSString *)value
                             action:(WCAtlasSettingAction)action;
@end

@interface WCAtlasSettingSection : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, copy) NSArray<WCAtlasSettingItem *> *items;
+ (instancetype)sectionWithIdentifier:(NSString *)identifier
                                  title:(nullable NSString *)title
                                 footer:(nullable NSString *)footer
                                  items:(NSArray<WCAtlasSettingItem *> *)items;
@end

NS_ASSUME_NONNULL_END
