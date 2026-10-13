#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>
#import <stdlib.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#include <limits.h>
#include <atomic>

extern "C" void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);

#import "Sources/WCAtlasSettingsViewController.h"
#import "Sources/WCAtlasSettingsCatalog.h"
#import "Sources/WCAtlasBackgroundKeeper.h"
#import "Sources/WCAtlasAutomation.h"
#import "Sources/WCAtlasMomentsReminder.h"
#import "Sources/WCAtlasMomentsInteractionReminder.h"
#import "Sources/WCAtlasMomentsPrewarmer.h"
#import "Sources/WCAtlasMomentsCommentAntiDelete.h"
#import "Sources/WCAtlasMomentsTail.h"
#import "Sources/WCAtlasAccount.h"
#import "Sources/WCAtlasAntiRevoke.h"
#import "Sources/WCAtlasChatExport.h"
#import "Sources/WCAtlasCompatibility.h"
#import "Sources/WCAtlasLogging.h"
#import "Sources/WCAtlasEnhancements.h"
#import "Sources/WCAtlasPluginManager.h"
#import "Sources/WCAtlasPrivateAPI.h"
#import "Sources/WCAtlasCallAudio.h"
#import "Sources/WCAtlasRuntimeFeatures.h"
#import "Sources/WCAtlasInterfaceTweaks.h"
#import "Sources/WCAtlasMessageTime.h"
#import "Sources/WCAtlasGlassCapsuleView.h"
#import "Sources/WCAtlasQuickReplyStore.h"
#import "Sources/WCAtlasQuickReplyViewController.h"
#import "Sources/WCAtlasSendConfirmation.h"
#import "Sources/WCAtlasMessageBlock.h"
#import "Sources/WCAtlasAvatarQuickPanel.h"
#import "Sources/WCAtlasContactInfoCard.h"
#import "Sources/WCAtlasFriendRelationChecker.h"
#import "Sources/WCAtlasInfoListViewController.h"
#import "Sources/WCAtlasSilkEncoder.h"
#import "Sources/WCAtlasInAppNotification.h"
#import "Sources/WCAtlasMentionHighlight.h"
#import "Sources/WCAtlasHomeCategories.h"
#import "Sources/WCAtlasChatTTS.h"

@interface WCActionSheet : NSObject
- (void)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))eventAction;
- (BOOL)isContainButtonTitle:(NSString *)title;
@end

@interface WCTimeLineViewController : UIViewController
- (void)showPhotoAlert:(id)context;
- (void)showImagePicker:(id)context;
@end

@interface WCCommentDetailViewControllerFB : UIViewController
@end

@interface WCActionSheetItem : NSObject
- (instancetype)initWithTitle:(NSString *)title;
- (void)setBEnable:(BOOL)enabled;
- (void)setBDestructiveButton:(BOOL)destructive;
- (void)setEventAction:(void (^)(void))eventAction;
@end

@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
- (instancetype)initWithTitle:(NSString *)title svgName:(NSString *)svgName target:(id)target action:(SEL)action;
- (instancetype)initWithTitle:(NSString *)title svgName:(NSString *)svgName action:(SEL)action;
@end

@interface SharePreConfirmSheetView : UIView
@end

@interface EditImageForwardAndEditLogicController : NSObject
@end

@interface MultiDeviceCardLoginContentView : UIView
- (void)onTapConfirmButton;
@end

@interface MMAuthorizeUserInfoViewController : UIViewController
@end

@interface WCTimeLineCellView : UIView
- (void)editBlackList;
- (void)initTimeLabel;
- (void)updateWithDataItem:(id)dataItem actionAreaVM:(id)actionAreaVM;
- (void)onAccessibilityLike;
- (id)operateBtnImage:(BOOL)spring isSpringStyle:(BOOL)springStyle;
- (void)wcatlas_handleMomentsDoubleTap;
- (void)wcatlas_handleMomentsForward:(id)sender;
- (void)wcatlas_handleMomentsSaveImages:(id)sender;
@end

@interface WCTimeLineOperateButtonView : UIButton
@end

@interface MMUILabel : UILabel
@end

@interface WCOperateFloatView : UIView
- (void)showWithItemData:(id)item tipPoint:(CGPoint)tipPoint;
- (void)hide;
- (void)wcatlas_handleMomentsForward:(id)sender;
- (void)wcatlas_handleMomentsSaveImages:(id)sender;
@end

@interface CommonMessageCellView : UIView
- (void)wcatlas_refreshAntiRevokeSidePrompt;
- (void)wcatlas_scheduleAntiRevokeSidePromptRefresh;
- (void)wcatlas_handleReplyPan:(UIPanGestureRecognizer *)recognizer;
- (void)wcatlas_handleMessageTapAction:(UITapGestureRecognizer *)recognizer;
- (void)handleTapReferMessage;
- (void)handleTapForReferMsg:(id)sender;
- (void)onReturnToOriginalMsg;
- (void)onHeadImageLongPressed:(id)sender;
@end

@interface RoomContentLogicController : NSObject
- (NSArray *)getDefaultTitleTailSubViews;
- (id)getMemeberCountLabel;
- (CGFloat)GetTitleLabelOffset;
@end

@interface BaseMsgContentViewController : UIViewController
- (id)GetContact;
- (void)returnToOriginalMsg:(id)message;
- (void)wcatlas_openChatSearch:(id)sender;
- (void)wcatlas_handleChatSearchEdgePan:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)wcatlas_toggleSendConfirmation:(UILongPressGestureRecognizer *)recognizer;
@end

@interface BaseMsgContentLogicController : NSObject
- (NSString *)getCurrentChatName;
- (void)SendTextMessage:(id)text;
- (void)SendTextMessage:(id)text replyingMessage:(id)replyingMessage isPasted:(BOOL)isPasted;
- (void)SendImageMessageByMMAsset:(id)asset;
@end

@interface WeixinContentLogicController : NSObject
- (NSString *)getCurrentChatName;
- (void)AddMsg:(id)message MsgWrap:(id)wrap;
@end

@interface VoIPBubbleMessageCellView : UIView
- (void)startVoiceVoip;
- (void)startVideoVoip;
@end

@interface ScanQRCodeLogicController : NSObject
- (void)onDetectCodesWithMarkDotInfoList:(id)list isCameraScan:(BOOL)isCameraScan;
- (BOOL)isInScanSceneAndUseCameraScan;
- (NSInteger)fromScene;
- (NSInteger)m_sourceType;
- (NSInteger)fromRawScene;
- (NSInteger)picFrom;
- (void)setIsFromAlbum:(BOOL)isFromAlbum;
@end

@interface WCRedEnvelopesRedEnvelopesDetailViewController : UIViewController
@end

@interface BaseMessageCellView : UIView
- (NSArray *)filteredMenuItems:(NSArray *)items;
@end

@interface VoiceMessageCellView : UIView
- (void)onVoiceTrans:(id)sender;
@end

@interface MoreViewController : UIViewController
- (void)addCardsIfNeededToSection:(id)section;
- (void)addEmoticonsIfNeededToSection:(id)section;
- (id)createFinderEntranceCellConfig:(CGRect)frame;
@end

@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)cell;
- (void)insertCell:(id)cell At:(NSUInteger)index;
@end

@interface WeixinContactInfoAssist : NSObject
- (void)wcatlas_copyRawContactID;
- (void)wcatlas_openInfoCard;
@end

@interface ChatRoomInfoViewController : UIViewController
- (void)wcatlas_copyRawContactID;
- (void)wcatlas_openInfoCard;
@end

@interface SocialInfomationViewController : UIViewController
- (void)setM_contact:(id)contact;
- (void)reloadTableView;
- (void)onCRGDataUpdated;
@end

@interface SessionSelectController : UIViewController
- (BOOL)onShouldFilterContact:(id)contact;
@end

@interface SessionSelectView : UIView
- (BOOL)filterContact:(id)contact;
- (BOOL)onFilterContactCandidate:(id)contact;
- (void)setRecentForwardContacts:(id)contacts;
@end

@interface ShortVideoToolbar : UIView
@end

@interface MMScreenShotViewController : UIViewController
- (void)show;
@end

@interface SystemMessageCellView : UIView
- (id)getRichTextView;
- (void)wcatlas_applyAntiRevokeTextColor;
@end

@interface MMGrowTextView : UIView
- (void)wcatlas_handleInputSwipeLeft:(UISwipeGestureRecognizer *)recognizer;
- (void)wcatlas_handleInputSwipeRight:(UISwipeGestureRecognizer *)recognizer;
@end

@interface MMInputToolView : UIView
- (void)wcatlas_handleQuickReplyPlusLongPress:(UILongPressGestureRecognizer *)recognizer;
- (void)wcatlas_handleChatTTSLongPress:(UILongPressGestureRecognizer *)recognizer;
- (id)onTapSendButton;
- (void)sendMsgWithText:(id)text;
- (id)text;
- (void)resetText;
@end

@interface AppFileMessageCellViewV2 : CommonMessageCellView
@end

@interface TextMessageCellView : CommonMessageCellView
@end

@interface MMHeadImageView : UIView
- (instancetype)initWithUsrName:(NSString *)userName
                     headImgUrl:(NSString *)headImageURL
                    bAutoUpdate:(BOOL)autoUpdate
                   bRoundCorner:(BOOL)roundCorner;
- (void)setTargetForDoubleClick:(id)target action:(SEL)action;
- (void)setConerSize:(unsigned int)cornerSize;
@end

@interface FakeHeadImageView : UIView
- (instancetype)initWithRoundCorner:(BOOL)roundCorner;
- (void)setConerSize:(unsigned int)cornerSize;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) NSUInteger m_uiMessageType;
@property (nonatomic, assign) NSUInteger m_uiGameType;
@property (nonatomic, assign) NSUInteger m_uiGameContent;
@property (nonatomic, copy) NSString *m_nsEmoticonMD5;
@property (nonatomic, copy) NSString *m_nsContent;
@property (nonatomic, copy) NSString *m_nsToUsr;
@end

@interface UploadVoiceWrap : NSObject
- (void)setM_uiVoiceForwardFlag:(unsigned int)forwardFlag;
@end

@interface UploadVoiceRequest : NSObject
- (void)setForwardFlag:(unsigned int)forwardFlag;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)target MsgWrap:(CMessageWrap *)wrap;
- (id)AddAppMsg:(NSString *)target MsgWrap:(CMessageWrap *)wrap DataPath:(NSString *)dataPath Scene:(NSUInteger)scene;
- (id)AddVideoMsg:(id)message ToUsr:(NSString *)target VideoInfo:(id)videoInfo;
- (void)AddEmoticonMsg:(NSString *)message MsgWrap:(CMessageWrap *)wrap;
- (void)onNewSyncNotAddDBMessage:(CMessageWrap *)wrap;
- (void)AsyncOnAddMsg:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap;
- (void)AsyncOnAddMsgForSession:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap;
- (void)AsyncOnAddMsgForSession:(NSString *)sessionUserName
                        MsgWrap:(CMessageWrap *)wrap
             NewMsgArriveNotify:(BOOL)notify;
- (void)HandleMsgList:(NSString *)sessionUserName MsgList:(NSArray *)messages;
@end

@interface MMNewSessionMgr : NSObject
- (id)GetSessionByUserName:(NSString *)userName;
- (void)fulFillSession:(id)session;
- (void)fulFillSession:(id)session loadDetails:(BOOL)loadDetails;
- (BOOL)isNeedSaveSessionInfo:(id)session;
- (void)OnAddMsg:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap;
- (void)OnMsgNotAddDBNotify:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap;
@end

@interface MainSessionMgr : NSObject
- (void)updateMainSessionList;
- (void)updateMainSessionListNotify:(BOOL)notify;
- (void)rebuildMainSessions;
@end

@interface MainFrameCellData : NSObject
- (instancetype)initWithSessionInfo:(id)sessionInfo;
- (void)makeTextForNameLabel;
- (void)makeTextForMessageLabel;
- (void)updateData:(id)data;
- (void)updateDataFieldForUI;
@end

@interface CContactMgr : NSObject
- (void)printContactImportantChangeData:(id)newContact oldContact:(id)oldContact;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
- (void)setM7StepCount:(unsigned int)value;
- (void)setHkStepCount:(unsigned int)value;
@end

@interface UploadDeviceStepReq : NSObject
- (unsigned int)stepCount;
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
- (void)setStepCount:(unsigned int)value;
- (void)setM7StepCount:(unsigned int)value;
- (void)setHkStepCount:(unsigned int)value;
@end

@interface WCDataItem : NSObject
- (BOOL)isAd;
- (BOOL)isVideoAd;
- (unsigned int)stepCount;
@end

@interface WAAppTaskSplashADConfig : NSObject
- (BOOL)canShowSplashADWindow;
- (BOOL)launchShow;
@end

static BOOL WCAtlasDidRegister = NO;
static NSTimeInterval WCAtlasVoiceRepeatForwardDeadline = 0;
static std::atomic_bool WCAtlasHighRefreshRateEnabled(false);
static std::atomic_bool WCAtlasHighRefreshRateApplicationActive(false);
static std::atomic_int WCAtlasHighRefreshRateScreenMaximum(60);
static char WCAtlasDeviceCardDidConfirmKey;
static char WCAtlasGameDidAuthorizeKey;
static char WCAtlasMomentsDoubleTapRecognizerKey;
static char WCAtlasMomentsForwardButtonKey;
static char WCAtlasMomentsSaveButtonKey;
static char WCAtlasMomentsOriginalOperateFrameKey;
static char WCAtlasMomentsFloatForwardButtonKey;
static char WCAtlasMomentsFloatSaveButtonKey;
static char WCAtlasMomentsFloatSeparatorKey;
static char WCAtlasMomentsFloatSaveSeparatorKey;
static char WCAtlasMomentsFloatDataItemKey;
static char WCAtlasMomentsFloatSnapshotKey;
static char WCAtlasMomentsForwardTaskKey;
static char WCAtlasMomentsSaveTaskKey;
static char WCAtlasMomentsDataItemSaveTaskKey;
static char WCAtlasMediaToVoiceInProgressKey;
static char WCAtlasMomentsHighQualityMenuKey;
static char WCAtlasImageJokerPickerDelegateKey;
static char WCAtlasEmoticonPreviewLongPressKey;
static char WCAtlasMomentsOriginalTimeTextKey;
static char WCAtlasMomentsOriginalTimeLinesKey;
static char WCAtlasMomentsPreciseTimeAppliedKey;
static id WCAtlasPendingMomentsPermissionDataItem;
static __weak id WCAtlasPendingMomentsCameraController;
static id WCAtlasActiveMomentsMediaSaveTask;
static char WCAtlasGameSelectorPresentedKey;
static char WCAtlasChatExportBuildingMenuKey;
static char WCAtlasAntiRevokeSideLabelKey;
static char WCAtlasAntiRevokeSideRefreshScheduledKey;
static char WCAtlasAntiRevokeSideRefreshGenerationKey;
static char WCAtlasAntiRevokeOriginalSystemTextColorKey;
static char WCAtlasAntiRevokeSystemColorAppliedKey;
static NSString *const WCAtlasAntiRevokeSideLabelIdentifier = @"com.qiu7c.wcatlas.anti-revoke.side-label";
static char WCAtlasEditedImageKey;
static char WCAtlasEditConversationUserNameKey;
static char WCAtlasEditPresenterControllerKey;
static char WCAtlasQuickSendPendingImageKey;
static char WCAtlasInputSwipeLeftRecognizerKey;
static char WCAtlasInputSwipeRightRecognizerKey;
static char WCAtlasQuickReplyPlusRecognizerKey;
static char WCAtlasQuickReplyPlusDelegateKey;
static char WCAtlasChatTTSRecognizerKey;
static char WCAtlasChatTTSButtonKey;
static char WCAtlasAutoCombineSendAppliedKey;
static char WCAtlasWalletGestureRecognizerKey;
static char WCAtlasReplyPanRecognizerKey;
static char WCAtlasReplyPanDelegateKey;
static char WCAtlasMessageDoubleTapRecognizerKey;
static char WCAtlasMessageTripleTapRecognizerKey;
static char WCAtlasAvatarQuickHeadViewKey;
static char WCAtlasAvatarQuickDoubleTapRecognizerKey;
static char WCAtlasAvatarQuickGestureProxyKey;
static char WCAtlasAvatarNativeDoubleTapTargetKey;
static char WCAtlasAvatarNativeDoubleTapActionKey;
static char WCAtlasAvatarNativeDoubleTapOwnedKey;
static char WCAtlasOfficialInfoCardBoxKey;
static char WCAtlasOfficialInfoBaseRowsKey;
static char WCAtlasInfoCardOfficialControllerKey;
static char WCAtlasOfficialRelatedGroupLogicKey;
static char WCAtlasExclusiveRedEnvelopeContactKey;
static char WCAtlasExclusiveRedEnvelopeViewContactKey;
static char WCAtlasExclusiveRedEnvelopeViewDataKey;
static BOOL WCAtlasUpdatingAvatarNativeDoubleTap = NO;
static BOOL WCAtlasPerformingNativeAvatarLongPress = NO;
static id WCAtlasPendingExclusiveRedEnvelopeContact;
static NSString *WCAtlasPendingExclusiveRedEnvelopeGroupID;
static CFTimeInterval WCAtlasPendingExclusiveRedEnvelopeDeadline;
static NSUInteger WCAtlasPendingExclusiveRedEnvelopeGeneration;
static char WCAtlasReplyOriginalTransformKey;
static char WCAtlasReplyTransformSnapshotsKey;
static char WCAtlasReplyFeedbackGeneratorKey;
static char WCAtlasReplyFeedbackTriggeredKey;
static char WCAtlasReplyPanRightwardKey;
static char WCAtlasSeparatorOriginalHiddenKey;
static char WCAtlasVoiceTranscriptionScheduledKey;
static char WCAtlasVoiceTranscriptionDoneKey;
static char WCAtlasVoiceTranscriptionInProgressKey;
static char WCAtlasVoiceTranscriptionAttemptedKey;
static char WCAtlasChatTopProfileItemKey;
static char WCAtlasChatTopCapsuleItemKey;
static char WCAtlasChatSearchItemKey;
static char WCAtlasChatSearchActiveKey;
static char WCAtlasChatSearchCleanupKey;
static char WCAtlasChatSearchEdgePanKey;
static char WCAtlasChatTopOriginalLeftItemsKey;
static char WCAtlasChatTopOriginalRightItemsKey;
static char WCAtlasChatTopOriginalTitleViewKey;
static char WCAtlasChatTopOriginalSupplementKey;
static char WCAtlasChatTopMoreProxyKey;
static char WCAtlasChatTopBackProxyKey;
static char WCAtlasChatTopOriginalStandardAppearanceKey;
static char WCAtlasChatTopOriginalCompactAppearanceKey;
static char WCAtlasChatTopOriginalScrollEdgeAppearanceKey;
static char WCAtlasChatTopOriginalCompactScrollEdgeAppearanceKey;
static char WCAtlasChatTopBackgroundOriginalAlphaKey;
static char WCAtlasChatTopPlaceholderTitleViewKey;
static char WCAtlasChatTopOriginalNavigationStandardAppearanceKey;
static char WCAtlasChatTopOriginalNavigationCompactAppearanceKey;
static char WCAtlasChatTopOriginalNavigationScrollEdgeAppearanceKey;
static char WCAtlasChatTopOriginalNavigationCompactScrollEdgeAppearanceKey;
static char WCAtlasChatTopOriginalNavigationTranslucentKey;
static char WCAtlasChatTopOriginalEdgesForExtendedLayoutKey;
static char WCAtlasChatTopOriginalExtendedLayoutIncludesOpaqueBarsKey;
static char WCAtlasChatTopContainerOriginalBackgroundColorKey;
static char WCAtlasChatTopBackgroundOriginalHiddenKey;
static char WCAtlasChatTopGlassEffectMarkerKey;
static char WCAtlasChatTopTypingActiveKey;
static char WCAtlasChatTopStableDisplayNameKey;
static char WCAtlasChatTypingStatusLabelMarkerKey;
static char WCAtlasChatTopOriginalClipsToBoundsKey;
static char WCAtlasChatTopOriginalBorderWidthKey;
static char WCAtlasChatTopOriginalCornerRadiusKey;
static char WCAtlasChatTopContentNavigationBarKey;
static char WCAtlasChatTopOriginalVisualEffectKey;
static char WCAtlasChatTopOriginalVisualEffectMaskKey;
static char WCAtlasChatTopOriginalBackgroundMaskKey;
static char WCAtlasChatTopFadeBackgroundMaskKey;
static char WCAtlasChatSearchTransitionKey;
static char WCAtlasChatPinnedBlurViewKey;
static char WCAtlasChatPinnedOriginalBackgroundColorKey;
static char WCAtlasChatPinnedOriginalShadowOpacityKey;
static char WCAtlasChatPinnedOriginalShadowRadiusKey;
static char WCAtlasChatPinnedOriginalShadowOffsetKey;
static char WCAtlasChatPinnedOriginalShadowColorKey;
static char WCAtlasChatPinnedOriginalBorderWidthKey;
static char WCAtlasChatPinnedOriginalBorderColorKey;
static char WCAtlasRedEnvelopeOriginalAttributedTextKey;
static char WCAtlasCallVoiceConfirmedKey;
static char WCAtlasCallVideoConfirmedKey;
static char WCAtlasSendConfirmationNativeBypassKey;
static NSString *WCAtlasSendConfirmationImageBypassUsername;
static CFTimeInterval WCAtlasSendConfirmationImageBypassDeadline;
static NSString *WCAtlasSendConfirmationVideoBypassUsername;
static CFTimeInterval WCAtlasSendConfirmationVideoBypassDeadline;
static NSString *WCAtlasSendConfirmationRepeatBypassUsername;
static CFTimeInterval WCAtlasSendConfirmationRepeatBypassDeadline;
static NSInteger WCAtlasSendConfirmationRepeatBypassMessageType;
static __weak BaseMsgContentViewController *WCAtlasVisibleChatController;
static __weak BaseMsgContentViewController *WCAtlasSendConfirmationChatController;
static __weak id WCAtlasCurrentEditImageLogicController;
static __weak UIViewController *WCAtlasActiveMomentsDetailController;
static BOOL WCAtlasMomentsDispatchingQuickComment = NO;

static void WCAtlasUpdateChatTopBar(BaseMsgContentViewController *controller);
static void WCAtlasRefreshChatTopBarAfterWechatUpdate(BaseMsgContentViewController *controller);
static void WCAtlasUpdatePinnedMessageGlass(UIView *tipsView);
static BaseMsgContentViewController *WCAtlasResolveVisibleChatController(void);
static void WCAtlasPresentQuickReplyLibrary(BaseMsgContentViewController *controller);
static NSString *WCAtlasChatUserName(id controller);
static void WCAtlasShowTransientMessage(NSString *message, BOOL success);
static void WCAtlasShowChatTTSHint(UIView *inputToolView, NSString *message, BOOL success);
static BOOL WCAtlasMethodReturnsVoid(Method method);
static BOOL WCAtlasMethodReturnsObject(Method method);
static BOOL WCAtlasMethodReturnsInteger(Method method);
static BOOL WCAtlasMethodArgumentIsObject(Method method, unsigned int index);
static BOOL WCAtlasMethodArgumentIsIntegerScalar(Method method, unsigned int index);
static BOOL WCAtlasMethodArgumentIsSelector(Method method, unsigned int index);
static BOOL WCAtlasMomentCanSaveMedia(id dataItem);
static void WCAtlasSaveMomentMedia(id dataItem, UIViewController *presenter);
@class WCAtlasReplyTransformSnapshot;
static NSArray<WCAtlasReplyTransformSnapshot *> *WCAtlasReplyTransformSnapshots(CommonMessageCellView *sourceCell);
static void WCAtlasApplyReplyTransform(NSArray<WCAtlasReplyTransformSnapshot *> *snapshots, CGFloat offset);
static void WCAtlasRestoreReplyTransforms(NSArray<WCAtlasReplyTransformSnapshot *> *snapshots);

@interface WCAtlasBarButtonActionProxy : NSObject
@property (nonatomic, strong) UIBarButtonItem *originalItem;
@property (nonatomic, weak) UIViewController *fallbackController;
@property (nonatomic, assign) BOOL popsNavigationController;
- (void)invoke:(id)sender;
@end

static id WCAtlasTweakSafeValue(id object, NSString *key);
static void WCAtlasTweakSetValue(id object, NSString *key, id value);
static id WCAtlasTweakValueForSelectorNames(id object, NSArray<NSString *> *selectorNames);
static id WCAtlasMessageManager(void);
static id WCAtlasMessageWrapForCell(id cell);
static id WCAtlasMessageForCellViewModel(id viewModel);
static id WCAtlasImageJokerMessageForObject(id object);
static id WCAtlasContactForUserName(NSString *userName);
static void WCAtlasOpenHomeRemark(id owner, id contact, BOOL group);
static void WCAtlasOpenHomeMoments(id owner, id contact);
static void WCAtlasSynchronizeAvatarQuickGesture(CommonMessageCellView *cell);
static BOOL WCAtlasPresentAvatarQuickMenu(CommonMessageCellView *cell, UIView *headView);
static NSInteger WCAtlasGroupMemberRemovalScene(id groupContact,
                                               id memberContact,
                                               NSString *memberUserName);
static void WCAtlasConfirmRemoveGroupMember(UIViewController *presenter,
                                          id groupContact,
                                          id memberContact,
                                          NSString *memberUserName,
                                          NSInteger scene);
static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasProfileInfoRows(id contact, BOOL group);
static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasGroupMemberInfoRows(id contact,
                                                                                   id groupContact,
                                                                                   NSString *userName);
static void WCAtlasAddInfoCardRow(NSMutableArray<NSDictionary<NSString *, NSString *> *> *rows,
                                NSString *title,
                                id value);
static UIViewController *WCAtlasCreateOfficialSocialInformation(id contact);
static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasOfficialSocialInformationRows(id controller);
static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasMergeInfoCardRows(NSArray *baseRows,
                                                                                NSArray *officialRows);
static void WCAtlasRefreshInfoCardFromOfficialController(id officialController);
static void WCAtlasConfigureInfoCardSwitches(WCAtlasContactInfoCardViewController *card,
                                           NSString *username,
                                           BOOL group);
static void WCAtlasConfigureInfoCardDetailActions(WCAtlasContactInfoCardViewController *card,
                                                id contact,
                                                id groupContact,
                                                NSString *username,
                                                id officialController);
static UIViewController *WCAtlasSendConfirmationPresenterForTarget(NSString *target);
static BOOL WCAtlasSendConfirmationValidateTarget(NSString *target);
static BOOL WCAtlasSendConfirmationMessageIsAppEmoticon(id wrap);

static void WCAtlasArmRepeatSendConfirmationBypass(NSString *target, NSInteger messageType) {
    WCAtlasSendConfirmationRepeatBypassUsername = [target copy];
    WCAtlasSendConfirmationRepeatBypassMessageType = messageType;
    WCAtlasSendConfirmationRepeatBypassDeadline = CACurrentMediaTime() + 3.0;
}

static void WCAtlasClearRepeatSendConfirmationBypass(void) {
    WCAtlasSendConfirmationRepeatBypassUsername = nil;
    WCAtlasSendConfirmationRepeatBypassDeadline = 0.0;
    WCAtlasSendConfirmationRepeatBypassMessageType = 0;
}

static BOOL WCAtlasConsumeRepeatSendConfirmationBypass(NSString *target,
                                                       NSInteger messageType,
                                                       BOOL keepForImageSecondStage) {
    CFTimeInterval now = CACurrentMediaTime();
    if (now > WCAtlasSendConfirmationRepeatBypassDeadline) {
        WCAtlasClearRepeatSendConfirmationBypass();
        return NO;
    }
    BOOL videoTypeMatches = (messageType == 43 || messageType == 62) &&
                            (WCAtlasSendConfirmationRepeatBypassMessageType == 43 ||
                             WCAtlasSendConfirmationRepeatBypassMessageType == 62);
    BOOL matches = target.length > 0 &&
                   [WCAtlasSendConfirmationRepeatBypassUsername isEqualToString:target] &&
                   (WCAtlasSendConfirmationRepeatBypassMessageType == messageType || videoTypeMatches);
    if (matches && !keepForImageSecondStage) {
        WCAtlasClearRepeatSendConfirmationBypass();
    }
    return matches;
}

static BOOL WCAtlasMessageCellIsSender(CommonMessageCellView *cell) {
    if (!cell) return NO;
    id viewModel = WCAtlasTweakSafeValue(cell, @"viewModel") ?: WCAtlasTweakSafeValue(cell, @"m_viewModel");
    id senderValue = WCAtlasTweakSafeValue(viewModel, @"isSender");
    if ([senderValue respondsToSelector:@selector(boolValue)] && [senderValue boolValue]) return YES;
    id message = WCAtlasMessageWrapForCell(cell);
    senderValue = WCAtlasTweakSafeValue(message, @"isSender");
    if ([senderValue respondsToSelector:@selector(boolValue)] && [senderValue boolValue]) return YES;
    NSString *fromUser = WCAtlasTweakSafeValue(message, @"m_nsFromUsr");
    NSString *currentUser = WCAtlasCurrentUserWXID();
    return fromUser.length > 0 && currentUser.length > 0 && [fromUser isEqualToString:currentUser];
}

static WCAtlasReplySwipeAction WCAtlasMessageGestureAction(CommonMessageCellView *cell,
                                                        NSString *selfKey,
                                                        NSString *otherKey) {
    BOOL selfMessage = WCAtlasMessageCellIsSender(cell);
    NSInteger action = [[NSUserDefaults standardUserDefaults] integerForKey:selfMessage ? selfKey : otherKey];
    if (action < WCAtlasReplySwipeActionNone || action > WCAtlasReplySwipeActionRepeat) return WCAtlasReplySwipeActionNone;
    if (!selfMessage && action == WCAtlasReplySwipeActionRevoke) return WCAtlasReplySwipeActionNone;
    return (WCAtlasReplySwipeAction)action;
}

static WCAtlasReplySwipeAction WCAtlasMessageSwipeAction(CommonMessageCellView *cell, BOOL rightward) {
    return WCAtlasMessageGestureAction(cell,
                                     rightward ? WCAtlasReplySwipeRightSelfActionKey : WCAtlasReplySwipeSelfActionKey,
                                     rightward ? WCAtlasReplySwipeRightOtherActionKey : WCAtlasReplySwipeOtherActionKey);
}

static CGFloat WCAtlasReplySwipeTriggerDistance(void) {
    CGFloat value = [[NSUserDefaults standardUserDefaults] doubleForKey:WCAtlasReplySwipeTriggerDistanceKey];
    if (value <= 0.0) value = 56.0;
    return MIN(100.0, MAX(36.0, value));
}

static UIControl *WCAtlasFirstControlInView(UIView *view) {
    if (!view) return nil;
    id button = WCAtlasTweakSafeValue(view, @"m_btn");
    if ([button isKindOfClass:[UIControl class]]) return button;
    for (UIView *subview in view.subviews) {
        UIControl *control = WCAtlasFirstControlInView(subview);
        if (control) return control;
    }
    return [view isKindOfClass:[UIControl class]] ? (UIControl *)view : nil;
}

@implementation WCAtlasBarButtonActionProxy

- (void)invoke:(id)sender {
    UIBarButtonItem *item = self.originalItem;
    if (!item) {
        if (self.popsNavigationController) {
            [self.fallbackController.navigationController popViewControllerAnimated:YES];
        }
        return;
    }
    UIControl *control = WCAtlasFirstControlInView(item.customView);
    if (control) {
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        return;
    }
    if (item.action &&
        [UIApplication.sharedApplication sendAction:item.action to:item.target from:item forEvent:nil]) {
        return;
    }
    if (self.popsNavigationController) {
        [self.fallbackController.navigationController popViewControllerAnimated:YES];
    }
    (void)sender;
}

@end

@interface WCAtlasMomentsFloatMenuSnapshot : NSObject
@property (nonatomic, assign) CGRect baseFrame;
@property (nonatomic, assign) CGFloat addedWidth;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, assign) CGRect baseContainerFrame;
@property (nonatomic, assign) BOOL containerIsDirectChild;
@property (nonatomic, copy) NSArray<UIView *> *baseViews;
@property (nonatomic, copy) NSArray<NSValue *> *baseFrames;
@property (nonatomic, strong) CALayer *originalLayerMask;
@property (nonatomic, strong) CAShapeLayer *expandedLayerMask;
@property (nonatomic, assign) CGRect forwardFrame;
@property (nonatomic, assign) CGRect saveFrame;
@property (nonatomic, assign) CGRect separatorFrame;
@property (nonatomic, assign) CGRect saveSeparatorFrame;
@property (nonatomic, assign) BOOL applying;
@end

@implementation WCAtlasMomentsFloatMenuSnapshot
@end

static UIViewController *WCAtlasViewControllerForResponder(id responderObject) {
    UIResponder *responder = [responderObject isKindOfClass:[UIResponder class]] ? (UIResponder *)responderObject : nil;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
        responder = responder.nextResponder;
    }
    return nil;
}

static BOOL WCAtlasMomentsIsNativeDetailContext(id responderObject) {
    Class detailClass = NSClassFromString(@"WCCommentDetailViewControllerFB");
    if (!detailClass) return NO;
    UIViewController *controller = WCAtlasViewControllerForResponder(responderObject);
    UIViewController *activeDetail = WCAtlasActiveMomentsDetailController;
    if ([activeDetail isKindOfClass:detailClass] && !controller) return YES;
    for (UIViewController *current = controller; current; current = current.parentViewController) {
        if ([current isKindOfClass:detailClass] || current == activeDetail) return YES;
    }
    return [controller.navigationController.topViewController isKindOfClass:detailClass];
}

static NSArray<UIGestureRecognizer *> *WCAtlasNavigationReturnGesturesForView(UIView *view) {
    UIViewController *controller = WCAtlasViewControllerForResponder(view);
    UINavigationController *navigationController = controller.navigationController;
    if (!navigationController || navigationController.viewControllers.count <= 1) return @[];

    NSMutableArray<UIGestureRecognizer *> *gestures = [NSMutableArray array];
    UIGestureRecognizer *interactivePop = navigationController.interactivePopGestureRecognizer;
    if (interactivePop && interactivePop.enabled) [gestures addObject:interactivePop];

    // WCPulse and some WeChat navigation containers expose an additional
    // full-screen return recognizer. Resolve it dynamically so message gestures
    // keep yielding even when the navigation view recreates that recognizer.
    for (id owner in @[navigationController, navigationController.view]) {
        for (NSString *selectorName in @[@"screenDismissPanGestureRecognizer", @"dismissPanGestureRecognizer"]) {
            SEL selector = NSSelectorFromString(selectorName);
            if (![owner respondsToSelector:selector]) continue;
            id candidate = ((id (*)(id, SEL))objc_msgSend)(owner, selector);
            if (![candidate isKindOfClass:[UIGestureRecognizer class]] ||
                ![(UIGestureRecognizer *)candidate isEnabled] ||
                [gestures containsObject:candidate]) continue;
            [gestures addObject:candidate];
        }
    }
    return gestures;
}

static BOOL WCAtlasIsNavigationReturnGesture(UIGestureRecognizer *candidate, UIView *view) {
    if (!candidate) return NO;
    return [WCAtlasNavigationReturnGesturesForView(view) containsObject:candidate];
}

@interface WCAtlasReplyPanGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *cell;
@property (nonatomic, assign) CGFloat initialWindowX;
@end

@interface WCAtlasAvatarQuickGestureProxy : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) CommonMessageCellView *cell;
@property (nonatomic, weak) UIView *headView;
- (void)handleGesture:(UIGestureRecognizer *)recognizer;
@end

@interface WCAtlasWeakObjectBox : NSObject
@property (nonatomic, weak) id object;
@end

@interface WCAtlasReplyTransformSnapshot : NSObject
@property (nonatomic, strong) UIView *view;
@property (nonatomic, assign) CGAffineTransform transform;
@end

@implementation WCAtlasReplyTransformSnapshot
@end

@implementation WCAtlasAvatarQuickGestureProxy

- (void)handleGesture:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:UILongPressGestureRecognizer.class] &&
        recognizer.state != UIGestureRecognizerStateBegan) return;
    if ([recognizer isKindOfClass:UITapGestureRecognizer.class] &&
        recognizer.state != UIGestureRecognizerStateRecognized) return;
    CommonMessageCellView *cell = self.cell;
    UIView *headView = self.headView;
    if (!cell.window || !headView.window) return;
    (void)WCAtlasPresentAvatarQuickMenu(cell, headView);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    (void)gestureRecognizer;
    return self.cell.window && self.headView.window &&
           WCAtlasEnhancementEnabled(WCAtlasAvatarQuickMenuGestureKey);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

@end

@implementation WCAtlasWeakObjectBox
@end

@interface WCAtlasQuickReplyPlusGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) MMInputToolView *toolView;
@end

@implementation WCAtlasQuickReplyPlusGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    MMInputToolView *toolView = self.toolView;
    if (!toolView) return NO;
    BOOL quickReplyEnabled = WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey);
    if (!quickReplyEnabled) return NO;
    UIView *candidate = [toolView hitTest:[gestureRecognizer locationInView:toolView] withEvent:nil];
    UIView *sendButton = WCAtlasTweakValueForSelectorNames(toolView, @[@"sendButton", @"_sendButton"]);
    UIView *attachmentButton = WCAtlasTweakValueForSelectorNames(toolView, @[@"attachmentButton", @"_attachmentButton"]);
    while (candidate && candidate != toolView) {
        if (candidate == sendButton) return NO;
        if (candidate == attachmentButton) return quickReplyEnabled;
        if ([candidate isKindOfClass:UIControl.class]) {
            NSMutableString *semanticText = [NSMutableString string];
            for (NSString *value in @[candidate.accessibilityLabel ?: @"",
                                      candidate.accessibilityIdentifier ?: @"",
                                      [candidate isKindOfClass:UIButton.class] ? [(UIButton *)candidate currentTitle] ?: @"" : @""]) {
                if (value.length > 0) [semanticText appendFormat:@" %@", value.lowercaseString];
            }
            if ([semanticText containsString:@"发送"] || [semanticText containsString:@"send"]) {
                return NO;
            }
            if ([semanticText containsString:@"更多"] || [semanticText containsString:@"添加"] ||
                [semanticText containsString:@"加号"] || [semanticText containsString:@"more"] ||
                [semanticText containsString:@"plus"] || [semanticText containsString:@"add"]) {
                return quickReplyEnabled;
            }
        }
        candidate = candidate.superview;
    }
    return NO;
}

@end



@implementation WCAtlasReplyPanGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if (!WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey) ||
        !self.cell.window ||
        ![recognizer isKindOfClass:[UIPanGestureRecognizer class]]) return NO;
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)recognizer;
    CGPoint velocity = [pan velocityInView:self.cell];
    if (fabs(velocity.x) <= fabs(velocity.y)) return NO;
    if (WCAtlasMessageSwipeAction((CommonMessageCellView *)self.cell, velocity.x > 0.0) == WCAtlasReplySwipeActionNone) return NO;
    if (velocity.x > 0.0 && WCAtlasNavigationReturnGesturesForView(self.cell).count > 0) {
        CGFloat edgeWidth = MAX(50.0, self.cell.window.safeAreaInsets.left + 32.0);
        if (self.initialWindowX <= edgeWidth) return NO;
    }
    CGPoint location = [pan locationInView:self.cell];
    CGFloat width = CGRectGetWidth(self.cell.bounds);
    return location.x >= 24.0 && location.x <= MAX(24.0, width - 24.0);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    UIWindow *window = self.cell.window;
    self.initialWindowX = window ? [touch locationInView:window].x : CGFLOAT_MAX;
    if (!window || WCAtlasNavigationReturnGesturesForView(self.cell).count == 0) return YES;
    CGFloat edgeWidth = MAX(50.0, window.safeAreaInsets.left + 32.0);
    // The decision is based on the original touch, not the later point at which
    // UIKit asks shouldBegin. This prevents an edge-back drag from entering a
    // message cell and subsequently firing its configured right-swipe action.
    return self.initialWindowX > edgeWidth;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    return WCAtlasIsNavigationReturnGesture(otherGestureRecognizer, self.cell);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

@end

static void WCAtlasSynchronizeReplyGesture(CommonMessageCellView *cell) {
    if (!cell) return;
    UIPanGestureRecognizer *panRecognizer = objc_getAssociatedObject(cell, &WCAtlasReplyPanRecognizerKey);
    UITapGestureRecognizer *doubleRecognizer = objc_getAssociatedObject(cell, &WCAtlasMessageDoubleTapRecognizerKey);
    UITapGestureRecognizer *tripleRecognizer = objc_getAssociatedObject(cell, &WCAtlasMessageTripleTapRecognizerKey);
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey) && cell.window;
    WCAtlasReplySwipeAction leftSwipeAction = enabled ? WCAtlasMessageSwipeAction(cell, NO) : WCAtlasReplySwipeActionNone;
    WCAtlasReplySwipeAction rightSwipeAction = enabled ? WCAtlasMessageSwipeAction(cell, YES) : WCAtlasReplySwipeActionNone;
    BOOL hasSwipeAction = leftSwipeAction != WCAtlasReplySwipeActionNone || rightSwipeAction != WCAtlasReplySwipeActionNone;
    WCAtlasReplySwipeAction doubleAction = enabled
        ? WCAtlasMessageGestureAction(cell, WCAtlasMessageDoubleTapSelfActionKey, WCAtlasMessageDoubleTapOtherActionKey)
        : WCAtlasReplySwipeActionNone;
    WCAtlasReplySwipeAction tripleAction = enabled
        ? WCAtlasMessageGestureAction(cell, WCAtlasMessageTripleTapSelfActionKey, WCAtlasMessageTripleTapOtherActionKey)
        : WCAtlasReplySwipeActionNone;

    if (!hasSwipeAction) {
        if (panRecognizer) {
            NSArray *snapshots = objc_getAssociatedObject(cell, &WCAtlasReplyTransformSnapshotsKey);
            if (snapshots.count) WCAtlasRestoreReplyTransforms(snapshots);
            else {
                NSValue *originalTransform = objc_getAssociatedObject(cell, &WCAtlasReplyOriginalTransformKey);
                if (originalTransform) cell.transform = originalTransform.CGAffineTransformValue;
            }
            [cell removeGestureRecognizer:panRecognizer];
        }
        objc_setAssociatedObject(cell, &WCAtlasReplyPanRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyPanDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyOriginalTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyTransformSnapshotsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyFeedbackGeneratorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyFeedbackTriggeredKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyPanRightwardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        panRecognizer = nil;
    }
    if (!panRecognizer && hasSwipeAction) {
        WCAtlasReplyPanGestureDelegate *delegate = [WCAtlasReplyPanGestureDelegate new];
        delegate.cell = cell;
        panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:cell action:@selector(wcatlas_handleReplyPan:)];
        panRecognizer.delegate = delegate;
        panRecognizer.maximumNumberOfTouches = 1;
        panRecognizer.cancelsTouchesInView = YES;
        panRecognizer.delaysTouchesBegan = NO;
        panRecognizer.delaysTouchesEnded = NO;
        [cell addGestureRecognizer:panRecognizer];
        for (UIGestureRecognizer *returnGesture in WCAtlasNavigationReturnGesturesForView(cell)) {
            if (returnGesture != panRecognizer) [panRecognizer requireGestureRecognizerToFail:returnGesture];
        }
        objc_setAssociatedObject(cell, &WCAtlasReplyPanRecognizerKey, panRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasReplyPanDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (doubleAction == WCAtlasReplySwipeActionNone && doubleRecognizer) {
        [cell removeGestureRecognizer:doubleRecognizer];
        objc_setAssociatedObject(cell, &WCAtlasMessageDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        doubleRecognizer = nil;
    }
    if (tripleAction == WCAtlasReplySwipeActionNone && tripleRecognizer) {
        [cell removeGestureRecognizer:tripleRecognizer];
        objc_setAssociatedObject(cell, &WCAtlasMessageTripleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tripleRecognizer = nil;
        // Recreate double tap so it no longer retains a failure dependency on the removed triple tap.
        if (doubleRecognizer) {
            [cell removeGestureRecognizer:doubleRecognizer];
            objc_setAssociatedObject(cell, &WCAtlasMessageDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            doubleRecognizer = nil;
        }
    }
    if (!doubleRecognizer && doubleAction != WCAtlasReplySwipeActionNone) {
        doubleRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wcatlas_handleMessageTapAction:)];
        doubleRecognizer.numberOfTapsRequired = 2;
        doubleRecognizer.numberOfTouchesRequired = 1;
        doubleRecognizer.cancelsTouchesInView = YES;
        [cell addGestureRecognizer:doubleRecognizer];
        objc_setAssociatedObject(cell, &WCAtlasMessageDoubleTapRecognizerKey, doubleRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!tripleRecognizer && tripleAction != WCAtlasReplySwipeActionNone) {
        tripleRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wcatlas_handleMessageTapAction:)];
        tripleRecognizer.numberOfTapsRequired = 3;
        tripleRecognizer.numberOfTouchesRequired = 1;
        tripleRecognizer.cancelsTouchesInView = YES;
        [cell addGestureRecognizer:tripleRecognizer];
        objc_setAssociatedObject(cell, &WCAtlasMessageTripleTapRecognizerKey, tripleRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (doubleRecognizer && tripleRecognizer) [doubleRecognizer requireGestureRecognizerToFail:tripleRecognizer];
}

static NSMutableSet *WCAtlasActiveQuickSendSessions(void) {
    static NSMutableSet *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

static id WCAtlasTweakSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL WCAtlasUsesAntiRevokeSidePrompt(void) {
    return WCAtlasEnhancementEnabled(WCAtlasAntiRevokeKey) &&
           [[NSUserDefaults standardUserDefaults] integerForKey:WCAtlasAntiRevokePromptStyleKey] == 1;
}

static void WCAtlasTweakSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {
    }
}

static BOOL WCAtlasInvokeFirstMessageCellAction(CommonMessageCellView *cell, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![cell respondsToSelector:selector]) continue;
        ((void (*)(id, SEL, id))objc_msgSend)(cell, selector, nil);
        return YES;
    }
    return NO;
}

@interface WCAtlasMessageRepeatSession : NSObject
@property (nonatomic, strong) id forwardLogic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, assign) BOOL finished;
- (void)finishSession;
@end

@implementation WCAtlasMessageRepeatSession

- (void)finishSession {
    if (self.finished) return;
    self.finished = YES;
    [WCAtlasActiveQuickSendSessions() removeObject:self];
    self.forwardLogic = nil;
    self.message = nil;
    self.contact = nil;
    self.presenter = nil;
}

- (UIViewController *)getCurrentViewController { return self.presenter; }
- (UIViewController *)GetCurrentViewController { return self.presenter; }
- (void)OnForwardMessageSend:(__unused id)logic { [self finishSession]; }
- (void)OnForwardMessageCancel:(__unused id)logic { [self finishSession]; }
- (void)OnForwardMessageConfirmCanceled:(id)logic { [self OnForwardMessageCancel:logic]; }
- (void)OnForwardDone { [self finishSession]; }

@end

static id WCAtlasMessageManager(void) {
    Class managerClass = objc_getClass("CMessageMgr");
    return WCAtlasServiceForClass(managerClass);
}

static NSString *WCAtlasSessionForMessage(id message) {
    SEL selector = NSSelectorFromString(@"GetChatName");
    if ([message respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(message, selector);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    }
    NSString *fromUser = WCAtlasTweakSafeValue(message, @"m_nsFromUsr");
    NSString *toUser = WCAtlasTweakSafeValue(message, @"m_nsToUsr");
    NSString *currentUser = WCAtlasCurrentUserWXID();
    if ([fromUser hasSuffix:@"@chatroom"]) return fromUser;
    if ([toUser hasSuffix:@"@chatroom"]) return toUser;
    if (currentUser.length > 0 && [fromUser isEqualToString:currentUser]) return toUser;
    return fromUser.length > 0 ? fromUser : toUser;
}

static BOOL WCAtlasRepeatPlainTextMessageFallback(CommonMessageCellView *cell) {
    id source = WCAtlasMessageWrapForCell(cell);
    NSInteger messageType = [WCAtlasTweakSafeValue(source, @"m_uiMessageType") integerValue];
    NSString *content = WCAtlasTweakSafeValue(source, @"m_nsContent");
    NSString *session = WCAtlasSessionForMessage(source);
    if (messageType != 1 || content.length == 0 || session.length == 0) return NO;

    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector]) return NO;
    id repeated = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([wrapClass alloc], initSelector, 1);
    if (!repeated) return NO;
    WCAtlasTweakSetValue(repeated, @"m_nsFromUsr", WCAtlasCurrentUserWXID() ?: @"");
    WCAtlasTweakSetValue(repeated, @"m_nsToUsr", session);
    WCAtlasTweakSetValue(repeated, @"m_nsContent", content);
    WCAtlasTweakSetValue(repeated, @"m_uiStatus", @1);
    WCAtlasTweakSetValue(repeated, @"m_uiCreateTime", @((NSUInteger)NSDate.date.timeIntervalSince1970));

    id manager = WCAtlasMessageManager();
    SEL sendSelector = sel_registerName("AddMsg:MsgWrap:");
    if (!manager || ![manager respondsToSelector:sendSelector]) return NO;
    ((void (*)(id, SEL, NSString *, id))objc_msgSend)(manager, sendSelector, session, repeated);
    return YES;
}

static BOOL WCAtlasVoiceRepeatUploadIsActive(void) {
    return WCAtlasVoiceRepeatForwardDeadline > NSDate.date.timeIntervalSince1970;
}

static BOOL WCAtlasSendVoiceMessage(id source, NSString *sourcePathOverride, NSString *session) {
    if (!source || session.length == 0) return NO;

    id manager = WCAtlasMessageManager();
    SEL voicePathSelector = sel_registerName("getVoicePath");
    SEL destinationPathSelector = sel_registerName("getPathOfAudio:");
    SEL addLocalSelector = sel_registerName("AddLocalMsg:MsgWrap:");
    SEL saveVoiceSelector = sel_registerName("SaveMesVoice:MsgWrap:");
    SEL resendSelector = sel_registerName("ResendVoiceMsg:MsgWrap:");
    SEL uploaderSelector = sel_registerName("uploaderForMsgWrap:");
    Class messageWrapClass = objc_getClass("CMessageWrap");
    Class audioSenderClass = objc_getClass("AudioSender");
    id audioSender = audioSenderClass ? WCAtlasServiceForClass(audioSenderClass) : nil;
    if ((sourcePathOverride.length == 0 && ![source respondsToSelector:voicePathSelector]) ||
        !manager ||
        ![manager respondsToSelector:addLocalSelector] ||
        !messageWrapClass ||
        ![messageWrapClass respondsToSelector:destinationPathSelector] ||
        !audioSender) {
        WCAtlasLog(@"语音复读入口不完整，取消发送");
        return NO;
    }

    NSString *sourcePath = sourcePathOverride;
    if (sourcePath.length == 0) sourcePath = ((id (*)(id, SEL))objc_msgSend)(source, voicePathSelector);
    if (![sourcePath isKindOfClass:[NSString class]] || sourcePath.length == 0 ||
        ![[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
        WCAtlasLog(@"语音复读找不到本地语音文件");
        return NO;
    }

    id repeated = nil;
    @try {
        repeated = [source copy];
        if (!repeated) return NO;

        WCAtlasTweakSetValue(repeated, @"m_uiMesLocalID", @0);
        WCAtlasTweakSetValue(repeated, @"m_n64MesSvrID", @0);
        SEL resetLocalIDSelector = sel_registerName("resetLocalId");
        if ([repeated respondsToSelector:resetLocalIDSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(repeated, resetLocalIDSelector);
        }

        NSString *currentUser = WCAtlasCurrentUserWXID() ?: @"";
        NSUInteger now = (NSUInteger)NSDate.date.timeIntervalSince1970;
        WCAtlasTweakSetValue(repeated, @"m_nsFromUsr", currentUser);
        WCAtlasTweakSetValue(repeated, @"m_nsRealChatUsr", currentUser);
        WCAtlasTweakSetValue(repeated, @"m_nsToUsr", session);
        WCAtlasTweakSetValue(repeated, @"m_uiCreateTime", @(now));
        WCAtlasTweakSetValue(repeated, @"m_uiSendTime", @(now));
        WCAtlasTweakSetValue(repeated, @"m_uiStatus", @1);
        WCAtlasTweakSetValue(repeated, @"m_uiVoiceForwardFlag", @1);
        id extendInfo = WCAtlasTweakSafeValue(repeated, @"m_extendInfoWithMsgType");
        WCAtlasTweakSetValue(extendInfo, @"m_uiVoiceForwardFlag", @1);

        // AddLocalMsg assigns the new local message ID. WeChat derives the
        // audio destination path from that ID, so this must happen first.
        ((void (*)(id, SEL, id, id))objc_msgSend)(manager, addLocalSelector, session, repeated);

        NSString *destinationPath = ((id (*)(id, SEL, id))objc_msgSend)(messageWrapClass,
                                                                        destinationPathSelector,
                                                                        repeated);
        if (![destinationPath isKindOfClass:[NSString class]] || destinationPath.length == 0) {
            WCAtlasLog(@"语音复读无法生成目标文件路径");
            return NO;
        }

        BOOL voiceSaved = [sourcePath isEqualToString:destinationPath];
        if (!voiceSaved) {
            NSString *destinationDirectory = destinationPath.stringByDeletingLastPathComponent;
            if (destinationDirectory.length > 0) {
                [[NSFileManager defaultManager] createDirectoryAtPath:destinationDirectory
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:nil];
            }
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
            NSError *copyError = nil;
            voiceSaved = [[NSFileManager defaultManager] copyItemAtPath:sourcePath
                                                                 toPath:destinationPath
                                                                  error:&copyError];
            if (!voiceSaved && [manager respondsToSelector:saveVoiceSelector]) {
                NSData *voiceData = [NSData dataWithContentsOfFile:sourcePath];
                if (voiceData.length > 0) {
                    voiceSaved = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(manager,
                                                                           saveVoiceSelector,
                                                                           voiceData,
                                                                           repeated);
                }
            }
            NSDictionary *destinationAttributes = [[NSFileManager defaultManager]
                                                    attributesOfItemAtPath:destinationPath
                                                    error:nil];
            unsigned long long destinationSize = [destinationAttributes[NSFileSize] unsignedLongLongValue];
            if (!voiceSaved || destinationSize == 0) {
                WCAtlasLog(@"语音复读保存语音失败：%@", copyError.localizedDescription ?: @"未知错误");
                return NO;
            }
        }

        id resendTarget = audioSender;
        if (![resendTarget respondsToSelector:resendSelector] &&
            [audioSender respondsToSelector:uploaderSelector]) {
            resendTarget = ((id (*)(id, SEL, id))objc_msgSend)(audioSender, uploaderSelector, repeated);
        }
        if (![resendTarget respondsToSelector:resendSelector]) {
            WCAtlasLog(@"语音复读找不到微信语音上传入口");
            return NO;
        }
        // WeChatX keeps the native upload pipeline in forwarding mode for a
        // short, repeat-scoped window. The setter hooks below never affect
        // ordinary voice recording or forwarding outside this window.
        WCAtlasVoiceRepeatForwardDeadline = NSDate.date.timeIntervalSince1970 + 12.0;
        ((void (*)(id, SEL, id, id))objc_msgSend)(resendTarget, resendSelector, session, repeated);
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"语音复读调用失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

static BOOL WCAtlasRepeatVoiceMessage(id source, NSString *session) {
    return WCAtlasSendVoiceMessage(source, nil, session);
}

static NSString *WCAtlasVoiceForwardSessionForContact(id contact) {
    if (!contact) return nil;
    if ([contact isKindOfClass:[NSString class]] && [contact length] > 0) return contact;
    return WCAtlasPrivateContactUserName(contact);
}

// WeChat's stock forward controller accepts voice messages into its local
// result flow, but current versions do not start a usable voice upload for
// them. Match WeChatX by consuming voice wraps before the stock forward path
// and sending each one through AudioSender's native resend pipeline.
static NSArray *WCAtlasForwardMessagesBySendingVoices(NSArray *messages,
                                                    NSArray *contacts,
                                                    NSIndexSet **handledIndexes) {
    if (handledIndexes) *handledIndexes = nil;
    if (!WCAtlasEnhancementEnabled(WCAtlasVoiceForwardEnabledKey) ||
        ![messages isKindOfClass:[NSArray class]] || messages.count == 0 ||
        ![contacts isKindOfClass:[NSArray class]] || contacts.count == 0) {
        return messages;
    }

    NSMutableArray *remaining = [NSMutableArray arrayWithCapacity:messages.count];
    NSMutableIndexSet *handled = [NSMutableIndexSet indexSet];
    [messages enumerateObjectsUsingBlock:^(id message, NSUInteger index, BOOL *stop) {
        (void)stop;
        if ([WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue] != 34) {
            [remaining addObject:message];
            return;
        }

        BOOL sentToEveryContact = YES;
        for (id contact in contacts) {
            NSString *session = WCAtlasVoiceForwardSessionForContact(contact);
            if (session.length == 0 || !WCAtlasRepeatVoiceMessage(message, session)) {
                sentToEveryContact = NO;
                break;
            }
        }
        if (sentToEveryContact) {
            [handled addIndex:index];
            WCAtlasCompatibilityMarkTriggered(@"voice-forward");
        } else {
            [remaining addObject:message];
        }
    }];
    if (handledIndexes && handled.count > 0) *handledIndexes = [handled copy];
    return remaining;
}

static NSArray *WCAtlasVoiceForwardFilteredOrigins(NSArray *origins, NSIndexSet *handledIndexes) {
    if (![origins isKindOfClass:[NSArray class]] || handledIndexes.count == 0) return origins;
    NSMutableArray *remaining = [origins mutableCopy];
    [handledIndexes enumerateIndexesWithOptions:NSEnumerationReverse
                                     usingBlock:^(NSUInteger index, BOOL *stop) {
        (void)stop;
        if (index < remaining.count) [remaining removeObjectAtIndex:index];
    }];
    return remaining;
}

static BOOL WCAtlasRepeatMessage(CommonMessageCellView *cell) {
    id source = WCAtlasMessageWrapForCell(cell);
    NSString *chatName = WCAtlasSessionForMessage(source);
    NSInteger messageType = [WCAtlasTweakSafeValue(source, @"m_uiMessageType") integerValue];
    if (messageType == 34) return WCAtlasRepeatVoiceMessage(source, chatName);
    id contact = WCAtlasContactForUserName(chatName);
    Class forwardClass = objc_getClass("ForwardMessageLogicController");
    SEL forwardSelector = sel_registerName("forwardNoConfirmForMsgList:toContacts:");
    SEL delegateSelector = sel_registerName("setDelegate:");
    if (source && contact && forwardClass) {
        BOOL canForward = YES;
        Class utilityClass = objc_getClass("ForwardMsgUtil");
        SEL canForwardSelector = sel_registerName("canBeForwardWithMsg:");
        if ([utilityClass respondsToSelector:canForwardSelector]) {
            canForward = ((BOOL (*)(id, SEL, id))objc_msgSend)(utilityClass, canForwardSelector, source);
        }
        id logic = canForward ? [forwardClass new] : nil;
        if (logic && [logic respondsToSelector:forwardSelector] && [logic respondsToSelector:delegateSelector]) {
            WCAtlasMessageRepeatSession *repeatSession = [WCAtlasMessageRepeatSession new];
            repeatSession.forwardLogic = logic;
            repeatSession.message = source;
            repeatSession.contact = contact;
            repeatSession.presenter = WCAtlasVisibleChatController;
            ((void (*)(id, SEL, id))objc_msgSend)(logic, delegateSelector, repeatSession);
            [WCAtlasActiveQuickSendSessions() addObject:repeatSession];
            @try {
                ((void (*)(id, SEL, id, id))objc_msgSend)(logic, forwardSelector, @[source], @[contact]);
            } @catch (NSException *exception) {
                WCAtlasLog(@"复读调用微信转发引擎失败：%@", exception.reason ?: exception.name);
                [repeatSession finishSession];
                return WCAtlasRepeatPlainTextMessageFallback(cell);
            }
            __weak WCAtlasMessageRepeatSession *weakSession = repeatSession;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WCAtlasMessageRepeatSession *activeSession = weakSession;
                if (activeSession && !activeSession.finished) [activeSession finishSession];
            });
            return YES;
        }
    }
    return WCAtlasRepeatPlainTextMessageFallback(cell);
}

static NSString *WCAtlasRepeatConfirmationSummary(id message) {
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (messageType == 1) {
        NSString *content = WCAtlasTweakSafeValue(message, @"m_nsContent");
        if (content.length > 40) content = [[content substringToIndex:40] stringByAppendingString:@"…"];
        return content.length > 0 ? [NSString stringWithFormat:@"复读文字：%@", content] : @"复读文字消息";
    }
    if (messageType == 3) return @"复读图片消息";
    if (messageType == 34) return @"复读语音消息";
    if (messageType == 43 || messageType == 62) return @"复读视频消息";
    if (messageType == 47 || WCAtlasSendConfirmationMessageIsAppEmoticon(message)) return @"复读表情消息";
    return @"复读这条消息";
}

static BOOL WCAtlasRepeatMessageWithConfirmation(CommonMessageCellView *cell) {
    id source = WCAtlasMessageWrapForCell(cell);
    NSString *target = WCAtlasSessionForMessage(source);
    UIViewController *presenter = WCAtlasSendConfirmationPresenterForTarget(target);
    if (!presenter) return WCAtlasRepeatMessage(cell);
    __weak CommonMessageCellView *weakCell = cell;
    id retainedSource = source;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(presenter,
                                                      target,
                                                      WCAtlasRepeatConfirmationSummary(source),
                                                      ^BOOL{
        CommonMessageCellView *strongCell = weakCell;
        return strongCell && WCAtlasSendConfirmationValidateTarget(target) &&
               WCAtlasMessageWrapForCell(strongCell) == retainedSource;
    }, ^{
        CommonMessageCellView *strongCell = weakCell;
        if (strongCell && WCAtlasMessageWrapForCell(strongCell) == retainedSource) {
            NSInteger messageType = [WCAtlasTweakSafeValue(retainedSource, @"m_uiMessageType") integerValue];
            if (messageType == 1 || messageType == 3 || messageType == 43 ||
                messageType == 47 || messageType == 49 || messageType == 62) {
                WCAtlasArmRepeatSendConfirmationBypass(target, messageType);
            }
            @try {
                (void)WCAtlasRepeatMessage(strongCell);
            } @finally {
                // The exemption belongs only to this synchronous repeat dispatch.
                // If WeChat defers the real send, the downstream hook will ask again
                // instead of allowing an unrelated message through later.
                WCAtlasClearRepeatSendConfirmationBypass();
            }
        }
    });
    return held ? YES : WCAtlasRepeatMessage(cell);
}

static BOOL WCAtlasMessageCanRepeat(CommonMessageCellView *cell) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMessageRepeatMenuEnabledKey) || !cell) return NO;
    id message = WCAtlasMessageWrapForCell(cell);
    if (!message || WCAtlasSessionForMessage(message).length == 0) return NO;
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (messageType == 34) {
        SEL voicePathSelector = sel_registerName("getVoicePath");
        if (![message respondsToSelector:voicePathSelector]) return NO;
        id path = ((id (*)(id, SEL))objc_msgSend)(message, voicePathSelector);
        return [path isKindOfClass:[NSString class]] && [path length] > 0 &&
               [[NSFileManager defaultManager] fileExistsAtPath:path];
    }
    Class utilityClass = objc_getClass("ForwardMsgUtil");
    SEL canForwardSelector = sel_registerName("canBeForwardWithMsg:");
    if ([utilityClass respondsToSelector:canForwardSelector]) {
        return ((BOOL (*)(id, SEL, id))objc_msgSend)(utilityClass, canForwardSelector, message);
    }
    return messageType == 1 && [WCAtlasTweakSafeValue(message, @"m_nsContent") length] > 0;
}

static NSArray *WCAtlasOperationMenuItemsWithRepeat(CommonMessageCellView *target, NSArray *originalItems) {
    if (![originalItems isKindOfClass:[NSArray class]] || !WCAtlasMessageCanRepeat(target)) return originalItems;
    for (id item in originalItems) {
        if ([WCAtlasTweakSafeValue(item, @"title") isEqualToString:@"+1"]) return originalItems;
    }
    Class itemClass = objc_getClass("MMMenuItem");
    SEL initializer = @selector(initWithTitle:icon:target:action:);
    if (!itemClass || ![itemClass instancesRespondToSelector:initializer]) return originalItems;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [UIImage systemImageNamed:@"plus.message" withConfiguration:configuration] ?:
                    [UIImage systemImageNamed:@"plus" withConfiguration:configuration];
    icon = [icon imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *repeatItem = [[itemClass alloc] initWithTitle:@"+1" icon:icon
                                                       target:target action:@selector(wcatlas_repeatMessage:)];
    if (!repeatItem) return originalItems;
    NSMutableArray *items = [originalItems mutableCopy];
    [items insertObject:repeatItem atIndex:0];
    return items;
}

static BOOL WCAtlasPerformMessageGestureAction(CommonMessageCellView *cell, WCAtlasReplySwipeAction action) {
    if (!cell.window || action == WCAtlasReplySwipeActionNone) return NO;
    BOOL performed = NO;
    switch (action) {
        case WCAtlasReplySwipeActionQuote:
            performed = WCAtlasInvokeFirstMessageCellAction(cell, @[@"onShowMsgReplyMenuItem:"]);
            break;
        case WCAtlasReplySwipeActionRevoke:
            if (!WCAtlasMessageCellIsSender(cell)) return NO;
            performed = WCAtlasInvokeFirstMessageCellAction(cell, @[@"onRevokeMsg:"]);
            break;
        case WCAtlasReplySwipeActionCopy:
            performed = WCAtlasInvokeFirstMessageCellAction(cell, @[@"onCopy:"]);
            if (!performed) {
                NSString *content = WCAtlasTweakSafeValue(WCAtlasMessageWrapForCell(cell), @"m_nsContent");
                if (content.length > 0) {
                    UIPasteboard.generalPasteboard.string = content;
                    performed = YES;
                }
            }
            break;
        case WCAtlasReplySwipeActionDelete:
            performed = WCAtlasInvokeFirstMessageCellAction(cell, @[@"onDelete:", @"onDeleteMessage:"]);
            break;
        case WCAtlasReplySwipeActionRepeat:
            performed = WCAtlasRepeatMessageWithConfirmation(cell);
            break;
        case WCAtlasReplySwipeActionNone:
            break;
    }
    if (performed) WCAtlasCompatibilityMarkTriggered(@"reply-swipe");
    else WCAtlasLog(@"消息手势动作不可用，action=%ld cell=%@", (long)action, NSStringFromClass(cell.class));
    return performed;
}

static unsigned int WCAtlasGradualStepCountForTarget(NSInteger target, NSDate *date) {
    NSDateComponents *components = [[NSCalendar currentCalendar]
        components:(NSCalendarUnitHour | NSCalendarUnitMinute)
          fromDate:date];
    NSInteger minuteOfDay = components.hour * 60 + components.minute;
    static const NSInteger stageMinutes[] = {
        0,          // 凌晨保留少量基础步数
        7 * 60,     // 07:00
        9 * 60 + 30,// 09:30
        12 * 60,    // 12:00
        14 * 60 + 30,// 14:30
        16 * 60 + 30,// 16:30
        18 * 60 + 30,// 18:30，19:00 前完成目标
    };
    static const CGFloat stageProgress[] = {0.02, 0.15, 0.32, 0.50, 0.66, 0.82, 1.0};
    CGFloat fraction = stageProgress[0];
    for (NSUInteger index = 1; index < sizeof(stageMinutes) / sizeof(stageMinutes[0]); index++) {
        if (minuteOfDay < stageMinutes[index]) break;
        fraction = stageProgress[index];
    }
    NSInteger value = (NSInteger)floor(target * fraction);
    return (unsigned int)MIN(100000, MAX(1, value));
}

static unsigned int WCAtlasConfiguredDailyStepCount(void) {
    if (!WCAtlasEnhancementEnabled(WCAtlasStepOverrideEnabledKey)) return 0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    WCAtlasStepMode mode = (WCAtlasStepMode)[defaults integerForKey:WCAtlasStepModeKey];
    if (mode != WCAtlasStepModeDailyRandom) mode = WCAtlasStepModeDailyFixed;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSInteger dailyTarget = 0;
    @synchronized (defaults) {
        NSDate *configuredDate = [defaults objectForKey:WCAtlasStepCountDateKey];
        dailyTarget = [defaults integerForKey:WCAtlasStepDailyTargetKey];
        BOOL targetIsCurrent = [configuredDate isKindOfClass:[NSDate class]] &&
                               [calendar isDateInToday:configuredDate] && dailyTarget > 0;
        if (!targetIsCurrent) {
            if (mode == WCAtlasStepModeDailyRandom) {
                NSInteger minimum = MIN(100000, MAX(1, [defaults integerForKey:WCAtlasStepRandomMinimumKey]));
                NSInteger maximum = MIN(100000, MAX(minimum, [defaults integerForKey:WCAtlasStepRandomMaximumKey]));
                dailyTarget = minimum + (NSInteger)arc4random_uniform((uint32_t)(maximum - minimum + 1));
            } else {
                dailyTarget = MIN(100000, MAX(0, [defaults integerForKey:WCAtlasStepCountKey]));
            }
            if (dailyTarget > 0) {
                [defaults setInteger:dailyTarget forKey:WCAtlasStepDailyTargetKey];
                [defaults setObject:now forKey:WCAtlasStepCountDateKey];
            }
        }
    }
    if (dailyTarget <= 0) return 0;
    if ([defaults boolForKey:WCAtlasStepGradualEnabledKey]) {
        return WCAtlasGradualStepCountForTarget(dailyTarget, now);
    }
    return (unsigned int)MIN(100000, dailyTarget);
}

static CGFloat WCAtlasGlobalPageScaleFactor(void) {
    return WCAtlasScalePercentForDefaultsKey(WCAtlasPageScaleGlobalPercentKey, 100.0) / 100.0;
}

static BOOL WCAtlasThemeValueShouldScale(id property, id ruleSet) {
    if (!WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey) ||
        ![property isKindOfClass:[NSString class]] ||
        ![ruleSet isKindOfClass:[NSString class]]) return NO;
    if (![(NSString *)ruleSet isEqualToString:@"#font_set"]) return NO;
    return [(NSString *)property isEqualToString:@"alllevel"] ||
           [(NSString *)property isEqualToString:@"chatLevel"];
}

static id WCAtlasScaledThemeValue(id originalValue, id property, id ruleSet) {
    if (!WCAtlasThemeValueShouldScale(property, ruleSet) ||
        ![originalValue isKindOfClass:[NSArray class]] ||
        [(NSArray *)originalValue count] == 0) return originalValue;
    id firstValue = [(NSArray *)originalValue firstObject];
    id scaledValue = nil;
    CGFloat scale = WCAtlasGlobalPageScaleFactor();
    if ([firstValue isKindOfClass:[NSNumber class]]) {
        scaledValue = @([(NSNumber *)firstValue doubleValue] * scale);
    } else if ([firstValue isKindOfClass:[NSString class]]) {
        NSScanner *scanner = [NSScanner scannerWithString:firstValue];
        double ignored = 0.0;
        if (![scanner scanDouble:&ignored] || !scanner.isAtEnd) return originalValue;
        NSDecimalNumber *value = [NSDecimalNumber decimalNumberWithString:firstValue];
        NSDecimalNumber *factor = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%.4f", scale]];
        NSDecimalNumber *result = [value decimalNumberByMultiplyingBy:factor];
        if (![result isEqualToNumber:[NSDecimalNumber notANumber]]) scaledValue = result.stringValue;
    }
    if (!scaledValue) return originalValue;
    NSMutableArray *values = [(NSArray *)originalValue mutableCopy];
    values[0] = scaledValue;
    WCAtlasCompatibilityMarkTriggered(@"page-scale");
    return values;
}

static void WCAtlasApplyWebViewTextScale(id webView) {
    if (!WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey) || !webView) return;
    SEL selector = NSSelectorFromString(@"_setTextZoomFactor:");
    if (![webView respondsToSelector:selector]) return;
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(webView, selector, WCAtlasGlobalPageScaleFactor());
    WCAtlasCompatibilityMarkTriggered(@"page-scale");
}

static NSString *WCAtlasMomentsUserNameForDataItem(id dataItem) {
    SEL selector = NSSelectorFromString(@"username");
    if (!dataItem || ![dataItem respondsToSelector:selector]) return nil;
    @try {
        id value = ((id (*)(id, SEL))objc_msgSend)(dataItem, selector);
        return [value isKindOfClass:[NSString class]] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSMutableDictionary<NSString *, id> *WCAtlasMomentsPermissionsControllerCache(void) {
    static NSMutableDictionary<NSString *, id> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

static id WCAtlasMomentsPermissionsController(NSString *userName, id delegate) {
    if (userName.length == 0) return nil;
    Class controllerClass = NSClassFromString(@"WCSetPermissionsViewController");
    SEL initSelector = NSSelectorFromString(@"initWithUserName:");
    SEL viewSelector = NSSelectorFromString(@"view");
    SEL delegateSelector = NSSelectorFromString(@"setDelegate:");
    SEL viewDelegateSelector = NSSelectorFromString(@"setViewDelegate:");
    if (!controllerClass || ![controllerClass instancesRespondToSelector:initSelector]) return nil;

    id controller = nil;
    @try {
        id allocated = [controllerClass alloc];
        controller = ((id (*)(id, SEL, id))objc_msgSend)(allocated, initSelector, userName);
        if (!controller ||
            ![controller respondsToSelector:viewSelector] ||
            ![controller respondsToSelector:delegateSelector] ||
            ![controller respondsToSelector:viewDelegateSelector]) return nil;
        (void)((id (*)(id, SEL))objc_msgSend)(controller, viewSelector);
        ((void (*)(id, SEL, id))objc_msgSend)(controller, delegateSelector, delegate);
        ((void (*)(id, SEL, id))objc_msgSend)(controller, viewDelegateSelector, delegate);
    } @catch (__unused NSException *exception) {
        return nil;
    }

    NSMutableDictionary<NSString *, id> *cache = WCAtlasMomentsPermissionsControllerCache();
    cache[userName] = controller;
    NSString *cacheKey = [userName copy];
    __weak id weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id strongController = weakController;
        if (strongController && cache[cacheKey] == strongController) [cache removeObjectForKey:cacheKey];
    });
    return controller;
}

static NSString *WCAtlasMomentsCheckedPermissionTitle(NSString *title, BOOL checked) {
    return checked ? [NSString stringWithFormat:@"✓ %@", title] : title;
}

static WCActionSheetItem *WCAtlasMomentsPermissionItem(NSString *title,
                                                     BOOL enabled,
                                                     BOOL destructive,
                                                     void (^eventAction)(void)) {
    Class itemClass = NSClassFromString(@"WCActionSheetItem");
    if (!itemClass || title.length == 0 || !eventAction) return nil;
    id allocated = [itemClass alloc];
    SEL initSelector = NSSelectorFromString(@"initWithTitle:");
    if (![allocated respondsToSelector:initSelector]) return nil;
    WCActionSheetItem *item = [(WCActionSheetItem *)allocated initWithTitle:title];
    if (!item ||
        ![item respondsToSelector:@selector(setBEnable:)] ||
        ![item respondsToSelector:@selector(setBDestructiveButton:)] ||
        ![item respondsToSelector:@selector(setEventAction:)]) return nil;
    [item setBEnable:enabled];
    [item setBDestructiveButton:destructive];
    [item setEventAction:eventAction];
    return item;
}

static void WCAtlasPerformMomentsPermissionAction(NSString *userName,
                                                id delegate,
                                                NSString *selectorName,
                                                NSNumber *switchState) {
    id controller = WCAtlasMomentsPermissionsController(userName, delegate);
    SEL selector = NSSelectorFromString(selectorName);
    if (!controller || ![controller respondsToSelector:selector]) return;
    @try {
        if (switchState) {
            UISwitch *permissionSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
            permissionSwitch.on = switchState.boolValue;
            ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, permissionSwitch);
        } else {
            ((void (*)(id, SEL))objc_msgSend)(controller, selector);
        }
    } @catch (__unused NSException *exception) {
    }
}

static BOOL WCAtlasConfigureMomentsPermissionsActionSheet(WCActionSheet *sheet, id dataItem) {
    if (!sheet || !dataItem || !WCAtlasEnhancementEnabled(WCAtlasMomentsQuickPermissionsKey)) return NO;
    NSArray *buttonTitleList = WCAtlasTweakSafeValue(sheet, @"buttonTitleList");
    if (![buttonTitleList isKindOfClass:[NSArray class]] || buttonTitleList.count != 2) return NO;
    NSString *firstTitle = WCAtlasTweakSafeValue(buttonTitleList.firstObject, @"title");
    NSString *lastTitle = WCAtlasTweakSafeValue(buttonTitleList.lastObject, @"title");
    if ((! [firstTitle isEqualToString:@"设置权限"] && ![firstTitle isEqualToString:@"设置"]) ||
        ![lastTitle isEqualToString:@"投诉"]) return NO;

    NSString *userName = WCAtlasMomentsUserNameForDataItem(dataItem);
    id delegate = WCAtlasTweakSafeValue(sheet, @"delegate");
    id controller = WCAtlasMomentsPermissionsController(userName, delegate);
    SEL contactSelector = NSSelectorFromString(@"m_contact");
    if (userName.length == 0 || !delegate || !controller || ![controller respondsToSelector:contactSelector]) return NO;
    id contact = ((id (*)(id, SEL))objc_msgSend)(controller, contactSelector);
    SEL onlyChatSelector = NSSelectorFromString(@"isSocialBlack");
    if (!contact || ![contact respondsToSelector:onlyChatSelector]) return NO;
    BOOL onlyChat = ((BOOL (*)(id, SEL))objc_msgSend)(contact, onlyChatSelector);

    SEL allSelector = NSSelectorFromString(@"opAllPermission");
    SEL onlyChatActionSelector = NSSelectorFromString(@"opSocialBlackPermission");
    SEL outsiderActionSelector = NSSelectorFromString(@"opOutsider:");
    SEL blacklistActionSelector = NSSelectorFromString(@"opWCBlacklist:");
    if (![controller respondsToSelector:allSelector] ||
        ![controller respondsToSelector:onlyChatActionSelector] ||
        ![controller respondsToSelector:outsiderActionSelector] ||
        ![controller respondsToSelector:blacklistActionSelector]) return NO;

    BOOL outsider = NO;
    BOOL blacklist = NO;
    Class stateControllerClass = NSClassFromString(@"ContactSetPermissionsViewController");
    id stateController = stateControllerClass ? [stateControllerClass new] : nil;
    SEL setContactSelector = NSSelectorFromString(@"setM_contact:");
    SEL outsiderStateSelector = NSSelectorFromString(@"getIsOutsiderSwitchOn:");
    SEL blacklistStateSelector = NSSelectorFromString(@"getIsWCBlackSwitchOn:");
    if (stateController &&
        [stateController respondsToSelector:setContactSelector] &&
        [stateController respondsToSelector:outsiderStateSelector] &&
        [stateController respondsToSelector:blacklistStateSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(stateController, setContactSelector, contact);
        outsider = ((BOOL (*)(id, SEL, id))objc_msgSend)(stateController, outsiderStateSelector, contact);
        blacklist = ((BOOL (*)(id, SEL, id))objc_msgSend)(stateController, blacklistStateSelector, contact);
    }

    unsigned int sex = 0;
    SEL sexSelector = NSSelectorFromString(@"m_uiSex");
    if ([contact respondsToSelector:sexSelector]) sex = ((unsigned int (*)(id, SEL))objc_msgSend)(contact, sexSelector);
    NSString *pronoun = sex == 1 ? @"他" : (sex == 2 ? @"她" : @"TA");

    __weak id weakDelegate = delegate;
    __weak WCActionSheet *weakSheet = sheet;
    NSString *capturedUserName = [userName copy];
    WCActionSheetItem *allItem = WCAtlasMomentsPermissionItem(
        WCAtlasMomentsCheckedPermissionTitle(@"聊天、朋友圈、微信运动等", !onlyChat), YES, NO, ^{
            WCAtlasPerformMomentsPermissionAction(capturedUserName, weakDelegate, @"opAllPermission", nil);
        });
    WCActionSheetItem *onlyChatItem = WCAtlasMomentsPermissionItem(
        WCAtlasMomentsCheckedPermissionTitle(@"仅聊天", onlyChat), YES, NO, ^{
            WCAtlasPerformMomentsPermissionAction(capturedUserName, weakDelegate, @"opSocialBlackPermission", nil);
        });
    WCActionSheetItem *outsiderItem = WCAtlasMomentsPermissionItem(
        WCAtlasMomentsCheckedPermissionTitle([NSString stringWithFormat:@"不让%@看", pronoun], outsider), !onlyChat, NO, ^{
            WCAtlasPerformMomentsPermissionAction(capturedUserName, weakDelegate, @"opOutsider:", @(!outsider));
        });
    WCActionSheetItem *blacklistItem = WCAtlasMomentsPermissionItem(
        WCAtlasMomentsCheckedPermissionTitle([NSString stringWithFormat:@"不看%@", pronoun], blacklist), !onlyChat, NO, ^{
            WCAtlasPerformMomentsPermissionAction(capturedUserName, weakDelegate, @"opWCBlacklist:", @(!blacklist));
        });
    WCActionSheetItem *complaintItem = WCAtlasMomentsPermissionItem(@"投诉", YES, YES, ^{
        id strongDelegate = weakDelegate;
        WCActionSheet *strongSheet = weakSheet;
        SEL selector = NSSelectorFromString(@"actionSheet:clickedButtonAtIndex:");
        if (strongDelegate && strongSheet && [strongDelegate respondsToSelector:selector]) {
            ((void (*)(id, SEL, id, NSInteger))objc_msgSend)(strongDelegate, selector, strongSheet, 1);
        }
    });
    if (!allItem || !onlyChatItem || !outsiderItem || !blacklistItem || !complaintItem) return NO;

    SEL listSelector = NSSelectorFromString(@"setButtonTitleList:");
    SEL countSelector = NSSelectorFromString(@"setNumberOfButtons:");
    SEL firstSelector = NSSelectorFromString(@"setFirstOtherButtonIndex:");
    SEL destructiveSelector = NSSelectorFromString(@"setDestructiveButtonIndex:");
    if (![sheet respondsToSelector:listSelector] ||
        ![sheet respondsToSelector:countSelector] ||
        ![sheet respondsToSelector:firstSelector] ||
        ![sheet respondsToSelector:destructiveSelector]) return NO;
    NSMutableArray *items = [@[allItem, onlyChatItem, outsiderItem, blacklistItem, complaintItem] mutableCopy];
    ((void (*)(id, SEL, id))objc_msgSend)(sheet, listSelector, items);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(sheet, countSelector, 5);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(sheet, firstSelector, 0);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(sheet, destructiveSelector, 4);
    WCAtlasCompatibilityMarkTriggered(@"moments-quick-permissions");
    return YES;
}

static void WCAtlasOpenMomentsHighQualityPicker(UIViewController *timelineController) {
    SEL selector = NSSelectorFromString(@"showImagePicker:");
    if (!timelineController || ![timelineController respondsToSelector:selector]) {
        WCAtlasShowTransientMessage(@"当前微信版本不支持朋友圈原生媒体选择", NO);
        return;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(timelineController, selector, nil);
}

static void WCAtlasPrepareMomentsHighQualityMenu(WCActionSheet *sheet) {
    if (!sheet || !WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey) ||
        !WCAtlasPendingMomentsCameraController ||
        objc_getAssociatedObject(sheet, &WCAtlasMomentsHighQualityMenuKey)) return;
    __weak UIViewController *weakController = WCAtlasPendingMomentsCameraController;
    objc_setAssociatedObject(sheet, &WCAtlasMomentsHighQualityMenuKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL added = NO;
    @try {
        [sheet addButtonWithTitle:@"选择高清图片/原视频" eventAction:^{
            WCAtlasOpenMomentsHighQualityPicker(weakController);
        }];
        added = YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"增加朋友圈高清入口失败：%@", exception.reason ?: @"未知异常");
    }
    if (!added) {
        objc_setAssociatedObject(sheet, &WCAtlasMomentsHighQualityMenuKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    WCAtlasLog(@"已在朋友圈相机菜单增加高清入口");
}

static id WCAtlasTweakValueForSelectorNames(id object, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([object respondsToSelector:selector]) return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }
    return nil;
}

static long long WCAtlasLongLongDefaultForKey(NSString *key) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return [value respondsToSelector:@selector(longLongValue)] ? [value longLongValue] : 0;
}

static unsigned long long WCAtlasWalletBalanceFenOverride(void) {
    if (!WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey)) return 0;
    long long fen = WCAtlasLongLongDefaultForKey(WCAtlasWalletBalanceFenKey);
    return fen > 0 ? (unsigned long long)fen : 0;
}

static NSString *WCAtlasContactsCountTextForOriginal(NSString *original) {
    if (!WCAtlasEnhancementEnabled(WCAtlasContactsCountEnabledKey)) return nil;
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:WCAtlasContactsCountKey];
    if (count <= 0 || ![original isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [original stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([trimmed hasSuffix:@" 个朋友"]) return [NSString stringWithFormat:@"%ld 个朋友", (long)count];
    if ([trimmed hasSuffix:@"个朋友"]) return [NSString stringWithFormat:@"%ld个朋友", (long)count];
    if ([trimmed hasSuffix:@"个"] && [trimmed rangeOfString:@"朋友"].location == NSNotFound) {
        NSString *number = [[trimmed substringToIndex:trimmed.length - 1]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (number.length > 0 &&
            [number rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound) {
            return [NSString stringWithFormat:@"%ld 个", (long)count];
        }
    }
    return nil;
}

static BOOL WCAtlasResponderIsInsideControllerClass(UIResponder *responder, NSString *className) {
    Class controllerClass = NSClassFromString(className);
    if (!controllerClass) return NO;
    while (responder) {
        if ([responder isKindOfClass:controllerClass]) return YES;
        responder = responder.nextResponder;
    }
    return NO;
}

static id WCAtlasMessageWrapForCell(id cell) {
    // PKC resolves the visible native text cell through this WeChat selector.
    // Prefer it over guessing the internal view-model layout.
    id currentMessage = WCAtlasTweakValueForSelectorNames(cell,
        @[@"getCurrentMessageWrap", @"currentMessageWrap"]);
    if (currentMessage) return currentMessage;
    id directMessage = WCAtlasImageJokerMessageForObject(cell);
    if (directMessage) return directMessage;
    id viewModel = WCAtlasTweakValueForSelectorNames(cell, @[@"viewModel", @"m_viewModel"]);
    // Some WeChat builds expose the wrap directly as the view model rather
    // than under messageWrap; accept it when the content ivar is present.
    id directContent = WCAtlasTweakSafeValue(viewModel, @"m_nsContent");
    if ([directContent isKindOfClass:NSString.class]) return viewModel;
    id message = WCAtlasTweakValueForSelectorNames(viewModel, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    id parentModel = WCAtlasTweakSafeValue(viewModel, @"parentModel");
    message = WCAtlasTweakValueForSelectorNames(parentModel, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    return WCAtlasTweakValueForSelectorNames(cell, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
}

static NSString *WCAtlasImageJokerKeyForMessage(id message);

static void WCAtlasRecordMeMenuTitle(NSString *title) {
    if (title.length == 0 || [title isEqualToString:@"插件"]) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    @synchronized (defaults) {
        NSMutableArray<NSString *> *known = [[defaults arrayForKey:WCAtlasMeMenuKnownTitlesKey] mutableCopy] ?: [NSMutableArray array];
        if (![known containsObject:title]) {
            [known addObject:title];
            [defaults setObject:known forKey:WCAtlasMeMenuKnownTitlesKey];
        }
    }
}

static BOOL WCAtlasHidesMeMenuTitle(NSString *title) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id master = [defaults objectForKey:@"com.qiu7c.wcatlas.enabled"];
    return title.length > 0 && (!master || [master boolValue]) &&
           [[defaults arrayForKey:WCAtlasMeMenuHiddenTitlesKey] containsObject:title];
}

static BOOL WCAtlasVoiceMessageIsGroup(id message) {
    NSString *from = WCAtlasTweakValueForSelectorNames(message, @[@"m_nsFromUsr", @"fromUser"]);
    NSString *to = WCAtlasTweakValueForSelectorNames(message, @[@"m_nsToUsr", @"toUser"]);
    return [from hasSuffix:@"@chatroom"] || [to hasSuffix:@"@chatroom"];
}

static BOOL WCAtlasVoiceTranscriptionHasResult(id cell, id message) {
    SEL resultSelector = NSSelectorFromString(@"hasLocalTranslateResult");
    if ([message respondsToSelector:resultSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(message, resultSelector)) return YES;
    for (NSString *key in @[@"m_textTranslateView", @"m_textTranslateLabel", @"m_translateResultLabel"]) {
        UIView *view = WCAtlasTweakSafeValue(cell, key);
        if ([view isKindOfClass:[UIView class]] && !view.hidden && view.alpha > 0.01) return YES;
    }
    return NO;
}

static BOOL WCAtlasVoiceTranscriptionIsActive(id cell) {
    if ([WCAtlasTweakSafeValue(cell, @"m_isTranslating") boolValue]) return YES;
    for (NSString *key in @[@"m_translatingView", @"m_textTranslateLoadingView"]) {
        UIView *view = WCAtlasTweakSafeValue(cell, key);
        if ([view isKindOfClass:[UIView class]] && !view.hidden && view.alpha > 0.01) return YES;
    }
    return NO;
}

static BOOL WCAtlasShouldAutoTranscribeVoiceCell(id cell, id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasAutoVoiceTranscriptionEnabledKey) || !message) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL group = WCAtlasVoiceMessageIsGroup(message);
    if (group && [defaults boolForKey:WCAtlasAutoVoiceTranscriptionIgnoreGroupKey]) return NO;
    if (!group && [defaults boolForKey:WCAtlasAutoVoiceTranscriptionIgnorePrivateKey]) return NO;
    id viewModel = WCAtlasTweakValueForSelectorNames(cell, @[@"viewModel", @"m_viewModel"]);
    BOOL isSender = [WCAtlasTweakSafeValue(viewModel, @"isSender") boolValue] ||
                    [WCAtlasTweakSafeValue(message, @"isSender") boolValue];
    if (isSender && [defaults boolForKey:WCAtlasAutoVoiceTranscriptionIgnoreSelfKey]) return NO;
    if ([objc_getAssociatedObject(message, &WCAtlasVoiceTranscriptionDoneKey) boolValue] ||
        [objc_getAssociatedObject(message, &WCAtlasVoiceTranscriptionInProgressKey) boolValue] ||
        [objc_getAssociatedObject(message, &WCAtlasVoiceTranscriptionAttemptedKey) boolValue]) return NO;
    if (WCAtlasVoiceTranscriptionHasResult(cell, message)) {
        objc_setAssociatedObject(message, &WCAtlasVoiceTranscriptionDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return NO;
    }
    return !WCAtlasVoiceTranscriptionIsActive(cell);
}

static void WCAtlasScheduleVoiceTranscription(VoiceMessageCellView *cell, id message) {
    if (!cell.window || !WCAtlasShouldAutoTranscribeVoiceCell(cell, message)) return;
    if ([objc_getAssociatedObject(cell, &WCAtlasVoiceTranscriptionScheduledKey) boolValue]) return;
    objc_setAssociatedObject(cell, &WCAtlasVoiceTranscriptionScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak VoiceMessageCellView *weakCell = cell;
    __weak id weakMessage = message;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VoiceMessageCellView *strongCell = weakCell;
        id strongMessage = weakMessage;
        if (!strongCell) return;
        objc_setAssociatedObject(strongCell, &WCAtlasVoiceTranscriptionScheduledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id currentMessage = WCAtlasImageJokerMessageForObject(strongCell);
        if (currentMessage != strongMessage || !WCAtlasShouldAutoTranscribeVoiceCell(strongCell, strongMessage)) return;
        SEL selector = NSSelectorFromString(@"onVoiceTrans:");
        if (![strongCell respondsToSelector:selector]) return;
        id button = WCAtlasTweakSafeValue(strongCell, @"m_quickTransTipButton") ?: strongCell;
        objc_setAssociatedObject(strongMessage, &WCAtlasVoiceTranscriptionAttemptedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(strongMessage, &WCAtlasVoiceTranscriptionInProgressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, id))objc_msgSend)(strongCell, selector, button);
        WCAtlasCompatibilityMarkTriggered(@"auto-voice-transcription");
        __weak VoiceMessageCellView *checkingCell = strongCell;
        __weak id checkingMessage = strongMessage;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            VoiceMessageCellView *cellToCheck = checkingCell;
            id messageToCheck = checkingMessage;
            if (!messageToCheck) return;
            if (cellToCheck && WCAtlasVoiceTranscriptionHasResult(cellToCheck, messageToCheck)) {
                objc_setAssociatedObject(messageToCheck, &WCAtlasVoiceTranscriptionDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            objc_setAssociatedObject(messageToCheck, &WCAtlasVoiceTranscriptionInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        });
    });
}

static BOOL WCAtlasMessageIsText(id message) {
    SEL selector = NSSelectorFromString(@"IsTextMsg");
    return message && [message respondsToSelector:selector] && ((BOOL (*)(id, SEL))objc_msgSend)(message, selector);
}

static BOOL WCAtlasMessageIsRefer(id message) {
    SEL selector = NSSelectorFromString(@"isReferMsgType");
    return message && [message respondsToSelector:selector] && ((BOOL (*)(id, SEL))objc_msgSend)(message, selector);
}

static id WCAtlasPayInfoItemForMessage(id message) {
    if (!message) return nil;
    SEL parseSelector = NSSelectorFromString(@"parseWCPayInfoItemIfNeed");
    if ([message respondsToSelector:parseSelector]) ((void (*)(id, SEL))objc_msgSend)(message, parseSelector);

    SEL payItemSelector = NSSelectorFromString(@"m_oWCPayInfoItem");
    if (![message respondsToSelector:payItemSelector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(message, payItemSelector);
}

static BOOL WCAtlasMessageIsTransfer(id message) {
    id payItem = WCAtlasPayInfoItemForMessage(message);
    if (!payItem) return NO;

    unsigned int subType = 0;
    SEL subTypeSelector = NSSelectorFromString(@"m_uiPaySubType");
    if ([payItem respondsToSelector:subTypeSelector]) {
        subType = ((unsigned int (*)(id, SEL))objc_msgSend)(payItem, subTypeSelector);
    }
    if (subType == 3 || subType == 4) return YES;

    SEL transferIDSelector = NSSelectorFromString(@"m_nsTransferID");
    NSString *transferID = [payItem respondsToSelector:transferIDSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(payItem, transferIDSelector)
        : nil;
    return [transferID isKindOfClass:[NSString class]] && transferID.length > 0;
}

static BOOL WCAtlasMessageCanJokerEdit(id message) {
    return WCAtlasMessageIsText(message) || WCAtlasMessageIsRefer(message) || WCAtlasMessageIsTransfer(message);
}

static NSString *WCAtlasTransferDisplayText(id message) {
    id payItem = WCAtlasPayInfoItemForMessage(message);
    SEL feeDescSelector = NSSelectorFromString(@"m_nsFeeDesc");
    id value = payItem ? ((id (*)(id, SEL))objc_msgSend)(payItem, feeDescSelector) : nil;
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *WCAtlasDisplayTextForJokerMessage(id message) {
    if (WCAtlasMessageIsText(message)) {
        SEL contentSelector = NSSelectorFromString(@"GetDisplayContent");
        id value = ((id (*)(id, SEL))objc_msgSend)(message, contentSelector);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    } else if (WCAtlasMessageIsRefer(message)) {
        SEL titleSelector = NSSelectorFromString(@"m_nsTitle");
        id value = ((id (*)(id, SEL))objc_msgSend)(message, titleSelector);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    } else if (WCAtlasMessageIsTransfer(message)) {
        return WCAtlasTransferDisplayText(message);
    }
    return @"";
}

static UIViewController *WCAtlasJokerPresenterForCell(id cell) {
    return WCAtlasViewControllerForResponder(cell);
}

static void WCAtlasReloadJokerCell(id cell, id message, UIViewController *controller) {
    if (!controller) controller = WCAtlasJokerPresenterForCell(cell);
    if (!controller || !message) return;
    SEL clearSelector = NSSelectorFromString(@"clearNodeLayoutCache");
    if ([controller respondsToSelector:clearSelector]) ((void (*)(id, SEL))objc_msgSend)(controller, clearSelector);
    SEL reloadWrapSelector = NSSelectorFromString(@"reloadNodeWithMessageWrap:");
    if ([controller respondsToSelector:reloadWrapSelector]) ((void (*)(id, SEL, id))objc_msgSend)(controller, reloadWrapSelector, message);
    SEL reloadCellSelector = NSSelectorFromString(@"reloadVisibleNodeWithCellView:");
    if ([controller respondsToSelector:reloadCellSelector]) ((void (*)(id, SEL, id))objc_msgSend)(controller, reloadCellSelector, cell);
    SEL tableSelector = NSSelectorFromString(@"getMsgTableView");
    if ([controller respondsToSelector:tableSelector]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            id tableView = ((id (*)(id, SEL))objc_msgSend)(controller, tableSelector);
            if ([tableView isKindOfClass:[UITableView class]]) {
                [UIView performWithoutAnimation:^{
                    [(UITableView *)tableView beginUpdates];
                    [(UITableView *)tableView endUpdates];
                }];
            }
        });
    }
}

static NSString *WCAtlasJokerSanitizedAmountText(NSString *text) {
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar character = [text characterAtIndex:index];
        if (character == '.' || (character >= '0' && character <= '9')) {
            [result appendFormat:@"%C", character];
        }
    }
    return result.length > 0 ? result : nil;
}

static void WCAtlasApplyJokerText(id cell,
                                id message,
                                UIViewController *controller,
                                NSString *text,
                                BOOL transferContext) {
    BOOL isText = !transferContext && WCAtlasMessageIsText(message);
    BOOL isRefer = !transferContext && !isText && WCAtlasMessageIsRefer(message);
    BOOL isTransfer = transferContext || (!isText && !isRefer && WCAtlasMessageIsTransfer(message));
    if (!message || (!isText && !isRefer && !isTransfer)) return;
    BOOL changed = NO;
    if (isText) {
        NSString *original = WCAtlasDisplayTextForJokerMessage(message);
        if (text.length > 0 && ![text isEqualToString:original]) {
            ((void (*)(id, SEL, id))objc_msgSend)(message, NSSelectorFromString(@"setM_nsContent:"), text);
            changed = YES;
        }
    } else if (isRefer) {
        NSString *original = WCAtlasDisplayTextForJokerMessage(message);
        if (text.length > 0 && ![text isEqualToString:original]) {
            ((void (*)(id, SEL, id))objc_msgSend)(message, NSSelectorFromString(@"setM_nsTitle:"), text);
            changed = YES;
        }
    } else if (isTransfer) {
        if (text.length == 0) return;
        NSString *original = WCAtlasTransferDisplayText(message);
        if ([original hasPrefix:@"¥"] || [original hasPrefix:@"￥"]) {
            original = [original substringFromIndex:1];
        }
        if ([text isEqualToString:original]) return;
        NSString *amount = WCAtlasJokerSanitizedAmountText(text);
        if (amount.length == 0) return;
        id payItem = WCAtlasPayInfoItemForMessage(message);
        NSString *feeDesc = [@"¥" stringByAppendingString:amount];
        if (payItem) {
            ((void (*)(id, SEL, id))objc_msgSend)(payItem, NSSelectorFromString(@"setM_nsFeeDesc:"), feeDesc);
            ((void (*)(id, SEL, id))objc_msgSend)(payItem, NSSelectorFromString(@"setM_receiverDesc:"), feeDesc);
            ((void (*)(id, SEL, id))objc_msgSend)(payItem, NSSelectorFromString(@"setM_senderDesc:"), feeDesc);
            changed = YES;
        }
    }
    if (!changed) return;
    WCAtlasReloadJokerCell(cell, message, controller);
    WCAtlasLog(@"聊天记录小丑已修改当前页面显示");
}

static NSObject *WCAtlasImageJokerCacheLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lock = [NSObject new]; });
    return lock;
}

static NSMutableDictionary<NSString *, UIImage *> *WCAtlasImageJokerImages(void) {
    static NSMutableDictionary<NSString *, UIImage *> *images;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ images = [NSMutableDictionary dictionary]; });
    return images;
}

static NSMutableDictionary<NSString *, NSData *> *WCAtlasImageJokerData(void) {
    static NSMutableDictionary<NSString *, NSData *> *data;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ data = [NSMutableDictionary dictionary]; });
    return data;
}

static NSMutableDictionary<NSString *, NSString *> *WCAtlasImageJokerPaths(void) {
    static NSMutableDictionary<NSString *, NSString *> *paths;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ paths = [NSMutableDictionary dictionary]; });
    return paths;
}

static NSString *WCAtlasImageJokerKeyForMessage(id message) {
    if (!message) return nil;
    SEL combinedSelector = NSSelectorFromString(@"combineChatNameWithLocalId");
    if ([message respondsToSelector:combinedSelector]) {
        id combined = ((id (*)(id, SEL))objc_msgSend)(message, combinedSelector);
        if ([combined isKindOfClass:[NSString class]] && [combined length] > 0) return combined;
    }
    SEL chatSelector = NSSelectorFromString(@"GetChatName");
    SEL localIDSelector = NSSelectorFromString(@"m_uiMesLocalID");
    if (![message respondsToSelector:chatSelector] || ![message respondsToSelector:localIDSelector]) return nil;
    id chatName = ((id (*)(id, SEL))objc_msgSend)(message, chatSelector);
    if (![chatName isKindOfClass:[NSString class]] || [chatName length] == 0) return nil;
    unsigned int localID = ((unsigned int (*)(id, SEL))objc_msgSend)(message, localIDSelector);
    return localID > 0 ? [NSString stringWithFormat:@"%@_%u", chatName, localID] : nil;
}

static void WCAtlasCollectReplyTransformTargets(UIView *view,
                                               NSString *messageKey,
                                               NSMutableArray<WCAtlasReplyTransformSnapshot *> *snapshots) {
    if (!view || !messageKey.length) return;
    id message = WCAtlasMessageWrapForCell(view);
    NSString *candidateKey = WCAtlasImageJokerKeyForMessage(message);
    if ([candidateKey isEqualToString:messageKey]) {
        WCAtlasReplyTransformSnapshot *snapshot = [WCAtlasReplyTransformSnapshot new];
        snapshot.view = view;
        snapshot.transform = view.transform;
        [snapshots addObject:snapshot];
        return;
    }
    for (UIView *subview in view.subviews) WCAtlasCollectReplyTransformTargets(subview, messageKey, snapshots);
}

static NSArray<WCAtlasReplyTransformSnapshot *> *WCAtlasReplyTransformSnapshots(CommonMessageCellView *sourceCell) {
    NSString *messageKey = WCAtlasImageJokerKeyForMessage(WCAtlasMessageWrapForCell(sourceCell));
    NSMutableArray<WCAtlasReplyTransformSnapshot *> *snapshots = [NSMutableArray array];
    if (messageKey.length && sourceCell.window) {
        WCAtlasCollectReplyTransformTargets(sourceCell.window, messageKey, snapshots);
    }
    if (snapshots.count == 0 && sourceCell) {
        WCAtlasReplyTransformSnapshot *snapshot = [WCAtlasReplyTransformSnapshot new];
        snapshot.view = sourceCell;
        snapshot.transform = sourceCell.transform;
        [snapshots addObject:snapshot];
    }
    return snapshots;
}

static void WCAtlasApplyReplyTransform(NSArray<WCAtlasReplyTransformSnapshot *> *snapshots, CGFloat offset) {
    for (WCAtlasReplyTransformSnapshot *snapshot in snapshots) {
        UIView *view = snapshot.view;
        if (view.window) view.transform = CGAffineTransformTranslate(snapshot.transform, offset, 0.0);
    }
}

static void WCAtlasRestoreReplyTransforms(NSArray<WCAtlasReplyTransformSnapshot *> *snapshots) {
    for (WCAtlasReplyTransformSnapshot *snapshot in snapshots) {
        if (snapshot.view) snapshot.view.transform = snapshot.transform;
    }
}

static id WCAtlasImageJokerMessageForObject(id object) {
    if (!object) return nil;
    Class messageClass = NSClassFromString(@"CMessageWrap");
    if (messageClass && [object isKindOfClass:messageClass]) return object;
    id message = WCAtlasTweakValueForSelectorNames(object, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
    if (message) return message;
    id viewModel = WCAtlasTweakValueForSelectorNames(object, @[@"viewModel", @"m_viewModel"]);
    return WCAtlasTweakValueForSelectorNames(viewModel, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
}

static UIImage *WCAtlasImageJokerImageForMessage(id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return nil;
    NSString *key = WCAtlasImageJokerKeyForMessage(message);
    if (key.length == 0) return nil;
    @synchronized (WCAtlasImageJokerCacheLock()) {
        return WCAtlasImageJokerImages()[key];
    }
}

static NSData *WCAtlasImageJokerDataForMessage(id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return nil;
    NSString *key = WCAtlasImageJokerKeyForMessage(message);
    if (key.length == 0) return nil;
    @synchronized (WCAtlasImageJokerCacheLock()) {
        return WCAtlasImageJokerData()[key];
    }
}

static NSString *WCAtlasImageJokerPathForMessage(id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return nil;
    NSString *key = WCAtlasImageJokerKeyForMessage(message);
    if (key.length == 0) return nil;
    @synchronized (WCAtlasImageJokerCacheLock()) {
        return WCAtlasImageJokerPaths()[key];
    }
}

static UIImage *WCAtlasImageJokerImageForObject(id object) {
    return WCAtlasImageJokerImageForMessage(WCAtlasImageJokerMessageForObject(object));
}

static CGSize WCAtlasImageJokerDisplaySize(UIImage *image) {
    CGSize imageSize = image.size;
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0 ||
        !isfinite(imageSize.width) || !isfinite(imageSize.height)) return CGSizeZero;

    CGFloat ratio = imageSize.width / imageSize.height;
    CGFloat width = 0.0;
    CGFloat height = 0.0;
    if (ratio < 1.0) {
        height = 180.0;
        width = ratio * height;
        if (width < 76.0) {
            width = 76.0;
            height = width / ratio;
        }
        if (width > 135.0) {
            width = 135.0;
            height = width / ratio;
        }
    } else {
        width = 180.0;
        height = width / ratio;
        if (height < 76.0) {
            height = 76.0;
            width = ratio * height;
        }
        if (height > 135.0) {
            height = 135.0;
            width = ratio * height;
        }
    }
    return CGSizeMake(floor(MAX(1.0, width)), floor(MAX(1.0, height)));
}

static NSString *WCAtlasImageJokerTemporaryDirectory(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"wxi_image_joker"];
}

static NSString *WCAtlasImageJokerSafeFilename(NSString *key) {
    NSMutableString *name = [NSMutableString stringWithCapacity:MIN((NSUInteger)80, key.length)];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
    for (NSUInteger index = 0; index < key.length && name.length < 80; index++) {
        unichar character = [key characterAtIndex:index];
        if ([allowed characterIsMember:character]) [name appendFormat:@"%C", character];
        else [name appendString:@"_"];
    }
    return [(name.length > 0 ? name : [@"image" mutableCopy]) stringByAppendingPathExtension:@"jpg"];
}

static BOOL WCAtlasStoreImageJokerOverride(id message, UIImage *image) {
    NSString *key = WCAtlasImageJokerKeyForMessage(message);
    if (key.length == 0 || ![image isKindOfClass:[UIImage class]]) return NO;
    NSData *data = UIImageJPEGRepresentation(image, 0.95);
    if (data.length == 0) data = UIImagePNGRepresentation(image);
    if (data.length == 0) return NO;
    NSString *directory = WCAtlasImageJokerTemporaryDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [directory stringByAppendingPathComponent:WCAtlasImageJokerSafeFilename(key)];
    if (![data writeToFile:path options:NSDataWritingAtomic error:nil]) path = nil;
    @synchronized (WCAtlasImageJokerCacheLock()) {
        WCAtlasImageJokerImages()[key] = image;
        WCAtlasImageJokerData()[key] = data;
        if (path.length > 0) WCAtlasImageJokerPaths()[key] = path;
        else [WCAtlasImageJokerPaths() removeObjectForKey:key];
    }
    return YES;
}

static void WCAtlasClearImageJokerOverrides(void) {
    @synchronized (WCAtlasImageJokerCacheLock()) {
        [WCAtlasImageJokerImages() removeAllObjects];
        [WCAtlasImageJokerData() removeAllObjects];
        [WCAtlasImageJokerPaths() removeAllObjects];
    }
    [[NSFileManager defaultManager] removeItemAtPath:WCAtlasImageJokerTemporaryDirectory() error:nil];
}

static void WCAtlasApplyImageJokerToCell(id cell, id message, UIImage *image) {
    id imageView = WCAtlasTweakSafeValue(cell, @"m_imageView");
    if ([imageView isKindOfClass:[UIImageView class]]) ((UIImageView *)imageView).image = image;
    id viewModel = WCAtlasTweakValueForSelectorNames(cell, @[@"viewModel", @"m_viewModel"]);
    SEL resetSelector = NSSelectorFromString(@"resetLayoutCache");
    if ([viewModel respondsToSelector:resetSelector]) ((void (*)(id, SEL))objc_msgSend)(viewModel, resetSelector);
    WCAtlasReloadJokerCell(cell, message, WCAtlasJokerPresenterForCell(cell));
}

@interface WCAtlasImageJokerPickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, weak) id cell;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) id message;
@end

@implementation WCAtlasImageJokerPickerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (![image isKindOfClass:[UIImage class]]) image = info[UIImagePickerControllerEditedImage];
    id cell = self.cell;
    id message = self.message;
    if (image && message && WCAtlasStoreImageJokerOverride(message, image)) {
        if (cell) WCAtlasApplyImageJokerToCell(cell, message, image);
        WCAtlasCompatibilityMarkTriggered(@"image-joker");
        WCAtlasCompatibilityMarkTriggered(@"chat-joker");
        WCAtlasLog(@"聊天图片已在当前页面伪装");
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

static void WCAtlasPresentImageJokerPickerForCell(id cell) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return;
    id message = WCAtlasMessageWrapForCell(cell);
    UIViewController *presenter = WCAtlasJokerPresenterForCell(cell);
    if (!message || !presenter.view.window ||
        ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    WCAtlasImageJokerPickerDelegate *delegate = [WCAtlasImageJokerPickerDelegate new];
    delegate.cell = cell;
    delegate.presenter = presenter;
    delegate.message = message;
    picker.delegate = delegate;
    objc_setAssociatedObject(picker, &WCAtlasImageJokerPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}

static NSArray *WCAtlasOperationMenuItemsWithImageJoker(id target, NSArray *originalItems) {
    if (![originalItems isKindOfClass:[NSArray class]]) return originalItems;
    NSMutableArray *items = [originalItems mutableCopy];
    if (WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey) && WCAtlasMessageWrapForCell(target)) {
        BOOL exists = NO;
        for (id item in items) {
            if ([WCAtlasTweakSafeValue(item, @"title") isEqualToString:@"修改图片"]) { exists = YES; break; }
        }
        if (!exists) {
            Class itemClass = NSClassFromString(@"MMMenuItem");
            if ([itemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) {
                UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightRegular];
                UIImage *icon = [UIImage systemImageNamed:@"photo.badge.pencil" withConfiguration:configuration];
                if (!icon) icon = [UIImage systemImageNamed:@"square.and.pencil" withConfiguration:configuration];
                icon = [icon imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                MMMenuItem *menuItem = [[itemClass alloc] initWithTitle:@"修改图片" icon:icon target:target action:@selector(joker_handleImageMenuItem:)];
                if (menuItem) [items insertObject:menuItem atIndex:0];
            }
        }
    }
    return items;
}

static id WCAtlasEmoticonExtendInfoForCell(id cell, NSString *expectedClassName) {
    id message = WCAtlasMessageWrapForCell(cell);
    id extendInfo = WCAtlasTweakValueForSelectorNames(message, @[@"m_extendInfoWithMsgType"]);
    Class expectedClass = NSClassFromString(expectedClassName);
    if (!extendInfo || (expectedClass && ![extendInfo isKindOfClass:expectedClass])) return nil;
    return extendInfo;
}

static NSData *WCAtlasEmoticonDataForMD5(NSString *md5, BOOL needUpdateTime) {
    if (![md5 isKindOfClass:[NSString class]] || md5.length == 0) return nil;
    Class utilClass = NSClassFromString(@"EmoticonUtil");
    SEL existsSelector = NSSelectorFromString(@"fileExistOfEmoticonForMd5:");
    SEL dataSelector = NSSelectorFromString(@"dataOfEmoticonForMd5:needUpdateTime:ignoreWxAM:");
    if (!utilClass || ![utilClass respondsToSelector:existsSelector] || ![utilClass respondsToSelector:dataSelector]) return nil;
    if (!((BOOL (*)(id, SEL, id))objc_msgSend)(utilClass, existsSelector, md5)) return nil;
    id data = ((id (*)(id, SEL, id, BOOL, BOOL))objc_msgSend)(utilClass, dataSelector, md5, needUpdateTime, NO);
    return [data isKindOfClass:[NSData class]] && [data length] > 0 ? data : nil;
}

static id WCAtlasEmoticonAddLogicController(void) {
    static id controller;
    @synchronized ([NSObject class]) {
        if (!controller) {
            Class controllerClass = NSClassFromString(@"EmoticonCustomAddLogicController");
            if (controllerClass) controller = [controllerClass new];
        }
    }
    return controller;
}

static BOOL WCAtlasSaveDataAsSelfieEmoticon(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0) return NO;
    Class fileClass = NSClassFromString(@"CBaseFile");
    Class uploadClass = NSClassFromString(@"EmoticonUploadInfoObj");
    Class utilClass = NSClassFromString(@"EmoticonUtil");
    SEL md5Selector = NSSelectorFromString(@"GetDataMD5:");
    if (!fileClass || !uploadClass || !utilClass || ![fileClass respondsToSelector:md5Selector]) return NO;

    NSString *md5 = ((id (*)(id, SEL, id))objc_msgSend)(fileClass, md5Selector, data);
    id uploadInfo = [uploadClass new];
    if (![md5 isKindOfClass:[NSString class]] || md5.length == 0 || !uploadInfo) return NO;

    SEL setUploadMD5 = NSSelectorFromString(@"setUploadImgMd5:");
    SEL setIsSelfie = NSSelectorFromString(@"setIsSelfie:");
    SEL setScene = NSSelectorFromString(@"setSelfieScene:");
    SEL setWXAM = NSSelectorFromString(@"setIsUploadWxam:");
    SEL setEnterTime = NSSelectorFromString(@"setSelfieEnterTime:");
    SEL setLensID = NSSelectorFromString(@"setLensId:");
    SEL saveTemp = NSSelectorFromString(@"saveImgDataToTempPathWithImgData:");
    NSArray<NSString *> *requiredSelectors = @[
        NSStringFromSelector(setUploadMD5), NSStringFromSelector(setIsSelfie), NSStringFromSelector(setScene),
        NSStringFromSelector(setWXAM), NSStringFromSelector(setEnterTime), NSStringFromSelector(setLensID),
        NSStringFromSelector(saveTemp),
    ];
    for (NSString *selectorName in requiredSelectors) {
        if (![uploadInfo respondsToSelector:NSSelectorFromString(selectorName)]) return NO;
    }

    ((void (*)(id, SEL, id))objc_msgSend)(uploadInfo, setUploadMD5, md5);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(uploadInfo, setIsSelfie, YES);
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(uploadInfo, setScene, 2);
    SEL isWXAMSelector = NSSelectorFromString(@"isWxAMData:");
    BOOL isWXAM = [utilClass respondsToSelector:isWXAMSelector]
        ? ((BOOL (*)(id, SEL, id))objc_msgSend)(utilClass, isWXAMSelector, data)
        : NO;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(uploadInfo, setWXAM, isWXAM);

    NSTimeInterval timestamp = NSDate.date.timeIntervalSince1970;
    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(uploadInfo, setEnterTime, (unsigned long long)timestamp);
    ((void (*)(id, SEL, id))objc_msgSend)(uploadInfo, setLensID, [NSString stringWithFormat:@"%.0f", timestamp]);
    BOOL saved = ((BOOL (*)(id, SEL, id))objc_msgSend)(uploadInfo, saveTemp, data);
    if (!saved) return NO;

    id controller = WCAtlasEmoticonAddLogicController();
    SEL handleSelector = NSSelectorFromString(@"handleEmoticonUploadInfo:source:");
    if (!controller || ![controller respondsToSelector:handleSelector]) return NO;
    ((void (*)(id, SEL, id, NSUInteger))objc_msgSend)(controller, handleSelector, uploadInfo, 7);
    WCAtlasCompatibilityMarkTriggered(@"emoticon-to-selfie");
    return YES;
}

static BOOL WCAtlasSaveCellEmoticonAsSelfie(id cell, NSString *extendInfoClassName, BOOL needUpdateTime) {
    id extendInfo = WCAtlasEmoticonExtendInfoForCell(cell, extendInfoClassName);
    NSString *md5 = WCAtlasTweakValueForSelectorNames(extendInfo, @[@"m_nsEmoticonMD5"]);
    NSData *data = WCAtlasEmoticonDataForMD5(md5, needUpdateTime);
    return WCAtlasSaveDataAsSelfieEmoticon(data);
}

static NSArray *WCAtlasMenuItemsWithEmoticonToSelfie(id target, NSArray *originalItems, NSString *extendInfoClassName) {
    if (![originalItems isKindOfClass:[NSArray class]] || !WCAtlasEnhancementEnabled(WCAtlasEmoticonToSelfieEnabledKey)) return originalItems;
    if (!WCAtlasEmoticonExtendInfoForCell(target, extendInfoClassName)) return originalItems;
    for (id item in originalItems) {
        if ([WCAtlasTweakSafeValue(item, @"title") isEqualToString:@"存入自拍"]) return originalItems;
    }

    Class itemClass = NSClassFromString(@"MMMenuItem");
    if (!itemClass) return originalItems;
    id menuItem = nil;
    SEL action = NSSelectorFromString(@"wcatlas_saveEmoticonAsSelfie");
    SEL targetInitializer = NSSelectorFromString(@"initWithTitle:svgName:target:action:");
    SEL initializer = NSSelectorFromString(@"initWithTitle:svgName:action:");
    if ([itemClass instancesRespondToSelector:targetInitializer]) {
        menuItem = ((id (*)(id, SEL, id, id, id, SEL))objc_msgSend)([itemClass alloc], targetInitializer,
            @"存入自拍", @"icons_outlined_takephoto_nor", target, action);
    } else if ([itemClass instancesRespondToSelector:initializer]) {
        menuItem = ((id (*)(id, SEL, id, id, SEL))objc_msgSend)([itemClass alloc], initializer,
            @"存入自拍", @"icons_outlined_takephoto_nor", action);
    }
    if (!menuItem) return originalItems;
    NSMutableArray *items = [originalItems mutableCopy];
    [items addObject:menuItem];
    return items;
}

static NSData *WCAtlasPreviewEmoticonData(id controller) {
    id popoverView = WCAtlasTweakValueForSelectorNames(controller, @[@"popoverView"]);
    SEL downloadedSelector = NSSelectorFromString(@"checkIfEmojiDownloaded");
    if ([popoverView respondsToSelector:downloadedSelector] &&
        !((BOOL (*)(id, SEL))objc_msgSend)(popoverView, downloadedSelector)) return nil;
    id model = WCAtlasTweakValueForSelectorNames(popoverView, @[@"model"]);
    id emoticonWrap = WCAtlasTweakValueForSelectorNames(model, @[@"emoticonWrap"]);
    SEL selfieSelector = NSSelectorFromString(@"isSelfieEmoticon");
    if ([emoticonWrap respondsToSelector:selfieSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(emoticonWrap, selfieSelector)) return nil;
    id imageData = WCAtlasTweakValueForSelectorNames(emoticonWrap, @[@"m_imageData"]);
    if ([imageData isKindOfClass:[NSData class]] && [imageData length] > 0) return imageData;
    NSString *md5 = WCAtlasTweakValueForSelectorNames(emoticonWrap, @[@"m_nsEmoticonMD5"]);
    return WCAtlasEmoticonDataForMD5(md5, YES);
}

static NSString *WCAtlasAdBlockerRewrittenURLString(NSString *URLString) {
    if (!WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey) ||
        ![URLString isKindOfClass:[NSString class]]) return URLString;
    static NSArray<NSString *> *blockedFragments;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedFragments = @[
            @"mp.weixin.qq.com/mp/getappmsgad",
            @"wxsnsdy.wxs.qq.com",
            @"wxsnsdy.tc.qq.com",
            @"wxsnsdy.video.qq.com",
            @"wxsnsdythumb.wxs.qq.com",
            @"ad_data",
            @"/wxfile://usr/ad/",
            @"/ad.wx.com",
            @"lib/WASplashadWorker.js",
            @"lib/WAAppAd.js",
        ];
    });
    for (NSString *fragment in blockedFragments) {
        if ([URLString containsString:fragment]) return @"/t";
    }
    return URLString;
}

static UITextView *WCAtlasInnerTextView(id growTextView) {
    id textView = WCAtlasTweakSafeValue(growTextView, @"textView");
    if (![textView isKindOfClass:[UITextView class]]) textView = WCAtlasTweakSafeValue(growTextView, @"_textView");
    return [textView isKindOfClass:[UITextView class]] ? textView : nil;
}

static void WCAtlasSynchronizeInputSwipeActions(MMGrowTextView *view) {
    if (!view) return;
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasInputSwipeActionsEnabledKey);
    UISwipeGestureRecognizer *left = objc_getAssociatedObject(view, &WCAtlasInputSwipeLeftRecognizerKey);
    UISwipeGestureRecognizer *right = objc_getAssociatedObject(view, &WCAtlasInputSwipeRightRecognizerKey);
    if (enabled) {
        WCAtlasCompatibilityMarkTriggered(@"input-swipe");
        if (!left) {
            left = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wcatlas_handleInputSwipeLeft:)];
            left.direction = UISwipeGestureRecognizerDirectionLeft;
            left.cancelsTouchesInView = NO;
            [view addGestureRecognizer:left];
            objc_setAssociatedObject(view, &WCAtlasInputSwipeLeftRecognizerKey, left, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!right) {
            right = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wcatlas_handleInputSwipeRight:)];
            right.direction = UISwipeGestureRecognizerDirectionRight;
            right.cancelsTouchesInView = NO;
            [view addGestureRecognizer:right];
            objc_setAssociatedObject(view, &WCAtlasInputSwipeRightRecognizerKey, right, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (left) {
        [view removeGestureRecognizer:left];
        objc_setAssociatedObject(view, &WCAtlasInputSwipeLeftRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (right) {
        [view removeGestureRecognizer:right];
        objc_setAssociatedObject(view, &WCAtlasInputSwipeRightRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasSynchronizeQuickReplyPlusGesture(MMInputToolView *view) {
    if (!view) return;
    UILongPressGestureRecognizer *recognizer = objc_getAssociatedObject(view, &WCAtlasQuickReplyPlusRecognizerKey);
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey) && view.window;
    if (enabled && !recognizer) {
        WCAtlasQuickReplyPlusGestureDelegate *delegate = [WCAtlasQuickReplyPlusGestureDelegate new];
        delegate.toolView = view;
        recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:view
                                                                   action:@selector(wcatlas_handleQuickReplyPlusLongPress:)];
        recognizer.minimumPressDuration = 0.55;
        recognizer.cancelsTouchesInView = YES;
        recognizer.delegate = delegate;
        [view addGestureRecognizer:recognizer];
        objc_setAssociatedObject(view, &WCAtlasQuickReplyPlusRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &WCAtlasQuickReplyPlusDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!enabled && recognizer) {
        [view removeGestureRecognizer:recognizer];
        objc_setAssociatedObject(view, &WCAtlasQuickReplyPlusRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &WCAtlasQuickReplyPlusDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasSynchronizeChatTTSGesture(MMInputToolView *view) {
    if (!view) return;
    UIView *oldButton = objc_getAssociatedObject(view, &WCAtlasChatTTSButtonKey);
    UILongPressGestureRecognizer *recognizer = objc_getAssociatedObject(view, &WCAtlasChatTTSRecognizerKey);
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasChatTTSEnabledKey) && view.window;
    UIView *button = enabled
        ? WCAtlasTweakValueForSelectorNames(view, @[@"inputModeChangeButton", @"_inputModeChangeButton"])
        : nil;
    if (![button isKindOfClass:UIView.class]) button = nil;
    if (recognizer && (!enabled || oldButton != button)) {
        [oldButton removeGestureRecognizer:recognizer];
        objc_setAssociatedObject(view, &WCAtlasChatTTSRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &WCAtlasChatTTSButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        recognizer = nil;
    }
    if (enabled && button && !recognizer) {
        recognizer = [[UILongPressGestureRecognizer alloc]
            initWithTarget:view action:@selector(wcatlas_handleChatTTSLongPress:)];
        recognizer.minimumPressDuration = 0.55;
        recognizer.cancelsTouchesInView = YES;
        [button addGestureRecognizer:recognizer];
        objc_setAssociatedObject(view, &WCAtlasChatTTSRecognizerKey, recognizer,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &WCAtlasChatTTSButtonKey, button,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static id WCAtlasContactForUserName(NSString *userName) {
    return WCAtlasPrivateContact(userName);
}

static id WCAtlasMessageChatContact(id message) {
    if (!message) return nil;
    Class contactManagerClass = objc_getClass("CContactMgr");
    id manager = contactManagerClass ? WCAtlasServiceForClass(contactManagerClass) : nil;
    SEL selector = sel_registerName("getMessageChatContactByMessageWrap:");
    if (!manager || ![manager respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL, id))objc_msgSend)(manager, selector, message);
}

static UIView *WCAtlasAvatarHeadViewForCell(CommonMessageCellView *cell) {
    id candidate = WCAtlasTweakValueForSelectorNames(cell, @[@"getHeadImageView", @"m_headImageView", @"headImageView"]);
    if (!candidate) candidate = WCAtlasTweakSafeValue(cell, @"m_headImageView");
    if ([candidate isKindOfClass:UIView.class]) return candidate;
    Class headViewClass = NSClassFromString(@"MMHeadImageView");
    if (!headViewClass) return nil;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithArray:cell.subviews ?: @[]];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        if ([view isKindOfClass:headViewClass]) return view;
        if (view.subviews.count) [pending addObjectsFromArray:view.subviews];
    }
    return nil;
}

static CommonMessageCellView *WCAtlasAvatarMessageCellForView(UIView *view) {
    Class cellClass = NSClassFromString(@"CommonMessageCellView");
    UIView *candidate = view.superview;
    while (candidate) {
        if (cellClass && [candidate isKindOfClass:cellClass]) return (CommonMessageCellView *)candidate;
        candidate = candidate.superview;
    }
    return nil;
}

static void WCAtlasResolveAvatarGestureConflicts(UIView *headView, UIGestureRecognizer *ownedRecognizer) {
    if (!headView || !ownedRecognizer) return;
    NSArray<UIGestureRecognizer *> *recognizers = [headView.gestureRecognizers copy];
    for (UIGestureRecognizer *recognizer in recognizers) {
        if (recognizer == ownedRecognizer) continue;
        if ([ownedRecognizer isKindOfClass:UITapGestureRecognizer.class] &&
            [recognizer isKindOfClass:UITapGestureRecognizer.class]) {
            UITapGestureRecognizer *ownedTap = (UITapGestureRecognizer *)ownedRecognizer;
            UITapGestureRecognizer *nativeTap = (UITapGestureRecognizer *)recognizer;
            if (ownedTap.numberOfTapsRequired > nativeTap.numberOfTapsRequired) {
                [nativeTap requireGestureRecognizerToFail:ownedTap];
            }
        } else if ([ownedRecognizer isKindOfClass:UILongPressGestureRecognizer.class] &&
                   [recognizer isKindOfClass:UILongPressGestureRecognizer.class]) {
            [recognizer requireGestureRecognizerToFail:ownedRecognizer];
        }
    }
}

static BOOL WCAtlasConfigureNativeAvatarDoubleTap(UIView *headView,
                                                WCAtlasAvatarQuickGestureProxy *proxy,
                                                BOOL enabled) {
    SEL setter = NSSelectorFromString(@"setTargetForDoubleClick:action:");
    if (![headView respondsToSelector:setter]) return NO;
    WCAtlasWeakObjectBox *originalTargetBox = objc_getAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapTargetKey);
    NSString *originalActionName = objc_getAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapActionKey);
    BOOL owned = [objc_getAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapOwnedKey) boolValue];
    if (enabled) {
        if (!originalTargetBox.object || originalActionName.length == 0) return NO;
        WCAtlasUpdatingAvatarNativeDoubleTap = YES;
        ((void (*)(id, SEL, id, SEL))objc_msgSend)(headView, setter, proxy, @selector(handleGesture:));
        WCAtlasUpdatingAvatarNativeDoubleTap = NO;
        objc_setAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapOwnedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    }
    if (owned) {
        SEL originalAction = NSSelectorFromString(originalActionName);
        WCAtlasUpdatingAvatarNativeDoubleTap = YES;
        ((void (*)(id, SEL, id, SEL))objc_msgSend)(headView, setter, originalTargetBox.object, originalAction);
        WCAtlasUpdatingAvatarNativeDoubleTap = NO;
        objc_setAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapOwnedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return NO;
}

static UIImage *WCAtlasFirstImageInView(UIView *view) {
    if ([view isKindOfClass:UIImageView.class] && ((UIImageView *)view).image) return ((UIImageView *)view).image;
    for (UIView *subview in view.subviews) {
        UIImage *image = WCAtlasFirstImageInView(subview);
        if (image) return image;
    }
    return nil;
}

static UIImage *WCAtlasAvatarSnapshot(UIView *view) {
    UIImage *image = WCAtlasFirstImageInView(view);
    CGSize size = view.bounds.size;
    if (image || size.width <= 0.0 || size.height <= 0.0) return image;
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context) [view.layer renderInContext:context];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static NSString *WCAtlasAvatarDisplayName(id contact, NSString *fallback) {
    return WCAtlasPrivateContactDisplayName(contact, fallback) ?: @"";
}

static UIViewController *WCAtlasAvatarOwningViewController(UIView *view) {
    UIViewController *nearestController = nil;
    UIResponder *responder = view;
    Class chatControllerClass = NSClassFromString(@"BaseMsgContentViewController");
    while ((responder = responder.nextResponder)) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UIViewController *controller = (UIViewController *)responder;
        if (!nearestController) nearestController = controller;
        for (UIViewController *candidate = controller; candidate; candidate = candidate.parentViewController) {
            if (chatControllerClass && [candidate isKindOfClass:chatControllerClass]) return candidate;
        }
    }
    return nearestController;
}

static NSString *WCAtlasAvatarTargetUserName(CommonMessageCellView *cell, NSString *chatUserName) {
    id message = WCAtlasMessageWrapForCell(cell);
    NSString *currentUser = WCAtlasCurrentUserWXID();
    if (WCAtlasMessageCellIsSender(cell)) return currentUser;
    if ([chatUserName hasSuffix:@"@chatroom"]) {
        for (NSString *key in @[@"m_nsRealChatUsr", @"m_nsRealChatUsrName", @"realChatUserName", @"m_nsFromUsr"]) {
            id value = WCAtlasTweakValueForSelectorNames(message, @[key]);
            if (!value) value = WCAtlasTweakSafeValue(message, key);
            if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![value hasSuffix:@"@chatroom"]) return value;
        }
        return nil;
    }
    return chatUserName;
}

static void WCAtlasInvokeNativeAvatarDoubleTap(CommonMessageCellView *cell, UIView *headView) {
    WCAtlasWeakObjectBox *targetBox = objc_getAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapTargetKey);
    NSString *actionName = objc_getAssociatedObject(headView, &WCAtlasAvatarNativeDoubleTapActionKey);
    id target = targetBox.object;
    SEL action = actionName.length ? NSSelectorFromString(actionName) : NULL;
    if (target && action && [target respondsToSelector:action]) {
        ((void (*)(id, SEL, id))objc_msgSend)(target, action, headView);
        return;
    }
    SEL cellAction = NSSelectorFromString(@"onHeadImageDoubleClick:");
    if (cell && [cell respondsToSelector:cellAction]) {
        ((void (*)(id, SEL, id))objc_msgSend)(cell, cellAction, headView);
        return;
    }
    WCAtlasShowTransientMessage(@"当前微信版本不支持拍一拍", NO);
}

static void WCAtlasInvokeNativeAvatarLongPress(CommonMessageCellView *cell, UIView *headView) {
    SEL selector = NSSelectorFromString(@"onHeadImageLongPressed:");
    if (!cell || !headView || ![cell respondsToSelector:selector]) {
        WCAtlasShowTransientMessage(@"当前微信版本不支持艾特", NO);
        return;
    }
    WCAtlasPerformingNativeAvatarLongPress = YES;
    ((void (*)(id, SEL, id))objc_msgSend)(cell, selector, headView);
    WCAtlasPerformingNativeAvatarLongPress = NO;
}

static void WCAtlasOpenAvatarProfile(UIViewController *chatController, UIView *headView, id contact) {
    (void)headView;
    NSString *userName = WCAtlasPrivateContactUserName(contact);
    if (userName.length == 0 || !WCAtlasPushPrivateContactProfile(chatController, userName)) {
        WCAtlasShowTransientMessage(@"当前微信版本无法打开资料页", NO);
    }
}

static void WCAtlasClearPendingExclusiveRedEnvelope(void) {
    WCAtlasPendingExclusiveRedEnvelopeContact = nil;
    WCAtlasPendingExclusiveRedEnvelopeGroupID = nil;
    WCAtlasPendingExclusiveRedEnvelopeDeadline = 0.0;
}

static NSString *WCAtlasContactUserName(id contact) {
    if ([contact isKindOfClass:NSString.class]) return contact;
    return WCAtlasPrivateContactUserName(contact);
}

static void WCAtlasPrepareExclusiveRedEnvelopeData(id data) {
    if (!data || !WCAtlasPendingExclusiveRedEnvelopeContact ||
        WCAtlasPendingExclusiveRedEnvelopeGroupID.length == 0 ||
        CACurrentMediaTime() > WCAtlasPendingExclusiveRedEnvelopeDeadline) {
        if (CACurrentMediaTime() > WCAtlasPendingExclusiveRedEnvelopeDeadline) {
            WCAtlasClearPendingExclusiveRedEnvelope();
        }
        return;
    }
    id selectedConversation = WCAtlasTweakValueForSelectorNames(data, @[@"m_oSelectContact"]);
    if (!selectedConversation) selectedConversation = WCAtlasTweakSafeValue(data, @"m_oSelectContact");
    NSString *selectedUserName = WCAtlasContactUserName(selectedConversation);
    if (![selectedUserName isEqualToString:WCAtlasPendingExclusiveRedEnvelopeGroupID]) return;

    id targetContact = WCAtlasPendingExclusiveRedEnvelopeContact;
    SEL memberSelector = NSSelectorFromString(@"setSelectedMemberContact:");
    if ([data respondsToSelector:memberSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(data, memberSelector, targetContact);
    }
    objc_setAssociatedObject(data, &WCAtlasExclusiveRedEnvelopeContactKey,
                             targetContact, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasClearPendingExclusiveRedEnvelope();
}

static void WCAtlasOpenAvatarExclusiveRedEnvelope(id chatController,
                                                 id targetContact,
                                                 NSString *groupID) {
    SEL selector = NSSelectorFromString(@"redEnvelopesLogic");
    if (![chatController respondsToSelector:selector]) {
        WCAtlasShowTransientMessage(@"当前页面无法发红包", NO);
        return;
    }
    if (!targetContact || groupID.length == 0 || ![groupID hasSuffix:@"@chatroom"]) {
        WCAtlasShowTransientMessage(@"未取得群成员资料", NO);
        return;
    }
    NSUInteger generation = ++WCAtlasPendingExclusiveRedEnvelopeGeneration;
    WCAtlasPendingExclusiveRedEnvelopeContact = targetContact;
    WCAtlasPendingExclusiveRedEnvelopeGroupID = [groupID copy];
    WCAtlasPendingExclusiveRedEnvelopeDeadline = CACurrentMediaTime() + 2.0;
    @try {
        ((id (*)(id, SEL))objc_msgSend)(chatController, selector);
    } @catch (NSException *exception) {
        if (generation == WCAtlasPendingExclusiveRedEnvelopeGeneration) {
            WCAtlasClearPendingExclusiveRedEnvelope();
        }
        WCAtlasLog(@"打开专属红包失败：%@", exception.reason ?: exception.name);
        WCAtlasShowTransientMessage(@"打开红包失败", NO);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (generation == WCAtlasPendingExclusiveRedEnvelopeGeneration) {
            WCAtlasClearPendingExclusiveRedEnvelope();
        }
    });
}

static void WCAtlasOpenAvatarTransfer(id chatController, NSString *targetUserName, id targetContact, NSString *chatUserName) {
    Class dataClass = NSClassFromString(@"WCPayControlData");
    Class managerClass = NSClassFromString(@"WCPayControlMgr");
    id data = dataClass ? [dataClass new] : nil;
    id manager = managerClass ? WCAtlasServiceForClass(managerClass) : nil;
    SEL startSelector = NSSelectorFromString(@"startTransferMoneyLogic:Data:");
    if (!data || !manager || ![manager respondsToSelector:startSelector]) {
        WCAtlasShowTransientMessage(@"当前微信版本无法发起转账", NO);
        return;
    }
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray arrayWithArray:@[
        @{@"selector": @"setM_nsSelectedUserNameFromQRCode:", @"value": targetUserName ?: @""},
        @{@"selector": @"setM_oSelectedContact:", @"value": targetContact ?: NSNull.null},
    ]];
    if ([chatUserName hasSuffix:@"@chatroom"]) {
        [entries addObject:@{@"selector": @"setSelectedTransferChatroomUsername:", @"value": chatUserName}];
    }
    for (NSDictionary *entry in entries) {
        id value = entry[@"value"];
        if (value == NSNull.null) continue;
        SEL selector = NSSelectorFromString(entry[@"selector"]);
        if ([data respondsToSelector:selector]) ((void (*)(id, SEL, id))objc_msgSend)(data, selector, value);
    }
    Class recorderClass = NSClassFromString(@"WeChat.WCPaySessionInfoRecorder");
    SEL chatTypeSelector = NSSelectorFromString(@"chatTypeValueFromTalker:");
    SEL sendTypeSelector = NSSelectorFromString(@"commonSendTypeValue");
    SEL setChatTypeSelector = NSSelectorFromString(@"setSessionChatType:");
    SEL setSendTypeSelector = NSSelectorFromString(@"setSessionSendType:");
    if (recorderClass && [recorderClass respondsToSelector:chatTypeSelector] &&
        [data respondsToSelector:setChatTypeSelector]) {
        NSInteger chatType = ((NSInteger (*)(id, SEL, id))objc_msgSend)(recorderClass,
                                                                         chatTypeSelector,
                                                                         chatUserName ?: targetUserName);
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(data, setChatTypeSelector, chatType);
    }
    if (recorderClass && [recorderClass respondsToSelector:sendTypeSelector] &&
        [data respondsToSelector:setSendTypeSelector]) {
        NSInteger sendType = ((NSInteger (*)(id, SEL))objc_msgSend)(recorderClass, sendTypeSelector);
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(data, setSendTypeSelector, sendType);
    }
    SEL contactTypeSelector = NSSelectorFromString(@"m_uiType");
    SEL setTypeSelector = NSSelectorFromString(@"setM_uiType:");
    if (targetContact && [targetContact respondsToSelector:contactTypeSelector] &&
        [targetContact respondsToSelector:setTypeSelector]) {
        NSUInteger contactType = ((NSUInteger (*)(id, SEL))objc_msgSend)(targetContact, contactTypeSelector);
        if ((contactType & 1U) == 0) {
            ((void (*)(id, SEL, NSUInteger))objc_msgSend)(targetContact, setTypeSelector, contactType | 1U);
        }
    }
    ((void (*)(id, SEL, id, id))objc_msgSend)(manager, startSelector, chatController, data);
}

static void WCAtlasOpenGroupMemberHistory(UIViewController *presenter,
                                        NSString *chatRoomUserName,
                                        id memberContact) {
    if (!presenter || ![chatRoomUserName hasSuffix:@"@chatroom"] || !memberContact) {
        WCAtlasShowTransientMessage(@"未取得群成员资料", NO);
        return;
    }
    Class controllerClass = NSClassFromString(@"ChatRoomMemMsgListViewController");
    SEL initializer = NSSelectorFromString(@"initWithChat:memContact:");
    Method method = controllerClass ? class_getInstanceMethod(controllerClass, initializer) : NULL;
    if (!method || method_getNumberOfArguments(method) != 4 ||
        !WCAtlasMethodReturnsObject(method) ||
        !WCAtlasMethodArgumentIsObject(method, 2) ||
        !WCAtlasMethodArgumentIsObject(method, 3)) {
        WCAtlasShowTransientMessage(@"当前微信版本不支持成员聊天记录", NO);
        return;
    }
    UIViewController *controller = nil;
    @try {
        controller = ((id (*)(id, SEL, id, id))objc_msgSend)([controllerClass alloc],
                                                              initializer,
                                                              chatRoomUserName,
                                                              memberContact);
    } @catch (NSException *exception) {
        WCAtlasLog(@"打开群成员聊天记录失败：%@", exception.reason ?: exception.name);
    }
    if (![controller isKindOfClass:UIViewController.class]) {
        WCAtlasShowTransientMessage(@"无法打开成员聊天记录", NO);
        return;
    }
    if (presenter.navigationController) {
        [presenter.navigationController pushViewController:controller animated:YES];
    } else {
        [presenter presentViewController:[[UINavigationController alloc] initWithRootViewController:controller]
                                animated:YES
                              completion:nil];
    }
}

static void WCAtlasOpenAvatarInfoCard(UIViewController *chatController,
                                    id contact,
                                    UIImage *avatar,
                                    NSString *displayName,
                                    NSString *targetUserName,
                                    NSString *chatUserName) {
    if (!chatController || targetUserName.length == 0) return;
    UIViewController *officialController = contact ? WCAtlasCreateOfficialSocialInformation(contact) : nil;
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *rows =
        [WCAtlasProfileInfoRows(contact, NO) mutableCopy] ?: [NSMutableArray array];
    id groupContact = nil;
    if (contact == nil) {
        WCAtlasAddInfoCardRow(rows, @"原始号码", targetUserName);
    }
    if ([chatUserName hasSuffix:@"@chatroom"]) {
        groupContact = WCAtlasContactForUserName(chatUserName);
        [rows addObject:@{ @"title": @"所在群聊", @"value": chatUserName }];
        [rows addObjectsFromArray:WCAtlasGroupMemberInfoRows(contact, groupContact, targetUserName)];
    }
    NSArray *baseRows = [rows copy];
    NSArray *displayRows = WCAtlasMergeInfoCardRows(baseRows,
        officialController ? WCAtlasOfficialSocialInformationRows(officialController) : @[]);
    WCAtlasContactInfoCardViewController *card = [[WCAtlasContactInfoCardViewController alloc]
        initWithTitle:[chatUserName hasSuffix:@"@chatroom"] ? @"群成员详细信息" : @"详细信息"
               avatar:avatar
                 name:displayName ?: targetUserName
             userName:targetUserName
             rows:displayRows];
    if (officialController) {
        WCAtlasWeakObjectBox *box = [WCAtlasWeakObjectBox new];
        box.object = card;
        objc_setAssociatedObject(officialController, &WCAtlasOfficialInfoCardBoxKey,
                                 box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(officialController, &WCAtlasOfficialInfoBaseRowsKey,
                                 baseRows, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(card, &WCAtlasInfoCardOfficialControllerKey,
                                 officialController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasRefreshInfoCardFromOfficialController(officialController);
    }
    WCAtlasConfigureInfoCardSwitches(card, targetUserName, [chatUserName hasSuffix:@"@chatroom"]);
    WCAtlasConfigureInfoCardDetailActions(card, contact, groupContact,
                                        targetUserName, officialController);
    if (chatController.navigationController) {
        [chatController.navigationController pushViewController:card animated:YES];
    } else {
        [chatController presentViewController:[[UINavigationController alloc] initWithRootViewController:card]
                                      animated:YES completion:nil];
    }
}

static BOOL WCAtlasPresentAvatarQuickMenu(CommonMessageCellView *cell, UIView *headView) {
    id message = WCAtlasMessageWrapForCell(cell);
    NSString *chatUserName = WCAtlasSessionForMessage(message);
    UIViewController *chatController = WCAtlasAvatarOwningViewController(cell);
    NSString *targetUserName = WCAtlasAvatarTargetUserName(cell, chatUserName);
    if (chatController.view.window != cell.window ||
        chatUserName.length == 0 || targetUserName.length == 0) {
        WCAtlasShowTransientMessage(@"未能识别头像对应的联系人", NO);
        return NO;
    }
    BOOL group = [chatUserName hasSuffix:@"@chatroom"];
    BOOL isSelf = [targetUserName isEqualToString:WCAtlasCurrentUserWXID()];
    id contact = group ? WCAtlasMessageChatContact(message) : nil;
    if (!contact) contact = WCAtlasContactForUserName(targetUserName);
    id groupContact = group ? WCAtlasContactForUserName(chatUserName) : nil;
    NSInteger removalScene = (group && !isSelf)
        ? WCAtlasGroupMemberRemovalScene(groupContact, contact, targetUserName) : 0;
    NSString *displayName = WCAtlasAvatarDisplayName(contact, targetUserName);
    NSString *maskedRealName = [[WCAtlasFriendRelationChecker sharedChecker]
        maskedRealNameForUserName:targetUserName];
    UIImage *avatar = WCAtlasAvatarSnapshot(headView);
    __weak UIViewController *weakController = chatController;
    __weak CommonMessageCellView *weakCell = cell;
    __weak UIView *weakHeadView = headView;
    NSString *retainedTarget = [targetUserName copy];
    NSString *retainedChat = [chatUserName copy];
    id retainedContact = contact;
    id retainedGroupContact = groupContact;

    NSMutableArray<WCAtlasAvatarQuickAction *> *actions = [NSMutableArray array];
    if (WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey)) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"详细信息" symbolName:@"person.text.rectangle" handler:^{
            WCAtlasOpenAvatarInfoCard(weakController, retainedContact, avatar, displayName,
                                   retainedTarget, retainedChat);
        }]];
    }
    if (group && !isSelf) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"艾特" symbolName:@"at" handler:^{
            WCAtlasInvokeNativeAvatarLongPress(weakCell, weakHeadView);
        }]];
    }
    [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"拍一拍" symbolName:@"hand.tap" handler:^{
        WCAtlasInvokeNativeAvatarDoubleTap(weakCell, weakHeadView);
    }]];
    if (group && !isSelf) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"专属红包" symbolName:@"envelope" handler:^{
            WCAtlasOpenAvatarExclusiveRedEnvelope(weakController, retainedContact, retainedChat);
        }]];
    }
    if (!isSelf) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"转账" symbolName:@"arrow.left.arrow.right" handler:^{
            WCAtlasOpenAvatarTransfer(weakController, retainedTarget, retainedContact, retainedChat);
        }]];
    }
    if (group && !isSelf) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"私聊" symbolName:@"bubble.left" handler:^{
            WCAtlasOpenChatForUserName(retainedTarget);
        }]];
    }
    if (group) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"聊天记录" symbolName:@"clock.arrow.circlepath" handler:^{
            WCAtlasOpenGroupMemberHistory(weakController, retainedChat, retainedContact);
        }]];
    }
    if (removalScene > 0) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"移出群聊" symbolName:@"person.fill.xmark" handler:^{
            WCAtlasConfirmRemoveGroupMember(weakController, retainedGroupContact, retainedContact,
                                          retainedTarget, removalScene);
        }]];
    }
    [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"朋友圈" symbolName:@"circle.grid.3x3" handler:^{
        if (retainedContact) WCAtlasOpenHomeMoments(weakController, retainedContact);
        else WCAtlasShowTransientMessage(@"未获取到联系人资料", NO);
    }]];
    if (!isSelf) {
        [actions addObject:[WCAtlasAvatarQuickAction actionWithTitle:@"改备注" symbolName:@"pencil" handler:^{
            if (retainedContact) WCAtlasOpenHomeRemark(weakController, retainedContact, NO);
            else WCAtlasShowTransientMessage(@"未获取到联系人资料", NO);
        }]];
    }
    WCAtlasPresentAvatarQuickPanel(chatController,
                                 avatar,
                                 displayName,
                                 targetUserName,
                                 maskedRealName,
                                 actions,
                                 ^{ WCAtlasOpenAvatarProfile(weakController, weakHeadView, retainedContact); });
    return YES;
}

static void WCAtlasSynchronizeAvatarQuickGesture(CommonMessageCellView *cell) {
    if (!cell) return;
    UIView *oldHeadView = objc_getAssociatedObject(cell, &WCAtlasAvatarQuickHeadViewKey);
    UITapGestureRecognizer *doubleTap = objc_getAssociatedObject(cell, &WCAtlasAvatarQuickDoubleTapRecognizerKey);
    WCAtlasAvatarQuickGestureProxy *oldProxy = objc_getAssociatedObject(cell, &WCAtlasAvatarQuickGestureProxyKey);
    UIView *headView = cell.window ? WCAtlasAvatarHeadViewForCell(cell) : nil;
    NSInteger mode = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasAvatarQuickMenuGestureKey];
    if (!WCAtlasEnhancementEnabled(WCAtlasAvatarQuickMenuGestureKey)) mode = WCAtlasAvatarQuickMenuGestureOff;
    if (mode < WCAtlasAvatarQuickMenuGestureOff || mode > WCAtlasAvatarQuickMenuGestureLongPress) {
        mode = WCAtlasAvatarQuickMenuGestureOff;
    }
    if (!headView || mode == WCAtlasAvatarQuickMenuGestureOff || oldHeadView != headView) {
        if (oldHeadView && oldProxy) WCAtlasConfigureNativeAvatarDoubleTap(oldHeadView, oldProxy, NO);
        if (doubleTap && oldHeadView) [oldHeadView removeGestureRecognizer:doubleTap];
        doubleTap = nil;
        objc_setAssociatedObject(cell, &WCAtlasAvatarQuickDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasAvatarQuickGestureProxyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasAvatarQuickHeadViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!headView || mode == WCAtlasAvatarQuickMenuGestureOff) return;
    }

    WCAtlasAvatarQuickGestureProxy *proxy = objc_getAssociatedObject(cell, &WCAtlasAvatarQuickGestureProxyKey);
    if (!proxy) proxy = [WCAtlasAvatarQuickGestureProxy new];
    proxy.cell = cell;
    proxy.headView = headView;
    headView.userInteractionEnabled = YES;

    if (mode == WCAtlasAvatarQuickMenuGestureDoubleTap) {
        BOOL usingNativeDoubleTap = WCAtlasConfigureNativeAvatarDoubleTap(headView, proxy, YES);
        if (usingNativeDoubleTap && doubleTap) {
            [headView removeGestureRecognizer:doubleTap];
            doubleTap = nil;
        } else if (!usingNativeDoubleTap && !doubleTap) {
            doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:proxy action:@selector(handleGesture:)];
            doubleTap.numberOfTapsRequired = 2;
            doubleTap.cancelsTouchesInView = YES;
            doubleTap.delaysTouchesEnded = YES;
            doubleTap.delegate = proxy;
            [headView addGestureRecognizer:doubleTap];
        }
        if (doubleTap) WCAtlasResolveAvatarGestureConflicts(headView, doubleTap);
    } else {
        WCAtlasConfigureNativeAvatarDoubleTap(headView, proxy, NO);
        if (doubleTap) {
            [headView removeGestureRecognizer:doubleTap];
            doubleTap = nil;
        }
    }
    objc_setAssociatedObject(cell, &WCAtlasAvatarQuickHeadViewKey, headView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &WCAtlasAvatarQuickDoubleTapRecognizerKey, doubleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &WCAtlasAvatarQuickGestureProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *WCAtlasConversationUserNameForEditLogic(id logic) {
    if (!logic) return nil;
    SEL originalMessageSelector = sel_registerName("originalMessageWrap");
    if ([logic respondsToSelector:originalMessageSelector]) {
        id wrap = ((id (*)(id, SEL))objc_msgSend)(logic, originalMessageSelector);
        id fromValue = WCAtlasTweakValueForSelectorNames(wrap, @[@"m_nsFromUsr"]);
        id toValue = WCAtlasTweakValueForSelectorNames(wrap, @[@"m_nsToUsr"]);
        NSString *fromUser = [fromValue isKindOfClass:[NSString class]] ? fromValue : nil;
        NSString *toUser = [toValue isKindOfClass:[NSString class]] ? toValue : nil;
        Class settingUtilClass = objc_getClass("SettingUtil");
        SEL localUserSelector = sel_registerName("getLocalUsrName:");
        NSString *localUser = nil;
        if (settingUtilClass && [settingUtilClass respondsToSelector:localUserSelector]) {
            id localValue = ((id (*)(id, SEL, NSInteger))objc_msgSend)(settingUtilClass,
                                                                        localUserSelector,
                                                                        0);
            localUser = [localValue isKindOfClass:[NSString class]] ? localValue : nil;
        }
        NSString *conversation = nil;
        if (fromUser.length > 0 && localUser.length > 0 && [fromUser isEqualToString:localUser]) {
            conversation = toUser;
        } else if (fromUser.length > 0) {
            conversation = fromUser;
        }
        if (conversation.length > 0) {
            objc_setAssociatedObject(logic, &WCAtlasEditConversationUserNameKey,
                                     conversation, OBJC_ASSOCIATION_COPY_NONATOMIC);
            return conversation;
        }
    }
    SEL selector = sel_registerName("c2CUserName");
    if ([logic respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(logic, selector);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
            objc_setAssociatedObject(logic, &WCAtlasEditConversationUserNameKey, value, OBJC_ASSOCIATION_COPY_NONATOMIC);
            return value;
        }
    }
    id cachedValue = objc_getAssociatedObject(logic, &WCAtlasEditConversationUserNameKey);
    return [cachedValue isKindOfClass:[NSString class]] && [cachedValue length] > 0 ? cachedValue : nil;
}

static UIImage *WCAtlasImageFromEditValue(id value, NSUInteger depth) {
    if (!value || depth > 4) return nil;
    if ([value isKindOfClass:[UIImage class]]) return value;
    if ([value isKindOfClass:[CIImage class]]) return [UIImage imageWithCIImage:value];
    if ([value isKindOfClass:[NSData class]]) return [UIImage imageWithData:value];
    if ([value isKindOfClass:[NSURL class]]) {
        NSURL *url = value;
        return url.isFileURL ? [UIImage imageWithContentsOfFile:url.path] : nil;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *path = value;
        if ([path hasPrefix:@"file://"]) path = [NSURL URLWithString:path].path;
        return path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path] ? [UIImage imageWithContentsOfFile:path] : nil;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        for (id candidate in [(NSArray *)value reverseObjectEnumerator]) {
            UIImage *image = WCAtlasImageFromEditValue(candidate, depth + 1);
            if (image) return image;
        }
        return nil;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSArray<NSString *> *preferredKeys = @[@"editedImage", @"image", @"outputImage", @"resultImage", @"fullImage", @"path", @"url"];
        for (NSString *key in preferredKeys) {
            UIImage *image = WCAtlasImageFromEditValue(dictionary[key], depth + 1);
            if (image) return image;
        }
        NSUInteger checked = 0;
        for (id candidate in dictionary.allValues.reverseObjectEnumerator) {
            UIImage *image = WCAtlasImageFromEditValue(candidate, depth + 1);
            if (image) return image;
            if (++checked >= 16) break;
        }
    }
    return nil;
}

static void WCAtlasCacheEditedImage(id logic, UIImage *image, NSString *source) {
    if (!logic || ![image isKindOfClass:[UIImage class]]) return;
    objc_setAssociatedObject(logic, &WCAtlasEditedImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasLog(@"已从 %@ 取得编辑图片：%.0f × %.0f", source ?: @"未知来源", image.size.width * image.scale, image.size.height * image.scale);
}

static UIImage *WCAtlasEditedImageFromLogic(id logic) {
    UIImage *image = objc_getAssociatedObject(logic, &WCAtlasEditedImageKey);
    if ([image isKindOfClass:[UIImage class]]) return image;
    id initialView = WCAtlasTweakSafeValue(logic, @"_editImageInitialView");
    id scrollView = WCAtlasTweakValueForSelectorNames(initialView, @[@"eIScrollView"]);
    id editAttribute = WCAtlasTweakValueForSelectorNames(scrollView, @[@"getEditImageAttr"]);
    image = WCAtlasTweakSafeValue(editAttribute, @"editedImage");
    if ([image isKindOfClass:[UIImage class]]) {
        WCAtlasCacheEditedImage(logic, image, @"编辑器最终图片");
        return image;
    }
    return nil;
}

static void WCAtlasLogEditImageDiagnostics(id logic) {
    id attribute = WCAtlasTweakSafeValue(logic, @"_editImageAttr");
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in @[@"editedImage", @"editedImages", @"unCropImage", @"editImageAttrDic", @"originalImage", @"isEdited"]) {
        id value = WCAtlasTweakSafeValue(attribute, key);
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, value ? NSStringFromClass([value class]) : @"nil"]];
    }
    WCAtlasLog(@"编辑图片取图诊断：logic=%@ attr=%@ %@", NSStringFromClass([logic class]), attribute ? NSStringFromClass([attribute class]) : @"nil", [parts componentsJoinedByString:@" "]);
}

static UIWindow *WCAtlasActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) continue;
        NSArray<UIWindow *> *windows = ((UIWindowScene *)scene).windows;
        for (UIWindow *window in windows) {
            NSString *className = NSStringFromClass(window.class);
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal && ![className containsString:@"iConsole"]) return window;
        }
        for (UIWindow *window in windows) {
            NSString *className = NSStringFromClass(window.class);
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal && ![className containsString:@"iConsole"]) return window;
        }
    }
    id windows = WCAtlasTweakSafeValue(UIApplication.sharedApplication, @"windows");
    if ([windows isKindOfClass:[NSArray class]]) {
        for (UIWindow *window in windows) {
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal && ![NSStringFromClass(window.class) containsString:@"iConsole"]) return window;
        }
    }
    return nil;
}

static void WCAtlasShowTransientMessage(NSString *message, BOOL success) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasShowTransientMessage(message, success); });
        return;
    }
    Class toastClass = NSClassFromString(@"WeToast");
    SEL toastSelector = NSSelectorFromString(@"toast");
    id toast = toastClass && [toastClass respondsToSelector:toastSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(toastClass, toastSelector) : nil;
    SEL showSelector = NSSelectorFromString(success ? @"showDoneToastWithText:" : @"showErrorToastWithText:");
    if (toast && [toast respondsToSelector:showSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(toast, showSelector, message);
        return;
    }
    UIWindow *window = WCAtlasActiveWindow();
    if (!window || message.length == 0) return;
    UILabel *label = [UILabel new];
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.layer.cornerRadius = 12.0;
    label.layer.masksToBounds = YES;
    label.alpha = 0.0;
    CGFloat width = MIN(CGRectGetWidth(window.bounds) - 48.0, 320.0);
    label.frame = CGRectMake((CGRectGetWidth(window.bounds) - width) * 0.5, window.safeAreaInsets.top + 18.0, width, success ? 44.0 : 60.0);
    [window addSubview:label];
    [window bringSubviewToFront:label];
    [UIView animateWithDuration:0.18 animations:^{ label.alpha = 1.0; } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.20 delay:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{ label.alpha = 0.0; } completion:^(__unused BOOL done) { [label removeFromSuperview]; }];
    }];
}

static void WCAtlasShowChatTTSHint(UIView *inputToolView, NSString *message, BOOL success) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            WCAtlasShowChatTTSHint(inputToolView, message, success);
        });
        return;
    }
    UIWindow *window = inputToolView.window ?: WCAtlasActiveWindow();
    if (!window || message.length == 0) return;
    static const NSInteger hintTag = 0x57435454;
    [[window viewWithTag:hintTag] removeFromSuperview];

    NSString *displayText = message;
    if ([message containsString:@"正在请求 Fish Audio"]) displayText = @"正在生成语音…";
    else if ([message containsString:@"已有一条 TTS 正在生成"]) displayText = @"语音生成中";

    UILabel *label = [UILabel new];
    label.tag = hintTag;
    label.text = displayText;
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.64];
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.layer.cornerRadius = 9.0;
    label.layer.masksToBounds = YES;
    label.alpha = 0.0;
    CGFloat maximumWidth = MIN(CGRectGetWidth(window.bounds) - 64.0, 286.0);
    CGSize fitted = [label sizeThatFits:CGSizeMake(maximumWidth - 24.0, 44.0)];
    CGFloat width = MIN(maximumWidth, MAX(104.0, ceil(fitted.width) + 24.0));
    CGFloat height = MIN(44.0, MAX(30.0, ceil(fitted.height) + 12.0));
    CGFloat anchorY = CGRectGetHeight(window.bounds) - window.safeAreaInsets.bottom - 84.0;
    if (inputToolView.window) {
        CGRect inputRect = [inputToolView convertRect:inputToolView.bounds toView:window];
        if (!CGRectIsEmpty(inputRect)) anchorY = CGRectGetMinY(inputRect) - 8.0;
    }
    CGFloat y = MAX(window.safeAreaInsets.top + 12.0, anchorY - height);
    label.frame = CGRectMake((CGRectGetWidth(window.bounds) - width) * 0.5, y, width, height);
    [window addSubview:label];
    [window bringSubviewToFront:label];
    NSTimeInterval delay = success ? 1.0 : 1.6;
    [UIView animateWithDuration:0.14 animations:^{ label.alpha = 1.0; }
        completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.18 delay:delay options:UIViewAnimationOptionCurveEaseInOut
                animations:^{ label.alpha = 0.0; }
                completion:^(__unused BOOL done) { [label removeFromSuperview]; }];
        }];
}

static UIViewController *WCAtlasEditPresenterController(id logic) {
    if (!logic) return nil;
    UIViewController *cached = objc_getAssociatedObject(logic, &WCAtlasEditPresenterControllerKey);
    if ([cached isKindOfClass:[UIViewController class]]) return cached;
    id candidate = WCAtlasTweakSafeValue(logic, @"currentViewController");
    if (![candidate isKindOfClass:[UIViewController class]]) candidate = WCAtlasTweakSafeValue(logic, @"forwardBasedViewController");
    SEL selector = NSSelectorFromString(@"getCurrentViewController");
    if (![candidate isKindOfClass:[UIViewController class]] && [logic respondsToSelector:selector]) {
        candidate = ((id (*)(id, SEL))objc_msgSend)(logic, selector);
    }
    if (![candidate isKindOfClass:[UIViewController class]]) return nil;
    objc_setAssociatedObject(logic, &WCAtlasEditPresenterControllerKey, candidate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return candidate;
}

@interface WCAtlasQuickSendSession : NSObject
@property (nonatomic, strong) id sourceLogic;
@property (nonatomic, strong) id forwardLogic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIViewController *presenter;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL sendButtonTapped;
- (void)finishSession;
@end

@implementation WCAtlasQuickSendSession

- (UIViewController *)getCurrentViewController { return self.presenter; }
- (UIViewController *)GetCurrentViewController { return self.presenter; }
- (BOOL)shouldShowSendSuccessView:(__unused id)logic { return YES; }

- (void)OnForwardMessageSend:(id)logic {
    if (self.finished) return;
    id confirmSheet = WCAtlasTweakSafeValue(self.forwardLogic, @"confirmSheetView");
    BOOL confirmedBySheet = [WCAtlasTweakSafeValue(confirmSheet, @"isClickedSend") boolValue];
    if (!self.sendButtonTapped && !confirmedBySheet) {
        WCAtlasLog(@"快捷发送收到确认页准备回调，等待用户点击发送");
        return;
    }
    SEL selector = NSSelectorFromString(@"OnForwardMessageSend:");
    if ([self.sourceLogic respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self.sourceLogic, selector, logic ?: self.forwardLogic);
    }
    WCAtlasLog(@"快捷发送已确认发送，结束图片编辑流程");
    [self finishSession];
}

- (void)OnForwardMessageCancel:(id)logic {
    if (self.finished) return;
    SEL selector = NSSelectorFromString(@"OnForwardMessageCancel:");
    if ([self.sourceLogic respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self.sourceLogic, selector, logic ?: self.forwardLogic);
    }
    WCAtlasLog(@"快捷发送已取消，保留图片编辑流程");
    [self finishSession];
}

- (void)OnForwardMessageConfirmCanceled:(id)logic {
    [self OnForwardMessageCancel:logic];
}

- (void)finishSession {
    if (self.finished) return;
    self.finished = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [WCAtlasActiveQuickSendSessions() removeObject:self];
        self.forwardLogic = nil;
        self.sourceLogic = nil;
        self.message = nil;
        self.contact = nil;
        self.image = nil;
        self.presenter = nil;
    });
}

@end

static BOOL WCAtlasSendEditedImageToCurrentConversation(id logic, NSString **failureReason) {
    UIImage *image = WCAtlasEditedImageFromLogic(logic);
    NSString *userName = WCAtlasConversationUserNameForEditLogic(logic);
    id contact = WCAtlasContactForUserName(userName);
    Class providerClass = objc_getClass("PasteboardMsgProvider");
    Class forwardClass = objc_getClass("ForwardMessageLogicController");
    SEL makeMessageSelector = sel_registerName("GetMessageFromImage:contact:");
    if (!image) {
        WCAtlasLogEditImageDiagnostics(logic);
        if (failureReason) *failureReason = @"没有取得微信编辑后的图片";
        return NO;
    }
    if (userName.length == 0) { if (failureReason) *failureReason = @"当前编辑页不属于聊天会话"; return NO; }
    if (!contact) { if (failureReason) *failureReason = @"当前聊天联系人已失效"; return NO; }
    NSString *contactName = WCAtlasPrivateContactUserName(contact);
    if (contactName.length > 0 && ![contactName isEqualToString:userName]) { if (failureReason) *failureReason = @"会话校验失败，已阻止串会话发送"; return NO; }
    if (!providerClass || ![providerClass respondsToSelector:makeMessageSelector]) { if (failureReason) *failureReason = @"微信图片消息接口已变化"; return NO; }
    if (!forwardClass) { if (failureReason) *failureReason = @"微信确认发送组件不存在"; return NO; }
    id message = ((id (*)(id, SEL, id, id))objc_msgSend)(providerClass, makeMessageSelector, image, contact);
    if (!message) { if (failureReason) *failureReason = @"微信未能创建编辑图片消息"; return NO; }
    id forwardLogic = [forwardClass new];
    SEL forwardSelector = sel_registerName("forwardMsgList:msgOriginList:toContacts:ignoreTips:showConfirmView:");
    if (!forwardLogic || ![forwardLogic respondsToSelector:forwardSelector]) { if (failureReason) *failureReason = @"微信确认发送方法已变化"; return NO; }
    SEL delegateSelector = sel_registerName("setDelegate:");
    if (![forwardLogic respondsToSelector:delegateSelector]) { if (failureReason) *failureReason = @"微信转发代理接口已变化"; return NO; }
    UIViewController *presenter = WCAtlasEditPresenterController(logic);
    if (!presenter) {
        if (failureReason) *failureReason = @"无法取得微信图片编辑页面";
        return NO;
    }
    WCAtlasQuickSendSession *session = [WCAtlasQuickSendSession new];
    session.sourceLogic = logic;
    session.forwardLogic = forwardLogic;
    session.message = message;
    session.contact = contact;
    session.image = image;
    session.presenter = presenter;
    ((void (*)(id, SEL, id))objc_msgSend)(forwardLogic, delegateSelector, session);
    WCAtlasTweakSetValue(forwardLogic, @"bSpecificContact", @YES);
    WCAtlasTweakSetValue(forwardLogic, @"bPresent", @YES);
    WCAtlasTweakSetValue(forwardLogic, @"bAnimation", @YES);
    [WCAtlasActiveQuickSendSessions() addObject:session];
    WCAtlasLog(@"快捷发送调用微信官方确认页：会话=%@ 页面=%@", userName, NSStringFromClass(presenter.class));
    ((void (*)(id, SEL, id, id, id, BOOL, BOOL))objc_msgSend)(forwardLogic, forwardSelector, @[message], nil, @[contact], NO, YES);
    __weak WCAtlasQuickSendSession *weakSession = session;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WCAtlasQuickSendSession *activeSession = weakSession;
        if (activeSession && !activeSession.finished) {
            WCAtlasLog(@"快捷发送确认会话超时，释放保留资源");
            [activeSession finishSession];
        }
    });
    return YES;
}

static void WCAtlasAttemptQuickSendWhenReady(id logic, __unused NSUInteger attempt) {
    if (!logic) {
        WCAtlasShowTransientMessage(@"发送失败：图片编辑会话已经结束", NO);
        return;
    }
    NSString *reason = nil;
    if (WCAtlasSendEditedImageToCurrentConversation(logic, &reason)) return;
    NSString *message = [NSString stringWithFormat:@"发送失败：%@", reason ?: @"未知原因"];
    WCAtlasShowTransientMessage(message, NO);
    WCAtlasLog(@"%@", message);
}

static void WCAtlasResumePendingQuickSendIfReady(id logic) {
    if (!logic || ![objc_getAssociatedObject(logic, &WCAtlasQuickSendPendingImageKey) boolValue]) return;
    UIImage *image = objc_getAssociatedObject(logic, &WCAtlasEditedImageKey);
    if (![image isKindOfClass:[UIImage class]]) return;
    objc_setAssociatedObject(logic, &WCAtlasQuickSendPendingImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasAttemptQuickSendWhenReady(logic, 0);
}

static void WCAtlasBeginQuickSend(id logic) {
    if (!logic) {
        WCAtlasShowTransientMessage(@"发送失败：图片编辑会话已经结束", NO);
        return;
    }
    UIImage *cachedImage = WCAtlasEditedImageFromLogic(logic);
    if ([cachedImage isKindOfClass:[UIImage class]]) {
        WCAtlasAttemptQuickSendWhenReady(logic, 0);
        return;
    }
    objc_setAssociatedObject(logic, &WCAtlasQuickSendPendingImageKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasLog(@"快捷发送等待微信生成最终编辑图片");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![objc_getAssociatedObject(logic, &WCAtlasQuickSendPendingImageKey) boolValue]) return;
        objc_setAssociatedObject(logic, &WCAtlasQuickSendPendingImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasLogEditImageDiagnostics(logic);
        WCAtlasShowTransientMessage(@"发送失败：微信未生成编辑后的图片", NO);
        WCAtlasLog(@"发送失败：等待最终编辑图片超时");
    });
}

static NSString *WCAtlasGameMD5ForContent(NSUInteger content) {
    Class gameControllerClass = objc_getClass("GameController");
    SEL selector = sel_registerName("getMD5ByGameContent:");
    if (!gameControllerClass || ![gameControllerClass respondsToSelector:selector]) return nil;
    return ((NSString *(*)(id, SEL, NSUInteger))objc_msgSend)(gameControllerClass, selector, content);
}

static void WCAtlasRefreshDailyStepOverride(void) {
    unsigned int stepCount = WCAtlasConfiguredDailyStepCount();
    if (stepCount > 0) WCAtlasLog(@"微信运动今日配置为 %u 步", stepCount);
}

static id WCAtlasMomentsObjectForSelector(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id WCAtlasMomentsObjectForName(id object, NSString *name) {
    id value = WCAtlasMomentsObjectForSelector(object, name);
    return value ?: WCAtlasTweakSafeValue(object, name);
}

static NSArray<UIControl *> *WCAtlasMomentsVisibleControls(UIView *root) {
    if (![root isKindOfClass:[UIView class]]) return @[];
    NSMutableArray<UIControl *> *controls = [NSMutableArray array];
    id injectedForwardButton = objc_getAssociatedObject(root, &WCAtlasMomentsFloatForwardButtonKey);
    id injectedSaveButton = objc_getAssociatedObject(root, &WCAtlasMomentsFloatSaveButtonKey);
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count > 0) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        for (UIView *subview in view.subviews) {
            [pending addObject:subview];
            if (subview == injectedForwardButton || subview == injectedSaveButton || ![subview isKindOfClass:[UIControl class]] ||
                subview.hidden || subview.alpha <= 0.01) continue;
            CGRect frame = [subview convertRect:subview.bounds toView:root];
            if (CGRectGetWidth(frame) >= 36.0 && CGRectGetHeight(frame) >= 24.0) {
                [controls addObject:(UIControl *)subview];
            }
        }
    }
    [controls sortUsingComparator:^NSComparisonResult(UIControl *left, UIControl *right) {
        CGFloat leftX = CGRectGetMinX([left convertRect:left.bounds toView:root]);
        CGFloat rightX = CGRectGetMinX([right convertRect:right.bounds toView:root]);
        if (leftX < rightX) return NSOrderedAscending;
        if (leftX > rightX) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return controls;
}

static NSString *WCAtlasMomentsControlDescription(UIControl *control) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *value in @[control.accessibilityIdentifier ?: @"", control.accessibilityLabel ?: @""]) {
        if (value.length > 0) [parts addObject:value];
    }
    if ([control isKindOfClass:[UIButton class]]) {
        NSString *title = [(UIButton *)control currentTitle];
        if (title.length > 0) [parts addObject:title];
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

static void WCAtlasMomentsNativeFloatControls(WCOperateFloatView *floatView,
                                            UIControl **likeControl,
                                            UIControl **commentControl) {
    id like = WCAtlasMomentsObjectForName(floatView, @"m_likeBtn");
    id comment = WCAtlasMomentsObjectForName(floatView, @"m_commentBtn");
    NSArray<UIControl *> *controls = WCAtlasMomentsVisibleControls(floatView);
    for (UIControl *control in controls) {
        NSString *description = WCAtlasMomentsControlDescription(control);
        if (![comment isKindOfClass:[UIControl class]] &&
            ([description containsString:@"comment"] || [description containsString:@"评论"])) comment = control;
        if (![like isKindOfClass:[UIControl class]] &&
            ([description containsString:@"like"] || [description containsString:@"赞"])) like = control;
    }
    if (![comment isKindOfClass:[UIControl class]] && controls.count > 0) comment = controls.lastObject;
    if (![like isKindOfClass:[UIControl class]] && controls.count > 1) like = controls[controls.count - 2];
    if (likeControl) *likeControl = [like isKindOfClass:[UIControl class]] ? like : nil;
    if (commentControl) *commentControl = [comment isKindOfClass:[UIControl class]] ? comment : nil;
}

static BOOL WCAtlasMomentsBoolForSelector(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return NO;
    @try {
        return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static unsigned int WCAtlasMomentsUnsignedForSelector(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return 0;
    @try {
        return ((unsigned int (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return 0;
    }
}

static id WCAtlasMomentsContentObject(id dataItem) {
    return WCAtlasMomentsObjectForSelector(dataItem, @"contentObj");
}

static NSArray *WCAtlasMomentsMediaItems(id dataItem) {
    id mediaList = WCAtlasMomentsObjectForSelector(WCAtlasMomentsContentObject(dataItem), @"mediaList");
    return [mediaList isKindOfClass:[NSArray class]] ? mediaList : @[];
}

static NSString *WCAtlasMomentsBodyText(id dataItem) {
    id text = WCAtlasMomentsObjectForSelector(dataItem, @"contentDesc");
    return [text isKindOfClass:[NSString class]] ? text : @"";
}

static BOOL WCAtlasMomentsHasStructuredContent(id contentObject) {
    static NSArray<NSString *> *selectors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectors = @[@"noteInfo", @"musicShareItem", @"musicInfo", @"finderLiveShareItem",
                      @"finderThemeLiveShareItem", @"finderShareToMomentsItem", @"finderLongVideoShareItem",
                      @"finderShareItem", @"weappInfo", @"snsWeAppInfo", @"tingListenItem",
                      @"tingCategoryItem", @"tingChatRoomItem", @"tingLyricsItem"];
    });
    for (NSString *selectorName in selectors) {
        if (WCAtlasMomentsObjectForSelector(contentObject, selectorName)) return YES;
    }
    return NO;
}

static BOOL WCAtlasMomentCanForward(id dataItem) {
    if (!dataItem) return NO;
    id contentObject = WCAtlasMomentsContentObject(dataItem);
    if (!contentObject) return NO;
    if (WCAtlasMomentsHasStructuredContent(contentObject)) return YES;
    NSArray *mediaItems = WCAtlasMomentsMediaItems(dataItem);
    if ((WCAtlasMomentsBoolForSelector(contentObject, @"isPhotoType") ||
         WCAtlasMomentsBoolForSelector(contentObject, @"isVideoType")) && mediaItems.count > 0) return YES;
    if (WCAtlasMomentsUnsignedForSelector(contentObject, @"type") != 2 ||
        mediaItems.count > 0 || WCAtlasMomentsBodyText(dataItem).length == 0) return NO;
    id linkURL = WCAtlasMomentsObjectForSelector(contentObject, @"linkUrl");
    return ![linkURL isKindOfClass:[NSString class]] || [linkURL length] == 0;
}

static NSString *WCAtlasMomentsExistingMediaPath(id mediaItem, NSArray<NSString *> *selectors) {
    for (NSString *selectorName in selectors) {
        id value = WCAtlasMomentsObjectForSelector(mediaItem, selectorName);
        NSString *path = [value isKindOfClass:[NSURL class]] ? [value path] : ([value isKindOfClass:[NSString class]] ? value : nil);
        if (path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    }
    return nil;
}

static BOOL WCAtlasMomentsMediaFileIsUsable(NSString *path) {
    if (path.length == 0) return NO;
    BOOL directory = NO;
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager fileExistsAtPath:path isDirectory:&directory] || directory) return NO;
    NSNumber *size = [[manager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize];
    return size.unsignedLongLongValue > 0;
}

static void WCAtlasAppendUniqueMomentObject(NSMutableArray *objects, id object) {
    if (!object) return;
    for (id existing in objects) if (existing == object) return;
    [objects addObject:object];
}

static NSArray *WCAtlasLivePhotoVideoCandidateObjects(id mediaItem, id parentMediaItem) {
    NSMutableArray *objects = [NSMutableArray array];
    WCAtlasAppendUniqueMomentObject(objects, mediaItem);
    for (id owner in @[mediaItem ?: NSNull.null, parentMediaItem ?: NSNull.null]) {
        if (owner == NSNull.null) continue;
        for (NSString *selectorName in @[@"livePhotoVideoMediaItem", @"pairedVideoMediaItem",
                                         @"livePhotoMediaItem"]) {
            WCAtlasAppendUniqueMomentObject(objects, WCAtlasMomentsObjectForSelector(owner, selectorName));
        }
    }
    WCAtlasAppendUniqueMomentObject(objects, parentMediaItem);
    return objects;
}

static NSString *WCAtlasLivePhotoExistingVideoPath(id mediaItem, id parentMediaItem) {
    NSArray *selectors = @[@"pathForSightData", @"pathForData", @"pathForAttachVideoData",
                           @"pathForExistData", @"tempPathForSightData",
                           @"pathForTempAttachVideoData", @"livePhotoVideoPath",
                           @"pairedVideoPath"];
    for (id object in WCAtlasLivePhotoVideoCandidateObjects(mediaItem, parentMediaItem)) {
        for (NSString *selectorName in selectors) {
            id value = WCAtlasMomentsObjectForSelector(object, selectorName);
            NSString *path = [value isKindOfClass:NSURL.class] ? [value path]
                : ([value isKindOfClass:NSString.class] ? value : nil);
            if (WCAtlasMomentsMediaFileIsUsable(path)) return path;
        }
    }
    return nil;
}

static BOOL WCAtlasMomentsLongLongForSelector(id object, NSString *selectorName, long long *result) {
    if (!object || selectorName.length == 0 || !result) return NO;
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2) return NO;
    const char *returnType = signature.methodReturnType;
    if (!returnType || returnType[0] == 'v') return NO;

    BOOL integerReturn = strchr("cCsSiIlLqQ", returnType[0]) != NULL;
    if (integerReturn) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = object;
        invocation.selector = selector;
        @try {
            [invocation invoke];
            unsigned long long rawValue = 0;
            NSUInteger length = MIN(signature.methodReturnLength, sizeof(rawValue));
            [invocation getReturnValue:&rawValue];
            if (length < sizeof(rawValue) && (returnType[0] == 'c' || returnType[0] == 's' || returnType[0] == 'i' || returnType[0] == 'l')) {
                unsigned long long signBit = 1ULL << (length * 8 - 1);
                if (rawValue & signBit) rawValue |= ~0ULL << (length * 8);
            }
            *result = (long long)rawValue;
            return YES;
        } @catch (__unused NSException *exception) {
            return NO;
        }
    }

    if (returnType[0] != '@') return NO;
    // Some older builds expose the value as NSNumber rather than a scalar.
    id value = WCAtlasMomentsObjectForSelector(object, selectorName);
    if ([value respondsToSelector:@selector(longLongValue)]) {
        *result = [value longLongValue];
        return YES;
    }
    return NO;
}

static long long WCAtlasNormalizedLivePhotoStillImageTimeMs(long long stillImageTimeMs,
                                                           NSString *videoPath) {
    long long normalizedTimeMs = MAX(1LL, stillImageTimeMs);
    if (videoPath.length == 0) return normalizedTimeMs;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
    NSTimeInterval durationSeconds = CMTimeGetSeconds(asset.duration);
    if (!isfinite(durationSeconds) || durationSeconds <= 0.0) return normalizedTimeMs;

    long long durationMs = llround(durationSeconds * 1000.0);
    if (durationMs < 1) return normalizedTimeMs;
    if (stillImageTimeMs < 1 || stillImageTimeMs >= durationMs) {
        normalizedTimeMs = MAX(1LL, llround(MAX(1LL, durationMs) / 2.0));
    }
    long long maximumTimeMs = MAX(2LL, durationMs) - 1;
    return MIN(normalizedTimeMs, maximumTimeMs);
}

@interface WCAtlasMomentsForwardTask : NSObject
@property (nonatomic, strong) id dataItem;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) NSArray *mediaItems;
@property (nonatomic, strong) NSMutableArray *resolvedPaths;
@property (nonatomic, strong) NSMutableArray *downloaders;
@property (nonatomic, assign) NSUInteger remainingDownloads;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) BOOL failed;
- (void)start;
@end

@implementation WCAtlasMomentsForwardTask

- (void)releasePresenterRetention {
    UIViewController *presenter = self.presenter;
    if (presenter && objc_getAssociatedObject(presenter, &WCAtlasMomentsForwardTaskKey) == self) {
        objc_setAssociatedObject(presenter, &WCAtlasMomentsForwardTaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)applyBodyTextToController:(id)controller attempt:(NSUInteger)attempt {
    NSString *body = WCAtlasMomentsBodyText(self.dataItem);
    if (body.length == 0 || !controller) return;
    id textView = WCAtlasMomentsObjectForSelector(controller, @"textView");
    SEL setTextSelector = NSSelectorFromString(@"setText:");
    if (!textView || ![textView respondsToSelector:setTextSelector]) {
        if (attempt < 3) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf applyBodyTextToController:controller attempt:attempt + 1];
            });
        }
        return;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(textView, setTextSelector, body);
    for (NSString *selectorName in @[@"changeContentSize", @"adjustRect"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([textView respondsToSelector:selector]) ((void (*)(id, SEL))objc_msgSend)(textView, selector);
    }
    SEL changedSelector = NSSelectorFromString(@"textViewTextDidChange");
    if ([controller respondsToSelector:changedSelector]) ((void (*)(id, SEL))objc_msgSend)(controller, changedSelector);
    SEL heightSelector = NSSelectorFromString(@"MMGrowTextViewHeightDidChanged:");
    if ([controller respondsToSelector:heightSelector]) ((void (*)(id, SEL, id))objc_msgSend)(controller, heightSelector, textView);
}

- (void)presentController:(id)controller applyBody:(BOOL)applyBody {
    UIViewController *presenter = self.presenter;
    if (![controller isKindOfClass:[UIViewController class]] || !presenter.view.window) {
        WCAtlasShowTransientMessage(@"朋友圈转发失败：当前页面不可用", NO);
        [self releasePresenterRetention];
        return;
    }
    SEL delegateSelector = NSSelectorFromString(@"setDelegate:");
    if ([controller respondsToSelector:delegateSelector]) ((void (*)(id, SEL, id))objc_msgSend)(controller, delegateSelector, presenter);
    SEL fromListSelector = NSSelectorFromString(@"setM_bFromWCList:");
    if ([controller respondsToSelector:fromListSelector]) ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, fromListSelector, YES);
    Class navigationClass = NSClassFromString(@"MMUINavigationController");
    if (!navigationClass) navigationClass = [UINavigationController class];
    id navigation = [[navigationClass alloc] initWithRootViewController:controller];
    objc_setAssociatedObject(navigation, &WCAtlasMomentsForwardTaskKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self releasePresenterRetention];
    if ([navigation isKindOfClass:[UIViewController class]]) ((UIViewController *)navigation).modalPresentationStyle = UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf = self;
    [presenter presentViewController:navigation animated:YES completion:^{
        if (applyBody) [weakSelf applyBodyTextToController:controller attempt:0];
    }];
    WCAtlasCompatibilityMarkTriggered(@"moments-forward");
}

- (void)presentStructuredForward {
    Class controllerClass = NSClassFromString(@"WCForwardViewController");
    SEL initializer = NSSelectorFromString(@"initWithDataItem:");
    if (!controllerClass || ![controllerClass instancesRespondToSelector:initializer]) {
        WCAtlasShowTransientMessage(@"当前微信版本不支持此类朋友圈转发", NO);
        [self releasePresenterRetention];
        return;
    }
    id controller = ((id (*)(id, SEL, id))objc_msgSend)([controllerClass alloc], initializer, self.dataItem);
    [self presentController:controller applyBody:NO];
}

- (void)presentTextCommit {
    Class controllerClass = NSClassFromString(@"WCNewCommitViewController");
    SEL initializer = NSSelectorFromString(@"initWithTextType");
    if (!controllerClass || ![controllerClass instancesRespondToSelector:initializer]) {
        WCAtlasShowTransientMessage(@"当前微信版本不支持文字朋友圈转发", NO);
        [self releasePresenterRetention];
        return;
    }
    id controller = ((id (*)(id, SEL))objc_msgSend)([controllerClass alloc], initializer);
    [self presentController:controller applyBody:YES];
}

- (void)presentImageCommit {
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:self.resolvedPaths.count];
    Class imageClass = NSClassFromString(@"MMImage");
    SEL initializer = NSSelectorFromString(@"initWithImage:");
    for (id value in self.resolvedPaths) {
        NSString *path = [value isKindOfClass:[NSString class]] ? value : nil;
        UIImage *image = path.length > 0 ? [UIImage imageWithContentsOfFile:path] : nil;
        if (!image || !imageClass || ![imageClass instancesRespondToSelector:initializer]) continue;
        id wrappedImage = ((id (*)(id, SEL, id))objc_msgSend)([imageClass alloc], initializer, image);
        SEL dataPathSelector = NSSelectorFromString(@"setDataPath:");
        if ([wrappedImage respondsToSelector:dataPathSelector]) ((void (*)(id, SEL, id))objc_msgSend)(wrappedImage, dataPathSelector, path);
        if (wrappedImage) [images addObject:wrappedImage];
    }
    Class controllerClass = NSClassFromString(@"WCNewCommitViewController");
    SEL controllerInitializer = NSSelectorFromString(@"initWithImages:contacts:");
    if (images.count == 0 || !controllerClass || ![controllerClass instancesRespondToSelector:controllerInitializer]) {
        WCAtlasShowTransientMessage(@"朋友圈图片读取失败", NO);
        [self releasePresenterRetention];
        return;
    }
    id controller = ((id (*)(id, SEL, id, id))objc_msgSend)([controllerClass alloc], controllerInitializer, images, nil);
    SEL loadingSelector = NSSelectorFromString(@"setLoadingOKStr:");
    if ([controller respondsToSelector:loadingSelector]) ((void (*)(id, SEL, id))objc_msgSend)(controller, loadingSelector, nil);
    [self presentController:controller applyBody:YES];
}

- (void)presentVideoCommit {
    NSString *path = [self.resolvedPaths.firstObject isKindOfClass:[NSString class]] ? self.resolvedPaths.firstObject : nil;
    Class draftClass = NSClassFromString(@"SightDraft");
    SEL draftSelector = NSSelectorFromString(@"draftWithVideoURL:");
    id draft = path.length > 0 && [draftClass respondsToSelector:draftSelector]
        ? ((id (*)(id, SEL, id))objc_msgSend)(draftClass, draftSelector, [NSURL fileURLWithPath:path]) : nil;
    Class controllerClass = NSClassFromString(@"WCNewCommitViewController");
    SEL initializer = NSSelectorFromString(@"initWithSightDraft:");
    if (!draft || !controllerClass || ![controllerClass instancesRespondToSelector:initializer]) {
        WCAtlasShowTransientMessage(@"朋友圈视频读取失败", NO);
        [self releasePresenterRetention];
        return;
    }
    id controller = ((id (*)(id, SEL, id))objc_msgSend)([controllerClass alloc], initializer, draft);
    [self presentController:controller applyBody:YES];
}

- (void)finishMediaResolutionIfNeeded {
    if (self.remainingDownloads > 0) return;
    if (self.failed) {
        WCAtlasShowTransientMessage(@"朋友圈媒体下载失败，请稍后重试", NO);
        [self releasePresenterRetention];
        return;
    }
    if (self.video) [self presentVideoCommit];
    else [self presentImageCommit];
}

- (void)resolveMediaItem:(id)mediaItem index:(NSUInteger)index {
    NSArray *pathSelectors = self.video
        ? @[@"pathForSightData"]
        : @[@"pathForUhdData", @"pathForHdData", @"pathForData", @"pathForExistData"];
    NSString *path = WCAtlasMomentsExistingMediaPath(mediaItem, pathSelectors);
    if (path.length > 0) {
        self.resolvedPaths[index] = path;
        self.remainingDownloads--;
        [self finishMediaResolutionIfNeeded];
        return;
    }
    Class downloaderClass = NSClassFromString(@"WCMediaDownloader");
    SEL initializer = NSSelectorFromString(@"initWithDataItem:mediaItem:");
    SEL startSelector = NSSelectorFromString(@"startDownloadWithCompletionHandler:");
    id downloader = downloaderClass && [downloaderClass instancesRespondToSelector:initializer]
        ? ((id (*)(id, SEL, id, id))objc_msgSend)([downloaderClass alloc], initializer, self.dataItem, mediaItem) : nil;
    if (!downloader || ![downloader respondsToSelector:startSelector]) {
        self.failed = YES;
        self.remainingDownloads--;
        [self finishMediaResolutionIfNeeded];
        return;
    }
    [self.downloaders addObject:downloader];
    __weak typeof(self) weakSelf = self;
    void (^completion)(BOOL, NSError *) = ^(__unused BOOL success, __unused NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSString *resolvedPath = WCAtlasMomentsExistingMediaPath(mediaItem, pathSelectors);
            if (resolvedPath.length > 0) strongSelf.resolvedPaths[index] = resolvedPath;
            else strongSelf.failed = YES;
            [strongSelf.downloaders removeObject:downloader];
            strongSelf.remainingDownloads--;
            [strongSelf finishMediaResolutionIfNeeded];
        });
    };
    ((void (*)(id, SEL, id))objc_msgSend)(downloader, startSelector, completion);
}

- (void)startMediaResolution:(NSArray *)mediaItems video:(BOOL)video {
    self.video = video;
    self.mediaItems = video ? [mediaItems subarrayWithRange:NSMakeRange(0, 1)]
                            : [mediaItems subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)9, mediaItems.count))];
    self.resolvedPaths = [NSMutableArray arrayWithCapacity:self.mediaItems.count];
    for (__unused id item in self.mediaItems) [self.resolvedPaths addObject:NSNull.null];
    self.downloaders = [NSMutableArray array];
    self.remainingDownloads = self.mediaItems.count;
    [self.mediaItems enumerateObjectsUsingBlock:^(id mediaItem, NSUInteger index, __unused BOOL *stop) {
        [self resolveMediaItem:mediaItem index:index];
    }];
}

- (void)start {
    id contentObject = WCAtlasMomentsContentObject(self.dataItem);
    NSArray *mediaItems = WCAtlasMomentsMediaItems(self.dataItem);
    if (WCAtlasMomentsHasStructuredContent(contentObject)) {
        [self presentStructuredForward];
    } else if (WCAtlasMomentsBoolForSelector(contentObject, @"isVideoType") && mediaItems.count > 0) {
        [self startMediaResolution:mediaItems video:YES];
    } else if (WCAtlasMomentsBoolForSelector(contentObject, @"isPhotoType") && mediaItems.count > 0) {
        [self startMediaResolution:mediaItems video:NO];
    } else if (WCAtlasMomentCanForward(self.dataItem)) {
        [self presentTextCommit];
    } else {
        WCAtlasShowTransientMessage(@"当前朋友圈类型暂不支持转发", NO);
        [self releasePresenterRetention];
    }
}

@end

@interface WCAtlasMomentsMediaSaveTask : NSObject
@property (nonatomic, strong) id dataItem;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) NSArray *mediaItems;
@property (nonatomic, strong) NSMutableArray *resolvedPaths;
@property (nonatomic, strong) NSMutableArray *resolvedVideoPaths;
@property (nonatomic, strong) NSMutableArray *livePhotoTimes;
@property (nonatomic, strong) NSMutableArray *livePhotoIndexes;
@property (nonatomic, strong) NSMutableArray *downloaders;
@property (nonatomic, strong) NSMutableArray *livePhotoSaveQueue;
@property (nonatomic, strong) NSMutableArray *livePhotoMakers;
@property (nonatomic, strong) NSMutableArray<NSString *> *temporaryPaths;
@property (nonatomic, assign) NSUInteger remainingDownloads;
@property (nonatomic, assign) NSUInteger nextLivePhotoIndex;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL saveStarted;
@property (nonatomic, assign) BOOL finished;
- (void)start;
- (void)finishDownloadedMediaItem:(id)mediaItem
                  parentMediaItem:(id)parentMediaItem
                            index:(NSUInteger)index
                        videoPath:(BOOL)videoPath
                    pathSelectors:(NSArray *)pathSelectors
                       downloader:(id)downloader
                          attempt:(NSUInteger)attempt;
@end

@implementation WCAtlasMomentsMediaSaveTask

- (void)finish {
    UIViewController *presenter = self.presenter;
    if (presenter && objc_getAssociatedObject(presenter, &WCAtlasMomentsSaveTaskKey) == self) {
        objc_setAssociatedObject(presenter, &WCAtlasMomentsSaveTaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (self.dataItem && objc_getAssociatedObject(self.dataItem, &WCAtlasMomentsDataItemSaveTaskKey) == self) {
        objc_setAssociatedObject(self.dataItem, &WCAtlasMomentsDataItemSaveTaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (NSString *path in self.temporaryPaths) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    [self.temporaryPaths removeAllObjects];
    [self.livePhotoMakers removeAllObjects];
    if (WCAtlasActiveMomentsMediaSaveTask == self) WCAtlasActiveMomentsMediaSaveTask = nil;
}

- (BOOL)prepareLivePhotoForImagePath:(NSString *)imagePath
                           videoPath:(NSString *)videoPath
                    stillImageTimeMs:(long long)stillImageTimeMs
                          completion:(void (^)(NSString *, NSString *))completion {
    Class makerClass = NSClassFromString(@"WCLivePhotoMaker");
    Class pathManagerClass = NSClassFromString(@"WCLivePhotoFilePathManager");
    SEL heicSelector = NSSelectorFromString(@"getLivePhotoHEICPath:");
    SEL jpgSelector = NSSelectorFromString(@"getLivePhotoJPGPath:");
    SEL movSelector = NSSelectorFromString(@"getLivePhotoMovPath:");
    SEL makeSelector = NSSelectorFromString(@"makeLivePhotoByImagePath:videoPath:preferedHEVC:stillImageTimeMs:completionHandler:");
    if (!makerClass || !pathManagerClass ||
        ![pathManagerClass respondsToSelector:heicSelector] ||
        ![pathManagerClass respondsToSelector:jpgSelector] ||
        ![pathManagerClass respondsToSelector:movSelector]) return NO;

    NSString *fileIdentifier = imagePath.lastPathComponent.stringByDeletingPathExtension;
    if (fileIdentifier.length == 0) return NO;
    NSString *heicPath = ((id (*)(id, SEL, id))objc_msgSend)(pathManagerClass, heicSelector, fileIdentifier);
    NSString *jpgPath = ((id (*)(id, SEL, id))objc_msgSend)(pathManagerClass, jpgSelector, fileIdentifier);
    NSString *movPath = ((id (*)(id, SEL, id))objc_msgSend)(pathManagerClass, movSelector, fileIdentifier);
    if (heicPath.length == 0 || jpgPath.length == 0 || movPath.length == 0) return NO;

    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *path in @[heicPath, jpgPath, movPath]) {
        if ([fileManager fileExistsAtPath:path]) [fileManager removeItemAtPath:path error:nil];
        [self.temporaryPaths addObject:path];
    }

    id maker = [makerClass new];
    if (!maker || ![maker respondsToSelector:makeSelector]) return NO;
    [self.livePhotoMakers addObject:maker];
    __weak typeof(self) weakSelf = self;
    __weak id weakMaker = maker;
    void (^makerCompletion)(void) = [^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.finished) return;
            NSString *pairedImagePath = [fileManager fileExistsAtPath:heicPath] ? heicPath :
                                        ([fileManager fileExistsAtPath:jpgPath] ? jpgPath : nil);
            NSString *pairedVideoPath = [fileManager fileExistsAtPath:movPath] ? movPath : nil;
            id completedMaker = weakMaker;
            if (completedMaker) [strongSelf.livePhotoMakers removeObject:completedMaker];
            if (completion) completion(pairedImagePath, pairedVideoPath);
        });
    } copy];
    @try {
        // WeChatX first creates a paired HEIC/JPG + MOV through this maker,
        // then passes those generated paths to MMAlbumService.
        ((void (*)(id, SEL, id, id, BOOL, long long, id))objc_msgSend)(
            maker, makeSelector, imagePath, videoPath, YES, stillImageTimeMs, makerCompletion);
        return YES;
    } @catch (NSException *exception) {
        [self.livePhotoMakers removeObject:maker];
        WCAtlasLog(@"生成朋友圈实况配对文件失败：%@", exception.reason ?: @"未知异常");
        return NO;
    }
}

- (void)finishWithFailure:(NSString *)message {
    if (self.finished) return;
    self.finished = YES;
    WCAtlasShowTransientMessage(message.length > 0 ? message : @"保存失败，请检查照片权限", NO);
    [self finish];
}

- (void)finishWithSuccess {
    if (self.finished) return;
    self.finished = YES;
    NSUInteger imageCount = 0;
    NSUInteger videoCount = 0;
    NSUInteger livePhotoCount = self.livePhotoIndexes.count;
    if (self.video) {
        videoCount = self.mediaItems.count;
    } else {
        for (NSUInteger index = 0; index < self.mediaItems.count; index++) {
            if ([self.livePhotoIndexes containsObject:@(index)]) continue;
            imageCount++;
        }
    }

    NSString *message = nil;
    if (videoCount > 0) {
        message = [NSString stringWithFormat:@"已保存 %lu 个朋友圈视频", (unsigned long)videoCount];
    } else if (imageCount > 0 && livePhotoCount > 0) {
        message = [NSString stringWithFormat:@"已保存 %lu 张朋友圈图片和 %lu 张实况照片",
                   (unsigned long)imageCount, (unsigned long)livePhotoCount];
    } else if (livePhotoCount > 0) {
        message = [NSString stringWithFormat:@"已保存 %lu 张实况照片", (unsigned long)livePhotoCount];
    } else {
        message = [NSString stringWithFormat:@"已保存 %lu 张朋友圈图片", (unsigned long)imageCount];
    }
    WCAtlasShowTransientMessage(message, YES);
    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
    WCAtlasCompatibilityMarkTriggered(@"moments-save-images");
    [self finish];
}

- (BOOL)invokeLivePhotoSaveForImagePath:(NSString *)imagePath
                              videoPath:(NSString *)videoPath
                       stillImageTimeMs:(long long)stillImageTimeMs
                                success:(void (^)(void))success
                                failure:(void (^)(void))failure {
    Class albumServiceClass = NSClassFromString(@"MMAlbumService");
    SEL saveSelector = NSSelectorFromString(@"saveLivePhotoToAlbumWithImagePath:videoPath:stillImageTimeMs:isShowTips:successBlock:failureBlock:");
    if (!albumServiceClass) return NO;
    // Match WeChatX's service lookup order through WCAtlas's MMContext-aware
    // compatibility helper, which falls back to MMServiceCenter.defaultCenter.
    id service = WCAtlasServiceForClass(albumServiceClass);
    if (!service || ![service respondsToSelector:saveSelector]) return NO;
    void (^successBlock)(void) = [^{
        if (success) success();
    } copy];
    void (^failureBlock)(void) = [^{
        if (failure) failure();
    } copy];
    @try {
        // WeChatX calls this private API directly with two NSString paths,
        // a 64-bit millisecond time, isShowTips=NO and two no-argument blocks.
        ((void (*)(id, SEL, id, id, long long, BOOL, id, id))objc_msgSend)(
            service, saveSelector, imagePath, videoPath, stillImageTimeMs, NO, successBlock, failureBlock);
        return YES;
    } @catch (NSException *exception) {
        WCAtlasLog(@"调用微信实况保存接口失败：%@", exception.reason ?: @"未知异常");
        return NO;
    }
}

- (void)saveNextLivePhoto {
    if (self.nextLivePhotoIndex >= self.livePhotoSaveQueue.count) {
        [self finishWithSuccess];
        return;
    }
    NSUInteger queueIndex = self.nextLivePhotoIndex++;
    NSNumber *mediaIndexValue = self.livePhotoSaveQueue[queueIndex];
    NSUInteger mediaIndex = mediaIndexValue.unsignedIntegerValue;
    NSString *imagePath = [self.resolvedPaths[mediaIndex] isKindOfClass:[NSString class]] ? self.resolvedPaths[mediaIndex] : nil;
    NSString *videoPath = [self.resolvedVideoPaths[mediaIndex] isKindOfClass:[NSString class]] ? self.resolvedVideoPaths[mediaIndex] : nil;
    NSNumber *timeValue = [self.livePhotoTimes[mediaIndex] isKindOfClass:[NSNumber class]] ? self.livePhotoTimes[mediaIndex] : nil;
    if (imagePath.length == 0 || videoPath.length == 0 || !timeValue) {
        [self finishWithFailure:@"实况照片数据不完整，请稍后重试"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    long long normalizedTimeMs = WCAtlasNormalizedLivePhotoStillImageTimeMs(timeValue.longLongValue, videoPath);
    BOOL preparing = [self prepareLivePhotoForImagePath:imagePath
                                              videoPath:videoPath
                                       stillImageTimeMs:normalizedTimeMs
                                             completion:^(NSString *pairedImagePath, NSString *pairedVideoPath) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.finished) return;
        if (pairedImagePath.length == 0 || pairedVideoPath.length == 0) {
            [strongSelf finishWithFailure:@"实况照片配对文件生成失败"];
            return;
        }
        BOOL invoked = [strongSelf invokeLivePhotoSaveForImagePath:pairedImagePath
                                                          videoPath:pairedVideoPath
                                                   stillImageTimeMs:normalizedTimeMs
                                                            success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf || innerSelf.finished) return;
                [innerSelf saveNextLivePhoto];
            });
        } failure:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf || innerSelf.finished) return;
                [innerSelf finishWithFailure:@"实况照片保存失败，请检查照片权限"];
            });
        }];
        if (!invoked) [strongSelf finishWithFailure:@"当前微信版本不支持保存实况照片"];
    }];
    if (!preparing) {
        [self finishWithFailure:@"当前微信版本不支持生成实况照片"];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.finished || strongSelf.nextLivePhotoIndex != queueIndex + 1) return;
        [strongSelf finishWithFailure:@"实况照片保存超时，请检查照片权限"];
    });
}

- (void)saveResolvedMedia {
    if (self.failed) {
        [self finishWithFailure:self.video ? @"朋友圈视频下载失败，请稍后重试" : @"朋友圈媒体下载失败，请稍后重试"];
        return;
    }

    if (self.video) {
        NSString *path = [self.resolvedPaths.firstObject isKindOfClass:[NSString class]] ? self.resolvedPaths.firstObject : nil;
        if (path.length == 0) {
            [self finishWithFailure:@"朋友圈视频下载失败，请稍后重试"];
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:path]];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    WCAtlasLog(@"保存朋友圈视频失败：%@", error.localizedDescription ?: @"未知错误");
                    [self finishWithFailure:@"保存视频失败，请检查照片权限"];
                    return;
                }
                [self finishWithSuccess];
            });
        }];
        return;
    }

    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSUInteger index = 0; index < self.mediaItems.count; index++) {
        if ([self.livePhotoIndexes containsObject:@(index)]) continue;
        NSString *path = [self.resolvedPaths[index] isKindOfClass:[NSString class]] ? self.resolvedPaths[index] : nil;
        UIImage *image = path.length > 0 ? [UIImage imageWithContentsOfFile:path] : nil;
        if (!image) {
            [self finishWithFailure:@"朋友圈图片下载失败，请稍后重试"];
            return;
        }
        [images addObject:image];
    }

    void (^saveLivePhotos)(void) = ^{
        self.nextLivePhotoIndex = 0;
        [self saveNextLivePhoto];
    };
    if (images.count == 0) {
        saveLivePhotos();
        return;
    }
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        for (UIImage *image in images) {
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        }
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                WCAtlasLog(@"保存朋友圈图片失败：%@", error.localizedDescription ?: @"未知错误");
                [self finishWithFailure:@"保存图片失败，请检查照片权限"];
                return;
            }
            saveLivePhotos();
        });
    }];
}

- (void)finishMediaResolutionIfNeeded {
    if (self.remainingDownloads != 0 || self.saveStarted || self.finished) return;
    self.saveStarted = YES;
    [self saveResolvedMedia];
}

- (void)resolvePathForMediaItem:(id)mediaItem
                parentMediaItem:(id)parentMediaItem
                          index:(NSUInteger)index
                    videoPath:(BOOL)videoPath {
    BOOL useVideoSelectors = self.video || videoPath;
    NSArray *pathSelectors = useVideoSelectors
        ? @[@"pathForSightData", @"pathForData", @"pathForAttachVideoData", @"pathForExistData"]
        : @[@"pathForUhdData", @"pathForHdData", @"pathForData", @"pathForExistData"];
    NSString *path = videoPath
        ? WCAtlasLivePhotoExistingVideoPath(mediaItem, parentMediaItem)
        : WCAtlasMomentsExistingMediaPath(mediaItem, pathSelectors);
    if (path.length > 0) {
        NSMutableArray *targetPaths = videoPath ? self.resolvedVideoPaths : self.resolvedPaths;
        targetPaths[index] = path;
        self.remainingDownloads--;
        [self finishMediaResolutionIfNeeded];
        return;
    }

    Class downloaderClass = NSClassFromString(@"WCMediaDownloader");
    SEL initializer = NSSelectorFromString(@"initWithDataItem:mediaItem:");
    SEL startSelector = NSSelectorFromString(@"startDownloadWithCompletionHandler:");
    id downloader = downloaderClass && [downloaderClass instancesRespondToSelector:initializer]
        ? ((id (*)(id, SEL, id, id))objc_msgSend)([downloaderClass alloc], initializer, self.dataItem, mediaItem) : nil;
    if (!downloader || ![downloader respondsToSelector:startSelector]) {
        self.failed = YES;
        self.remainingDownloads--;
        [self finishMediaResolutionIfNeeded];
        return;
    }
    [self.downloaders addObject:downloader];
    __weak typeof(self) weakSelf = self;
    void (^completion)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.finished) return;
            [strongSelf finishDownloadedMediaItem:mediaItem
                                  parentMediaItem:parentMediaItem
                                            index:index
                                        videoPath:videoPath
                                    pathSelectors:pathSelectors
                                       downloader:downloader
                                          attempt:0];
        });
    };
    ((void (*)(id, SEL, id))objc_msgSend)(downloader, startSelector, completion);
}

- (void)finishDownloadedMediaItem:(id)mediaItem
                  parentMediaItem:(id)parentMediaItem
                            index:(NSUInteger)index
                        videoPath:(BOOL)videoPath
                    pathSelectors:(NSArray *)pathSelectors
                       downloader:(id)downloader
                          attempt:(NSUInteger)attempt {
    if (self.finished) return;
    NSString *resolvedPath = videoPath
        ? WCAtlasLivePhotoExistingVideoPath(mediaItem, parentMediaItem)
        : WCAtlasMomentsExistingMediaPath(mediaItem, pathSelectors);
    // AFN also rechecks after its completion when the path/file-size update is
    // slightly behind the callback. Keep this bounded below one second.
    if (resolvedPath.length == 0 && videoPath && attempt < 3) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf finishDownloadedMediaItem:mediaItem
                                  parentMediaItem:parentMediaItem
                                            index:index
                                        videoPath:videoPath
                                    pathSelectors:pathSelectors
                                       downloader:downloader
                                          attempt:attempt + 1];
        });
        return;
    }
    if (resolvedPath.length > 0) {
        NSMutableArray *targetPaths = videoPath ? self.resolvedVideoPaths : self.resolvedPaths;
        targetPaths[index] = resolvedPath;
    } else {
        self.failed = YES;
    }
    [self.downloaders removeObject:downloader];
    self.remainingDownloads--;
    [self finishMediaResolutionIfNeeded];
}

- (void)start {
    id contentObject = WCAtlasMomentsContentObject(self.dataItem);
    NSArray *mediaItems = WCAtlasMomentsMediaItems(self.dataItem);
    BOOL isVideo = WCAtlasMomentsBoolForSelector(contentObject, @"isVideoType");
    BOOL isPhoto = WCAtlasMomentsBoolForSelector(contentObject, @"isPhotoType");
    if ((!isVideo && !isPhoto) || mediaItems.count == 0) {
        [self finishWithFailure:@"该条朋友圈没有可保存的媒体"];
        return;
    }

    self.video = isVideo;
    self.mediaItems = [mediaItems subarrayWithRange:NSMakeRange(0, isVideo ? 1 : MIN((NSUInteger)9, mediaItems.count))];
    self.resolvedPaths = [NSMutableArray arrayWithCapacity:self.mediaItems.count];
    self.resolvedVideoPaths = [NSMutableArray arrayWithCapacity:self.mediaItems.count];
    self.livePhotoTimes = [NSMutableArray arrayWithCapacity:self.mediaItems.count];
    self.livePhotoIndexes = [NSMutableArray array];
    self.downloaders = [NSMutableArray array];
    self.livePhotoMakers = [NSMutableArray array];
    self.temporaryPaths = [NSMutableArray array];
    for (__unused id item in self.mediaItems) {
        [self.resolvedPaths addObject:NSNull.null];
        [self.resolvedVideoPaths addObject:NSNull.null];
        [self.livePhotoTimes addObject:NSNull.null];
    }

    NSMutableArray<NSDictionary *> *requests = [NSMutableArray array];
    for (NSUInteger index = 0; index < self.mediaItems.count; index++) {
        id mediaItem = self.mediaItems[index];
        [requests addObject:@{ @"item": mediaItem, @"index": @(index), @"video": @NO }];
        id livePhotoMediaItem = !isVideo ? WCAtlasMomentsObjectForSelector(mediaItem, @"livePhotoMediaItem") : nil;
        BOOL isLivePhoto = !isVideo && (WCAtlasMomentsBoolForSelector(mediaItem, @"isLivePhoto") || livePhotoMediaItem != nil);
        if (isLivePhoto) {
            long long stillImageTimeMs = 0;
            BOOL hasStillImageTime = WCAtlasMomentsLongLongForSelector(mediaItem, @"livePhotoStillImageTimeMs", &stillImageTimeMs);
            if (!hasStillImageTime && livePhotoMediaItem) {
                hasStillImageTime = WCAtlasMomentsLongLongForSelector(livePhotoMediaItem, @"livePhotoStillImageTimeMs", &stillImageTimeMs);
            }
            if (!livePhotoMediaItem) {
                self.failed = YES;
                continue;
            }
            [self.livePhotoIndexes addObject:@(index)];
            // A cold, never-played Live Photo commonly reports no still-image
            // timestamp (or zero). Match WeChatX by allowing that state; after
            // the MOV finishes downloading, the save path derives a safe time
            // from its duration instead of requiring playback to prime it.
            self.livePhotoTimes[index] = @(hasStillImageTime ? stillImageTimeMs : 0);
            [requests addObject:@{ @"item": livePhotoMediaItem, @"parent": mediaItem,
                                   @"index": @(index), @"video": @YES }];
        }
    }
    self.livePhotoSaveQueue = [self.livePhotoIndexes mutableCopy];
    self.remainingDownloads = requests.count;
    for (NSDictionary *request in requests) {
        [self resolvePathForMediaItem:request[@"item"]
                      parentMediaItem:request[@"parent"]
                                index:[request[@"index"] unsignedIntegerValue]
                          videoPath:[request[@"video"] boolValue]];
    }
    if (self.remainingDownloads == 0) [self finishMediaResolutionIfNeeded];
}

@end

static void WCAtlasForwardMoment(id dataItem, UIViewController *presenter) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsForwardEnabledKey) || !presenter.view.window) return;
    if (!WCAtlasMomentCanForward(dataItem)) {
        WCAtlasShowTransientMessage(@"当前朋友圈类型暂不支持转发", NO);
        return;
    }
    WCAtlasMomentsForwardTask *task = [WCAtlasMomentsForwardTask new];
    task.dataItem = dataItem;
    task.presenter = presenter;
    objc_setAssociatedObject(presenter, &WCAtlasMomentsForwardTaskKey, task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [task start];
}

static BOOL WCAtlasMomentCanSaveMedia(id dataItem) {
    id contentObject = WCAtlasMomentsContentObject(dataItem);
    return (WCAtlasMomentsBoolForSelector(contentObject, @"isPhotoType") ||
            WCAtlasMomentsBoolForSelector(contentObject, @"isVideoType")) &&
           WCAtlasMomentsMediaItems(dataItem).count > 0;
}

static void WCAtlasSaveMomentMedia(id dataItem, UIViewController *presenter) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsSaveImagesEnabledKey) || !presenter.view.window) return;
    if (!WCAtlasMomentCanSaveMedia(dataItem)) {
        WCAtlasShowTransientMessage(@"该条朋友圈没有可保存的媒体", NO);
        return;
    }
    WCAtlasMomentsMediaSaveTask *activeTask = [WCAtlasActiveMomentsMediaSaveTask isKindOfClass:[WCAtlasMomentsMediaSaveTask class]]
        ? WCAtlasActiveMomentsMediaSaveTask
        : objc_getAssociatedObject(dataItem, &WCAtlasMomentsDataItemSaveTaskKey);
    if ([activeTask isKindOfClass:[WCAtlasMomentsMediaSaveTask class]] && !activeTask.finished) {
        WCAtlasLog(@"已忽略同一条朋友圈媒体的重复保存触发");
        return;
    }
    WCAtlasMomentsMediaSaveTask *task = [WCAtlasMomentsMediaSaveTask new];
    task.dataItem = dataItem;
    task.presenter = presenter;
    objc_setAssociatedObject(presenter, &WCAtlasMomentsSaveTaskKey, task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(dataItem, &WCAtlasMomentsDataItemSaveTaskKey, task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasActiveMomentsMediaSaveTask = task;
    [task start];
}

static UIButton *WCAtlasMomentsForwardButton(id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightRegular];
    UIImage *icon = [UIImage systemImageNamed:@"arrow.turn.up.right" withConfiguration:configuration] ?:
                    [UIImage systemImageNamed:@"arrowshape.turn.up.right" withConfiguration:configuration] ?:
                    [UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:configuration];
    icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [button setImage:icon forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.tintColor = UIColor.darkGrayColor;
    button.accessibilityLabel = @"转发";
    button.layer.zPosition = 1000.0;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static BOOL WCAtlasMomentsVisibleTextIntersectsRect(UIView *view,
                                                   UIView *root,
                                                   UIView *excludedView,
                                                   UIView *excludedLabel,
                                                   CGRect rect) {
    if (!view || view == excludedView || view == excludedLabel || view.hidden || view.alpha <= 0.01) return NO;
    if ([view isKindOfClass:[UILabel class]] && ((UILabel *)view).text.length > 0) {
        UILabel *label = (UILabel *)view;
        CGRect textRect = [label textRectForBounds:label.bounds limitedToNumberOfLines:label.numberOfLines];
        CGRect textFrame = [label convertRect:textRect toView:root];
        if (CGRectIntersectsRect(textFrame, rect)) return YES;
    }
    for (UIView *subview in view.subviews) {
        if (WCAtlasMomentsVisibleTextIntersectsRect(subview, root, excludedView, excludedLabel, rect)) return YES;
    }
    return NO;
}

static void WCAtlasSynchronizeMomentsForwardButton(WCTimeLineCellView *cell) {
    UIButton *button = objc_getAssociatedObject(cell, &WCAtlasMomentsForwardButtonKey);
    UIButton *saveButton = objc_getAssociatedObject(cell, &WCAtlasMomentsSaveButtonKey);
    id dataItem = WCAtlasMomentsObjectForName(cell, @"m_dataItem");
    BOOL detailContext = WCAtlasMomentsIsNativeDetailContext(cell);
    BOOL quickComment = WCAtlasEnhancementEnabled(WCAtlasMomentsQuickCommentKey) && !detailContext;
    BOOL shouldShowForward = quickComment && WCAtlasEnhancementEnabled(WCAtlasMomentsForwardEnabledKey);
    BOOL shouldShowSave = quickComment && WCAtlasEnhancementEnabled(WCAtlasMomentsSaveImagesEnabledKey) &&
                          WCAtlasMomentCanSaveMedia(dataItem);
    BOOL shouldShow = shouldShowForward || shouldShowSave;
    UIView *operateButton = WCAtlasMomentsObjectForName(cell, @"m_operateBtn");
    NSValue *storedFrameValue = [operateButton isKindOfClass:[UIView class]]
        ? objc_getAssociatedObject(operateButton, &WCAtlasMomentsOriginalOperateFrameKey)
        : nil;
    BOOL hasLayout = cell.window && CGRectGetWidth(cell.bounds) > 0.0 &&
                      [operateButton isKindOfClass:[UIView class]] &&
                      CGRectGetWidth(operateButton.bounds) > 0.0;
    if (!shouldShow || !dataItem || !hasLayout) {
        if (storedFrameValue) {
            operateButton.frame = storedFrameValue.CGRectValue;
            objc_setAssociatedObject(operateButton, &WCAtlasMomentsOriginalOperateFrameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [button removeFromSuperview];
        [saveButton removeFromSuperview];
        objc_setAssociatedObject(cell, &WCAtlasMomentsForwardButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCAtlasMomentsSaveButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!button) {
        button = WCAtlasMomentsForwardButton(cell, @selector(wcatlas_handleMomentsForward:));
        objc_setAssociatedObject(cell, &WCAtlasMomentsForwardButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!saveButton) {
        saveButton = WCAtlasMomentsForwardButton(cell, @selector(wcatlas_handleMomentsSaveImages:));
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightRegular];
        UIImage *icon = [UIImage systemImageNamed:@"square.and.arrow.down" withConfiguration:configuration] ?:
                        [UIImage systemImageNamed:@"arrow.down.to.line" withConfiguration:configuration];
        [saveButton setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        saveButton.accessibilityLabel = @"保存朋友圈媒体";
        objc_setAssociatedObject(cell, &WCAtlasMomentsSaveButtonKey, saveButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    button.hidden = !shouldShowForward;
    saveButton.hidden = !shouldShowSave;
    if (button.superview != cell) {
        [button removeFromSuperview];
        [cell addSubview:button];
    }
    if (saveButton.superview != cell) {
        [saveButton removeFromSuperview];
        [cell addSubview:saveButton];
    }
    button.tintColor = operateButton.tintColor ?: UIColor.darkGrayColor;
    saveButton.tintColor = button.tintColor;
    CGRect originalFrame = storedFrameValue ? storedFrameValue.CGRectValue : operateButton.frame;
    NSUInteger slotCount = (shouldShowForward ? 1 : 0) + (shouldShowSave ? 1 : 0);
    CGRect shiftedFrame = CGRectOffset(originalFrame, -36.0 * slotCount, 0.0);
    CGRect oneSlotFrame = CGRectOffset(originalFrame, -36.0, 0.0);
    CGRect twoSlotFrame = CGRectOffset(originalFrame, -72.0, 0.0);
    if (storedFrameValue &&
        !CGRectEqualToRect(operateButton.frame, originalFrame) &&
        !CGRectEqualToRect(operateButton.frame, oneSlotFrame) &&
        !CGRectEqualToRect(operateButton.frame, twoSlotFrame)) {
        originalFrame = operateButton.frame;
        shiftedFrame = CGRectOffset(originalFrame, -36.0 * slotCount, 0.0);
    }
    objc_setAssociatedObject(operateButton, &WCAtlasMomentsOriginalOperateFrameKey,
                             [NSValue valueWithCGRect:originalFrame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIView *operateSuperview = operateButton.superview;
    CGRect originalFrameInCell = operateSuperview
        ? [operateSuperview convertRect:originalFrame toView:cell]
        : [operateButton convertRect:operateButton.bounds toView:cell];
    CGRect shiftedFrameInCell = operateSuperview
        ? [operateSuperview convertRect:shiftedFrame toView:cell]
        : shiftedFrame;
    UIView *timeLabel = WCAtlasMomentsObjectForName(cell, @"m_timeLabel");
    BOOL shouldStackVertically = WCAtlasEnhancementEnabled(WCAtlasMomentsPreciseTimeKey) &&
        WCAtlasMomentsVisibleTextIntersectsRect(cell, cell, operateButton, timeLabel, shiftedFrameInCell) &&
        CGRectGetMinY(originalFrameInCell) >= CGRectGetHeight(originalFrameInCell) + 2.0;
    if (shouldStackVertically) {
        operateButton.frame = originalFrame;
        CGFloat nextX = CGRectGetMinX(originalFrameInCell) - 36.0 * (slotCount - 1);
        if (shouldShowForward) {
            button.frame = CGRectMake(nextX, CGRectGetMinY(originalFrameInCell) - CGRectGetHeight(originalFrameInCell) - 2.0,
                                      CGRectGetWidth(originalFrameInCell), CGRectGetHeight(originalFrameInCell));
            nextX += 36.0;
        }
        if (shouldShowSave) {
            saveButton.frame = CGRectMake(nextX, CGRectGetMinY(originalFrameInCell) - CGRectGetHeight(originalFrameInCell) - 2.0,
                                          CGRectGetWidth(originalFrameInCell), CGRectGetHeight(originalFrameInCell));
        }
    } else {
        operateButton.frame = shiftedFrame;
        CGFloat nextX = CGRectGetMinX(originalFrameInCell) - 36.0 * (slotCount - 1);
        if (shouldShowForward) {
            button.frame = CGRectMake(nextX, CGRectGetMinY(originalFrameInCell), CGRectGetWidth(originalFrameInCell), CGRectGetHeight(originalFrameInCell));
            nextX += 36.0;
        }
        if (shouldShowSave) {
            saveButton.frame = CGRectMake(nextX, CGRectGetMinY(originalFrameInCell), CGRectGetWidth(originalFrameInCell), CGRectGetHeight(originalFrameInCell));
        }
    }
    if (shouldShowForward) {
        button.alpha = 1.0;
        [cell bringSubviewToFront:button];
    }
    if (shouldShowSave) {
        saveButton.alpha = 1.0;
        [cell bringSubviewToFront:saveButton];
    }
}

static void WCAtlasRestoreMomentsFloatMenu(WCOperateFloatView *floatView) {
    WCAtlasMomentsFloatMenuSnapshot *snapshot = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSnapshotKey);
    if (![snapshot isKindOfClass:[WCAtlasMomentsFloatMenuSnapshot class]] || snapshot.applying) return;
    snapshot.applying = YES;
    [snapshot.expandedLayerMask removeAllAnimations];
    UIButton *button = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatForwardButtonKey);
    UIButton *saveButton = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveButtonKey);
    UIImageView *separator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSeparatorKey);
    UIImageView *saveSeparator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveSeparatorKey);
    floatView.frame = snapshot.baseFrame;
    if (snapshot.container != floatView) snapshot.container.frame = snapshot.baseContainerFrame;
    NSUInteger count = MIN(snapshot.baseViews.count, snapshot.baseFrames.count);
    for (NSUInteger index = 0; index < count; index++) {
        snapshot.baseViews[index].frame = snapshot.baseFrames[index].CGRectValue;
    }
    button.hidden = YES;
    saveButton.hidden = YES;
    separator.hidden = YES;
    saveSeparator.hidden = YES;
    floatView.layer.mask = snapshot.originalLayerMask;
    snapshot.applying = NO;
    objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSnapshotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static WCAtlasMomentsFloatMenuSnapshot *WCAtlasCaptureMomentsFloatMenu(WCOperateFloatView *floatView,
                                                                   UIButton *button,
                                                                   UIButton *saveButton,
                                                                   UIView *separator,
                                                                   UIView *saveSeparator) {
    UIControl *likeButton = nil;
    UIControl *commentButton = nil;
    WCAtlasMomentsNativeFloatControls(floatView, &likeButton, &commentButton);
    UIControl *anchor = commentButton ?: likeButton;
    if (![anchor isKindOfClass:[UIControl class]]) return nil;

    UIView *container = anchor.superview ?: floatView;
    CGFloat slotWidth = CGRectGetWidth(anchor.frame);
    if (slotWidth < 44.0) slotWidth = 80.0;

    WCAtlasMomentsFloatMenuSnapshot *snapshot = [WCAtlasMomentsFloatMenuSnapshot new];
    snapshot.baseFrame = floatView.frame;
    NSUInteger slotCount = (button.hidden ? 0 : 1) + (saveButton.hidden ? 0 : 1);
    snapshot.addedWidth = slotWidth * slotCount;
    snapshot.container = container;
    snapshot.baseContainerFrame = container.frame;
    snapshot.containerIsDirectChild = container.superview == floatView;
    snapshot.originalLayerMask = floatView.layer.mask;

    NSMutableArray<UIView *> *baseViews = [NSMutableArray array];
    NSMutableArray<NSValue *> *baseFrames = [NSMutableArray array];
    for (UIView *view in container.subviews) {
        if (view == button || view == saveButton || view == separator || view == saveSeparator) continue;
        [baseViews addObject:view];
        [baseFrames addObject:[NSValue valueWithCGRect:view.frame]];
    }
    snapshot.baseViews = baseViews;
    snapshot.baseFrames = baseFrames;

    CGFloat slotHeight = CGRectGetHeight(anchor.frame);
    CGFloat slotY = CGRectGetMinY(anchor.frame);
    if (slotHeight < 24.0) {
        slotHeight = CGRectGetHeight(container.bounds);
        slotY = 0.0;
    }
    CGFloat separatorWidth = CGRectGetWidth(separator.bounds);
    if (separatorWidth < 0.75) separatorWidth = 1.0;
    CGFloat separatorHeight = CGRectGetHeight(separator.bounds);
    if (separatorHeight < 12.0) separatorHeight = 24.0;
    CGFloat separatorY = slotY + (slotHeight - separatorHeight) * 0.5;
    CGFloat containerWidth = CGRectGetWidth(container.bounds);
    if (containerWidth <= 0.0) containerWidth = CGRectGetWidth(snapshot.baseContainerFrame);
    CGFloat nextX = containerWidth;
    if (!button.hidden) {
        snapshot.forwardFrame = CGRectMake(nextX, slotY, slotWidth, slotHeight);
        snapshot.separatorFrame = CGRectMake(nextX - separatorWidth, separatorY, separatorWidth, separatorHeight);
        nextX += slotWidth;
    }
    if (!saveButton.hidden) {
        snapshot.saveFrame = CGRectMake(nextX, slotY, slotWidth, slotHeight);
        snapshot.saveSeparatorFrame = CGRectMake(nextX - separatorWidth, separatorY, separatorWidth, separatorHeight);
    }
    if (button.hidden) snapshot.separatorFrame = CGRectMake(containerWidth - separatorWidth,
                                         separatorY,
                                         separatorWidth,
                                         separatorHeight);
    return snapshot;
}

static void WCAtlasCollectMomentsNativeSeparators(UIView *root,
                                                 UIView *excluded,
                                                 NSMutableArray<UIImageView *> *matches) {
    for (UIView *view in root.subviews) {
        if (view == excluded) continue;
        if ([view isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)view;
            CGFloat width = CGRectGetWidth(imageView.bounds);
            CGFloat height = CGRectGetHeight(imageView.bounds);
            if (width >= 0.75 && width <= 2.0 && height >= 12.0 && height <= 32.0) {
                [matches addObject:imageView];
            }
        }
        WCAtlasCollectMomentsNativeSeparators(view, excluded, matches);
    }
}

static UIImageView *WCAtlasMomentsNativeSeparator(WCOperateFloatView *floatView,
                                                 UIControl *anchor,
                                                 UIImageView *excluded) {
    NSMutableArray<UIImageView *> *candidates = [NSMutableArray array];
    WCAtlasCollectMomentsNativeSeparators(floatView, excluded, candidates);
    UIImageView *nearest = nil;
    CGFloat nearestDistance = CGFLOAT_MAX;
    CGFloat anchorEdge = CGRectGetMinX([anchor convertRect:anchor.bounds toView:floatView]);
    for (UIImageView *candidate in candidates) {
        NSString *description = candidate.image.description ?: @"";
        if ([description rangeOfString:@"AlbumCommentLine"
                               options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return candidate;
        }
        CGRect frame = [candidate convertRect:candidate.bounds toView:floatView];
        CGFloat distance = fabs(CGRectGetMaxX(frame) - anchorEdge);
        if (distance < nearestDistance) {
            nearest = candidate;
            nearestDistance = distance;
        }
    }
    return nearestDistance <= 3.0 ? nearest : nil;
}

static UIImageView *WCAtlasCloneMomentsNativeSeparator(UIImageView *source,
                                                      UIImageView *separator) {
    UIImage *image = source.image ?: [UIImage imageNamed:@"AlbumCommentLine"];
    if (!separator || separator.image != image) {
        [separator removeFromSuperview];
        separator = [[UIImageView alloc] initWithImage:image highlightedImage:source.highlightedImage];
    }
    separator.contentMode = source ? source.contentMode : UIViewContentModeScaleToFill;
    separator.backgroundColor = source.backgroundColor;
    separator.tintColor = source.tintColor;
    separator.alpha = source ? source.alpha : 1.0;
    separator.highlighted = source.highlighted;
    separator.userInteractionEnabled = NO;
    return separator;
}

static void WCAtlasApplyMomentsFloatMenuSnapshot(WCOperateFloatView *floatView) {
    WCAtlasMomentsFloatMenuSnapshot *snapshot = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSnapshotKey);
    if (![snapshot isKindOfClass:[WCAtlasMomentsFloatMenuSnapshot class]] ||
        snapshot.addedWidth <= 0.0 || snapshot.applying) return;
    snapshot.applying = YES;

    UIButton *button = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatForwardButtonKey);
    UIButton *saveButton = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveButtonKey);
    UIImageView *separator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSeparatorKey);
    UIImageView *saveSeparator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveSeparatorKey);
    CGRect expandedFrame = snapshot.baseFrame;
    expandedFrame.origin.x -= snapshot.addedWidth;
    expandedFrame.size.width += snapshot.addedWidth;
    floatView.frame = expandedFrame;

    if (snapshot.container != floatView) {
        CGRect containerFrame = snapshot.baseContainerFrame;
        containerFrame.size.width += snapshot.addedWidth;
        snapshot.container.frame = containerFrame;
    }

    NSUInteger count = MIN(snapshot.baseViews.count, snapshot.baseFrames.count);
    CGFloat containerWidth = CGRectGetWidth(snapshot.baseContainerFrame);
    for (NSUInteger index = 0; index < count; index++) {
        UIView *view = snapshot.baseViews[index];
        CGRect frame = snapshot.baseFrames[index].CGRectValue;
        BOOL fillsContainer = CGRectGetMinX(frame) <= 1.0 &&
                              CGRectGetWidth(frame) >= containerWidth - 2.0;
        if (fillsContainer) {
            frame.size.width += snapshot.addedWidth;
        }
        view.frame = frame;
    }

    button.frame = snapshot.forwardFrame;
    saveButton.frame = snapshot.saveFrame;
    separator.frame = snapshot.separatorFrame;
    saveSeparator.frame = snapshot.saveSeparatorFrame;
    if (!button.hidden) {
        button.alpha = 1.0;
        separator.hidden = NO;
        [snapshot.container bringSubviewToFront:separator];
        [snapshot.container bringSubviewToFront:button];
    }
    if (!saveButton.hidden) {
        saveButton.alpha = 1.0;
        saveSeparator.hidden = NO;
        [snapshot.container bringSubviewToFront:saveSeparator];
        [snapshot.container bringSubviewToFront:saveButton];
    }

    if (!snapshot.expandedLayerMask) {
        snapshot.expandedLayerMask = [CAShapeLayer layer];
        snapshot.expandedLayerMask.fillColor = UIColor.blackColor.CGColor;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    snapshot.expandedLayerMask.frame = floatView.bounds;
    snapshot.expandedLayerMask.path = [UIBezierPath bezierPathWithRect:floatView.bounds].CGPath;
    floatView.layer.mask = snapshot.expandedLayerMask;
    [CATransaction commit];
    snapshot.applying = NO;
}

static void WCAtlasPrepareMomentsFloatMenu(WCOperateFloatView *floatView) {
    id dataItem = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatDataItemKey);
    BOOL detailContext = WCAtlasMomentsIsNativeDetailContext(floatView);
    BOOL allowFloatExtension = (!WCAtlasEnhancementEnabled(WCAtlasMomentsQuickCommentKey) || detailContext) &&
                               dataItem != nil;
    BOOL shouldShowForward = allowFloatExtension && WCAtlasEnhancementEnabled(WCAtlasMomentsForwardEnabledKey);
    BOOL shouldShowSave = allowFloatExtension && WCAtlasEnhancementEnabled(WCAtlasMomentsSaveImagesEnabledKey) &&
                          WCAtlasMomentCanSaveMedia(dataItem);
    BOOL shouldShow = shouldShowForward || shouldShowSave;
    UIControl *likeButton = nil;
    UIControl *commentButton = nil;
    WCAtlasMomentsNativeFloatControls(floatView, &likeButton, &commentButton);
    UIControl *anchor = commentButton ?: likeButton;
    UIButton *button = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatForwardButtonKey);
    UIButton *saveButton = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveButtonKey);
    UIImageView *separator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSeparatorKey);
    UIImageView *saveSeparator = objc_getAssociatedObject(floatView, &WCAtlasMomentsFloatSaveSeparatorKey);
    if (!shouldShow || ![anchor isKindOfClass:[UIControl class]]) {
        WCAtlasRestoreMomentsFloatMenu(floatView);
        [button removeFromSuperview];
        [saveButton removeFromSuperview];
        [separator removeFromSuperview];
        [saveSeparator removeFromSuperview];
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSnapshotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatForwardButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSaveButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSeparatorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSaveSeparatorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!saveButton) {
        saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [saveButton setTitle:@"保存" forState:UIControlStateNormal];
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightRegular];
        UIImage *icon = [UIImage systemImageNamed:@"square.and.arrow.down" withConfiguration:configuration] ?:
                        [UIImage systemImageNamed:@"arrow.down.to.line" withConfiguration:configuration];
        [saveButton setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        saveButton.accessibilityIdentifier = @"moments_save_images";
        saveButton.accessibilityLabel = @"保存朋友圈媒体";
        saveButton.contentEdgeInsets = UIEdgeInsetsZero;
        saveButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        saveButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, -3.0, 0.0, 3.0);
        saveButton.titleEdgeInsets = UIEdgeInsetsMake(0.0, 3.0, 0.0, -3.0);
        [saveButton addTarget:floatView action:@selector(wcatlas_handleMomentsSaveImages:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSaveButtonKey, saveButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIView *container = anchor.superview ?: floatView;
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:@"转发" forState:UIControlStateNormal];
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightRegular];
        UIImage *icon = [UIImage systemImageNamed:@"arrow.turn.up.right" withConfiguration:configuration] ?:
                        [UIImage systemImageNamed:@"arrowshape.turn.up.right" withConfiguration:configuration] ?:
                        [UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:configuration];
        [button setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        button.accessibilityIdentifier = @"moments_forward";
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        button.contentEdgeInsets = UIEdgeInsetsZero;
        button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        button.imageEdgeInsets = UIEdgeInsetsMake(0.0, -3.0, 0.0, 3.0);
        button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 3.0, 0.0, -3.0);
        [button addTarget:floatView action:@selector(wcatlas_handleMomentsForward:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatForwardButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    button.hidden = !shouldShowForward;
    saveButton.hidden = !shouldShowSave;
    UIButton *anchorButton = [anchor isKindOfClass:[UIButton class]] ? (UIButton *)anchor : nil;
    UIColor *contentColor = [anchorButton titleColorForState:UIControlStateNormal] ?: anchor.tintColor ?: UIColor.whiteColor;
    [button setTitleColor:contentColor forState:UIControlStateNormal];
    [saveButton setTitleColor:contentColor forState:UIControlStateNormal];
    [button setTitleColor:[anchorButton titleColorForState:UIControlStateHighlighted] ?: contentColor
                 forState:UIControlStateHighlighted];
    [saveButton setTitleColor:[anchorButton titleColorForState:UIControlStateHighlighted] ?: contentColor
                     forState:UIControlStateHighlighted];
    [button setTitleColor:[anchorButton titleColorForState:UIControlStateDisabled] ?: contentColor
                 forState:UIControlStateDisabled];
    button.tintColor = contentColor;
    saveButton.tintColor = contentColor;
    button.titleLabel.font = anchorButton.titleLabel.font ?: [UIFont systemFontOfSize:14.0];
    saveButton.titleLabel.font = button.titleLabel.font;
    button.contentHorizontalAlignment = anchorButton ? anchorButton.contentHorizontalAlignment : UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = anchorButton ? anchorButton.contentVerticalAlignment : UIControlContentVerticalAlignmentCenter;
    button.enabled = anchor.enabled;
    saveButton.enabled = anchor.enabled;
    if (button.superview != container) {
        [button removeFromSuperview];
        [container addSubview:button];
    }
    if (saveButton.superview != container) {
        [saveButton removeFromSuperview];
        [container addSubview:saveButton];
    }
    UIImageView *nativeSeparator = WCAtlasMomentsNativeSeparator(floatView, anchor, separator);
    UIImageView *clonedSeparator = WCAtlasCloneMomentsNativeSeparator(nativeSeparator, separator);
    if (clonedSeparator != separator) {
        separator = clonedSeparator;
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSeparatorKey, separator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (separator.superview != container) {
        [separator removeFromSuperview];
        [container addSubview:separator];
    }

    UIImageView *clonedSaveSeparator = WCAtlasCloneMomentsNativeSeparator(nativeSeparator, saveSeparator);
    if (clonedSaveSeparator != saveSeparator) {
        saveSeparator = clonedSaveSeparator;
        objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSaveSeparatorKey, saveSeparator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (saveSeparator.superview != container) {
        [saveSeparator removeFromSuperview];
        [container addSubview:saveSeparator];
    }

    WCAtlasMomentsFloatMenuSnapshot *snapshot = WCAtlasCaptureMomentsFloatMenu(floatView, button, saveButton, separator, saveSeparator);
    objc_setAssociatedObject(floatView, &WCAtlasMomentsFloatSnapshotKey, snapshot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasApplyMomentsFloatMenuSnapshot(floatView);
}

static BOOL WCAtlasTriggerNativeMomentsComment(WCOperateFloatView *floatView) {
    UIControl *commentButton = nil;
    WCAtlasMomentsNativeFloatControls(floatView, nil, &commentButton);
    if (![commentButton isKindOfClass:[UIControl class]]) return NO;
    [commentButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    return YES;
}

static NSDateFormatter *WCAtlasMomentsPreciseDateFormatter(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    });
    return formatter;
}

static id WCAtlasMomentsValueForExactSelector(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void WCAtlasRestoreMomentsTimeLabel(WCTimeLineCellView *cell, id label) {
    if (![objc_getAssociatedObject(cell, &WCAtlasMomentsPreciseTimeAppliedKey) boolValue]) return;
    SEL setTextSelector = NSSelectorFromString(@"setText:");
    if ([label respondsToSelector:setTextSelector]) {
        id original = objc_getAssociatedObject(cell, &WCAtlasMomentsOriginalTimeTextKey);
        ((void (*)(id, SEL, id))objc_msgSend)(label, setTextSelector, original == NSNull.null ? nil : original);
    }
    NSNumber *originalLines = objc_getAssociatedObject(cell, &WCAtlasMomentsOriginalTimeLinesKey);
    SEL linesSelector = NSSelectorFromString(@"setNumberOfLines:");
    if (originalLines && [label respondsToSelector:linesSelector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(label, linesSelector, originalLines.integerValue);
    }
    objc_setAssociatedObject(cell, &WCAtlasMomentsPreciseTimeAppliedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *WCAtlasMomentsPreciseTimeText(unsigned int createTime) {
    if (createTime == 0) return nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *format = WCAtlasNormalizedMomentsDateFormat([defaults stringForKey:WCAtlasMomentsPreciseTimeFormatKey]);
    if (!format) format = WCAtlasMomentsPreciseTimeDefaultFormat;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)createTime];
    NSDateFormatter *formatter = WCAtlasMomentsPreciseDateFormatter();
    @synchronized (formatter) {
        formatter.timeZone = NSTimeZone.localTimeZone;
        if (![formatter.dateFormat isEqualToString:format]) formatter.dateFormat = format;
        return [formatter stringFromDate:date];
    }
}

static void WCAtlasApplyMomentsPreciseTime(WCTimeLineCellView *cell, BOOL nativeTimeRefreshed) {
    if (!cell) return;
    id label = WCAtlasMomentsValueForExactSelector(cell, @"m_timeLabel");
    if (!label) return;
    SEL textSelector = NSSelectorFromString(@"text");
    SEL setTextSelector = NSSelectorFromString(@"setText:");
    if (![label respondsToSelector:textSelector] || ![label respondsToSelector:setTextSelector]) return;

    if (nativeTimeRefreshed) {
        id originalText = ((id (*)(id, SEL))objc_msgSend)(label, textSelector);
        objc_setAssociatedObject(cell, &WCAtlasMomentsOriginalTimeTextKey,
                                 originalText ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SEL numberOfLinesSelector = NSSelectorFromString(@"numberOfLines");
        if ([label respondsToSelector:numberOfLinesSelector]) {
            NSInteger lines = ((NSInteger (*)(id, SEL))objc_msgSend)(label, numberOfLinesSelector);
            objc_setAssociatedObject(cell, &WCAtlasMomentsOriginalTimeLinesKey,
                                     @(lines), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(cell, &WCAtlasMomentsPreciseTimeAppliedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!objc_getAssociatedObject(cell, &WCAtlasMomentsOriginalTimeTextKey)) {
        id currentText = ((id (*)(id, SEL))objc_msgSend)(label, textSelector);
        objc_setAssociatedObject(cell, &WCAtlasMomentsOriginalTimeTextKey,
                                 currentText ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsPreciseTimeKey)) {
        WCAtlasRestoreMomentsTimeLabel(cell, label);
        return;
    }
    id dataItem = WCAtlasMomentsValueForExactSelector(cell, @"m_dataItem");
    SEL createTimeSelector = NSSelectorFromString(@"createtime");
    if (!dataItem || ![dataItem respondsToSelector:createTimeSelector]) {
        WCAtlasRestoreMomentsTimeLabel(cell, label);
        return;
    }
    unsigned int createTime = 0;
    @try {
        createTime = ((unsigned int (*)(id, SEL))objc_msgSend)(dataItem, createTimeSelector);
    } @catch (__unused NSException *exception) {
        WCAtlasRestoreMomentsTimeLabel(cell, label);
        return;
    }
    NSString *preciseText = WCAtlasMomentsPreciseTimeText(createTime);
    if (preciseText.length == 0) {
        WCAtlasRestoreMomentsTimeLabel(cell, label);
        return;
    }
    NSString *currentText = ((id (*)(id, SEL))objc_msgSend)(label, textSelector);
    if (![currentText isEqualToString:preciseText]) {
        ((void (*)(id, SEL, id))objc_msgSend)(label, setTextSelector, preciseText);
    }
    SEL linesSelector = NSSelectorFromString(@"setNumberOfLines:");
    if ([label respondsToSelector:linesSelector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(label, linesSelector, 1);
    }
    objc_setAssociatedObject(cell, &WCAtlasMomentsPreciseTimeAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasSynchronizeMomentsCell(WCTimeLineCellView *cell) {
    if (!cell) return;
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(cell, &WCAtlasMomentsDoubleTapRecognizerKey);
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasMomentsDoubleTapLikeKey) &&
                   !WCAtlasMomentsIsNativeDetailContext(cell);
    if (enabled && !recognizer) {
        recognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wcatlas_handleMomentsDoubleTap)];
        recognizer.numberOfTapsRequired = 2;
        recognizer.cancelsTouchesInView = NO;
        [cell addGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCAtlasMomentsDoubleTapRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!enabled && recognizer) {
        [cell removeGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCAtlasMomentsDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    WCAtlasApplyMomentsPreciseTime(cell, NO);
    WCAtlasSynchronizeMomentsForwardButton(cell);
}

static void WCAtlasSynchronizeMomentsCellsInView(UIView *view) {
    if (!view) return;
    Class cellClass = NSClassFromString(@"WCTimeLineCellView");
    if (cellClass && [view isKindOfClass:cellClass]) WCAtlasSynchronizeMomentsCell((WCTimeLineCellView *)view);
    Class floatClass = NSClassFromString(@"WCOperateFloatView");
    if (floatClass && [view isKindOfClass:floatClass]) {
        WCAtlasApplyMomentsFloatMenuSnapshot((WCOperateFloatView *)view);
    }
    for (UIView *subview in view.subviews) WCAtlasSynchronizeMomentsCellsInView(subview);
}

static void WCAtlasSynchronizeVisibleMomentsCells(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                    if (!window.hidden) WCAtlasSynchronizeMomentsCellsInView(window);
                }
            }
            return;
        }
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (!window.hidden) WCAtlasSynchronizeMomentsCellsInView(window);
        }
    });
}

static void WCAtlasShowMomentsHeart(WCTimeLineCellView *cell) {
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(cell, &WCAtlasMomentsDoubleTapRecognizerKey);
    UIWindow *window = cell.window;
    if (!window || !recognizer) return;
    CGPoint point = [recognizer locationInView:window];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:34.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *heart = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill" withConfiguration:configuration]];
    heart.tintColor = [UIColor colorWithRed:0.96 green:0.25 blue:0.34 alpha:1.0];
    heart.contentMode = UIViewContentModeScaleAspectFit;
    heart.bounds = CGRectMake(0.0, 0.0, 44.0, 44.0);
    heart.center = point;
    heart.alpha = 0.0;
    heart.transform = CGAffineTransformMakeScale(0.52, 0.52);
    heart.userInteractionEnabled = NO;
    [window addSubview:heart];
    [UIView animateKeyframesWithDuration:0.52 delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewAnimationOptionAllowUserInteraction animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.30 animations:^{
            heart.alpha = 1.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -5.0), CGAffineTransformMakeScale(1.12, 1.12));
        }];
        [UIView addKeyframeWithRelativeStartTime:0.30 relativeDuration:0.32 animations:^{
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -12.0), CGAffineTransformIdentity);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.62 relativeDuration:0.38 animations:^{
            heart.alpha = 0.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -24.0), CGAffineTransformMakeScale(0.88, 0.88));
        }];
    } completion:^(__unused BOOL finished) {
        [heart removeFromSuperview];
    }];
}

static void WCAtlasPlayMomentsLikeHaptic(NSUserDefaults *defaults) {
    if (![defaults boolForKey:WCAtlasMomentsLikeHapticEnabledKey]) return;
    CGFloat savedIntensity = [defaults objectForKey:WCAtlasMomentsLikeHapticIntensityKey] ? [defaults doubleForKey:WCAtlasMomentsLikeHapticIntensityKey] : 0.65;
    CGFloat calibratedIntensity = savedIntensity < 0.34 ? 0.58 : (savedIntensity < 0.75 ? 0.76 : 0.90);
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    if (@available(iOS 13.0, *)) [generator impactOccurredWithIntensity:calibratedIntensity];
    else [generator impactOccurred];
}

static UIButton *WCAtlasFindButton(NSString *title, UIView *rootView) {
    if (!rootView || title.length == 0) return nil;
    for (UIView *subview in rootView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *buttonTitle = button.currentTitle ?: button.currentAttributedTitle.string;
            if ([buttonTitle isEqualToString:title] && button.enabled && !button.hidden && button.alpha > 0.01) return button;
        }
        UIButton *button = WCAtlasFindButton(title, subview);
        if (button) return button;
    }
    return nil;
}

static UIViewController *WCAtlasTopControllerForLoginToast(UIViewController *controller) {
    if (controller.presentedViewController) return WCAtlasTopControllerForLoginToast(controller.presentedViewController);
    if ([controller isKindOfClass:[UINavigationController class]]) {
        return WCAtlasTopControllerForLoginToast(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        return WCAtlasTopControllerForLoginToast(((UITabBarController *)controller).selectedViewController);
    }
    return controller;
}

static UIWindow *WCAtlasActiveApplicationWindow(void) {
    if (@available(iOS 13.0, *)) {
        UIWindow *fallbackWindow = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if ([NSStringFromClass(candidate.class) containsString:@"iConsole"]) continue;
                if (candidate.isKeyWindow) return candidate;
                if (!candidate.hidden && candidate.alpha > 0.0 && !fallbackWindow) fallbackWindow = candidate;
            }
        }
        if (fallbackWindow) return fallbackWindow;
    }
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if ([NSStringFromClass(candidate.class) containsString:@"iConsole"]) continue;
        if (candidate.isKeyWindow) return candidate;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static BaseMsgContentViewController *WCAtlasResolveVisibleChatController(void) {
    BaseMsgContentViewController *cached = WCAtlasVisibleChatController;
    if (cached.isViewLoaded && cached.view.window &&
        (!cached.navigationController || cached.navigationController.topViewController == cached)) return cached;
    BaseMsgContentViewController *controller =
        (BaseMsgContentViewController *)WCAtlasPrivateCurrentChatController();
    if (controller) WCAtlasVisibleChatController = controller;
    return controller;
}

static void WCAtlasRefreshPinnedMessageGlassInView(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:NSClassFromString(@"MMMsgCommonTipsView")]) {
        WCAtlasUpdatePinnedMessageGlass(view);
    }
    for (UIView *subview in view.subviews) WCAtlasRefreshPinnedMessageGlassInView(subview);
}

static void WCAtlasRefreshGlassBackdropsInView(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:WCAtlasGlassCapsuleView.class]) {
        [(WCAtlasGlassCapsuleView *)view refreshBackdropAfterForeground];
    }
    for (UIView *subview in view.subviews) WCAtlasRefreshGlassBackdropsInView(subview);
}

static void WCAtlasRefreshAntiRevokeCellsInView(UIView *view) {
    if (!view) return;
    Class cellClass = NSClassFromString(@"CommonMessageCellView");
    if (cellClass && [view isKindOfClass:cellClass]) {
        SEL refreshSelector = NSSelectorFromString(@"wcatlas_scheduleAntiRevokeSidePromptRefresh");
        if ([view respondsToSelector:refreshSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(view, refreshSelector);
        }
    }
    Class systemCellClass = NSClassFromString(@"SystemMessageCellView");
    if (systemCellClass && [view isKindOfClass:systemCellClass]) {
        SEL colorSelector = NSSelectorFromString(@"wcatlas_applyAntiRevokeTextColor");
        if ([view respondsToSelector:colorSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(view, colorSelector);
        }
    }
    for (UIView *subview in view.subviews) WCAtlasRefreshAntiRevokeCellsInView(subview);
}

static void WCAtlasRefreshVisibleAntiRevokeCells(void) {
    UIWindow *window = WCAtlasActiveApplicationWindow();
    if (window) WCAtlasRefreshAntiRevokeCellsInView(window);
}

static void WCAtlasSynchronizeReplyGesturesInView(UIView *view) {
    if (!view) return;
    Class cellClass = NSClassFromString(@"CommonMessageCellView");
    if (cellClass && [view isKindOfClass:cellClass]) {
        WCAtlasSynchronizeReplyGesture((CommonMessageCellView *)view);
        WCAtlasSynchronizeAvatarQuickGesture((CommonMessageCellView *)view);
        WCAtlasScheduleMessageTimeRefresh(view);
    }
    for (UIView *subview in view.subviews) WCAtlasSynchronizeReplyGesturesInView(subview);
}

static void WCAtlasSynchronizeVisibleReplyGestures(void) {
    UIWindow *window = WCAtlasActiveApplicationWindow();
    if (window) WCAtlasSynchronizeReplyGesturesInView(window);
}

static id WCAtlasExactIvarValue(id object, NSString *ivarName) {
    if (!object || ivarName.length == 0) return nil;
    Ivar ivar = class_getInstanceVariable([object class], ivarName.UTF8String);
    if (ivar) return object_getIvar(object, ivar);
    return WCAtlasTweakSafeValue(object, ivarName);
}

static void WCAtlasApplyAutoOriginalSelection(id controller, NSString *originCheckKey) {
    if (!controller || !WCAtlasEnhancementEnabled(WCAtlasAutoOriginalImageEnabledKey)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!WCAtlasEnhancementEnabled(WCAtlasAutoOriginalImageEnabledKey)) return;

        SEL selectedSelector = NSSelectorFromString(@"isOriginSelected");
        SEL checkSelector = NSSelectorFromString(@"onOriginImageCheck:");
        if ([controller respondsToSelector:selectedSelector] &&
            [controller respondsToSelector:checkSelector]) {
            BOOL selected = ((BOOL (*)(id, SEL))objc_msgSend)(controller, selectedSelector);
            if (selected) return;

            id originCheck = WCAtlasExactIvarValue(controller, originCheckKey);
            if (originCheck) {
                ((void (*)(id, SEL, id))objc_msgSend)(controller, checkSelector, originCheck);
                WCAtlasCompatibilityMarkTriggered(@"auto-original-image");
                return;
            }
        }

        // Older WeChat builds may not expose the native checkbox callback.
        SEL setter = NSSelectorFromString(@"setIsOriginSelected:");
        if ([controller respondsToSelector:setter]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, setter, YES);
            WCAtlasCompatibilityMarkTriggered(@"auto-original-image");
        }
    });
}

static void WCAtlasApplyAutoCombineSendSelection(id controller) {
    // WeChatX 2.1-9 uses this native chain verbatim: combineSendView ->
    // isCombineSendHidden -> controlCenter setIsCombineSend:YES ->
    // combineSendView updateSelected:YES. Its option is gated by auto-original.
    if (!controller) return;
    if (!WCAtlasEnhancementEnabled(WCAtlasAutoOriginalImageEnabledKey) ||
        !WCAtlasEnhancementEnabled(WCAtlasAutoCombineSendEnabledKey)) {
        objc_setAssociatedObject(controller, &WCAtlasAutoCombineSendAppliedKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!WCAtlasEnhancementEnabled(WCAtlasAutoOriginalImageEnabledKey) ||
            !WCAtlasEnhancementEnabled(WCAtlasAutoCombineSendEnabledKey)) return;

        id combineSendView = WCAtlasTweakSafeValue(controller, @"combineSendView");
        if (!combineSendView) {
            objc_setAssociatedObject(controller, &WCAtlasAutoCombineSendAppliedKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        SEL hiddenSelector = NSSelectorFromString(@"isCombineSendHidden");
        BOOL combineSendHidden = YES;
        if ([controller respondsToSelector:hiddenSelector]) {
            combineSendHidden = ((BOOL (*)(id, SEL))objc_msgSend)(controller, hiddenSelector);
        }
        if (combineSendHidden) {
            objc_setAssociatedObject(controller, &WCAtlasAutoCombineSendAppliedKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        if ([objc_getAssociatedObject(controller, &WCAtlasAutoCombineSendAppliedKey) boolValue]) return;

        id controlCenter = WCAtlasTweakSafeValue(controller, @"controlCenter");
        SEL combineSelector = NSSelectorFromString(@"setIsCombineSend:");
        if (![controlCenter respondsToSelector:combineSelector]) return;
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controlCenter, combineSelector, YES);
        objc_setAssociatedObject(controller, &WCAtlasAutoCombineSendAppliedKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        SEL updateSelector = NSSelectorFromString(@"updateSelected:");
        if ([combineSendView respondsToSelector:updateSelector]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(combineSendView, updateSelector, YES);
        }
        WCAtlasCompatibilityMarkTriggered(@"auto-combine-send");
    });
}

static void WCAtlasSetMomentsOriginalFlag(id object) {
    if (!object || !WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey)) return;
    SEL originalSelector = NSSelectorFromString(@"setOriginal:");
    if ([object respondsToSelector:originalSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(object, originalSelector, YES);
    }

    // Copy WCUploadTask.mediaList before marking each upload subtask so the
    // collection cannot change while the compression flags are being updated.
    SEL mediaListSelector = NSSelectorFromString(@"mediaList");
    SEL skipSelector = NSSelectorFromString(@"setSkipCompress:");
    if (![object respondsToSelector:mediaListSelector]) return;
    id mediaList = ((id (*)(id, SEL))objc_msgSend)(object, mediaListSelector);
    id stableMediaList = [mediaList respondsToSelector:@selector(copy)] ? [mediaList copy] : mediaList;
    if (![stableMediaList conformsToProtocol:@protocol(NSFastEnumeration)]) return;
    for (id mediaTask in stableMediaList) {
        if ([mediaTask respondsToSelector:skipSelector]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(mediaTask, skipSelector, YES);
        }
    }
}

static void WCAtlasSetMomentsCommitImagesOriginal(id controller) {
    if (!controller || !WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey)) return;
    SEL imageSelectorControllerSelector = NSSelectorFromString(@"imageSelectorController");
    SEL imagesSelector = NSSelectorFromString(@"arrImages");
    SEL assetSelector = NSSelectorFromString(@"m_asset");
    SEL needOriginSelector = NSSelectorFromString(@"setM_isNeedOriginImage:");
    SEL useAssetSelector = NSSelectorFromString(@"setM_isUseMMAsset:");
    id imageSelectorController = [controller respondsToSelector:imageSelectorControllerSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(controller, imageSelectorControllerSelector) : nil;
    id images = [imageSelectorController respondsToSelector:imagesSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(imageSelectorController, imagesSelector) : nil;
    id stableImages = [images respondsToSelector:@selector(copy)] ? [images copy] : images;
    if ([stableImages conformsToProtocol:@protocol(NSFastEnumeration)]) {
        for (id image in stableImages) {
            id asset = [image respondsToSelector:assetSelector]
                ? ((id (*)(id, SEL))objc_msgSend)(image, assetSelector) : nil;
            if ([asset respondsToSelector:needOriginSelector]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(asset, needOriginSelector, YES);
            }
        }
    }
    if ([controller respondsToSelector:useAssetSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, useAssetSelector, YES);
    }
}

static void WCAtlasPresentJokerEditorForCell(id cell, BOOL transferContext) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return;
    id message = WCAtlasMessageWrapForCell(cell);
    if (!message || (!transferContext && !WCAtlasMessageCanJokerEdit(message))) return;
    UIViewController *presenter = WCAtlasJokerPresenterForCell(cell);
    if (!presenter.view.window) return;
    BOOL isText = !transferContext && WCAtlasMessageIsText(message);
    BOOL isRefer = !transferContext && !isText && WCAtlasMessageIsRefer(message);
    BOOL isTransfer = transferContext || (!isText && !isRefer && WCAtlasMessageIsTransfer(message));
    NSString *current = transferContext ? WCAtlasTransferDisplayText(message) : WCAtlasDisplayTextForJokerMessage(message);
    if (isTransfer && ([current hasPrefix:@"¥"] || [current hasPrefix:@"￥"])) current = [current substringFromIndex:1];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"聊天记录小丑"
                                                                   message:@"仅修改当前页面的本机显示，离开页面后可能恢复"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = current;
        textField.placeholder = isRefer ? @"输入新的回复文字" : @"输入新的显示文字或金额";
        textField.accessibilityLabel = isRefer ? @"新的回复文字" : @"新的显示文字或金额";
        if (isTransfer) textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak id targetCell = cell;
    id targetMessage = message;
    UIViewController *targetController = presenter;
    [alert addAction:[UIAlertAction actionWithTitle:@"应用" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *text = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (targetCell && text.length > 0) {
            WCAtlasApplyJokerText(targetCell, targetMessage, targetController, text, transferContext);
        }
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static MMMenuItem *WCAtlasJokerMenuItem(id target, BOOL transferContext) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) return nil;
    id message = WCAtlasMessageWrapForCell(target);
    if (!message || (!transferContext && !WCAtlasMessageCanJokerEdit(message))) return nil;
    Class itemClass = NSClassFromString(@"MMMenuItem");
    if (!itemClass) return nil;
    if (![itemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) return nil;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightRegular];
    UIImage *icon = [UIImage systemImageNamed:@"pencil.circle.fill" withConfiguration:configuration];
    if (!icon) icon = [UIImage systemImageNamed:@"square.and.pencil" withConfiguration:configuration];
    icon = [icon imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    return [[itemClass alloc] initWithTitle:@"小丑" icon:icon target:target action:@selector(joker_handleMenuItem:)];
}

static NSArray *WCAtlasOperationMenuItemsWithJoker(id target, NSArray *originalItems, BOOL transferContext) {
    if (![originalItems isKindOfClass:[NSArray class]]) return originalItems;
    NSArray *items = originalItems;
    if (WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey)) {
        BOOL containsJoker = NO;
        for (id item in originalItems) {
            if ([WCAtlasTweakSafeValue(item, @"title") isEqualToString:@"小丑"]) {
                containsJoker = YES;
                break;
            }
        }
        if (!containsJoker) {
            MMMenuItem *jokerItem = WCAtlasJokerMenuItem(target, transferContext);
            if (jokerItem) {
                NSMutableArray *mutableItems = [originalItems mutableCopy];
                [mutableItems insertObject:jokerItem atIndex:0];
                items = mutableItems;
            }
        }
    }
    return items;
}

static BOOL WCAtlasMessageIsFileAttachment(id message) {
    SEL fileSelector = sel_registerName("IsFileMsg");
    if ([message respondsToSelector:fileSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(message, fileSelector)) return YES;
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    NSInteger innerType = [WCAtlasTweakSafeValue(message, @"m_uiAppMsgInnerType") integerValue];
    return messageType == 0x31 && innerType == 6;
}

static WCAtlasQuickReplyType WCAtlasQuickReplyTypeForMessage(id message, BOOL *supported) {
    if (supported) *supported = NO;
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (messageType == 1) {
        if (supported) *supported = YES;
        return WCAtlasQuickReplyTypeText;
    }
    if (messageType == 3) {
        if (supported) *supported = YES;
        return WCAtlasQuickReplyTypeImage;
    }
    if (messageType == 34) {
        if (supported) *supported = YES;
        return WCAtlasQuickReplyTypeVoice;
    }
    if (WCAtlasMessageIsFileAttachment(message)) {
        NSString *fileName = WCAtlasTweakSafeValue(message, @"m_nsAppFileName");
        NSString *extension = fileName.pathExtension.lowercaseString;
        static NSSet<NSString *> *videoExtensions;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ videoExtensions = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v"]]; });
        if ([videoExtensions containsObject:extension]) {
            if (supported) *supported = YES;
            return WCAtlasQuickReplyTypeVideo;
        }
    }
    return WCAtlasQuickReplyTypeText;
}

static BOOL WCAtlasMessageCanAddToQuickReply(id message) {
    if (!WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey) || !message) return NO;
    NSString *session = WCAtlasSessionForMessage(message);
    unsigned long long localID = [WCAtlasTweakSafeValue(message, @"m_uiMesLocalID") unsignedLongLongValue];
    long long serverID = [WCAtlasTweakSafeValue(message, @"m_n64MesSvrID") longLongValue];
    return session.length > 0 && (localID > 0 || serverID != 0);
}

static NSString *WCAtlasQuickReplySourceMessageID(id message) {
    long long serverID = [WCAtlasTweakSafeValue(message, @"m_n64MesSvrID") longLongValue];
    unsigned long long localID = [WCAtlasTweakSafeValue(message, @"m_uiMesLocalID") unsignedLongLongValue];
    return serverID != 0 ? [NSString stringWithFormat:@"svr:%lld", serverID]
                         : [NSString stringWithFormat:@"local:%llu", localID];
}

static NSString *WCAtlasExistingQuickReplyImagePath(id message) {
    Class wrapClass = objc_getClass("CMessageWrap");
    if (!wrapClass) return nil;
    for (NSString *selectorName in @[@"getJpgPathOfMsgHDImg:",
                                     @"getJpgPathOfMsgHdOrMiddleImg:",
                                     @"getJpgPathOfMsgMiddleImg:",
                                     @"getPathOfMsgImg:"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![wrapClass respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL, id))objc_msgSend)(wrapClass, selector, message);
        NSString *path = [value isKindOfClass:NSString.class] ? value : nil;
        if (path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path]) return path;
    }
    return nil;
}

static NSString *WCAtlasExistingQuickReplyAttachmentPath(id message) {
    SEL selector = sel_registerName("GetAppAttachmentPath");
    if (![message respondsToSelector:selector]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(message, selector);
    NSString *path = [value isKindOfClass:NSString.class] ? value : nil;
    return path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
}

static NSString *WCAtlasExistingQuickReplyVoicePath(id message) {
    SEL selector = sel_registerName("getVoicePath");
    if (![message respondsToSelector:selector]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(message, selector);
    NSString *path = [value isKindOfClass:NSString.class] ? value : nil;
    return path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
}

static NSDictionary *WCAtlasQuickReplyVoiceMetadata(id message) {
    id extendInfo = WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType");
    NSNumber *voiceTime = WCAtlasTweakSafeValue(extendInfo, @"m_uiVoiceTime");
    NSNumber *voiceFormat = WCAtlasTweakSafeValue(extendInfo, @"m_uiVoiceFormat");
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    if ([voiceTime respondsToSelector:@selector(unsignedIntegerValue)] && voiceTime.unsignedIntegerValue > 0) metadata[@"voiceTime"] = voiceTime;
    if ([voiceFormat respondsToSelector:@selector(unsignedIntegerValue)]) metadata[@"voiceFormat"] = voiceFormat;
    return metadata;
}

static NSString *WCAtlasQuickReplyMessagePreview(id message) {
    SEL displaySelector = NSSelectorFromString(@"GetDisplayContent");
    Method displayMethod = message ? class_getInstanceMethod([message class], displaySelector) : NULL;
    if (displayMethod && method_getNumberOfArguments(displayMethod) == 2 &&
        WCAtlasMethodReturnsObject(displayMethod)) {
        @try {
            id value = ((id (*)(id, SEL))objc_msgSend)(message, displaySelector);
            if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
        } @catch (__unused NSException *exception) {}
    }
    for (NSString *key in @[@"m_nsTitle", @"m_nsAppFileName", @"m_nsDesc"]) {
        id value = WCAtlasTweakSafeValue(message, key);
        if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
    }
    NSInteger type = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (type == 1) {
        id content = WCAtlasTweakSafeValue(message, @"m_nsContent");
        if ([content isKindOfClass:NSString.class] && [content length] > 0) return content;
    }
    return [NSString stringWithFormat:@"微信消息 · 类型 %ld", (long)type];
}

typedef NS_ENUM(NSUInteger, WCAtlasMediaToVoiceKind) {
    WCAtlasMediaToVoiceKindAudioFile = 1,
    WCAtlasMediaToVoiceKindVideo,
    WCAtlasMediaToVoiceKindMusic,
};

static BOOL WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKind kind) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMediaToVoiceEnabledKey)) return NO;
    NSString *key = kind == WCAtlasMediaToVoiceKindAudioFile ? WCAtlasAudioFileToVoiceEnabledKey :
        (kind == WCAtlasMediaToVoiceKindVideo ? WCAtlasVideoToVoiceEnabledKey : WCAtlasMusicToVoiceEnabledKey);
    return WCAtlasEnhancementEnabled(key);
}

static NSSet<NSString *> *WCAtlasAudioFileExtensions(void) {
    static NSSet<NSString *> *extensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Matches the exact extension allow-list in WeChatX(14).
        extensions = [NSSet setWithArray:@[@"mp3", @"m4a", @"wav", @"flac"]];
    });
    return extensions;
}

static BOOL WCAtlasMessageIsConvertibleAudioFile(id message) {
    if (!message) return NO;
    id extension = WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType");
    NSString *fileName = WCAtlasTweakSafeValue(message, @"m_nsAppFileName");
    if (fileName.length == 0) fileName = WCAtlasTweakSafeValue(extension, @"m_nsAppFileName");
    BOOL supportedExtension = [WCAtlasAudioFileExtensions() containsObject:fileName.pathExtension.lowercaseString ?: @""];
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    return supportedExtension && (WCAtlasMessageIsFileAttachment(message) || messageType == 49);
}

static BOOL WCAtlasMessageIsMusicCard(id message) {
    if (!message || [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue] != 49) return NO;
    NSInteger innerType = [WCAtlasTweakSafeValue(message, @"m_uiAppMsgInnerType") integerValue];
    if (innerType == 0) {
        innerType = [WCAtlasTweakSafeValue(WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType"),
                                         @"m_uiAppMsgInnerType") integerValue];
    }
    if (innerType == 3) return YES;
    // AFN identifies music app messages from the serialized app-message body as
    // well as the parsed inner-type field. Some WeChat builds populate the XML
    // before exposing m_uiAppMsgInnerType to AppMessageCellView.
    NSString *content = WCAtlasTweakSafeValue(message, @"m_nsContent");
    if (![content isKindOfClass:NSString.class]) return NO;
    return [content rangeOfString:@"<appmsg type=\"3\"" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [content rangeOfString:@"<appmsg type='3'" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [content rangeOfString:@"<type>3</type>" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [content rangeOfString:@"<mediatagname>music" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static NSString *WCAtlasMusicCardPlayableURLString(id message) {
    id extension = WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType");
    NSArray<NSString *> *keys = @[@"m_nsAppMediaDataUrl", @"m_nsAppMediaLowBandDataUrl",
                                  @"m_nsAppMediaUrl", @"m_nsAppMediaLowUrl"];
    for (id owner in @[message ?: NSNull.null, extension ?: NSNull.null]) {
        if (owner == NSNull.null) continue;
        for (NSString *key in keys) {
            NSString *value = WCAtlasTweakSafeValue(owner, key);
            if (![value isKindOfClass:NSString.class]) continue;
            NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSURL *URL = [NSURL URLWithString:trimmed];
            NSString *scheme = URL.scheme.lowercaseString;
            if (([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) && URL.host.length > 0) {
                return trimmed;
            }
        }
    }
    NSString *content = WCAtlasTweakSafeValue(message, @"m_nsContent");
    if ([content isKindOfClass:NSString.class]) {
        NSRegularExpression *expression = [NSRegularExpression
            regularExpressionWithPattern:@"(?is)<(?:dataurl|lowdataurl|musicurl|musichighbandurl|musiclowbandurl)>\\s*(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?\\s*</(?:dataurl|lowdataurl|musicurl|musichighbandurl|musiclowbandurl)>"
                                 options:0 error:nil];
        for (NSTextCheckingResult *match in [expression matchesInString:content options:0
                                                                        range:NSMakeRange(0, content.length)]) {
            if (match.numberOfRanges < 2) continue;
            NSString *value = [[content substringWithRange:[match rangeAtIndex:1]]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            value = [value stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
            NSURL *URL = [NSURL URLWithString:value];
            NSString *scheme = URL.scheme.lowercaseString;
            if (([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) && URL.host.length > 0) {
                return value;
            }
        }
    }
    return nil;
}

static NSString *WCAtlasExistingVideoMessagePath(id message) {
    if (!message) return nil;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    Class wrapClass = objc_getClass("CMessageWrap");
    for (NSString *selectorName in @[@"GetPathOfMesVideoWithMessageWrap:",
                                     @"GetPathOfRawVideoWithMessageWrap:",
                                     @"GetPathOfRawOrCompressVideo:"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![wrapClass respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL, id))objc_msgSend)(wrapClass, selector, message);
        NSString *path = [value isKindOfClass:NSURL.class] ? [value path] :
            ([value isKindOfClass:NSString.class] ? value : nil);
        NSNumber *size = path.length > 0 ? [[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] : nil;
        if (size.unsignedLongLongValue > 0) return path;
    }
    for (NSString *selectorName in @[@"GetCdnDownloadPathOfVideo",
                                     @"GetLivePhotoVideoPath",
                                     @"GetLivePhotoHDVideoPath"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![message respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(message, selector);
        NSString *path = [value isKindOfClass:NSURL.class] ? [value path] :
            ([value isKindOfClass:NSString.class] ? value : nil);
        NSNumber *size = path.length > 0 ? [[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] : nil;
        if (size.unsignedLongLongValue > 0) return path;
    }
    return nil;
}

static NSString *WCAtlasExistingAudioFileMessagePath(id message) {
    if (!message) return nil;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *selectorName in @[@"GetAppAttachmentPath", @"getAppAttachmentPath",
                                     @"appAttachmentPath", @"getFilePath", @"filePath",
                                     @"localPath", @"path", @"m_nsFilePath", @"m_nsAppFilePath"]) {
        id value = WCAtlasTweakValueForSelectorNames(message, @[selectorName]);
        NSString *path = [value isKindOfClass:NSURL.class] ? [value path] :
            ([value isKindOfClass:NSString.class] ? value : nil);
        NSNumber *size = path.length > 0 ? [[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] : nil;
        if (size.unsignedLongLongValue > 0) return path;
    }
    return nil;
}

static NSString *WCAtlasMediaToVoiceLocalPath(id message, WCAtlasMediaToVoiceKind kind) {
    if (kind == WCAtlasMediaToVoiceKindAudioFile) return WCAtlasExistingAudioFileMessagePath(message);
    if (kind == WCAtlasMediaToVoiceKindVideo) return WCAtlasExistingVideoMessagePath(message);
    return nil;
}

static NSString *WCAtlasMediaToVoiceTemporaryPath(NSString *extension) {
    NSString *name = [NSString stringWithFormat:@"WCAtlas-media-to-voice-%@.%@",
                      NSUUID.UUID.UUIDString, extension.length > 0 ? extension : @"tmp"];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static BOOL WCAtlasSendConvertedSilkVoice(NSString *silkPath,
                                        NSUInteger durationMilliseconds,
                                        NSString *session) {
    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initializer = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initializer]) return NO;
    id voice = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([wrapClass alloc], initializer, 34);
    if (!voice) return NO;
    WCAtlasTweakSetValue(voice, @"m_uiMessageType", @34);
    id extension = WCAtlasTweakSafeValue(voice, @"m_extendInfoWithMsgType");
    WCAtlasTweakSetValue(voice, @"m_uiVoiceTime", @(MAX((NSUInteger)1, durationMilliseconds)));
    WCAtlasTweakSetValue(voice, @"m_uiVoiceFormat", @4);
    WCAtlasTweakSetValue(voice, @"m_uiVoiceForwardFlag", @1);
    WCAtlasTweakSetValue(extension, @"m_uiVoiceTime", @(MAX((NSUInteger)1, durationMilliseconds)));
    WCAtlasTweakSetValue(extension, @"m_uiVoiceFormat", @4);
    WCAtlasTweakSetValue(extension, @"m_uiVoiceForwardFlag", @1);
    return WCAtlasSendVoiceMessage(voice, silkPath, session);
}

static void WCAtlasFinishMediaToVoiceConversion(NSString *sourcePath,
                                               NSString *downloadedPath,
                                               NSString *session,
                                               id message) {
    NSString *silkPath = WCAtlasMediaToVoiceTemporaryPath(@"silk");
    NSError *conversionError = nil;
    NSUInteger durationMilliseconds = 0;
    BOOL converted = WCAtlasEncodeAudioFileToSilk(sourcePath, silkPath, &durationMilliseconds, &conversionError);
    if (downloadedPath.length > 0) [NSFileManager.defaultManager removeItemAtPath:downloadedPath error:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL queued = converted && WCAtlasSendConvertedSilkVoice(silkPath, durationMilliseconds, session);
        [NSFileManager.defaultManager removeItemAtPath:silkPath error:nil];
        objc_setAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!converted) {
            WCAtlasShowTransientMessage(conversionError.localizedDescription ?: @"媒体转语音失败", NO);
        } else if (!queued) {
            WCAtlasShowTransientMessage(@"微信语音发送接口已变化，未发送", NO);
        } else {
            WCAtlasShowTransientMessage(@"已提交微信语音发送", YES);
        }
    });
}

static void WCAtlasConvertMusicURLToVoice(NSString *URLString, NSString *session, id message) {
    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) {
        objc_setAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasShowTransientMessage(@"音乐卡片没有有效播放地址", NO);
        return;
    }
    NSURLSessionDownloadTask *task = [NSURLSession.sharedSession downloadTaskWithURL:URL
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *downloadError) {
        NSInteger statusCode = [response isKindOfClass:NSHTTPURLResponse.class]
            ? [(NSHTTPURLResponse *)response statusCode] : 200;
        if (downloadError || !location || statusCode < 200 || statusCode >= 300) {
            dispatch_async(dispatch_get_main_queue(), ^{
                objc_setAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                WCAtlasShowTransientMessage(downloadError.localizedDescription ?: @"音乐音频下载失败", NO);
            });
            return;
        }
        NSString *downloadExtension = response.suggestedFilename.pathExtension.lowercaseString;
        if (downloadExtension.length == 0) downloadExtension = URL.pathExtension.lowercaseString;
        if (downloadExtension.length == 0) {
            NSString *MIMEType = response.MIMEType.lowercaseString;
            if ([MIMEType containsString:@"mpeg"]) downloadExtension = @"mp3";
            else if ([MIMEType containsString:@"wav"]) downloadExtension = @"wav";
            else if ([MIMEType containsString:@"flac"]) downloadExtension = @"flac";
            else if ([MIMEType containsString:@"mp4"] || [MIMEType containsString:@"aac"]) downloadExtension = @"m4a";
        }
        NSString *downloadedPath = WCAtlasMediaToVoiceTemporaryPath(downloadExtension.length > 0 ? downloadExtension : @"m4a");
        NSError *moveError = nil;
        if (![NSFileManager.defaultManager moveItemAtURL:location
                                                   toURL:[NSURL fileURLWithPath:downloadedPath]
                                                   error:&moveError]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                objc_setAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                WCAtlasShowTransientMessage(moveError.localizedDescription ?: @"无法保存音乐音频", NO);
            });
            return;
        }
        WCAtlasFinishMediaToVoiceConversion(downloadedPath, downloadedPath, session, message);
    }];
    [task resume];
}

static NSString *WCAtlasMediaToVoiceDisplayName(id message, WCAtlasMediaToVoiceKind kind) {
    NSString *title = kind == WCAtlasMediaToVoiceKindAudioFile
        ? WCAtlasTweakSafeValue(message, @"m_nsAppFileName")
        : WCAtlasTweakSafeValue(message, @"m_nsTitle");
    if ([title isKindOfClass:NSString.class] && title.length > 0) return title;
    return kind == WCAtlasMediaToVoiceKindVideo ? @"聊天视频" :
        (kind == WCAtlasMediaToVoiceKindMusic ? @"音乐卡片" : @"音频文件");
}

static void WCAtlasPresentMediaToVoiceConfirmation(id cell, WCAtlasMediaToVoiceKind kind) {
    if (!WCAtlasMediaToVoiceKindEnabled(kind)) return;
    id message = WCAtlasMessageWrapForCell(cell);
    if (kind == WCAtlasMediaToVoiceKindAudioFile && !WCAtlasMessageIsConvertibleAudioFile(message)) return;
    if (kind == WCAtlasMediaToVoiceKindMusic && !WCAtlasMessageIsMusicCard(message)) return;
    NSString *session = [WCAtlasSessionForMessage(message) copy];
    UIViewController *presenter = WCAtlasJokerPresenterForCell(cell);
    if (!message || session.length == 0 || !presenter.view.window) return;
    if ([objc_getAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey) boolValue]) {
        WCAtlasShowTransientMessage(@"该媒体正在转换，请稍候", NO);
        return;
    }

    NSString *localPath = WCAtlasMediaToVoiceLocalPath(message, kind);
    NSString *musicURL = kind == WCAtlasMediaToVoiceKindMusic ? WCAtlasMusicCardPlayableURLString(message) : nil;
    if (kind != WCAtlasMediaToVoiceKindMusic && localPath.length == 0) {
        WCAtlasShowTransientMessage(kind == WCAtlasMediaToVoiceKindVideo
            ? @"未找到完整视频文件，请先播放或下载完视频"
            : @"未找到完整音频文件，请先下载完成", NO);
        return;
    }
    if (kind == WCAtlasMediaToVoiceKindMusic && musicURL.length == 0) {
        WCAtlasShowTransientMessage(@"音乐卡片没有可下载的播放地址", NO);
        return;
    }

    NSString *name = WCAtlasMediaToVoiceDisplayName(message, kind);
    NSString *detail = [NSString stringWithFormat:@"发送到：%@\n来源：%@", session, name];
    if (localPath.length > 0) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:localPath] options:nil];
        if ([asset tracksWithMediaType:AVMediaTypeAudio].count == 0) {
            WCAtlasShowTransientMessage(@"该媒体不包含可用音轨", NO);
            return;
        }
        NSTimeInterval seconds = CMTimeGetSeconds(asset.duration);
        if (isfinite(seconds) && seconds > 0.0) {
            NSInteger totalSeconds = MAX((NSInteger)1, (NSInteger)llround(seconds));
            detail = [detail stringByAppendingFormat:@"\n时长：%ld:%02ld",
                      (long)(totalSeconds / 60), (long)(totalSeconds % 60)];
        }
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"转为语音发送？"
                                                                   message:detail
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"转换并发送" style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        objc_setAssociatedObject(message, &WCAtlasMediaToVoiceInProgressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasShowTransientMessage(kind == WCAtlasMediaToVoiceKindMusic ? @"正在下载并转换音乐" : @"正在转换媒体音轨", YES);
        if (kind == WCAtlasMediaToVoiceKindMusic) {
            WCAtlasConvertMusicURLToVoice(musicURL, session, message);
        } else {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                WCAtlasFinishMediaToVoiceConversion(localPath, nil, session, message);
            });
        }
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static NSArray *WCAtlasOperationMenuItemsWithMediaToVoice(id target,
                                                         NSArray *originalItems,
                                                         WCAtlasMediaToVoiceKind kind) {
    if (![originalItems isKindOfClass:NSArray.class] || !WCAtlasMediaToVoiceKindEnabled(kind)) return originalItems;
    id message = WCAtlasMessageWrapForCell(target);
    BOOL eligible = kind == WCAtlasMediaToVoiceKindAudioFile ? WCAtlasMessageIsConvertibleAudioFile(message) :
        (kind == WCAtlasMediaToVoiceKindMusic ? WCAtlasMessageIsMusicCard(message) : message != nil);
    if (!eligible) return originalItems;
    for (id item in originalItems) {
        if ([WCAtlasTweakSafeValue(item, @"title") isEqualToString:@"转语音"]) return originalItems;
    }
    Class itemClass = objc_getClass("MMMenuItem");
    if (!itemClass || ![itemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) return originalItems;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                                  weight:UIImageSymbolWeightRegular];
    UIImage *icon = [[UIImage systemImageNamed:@"waveform" withConfiguration:configuration]
        imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    SEL action = kind == WCAtlasMediaToVoiceKindAudioFile ? @selector(wcatlas_convertAudioFileToVoice:) :
        (kind == WCAtlasMediaToVoiceKindVideo ? @selector(wcatlas_convertVideoToVoice:) :
                                             @selector(wcatlas_convertMusicToVoice:));
    MMMenuItem *item = [[itemClass alloc] initWithTitle:@"转语音" icon:icon target:target action:action];
    if (!item) return originalItems;
    NSMutableArray *items = [originalItems mutableCopy];
    [items addObject:item];
    return items;
}


static void WCAtlasCommitMessageToQuickReply(id message, WCAtlasQuickReplyType type, NSString *session,
                                           NSString *messageID, NSString *path, NSString *remark,
                                           NSString *folderIdentifier) {
    NSString *trimmedRemark = [remark stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger beforeCount = WCAtlasQuickReplyStore.sharedStore.items.count;
    NSError *error = nil;
    WCAtlasQuickReplyItem *item = nil;
    if (type == WCAtlasQuickReplyTypeMessageReference) {
        NSInteger innerType = [WCAtlasTweakSafeValue(message, @"m_uiAppMsgInnerType") integerValue];
        if (innerType == 0) {
            innerType = [WCAtlasTweakSafeValue(WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType"),
                                              @"m_uiAppMsgInnerType") integerValue];
        }
        item = [WCAtlasQuickReplyStore.sharedStore
            addMessageReferenceForConversation:session
                                        localID:[WCAtlasTweakSafeValue(message, @"m_uiMesLocalID") unsignedLongLongValue]
                                       serverID:[WCAtlasTweakSafeValue(message, @"m_n64MesSvrID") longLongValue]
                                    messageType:[WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue]
                                      innerType:innerType
                                        preview:WCAtlasQuickReplyMessagePreview(message)
                                          title:trimmedRemark
                              folderIdentifier:folderIdentifier
                                          error:&error];
    } else if (type == WCAtlasQuickReplyTypeText) {
        NSString *text = WCAtlasTweakSafeValue(message, @"m_nsContent");
        item = [WCAtlasQuickReplyStore.sharedStore addText:text ?: @""
                                                    title:trimmedRemark
                                        folderIdentifier:folderIdentifier
                                       sourceConversation:session
                                          sourceMessageID:messageID
                                                    error:&error];
    } else {
        item = [WCAtlasQuickReplyStore.sharedStore addMediaAtURL:[NSURL fileURLWithPath:path]
                                                          type:type
                                                         title:trimmedRemark
                                              folderIdentifier:folderIdentifier
                                            sourceConversation:session
                                               sourceMessageID:messageID
                                                         error:&error];
        if (item && WCAtlasQuickReplyStore.sharedStore.items.count > beforeCount) {
            if (type == WCAtlasQuickReplyTypeVoice) item.metadata = WCAtlasQuickReplyVoiceMetadata(message);
            [WCAtlasQuickReplyStore.sharedStore updateItem:item error:&error];
        }
    }
    if (error) WCAtlasShowTransientMessage(error.localizedDescription ?: @"加入快捷回复失败", NO);
    else if (item && WCAtlasQuickReplyStore.sharedStore.items.count > beforeCount) WCAtlasShowTransientMessage(@"已加入快捷回复", YES);
    else if (item) WCAtlasShowTransientMessage(@"该消息已在消息库中", YES);
    else WCAtlasShowTransientMessage(@"加入快捷回复失败", NO);
}

static void WCAtlasPresentQuickReplyFolderPicker(UIViewController *presenter, id message, WCAtlasQuickReplyType type,
                                                NSString *session, NSString *messageID, NSString *path,
                                                NSString *remark) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"存入文件夹" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    void (^commit)(NSString *) = ^(NSString *folderIdentifier) {
        WCAtlasCommitMessageToQuickReply(message, type, session, messageID, path, remark, folderIdentifier);
    };
    [sheet addAction:[UIAlertAction actionWithTitle:@"消息库根目录" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        commit(nil);
    }]];
    for (WCAtlasQuickReplyFolder *folder in WCAtlasQuickReplyStore.sharedStore.folders) {
        [sheet addAction:[UIAlertAction actionWithTitle:folder.name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            commit(folder.identifier);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"文件夹名称"; }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"创建并导入" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *saveAction) {
            NSError *error = nil;
            WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyStore.sharedStore createFolderWithName:alert.textFields.firstObject.text error:&error];
            if (folder) commit(folder.identifier);
            else WCAtlasShowTransientMessage(error.localizedDescription ?: @"创建文件夹失败", NO);
        }]];
        [presenter presentViewController:alert animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.sourceView = presenter.view; popover.sourceRect = presenter.view.bounds; }
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void WCAtlasAddMessageToQuickReply(id cell) {
    id message = WCAtlasMessageWrapForCell(cell);
    if (!WCAtlasMessageCanAddToQuickReply(message)) return;
    BOOL supported = NO;
    WCAtlasQuickReplyType type = WCAtlasQuickReplyTypeForMessage(message, &supported);
    if (!supported) type = WCAtlasQuickReplyTypeMessageReference;
    NSString *path = nil;
    if (type != WCAtlasQuickReplyTypeText && type != WCAtlasQuickReplyTypeMessageReference) {
        path = type == WCAtlasQuickReplyTypeImage ? WCAtlasExistingQuickReplyImagePath(message) :
            (type == WCAtlasQuickReplyTypeVoice ? WCAtlasExistingQuickReplyVoicePath(message) : WCAtlasExistingQuickReplyAttachmentPath(message));
        if (path.length == 0) {
            NSString *notice = type == WCAtlasQuickReplyTypeImage ? @"请先下载或打开原图后再加入快捷回复" :
                (type == WCAtlasQuickReplyTypeVoice ? @"请先播放或下载语音后再加入快捷回复" : @"请先下载视频文件后再加入快捷回复");
            WCAtlasShowTransientMessage(notice, NO);
            return;
        }
    }
    UIViewController *presenter = WCAtlasJokerPresenterForCell(cell);
    if (!presenter.view.window) return;
    NSString *session = WCAtlasSessionForMessage(message);
    NSString *messageID = WCAtlasQuickReplySourceMessageID(message);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加入快捷回复"
                                                                   message:@"可填写备注并选择保存文件夹。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"备注（可选）"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        WCAtlasPresentQuickReplyFolderPicker(presenter, message, type, session, messageID, path,
                                           alert.textFields.firstObject.text ?: @"");
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static NSArray *WCAtlasOperationMenuItemsWithQuickReply(id target, NSArray *originalItems) {
    if (![originalItems isKindOfClass:NSArray.class]) return originalItems;
    id message = WCAtlasMessageWrapForCell(target);
    if (!WCAtlasMessageCanAddToQuickReply(message)) return originalItems;
    for (id item in originalItems) {
        NSString *title = WCAtlasTweakSafeValue(item, @"title");
        if ([title isEqualToString:@"存入素材"] || [title isEqualToString:@"存入消息库"] ||
            [title isEqualToString:@"加入快捷回复"]) return originalItems;
    }
    Class itemClass = objc_getClass("MMMenuItem");
    if (!itemClass || ![itemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) return originalItems;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightRegular];
    UIImage *icon = [[UIImage systemImageNamed:@"tray.and.arrow.down.fill" withConfiguration:configuration]
        imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *menuItem = [[itemClass alloc] initWithTitle:@"存入消息库"
                                                       icon:icon
                                                     target:target
                                                     action:@selector(wcatlas_addToQuickReply:)];
    if (!menuItem) return originalItems;
    NSMutableArray *items = [originalItems mutableCopy];
    [items insertObject:menuItem atIndex:0];
    return items;
}

static void WCAtlasPresentWalletBalanceEditor(id headerView) {
    UIWindow *window = WCAtlasActiveApplicationWindow();
    UIViewController *presenter = WCAtlasTopControllerForLoginToast(window.rootViewController);
    if (!presenter.view.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"钱包余额本地显示"
                                                                   message:@"仅修改本机界面文字；留空或输入 0 恢复真实显示"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        long long fen = WCAtlasLongLongDefaultForKey(WCAtlasWalletBalanceFenKey);
        textField.text = fen > 0 ? [NSString stringWithFormat:@"%.2f", fen / 100.0] : nil;
        textField.placeholder = @"例如 888.88";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak id weakHeaderView = headerView;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *text = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        long long fen = text.length > 0 ? (long long)llround(text.doubleValue * 100.0) : 0;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@(MAX(0LL, fen)) forKey:WCAtlasWalletBalanceFenKey];
        [defaults setBool:fen > 0 forKey:WCAtlasWalletBalanceEnabledKey];
        id currentHeaderView = weakHeaderView;
        if (fen > 0 && currentHeaderView) {
            WCAtlasRefreshWalletHeaderBalance(currentHeaderView);
        } else if (currentHeaderView) {
            SEL refreshSelector = NSSelectorFromString(@"updateBalanceEntryView");
            if ([currentHeaderView respondsToSelector:refreshSelector]) {
                ((void (*)(id, SEL))objc_msgSend)(currentHeaderView, refreshSelector);
            }
        }
        WCAtlasShowTransientMessage(fen > 0 ? @"钱包余额显示已更新" : @"钱包余额显示已恢复", YES);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void WCAtlasInstallWalletLongPressIfNeeded(UIView *view, id target, SEL action) {
    if (!view || objc_getAssociatedObject(view, &WCAtlasWalletGestureRecognizerKey)) return;
    UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:action];
    recognizer.minimumPressDuration = 0.55;
    recognizer.cancelsTouchesInView = NO;
    [view addGestureRecognizer:recognizer];
    view.userInteractionEnabled = YES;
    objc_setAssociatedObject(view, &WCAtlasWalletGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasRemoveWalletLongPressIfNeeded(UIView *view) {
    if (!view) return;
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(view, &WCAtlasWalletGestureRecognizerKey);
    if (!recognizer) return;
    [view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &WCAtlasWalletGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface WCAtlasGameSelectorViewController : UIViewController
@property (nonatomic, copy) NSString *sourceType;
@property (nonatomic, copy) void (^selectionHandler)(NSUInteger value, NSString *title);
@property (nonatomic, copy) void (^cancelHandler)(void);
@property (nonatomic, strong) UIButton *dimmingButton;
@property (nonatomic, strong) UIView *sheetView;
@end

@implementation WCAtlasGameSelectorViewController

- (UIButton *)choiceButtonWithTitle:(NSString *)title symbol:(NSString *)symbol value:(NSUInteger)value {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = (NSInteger)value;
    button.backgroundColor = [UIColor secondarySystemFillColor];
    button.layer.cornerRadius = 16.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.accessibilityLabel = title;
    [button addTarget:self action:@selector(choiceTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.tintColor = [UIColor labelColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = NO;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    label.textColor = [UIColor labelColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;

    [button addSubview:imageView];
    [button addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [imageView.topAnchor constraintEqualToAnchor:button.topAnchor constant:11.0],
        [imageView.widthAnchor constraintEqualToConstant:24.0],
        [imageView.heightAnchor constraintEqualToConstant:24.0],
        [label.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:4.0],
        [label.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-4.0],
        [label.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:5.0],
        [label.bottomAnchor constraintLessThanOrEqualToAnchor:button.bottomAnchor constant:-8.0],
    ]];
    return button;
}

- (UIStackView *)rowWithButtons:(NSArray<UIButton *> *)buttons height:(CGFloat)height {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 10.0;
    [row.heightAnchor constraintEqualToConstant:height].active = YES;
    return row;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    UIButton *dimmingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dimmingButton.translatesAutoresizingMaskIntoConstraints = NO;
    dimmingButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.32];
    dimmingButton.alpha = 0.0;
    [dimmingButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dimmingButton];
    self.dimmingButton = dimmingButton;

    UIView *sheet = [UIView new];
    sheet.translatesAutoresizingMaskIntoConstraints = NO;
    sheet.backgroundColor = [UIColor systemBackgroundColor];
    sheet.layer.cornerRadius = 28.0;
    sheet.layer.cornerCurve = kCACornerCurveContinuous;
    sheet.layer.masksToBounds = YES;
    [self.view addSubview:sheet];
    self.sheetView = sheet;

    UIView *grabber = [UIView new];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor tertiaryLabelColor];
    grabber.layer.cornerRadius = 2.5;
    UIView *grabberContainer = [UIView new];
    [grabberContainer addSubview:grabber];
    [NSLayoutConstraint activateConstraints:@[
        [grabber.centerXAnchor constraintEqualToAnchor:grabberContainer.centerXAnchor],
        [grabber.topAnchor constraintEqualToAnchor:grabberContainer.topAnchor],
        [grabber.bottomAnchor constraintEqualToAnchor:grabberContainer.bottomAnchor],
        [grabber.widthAnchor constraintEqualToConstant:38.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],
    ]];

    UILabel *title = [UILabel new];
    title.text = @"选择小游戏结果";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    title.textColor = [UIColor labelColor];

    UILabel *subtitle = [UILabel new];
    subtitle.text = [NSString stringWithFormat:@"当前：%@ · 支持跨类型彩蛋", self.sourceType ?: @"小游戏"];
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    subtitle.textColor = [UIColor secondaryLabelColor];

    UIStackView *guessRow = [self rowWithButtons:@[
        [self choiceButtonWithTitle:@"剪刀" symbol:@"scissors" value:1],
        [self choiceButtonWithTitle:@"石头" symbol:@"circle.fill" value:2],
        [self choiceButtonWithTitle:@"布" symbol:@"hand.raised" value:3],
    ] height:70.0];

    UIStackView *diceRowOne = [self rowWithButtons:@[
        [self choiceButtonWithTitle:@"1 点" symbol:@"die.face.1" value:4],
        [self choiceButtonWithTitle:@"2 点" symbol:@"die.face.2" value:5],
        [self choiceButtonWithTitle:@"3 点" symbol:@"die.face.3" value:6],
    ] height:64.0];
    UIStackView *diceRowTwo = [self rowWithButtons:@[
        [self choiceButtonWithTitle:@"4 点" symbol:@"die.face.4" value:7],
        [self choiceButtonWithTitle:@"5 点" symbol:@"die.face.5" value:8],
        [self choiceButtonWithTitle:@"6 点" symbol:@"die.face.6" value:9],
    ] height:64.0];

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.backgroundColor = [UIColor secondarySystemFillColor];
    cancelButton.layer.cornerRadius = 16.0;
    cancelButton.layer.cornerCurve = kCACornerCurveContinuous;
    cancelButton.tintColor = [UIColor labelColor];
    cancelButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [cancelButton setTitle:@"取消发送" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton.heightAnchor constraintEqualToConstant:50.0].active = YES;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[
        grabberContainer, title, subtitle, [self sectionLabel:@"猜拳"], guessRow,
        [self sectionLabel:@"骰子"], diceRowOne, diceRowTwo, cancelButton,
    ]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentFill;
    content.spacing = 10.0;
    [content setCustomSpacing:18.0 afterView:subtitle];
    [content setCustomSpacing:8.0 afterView:grabberContainer];
    [content setCustomSpacing:14.0 afterView:guessRow];
    [sheet addSubview:content];

    NSLayoutConstraint *phoneWidth = [sheet.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-28.0];
    phoneWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [dimmingButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dimmingButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dimmingButton.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dimmingButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sheet.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [sheet.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10.0],
        [sheet.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [sheet.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-14.0],
        [sheet.widthAnchor constraintLessThanOrEqualToConstant:520.0],
        phoneWidth,
        [content.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor constant:18.0],
        [content.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor constant:-18.0],
        [content.topAnchor constraintEqualToAnchor:sheet.topAnchor constant:10.0],
        [content.bottomAnchor constraintEqualToAnchor:sheet.safeAreaLayoutGuide.bottomAnchor constant:-16.0],
    ]];
    self.sheetView.transform = CGAffineTransformMakeTranslation(0.0, 120.0);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [UIView animateWithDuration:0.16 delay:0.0 usingSpringWithDamping:0.94 initialSpringVelocity:0.25 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.dimmingButton.alpha = 1.0;
        self.sheetView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)choiceTapped:(UIButton *)sender {
    NSArray<NSString *> *titles = @[@"", @"剪刀", @"石头", @"布", @"骰子 1", @"骰子 2", @"骰子 3", @"骰子 4", @"骰子 5", @"骰子 6"];
    NSUInteger value = (NSUInteger)sender.tag;
    NSString *title = value < titles.count ? titles[value] : @"未知结果";
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.selectionHandler) self.selectionHandler(value, title);
    }];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.cancelHandler) self.cancelHandler();
    }];
}

@end

static BOOL WCAtlasTryAuthorizeGame(MMAuthorizeUserInfoViewController *controller) {
    if (!controller || !WCAtlasEnhancementEnabled(WCAtlasAutoGameAuthorizeKey)) return NO;
    if ([objc_getAssociatedObject(controller, &WCAtlasGameDidAuthorizeKey) boolValue]) return YES;
    UIButton *allowButton = WCAtlasFindButton(@"允许", controller.view);
    if (!allowButton || !allowButton.window) return NO;
    objc_setAssociatedObject(controller, &WCAtlasGameDidAuthorizeKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [allowButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    WCAtlasLog(@"已自动允许游戏扫码授权");
    WCAtlasShowTransientHUD(@"已自动允许游戏授权", @"gamecontroller.fill");
    return YES;
}

static void WCAtlasRegisterPlugin(void) {
    if (WCAtlasDidRegister) return;

    WCAtlasSettingsRegisterDefaults();

    BOOL hasExternalManager = WCAtlasExternalPluginManagerAvailable();
    Class managerClass = hasExternalManager ? NSClassFromString(@"WCPluginsMgr") : Nil;
    WCAtlasPluginsMgr *manager = managerClass ? [managerClass sharedInstance] : nil;
    BOOL useBuiltInManager = WCAtlasEnhancementEnabled(WCAtlasPluginManagerEnabledKey);
    if (manager && useBuiltInManager) {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:WCAtlasPluginManagerEnabledKey];
        useBuiltInManager = NO;
    }
    if (!manager && !useBuiltInManager) return;
    if (manager) {
        [manager registerControllerWithTitle:@"WCAtlas"
                                     version:WCAtlasDisplayVersion
                                  controller:NSStringFromClass([WCAtlasSettingsViewController class])];
    } else if (useBuiltInManager) {
        if (!WCAtlasInstallPluginRegistry()) return;
        Class builtInManagerClass = NSClassFromString(@"WCPluginsMgr");
        WCAtlasPluginsMgr *builtInManager = builtInManagerClass
            ? [builtInManagerClass sharedInstance] : nil;
        if (!builtInManager) return;
        [builtInManager registerControllerWithTitle:@"WCAtlas"
                                            version:WCAtlasDisplayVersion
                                         controller:NSStringFromClass([WCAtlasSettingsViewController class])];
    }
    WCAtlasPluginManagerRegisterSavedQuickSwitches();
    WCAtlasDidRegister = YES;
    WCAtlasLog(manager ? @"已注册到懒猫插件管理" : @"已按内置插件管理设置注册 WCAtlas");
}

static void WCAtlasRefreshHighRefreshRateConfiguration(void) {
    WCAtlasHighRefreshRateEnabled.store(WCAtlasEnhancementEnabled(WCAtlasScrollHighRefreshRateEnabledKey),
                                      std::memory_order_relaxed);
    NSInteger maximum = UIScreen.mainScreen.maximumFramesPerSecond;
    WCAtlasHighRefreshRateScreenMaximum.store((int)MAX(60, maximum), std::memory_order_relaxed);
}

static BOOL WCAtlasShouldUseHighRefreshRate(void) {
    return WCAtlasHighRefreshRateEnabled.load(std::memory_order_relaxed) &&
           WCAtlasHighRefreshRateApplicationActive.load(std::memory_order_relaxed);
}

@interface WCAtlasEntryLoader : NSObject
@end

@implementation WCAtlasEntryLoader

+ (void)load {
    // Install the optional WCPluginsMgr registry class synchronously. Delaying this to the
    // main queue causes plugins that register from +load/constructors to miss the registry.
    WCAtlasSettingsRegisterDefaults();
    WCAtlasInstallPluginRegistry();
    WCAtlasRegisterPlugin();
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasRegisterPlugin();
        WCAtlasRefreshDailyStepOverride();
        WCAtlasHighRefreshRateApplicationActive.store(
            UIApplication.sharedApplication.applicationState == UIApplicationStateActive,
            std::memory_order_relaxed);
        WCAtlasRefreshHighRefreshRateConfiguration();

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
                        WCAtlasRegisterPlugin();
                        WCAtlasRefreshDailyStepOverride();
                        WCAtlasRefreshHighRefreshRateConfiguration();
                    }];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationWillEnterForegroundNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
                        WCAtlasRefreshDailyStepOverride();
                        WCAtlasRefreshHighRefreshRateConfiguration();
                        BaseMsgContentViewController *controller = WCAtlasResolveVisibleChatController();
                        if (controller) {
                            WCAtlasRefreshGlassBackdropsInView(controller.navigationController.navigationBar);
                            WCAtlasRefreshGlassBackdropsInView(controller.view);
                        }
                    }];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
                        WCAtlasHighRefreshRateApplicationActive.store(true, std::memory_order_relaxed);
                        WCAtlasRefreshHighRefreshRateConfiguration();
                    }];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationWillResignActiveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
                        WCAtlasHighRefreshRateApplicationActive.store(false, std::memory_order_relaxed);
                    }];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:WCAtlasEnhancementDidChangeNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
                        WCAtlasSynchronizeVisibleMomentsCells();
                        WCAtlasSynchronizeVisibleReplyGestures();
                        NSString *changedKey = [note.object isKindOfClass:[NSString class]] ? note.object : nil;
                        if (!changedKey ||
                            [changedKey isEqualToString:WCAtlasScrollHighRefreshRateEnabledKey] ||
                            [changedKey isEqualToString:WCAtlasEnabledKey]) {
                            WCAtlasRefreshHighRefreshRateConfiguration();
                        }
                        if (!changedKey ||
                            [changedKey isEqualToString:WCAtlasGlobalAvatarRoundingEnabledKey] ||
                            [changedKey isEqualToString:WCAtlasGlobalAvatarCornerPercentKey] ||
                            [changedKey isEqualToString:WCAtlasEnabledKey]) {
                            WCAtlasRefreshTrackedGlobalAvatarViews();
                        }
                        BOOL refreshChatTop = !changedKey ||
                            [changedKey isEqualToString:WCAtlasChatSearchButtonEnabledKey] ||
                            [changedKey isEqualToString:WCAtlasChatTopBarCapsuleEnabledKey] ||
                            [changedKey isEqualToString:WCAtlasChatGlassStyleKey] ||
                            [changedKey isEqualToString:WCAtlasChatGlassBlurIntensityKey] ||
                            [changedKey isEqualToString:WCAtlasChatTopBarAvatarSizeKey] ||
                            [changedKey isEqualToString:WCAtlasChatTopBarNicknameSizeKey];
                        BaseMsgContentViewController *visibleChat = WCAtlasResolveVisibleChatController();
                        if (refreshChatTop && visibleChat) {
                            WCAtlasUpdateChatTopBar(visibleChat);
                            WCAtlasRefreshPinnedMessageGlassInView(visibleChat.view);
                        }
                    }];

        void (^refreshVisibleChatChrome)(void) = ^{
            BaseMsgContentViewController *controller = WCAtlasResolveVisibleChatController();
            if (!controller) return;
            WCAtlasRefreshChatTopBarAfterWechatUpdate(controller);
            WCAtlasRefreshPinnedMessageGlassInView(controller.view);
        };
        for (NSNotificationName lifecycleName in @[UIApplicationDidBecomeActiveNotification,
                                                    UIApplicationProtectedDataDidBecomeAvailable]) {
            [[NSNotificationCenter defaultCenter]
                addObserverForName:lifecycleName
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                            BaseMsgContentViewController *controller = WCAtlasResolveVisibleChatController();
                            if (controller) {
                                WCAtlasRefreshGlassBackdropsInView(controller.navigationController.navigationBar);
                                WCAtlasRefreshGlassBackdropsInView(controller.view);
                            }
                            refreshVisibleChatChrome();
                            // WeChat restores different background layers in separate passes.
                            // Replay after both passes without forcing a layout cycle.
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                                           dispatch_get_main_queue(), refreshVisibleChatChrome);
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                                           dispatch_get_main_queue(), refreshVisibleChatChrome);
                        }];
        }

        [[NSNotificationCenter defaultCenter]
            addObserverForName:WCAtlasAntiRevokePromptDidChangeNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
                        WCAtlasRefreshVisibleAntiRevokeCells();
                    }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WCAtlasRegisterPlugin();
        });
    });
}

@end

%hook CADisplayLink

- (void)setFrameInterval:(NSInteger)frameInterval {
    if (!WCAtlasShouldUseHighRefreshRate()) {
        %orig;
        return;
    }
    %orig(1);
    if ([self respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        self.preferredFramesPerSecond =
            WCAtlasHighRefreshRateScreenMaximum.load(std::memory_order_relaxed);
    }
}

- (void)setPreferredFramesPerSecond:(NSInteger)framesPerSecond {
    if (WCAtlasShouldUseHighRefreshRate()) {
        NSInteger maximum = WCAtlasHighRefreshRateScreenMaximum.load(std::memory_order_relaxed);
        %orig(maximum);
        return;
    }
    %orig;
}

%end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

%group WCAtlasHighRefreshRateRange

%hook CADisplayLink

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (WCAtlasShouldUseHighRefreshRate()) {
        float maximum = (float)WCAtlasHighRefreshRateScreenMaximum.load(std::memory_order_relaxed);
        CAFrameRateRange preferredRange = CAFrameRateRangeMake(maximum, maximum, maximum);
        %orig(preferredRange);
        return;
    }
    %orig;
}

%end

%end

#pragma clang diagnostic pop

%hook CAMetalLayer

- (NSUInteger)maximumDrawableCount {
    if (WCAtlasShouldUseHighRefreshRate()) return 2;
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)maximumDrawableCount {
    if (WCAtlasShouldUseHighRefreshRate()) {
        %orig(2);
        return;
    }
    %orig;
}

%end

static BOOL WCAtlasViewLooksLikeGlobalSeparator(UIView *view) {
    if (!view) return NO;
    NSString *className = NSStringFromClass(view.class);
    BOOL nativeSeparator = [className isEqualToString:@"_UITableViewCellSeparatorView"];
    CGRect frame = view.frame;
    CGFloat width = CGRectGetWidth(frame);
    CGFloat height = CGRectGetHeight(frame);
    BOOL thinLine = ((width > 0.3 && width <= 0.55) ||
                     (height > 0.3 && height <= 0.55)) &&
                    view.alpha > 0.9 &&
                    view.backgroundColor != nil &&
                    ![view isKindOfClass:[UILabel class]] &&
                    ![view isKindOfClass:[UIImageView class]];
    BOOL candidate = nativeSeparator || thinLine;
    if ([className isEqualToString:@"UIView"]) candidate = thinLine && view.subviews.count == 0;
    return candidate;
}

%hook UIView

- (void)layoutSubviews {
    %orig;
    NSNumber *originalHidden = objc_getAssociatedObject(self, &WCAtlasSeparatorOriginalHiddenKey);
    BOOL shouldHide = WCAtlasEnhancementEnabled(WCAtlasHideSeparatorLinesKey) && WCAtlasViewLooksLikeGlobalSeparator(self);
    if (shouldHide) {
        if (!originalHidden) {
            originalHidden = @(self.hidden);
            objc_setAssociatedObject(self, &WCAtlasSeparatorOriginalHiddenKey, originalHidden, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!self.hidden) self.hidden = YES;
    } else if (originalHidden) {
        self.hidden = originalHidden.boolValue;
        objc_setAssociatedObject(self, &WCAtlasSeparatorOriginalHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end

%hook NewSettingViewController

- (void)viewDidLoad {
    %orig;
    WCAtlasRegisterPlugin();
    WCAtlasInstallSettingsFallbackEntry(self);
}

- (void)reloadTableData {
    %orig;
    WCAtlasRegisterPlugin();
    WCAtlasInstallSettingsFallbackEntry(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    WCAtlasRegisterPlugin();
    WCAtlasInstallSettingsFallbackEntry(self);
}

%new
- (void)wcatlas_openSettings {
    WCAtlasPushSettingsController(self);
}

%end

%hook MMAssetPickerController

- (void)viewDidLoad {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"m_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)initBottomBar {
    %orig;
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)initCombineSendViewIfNeeded {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"m_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)reloadBottomBar {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"m_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

%end

%hook MMAssetTimeLineConfig

- (BOOL)isRetrivingOriginImage {
    if (WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"moments-original-media");
        return YES;
    }
    return %orig;
}

- (BOOL)shouldCompressLongImage {
    return WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey) ? NO : %orig;
}

- (CGSize)imageResultSizeForOriginSize:(CGSize)originSize {
    return WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey) ? originSize : %orig(originSize);
}

- (CGFloat)compressQuality {
    return WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey) ? 1.0 : %orig;
}

- (BOOL)useHighResolutionImageSize {
    return WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey) ? YES : %orig;
}

%end

%hook WCNewCommitViewController

- (void)OnDone {
    WCAtlasSetMomentsCommitImagesOriginal(self);
    %orig;
}

- (void)commonUpdateWCUploadTask:(id)task {
    %orig(task);
    WCAtlasSetMomentsOriginalFlag(task);
}

- (void)processUploadTask:(id)task {
    WCAtlasSetMomentsOriginalFlag(task);
    %orig(task);
}

%end

%hook MMImagePreviewBrowserController

- (void)viewDidLoad {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)initBottomBar {
    %orig;
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)initCombineSendViewIfNeeded {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

- (void)reloadSelectedCollectionView {
    %orig;
    WCAtlasApplyAutoOriginalSelection(self, @"_originImageCheck");
    WCAtlasApplyAutoCombineSendSelection(self);
}

%end

%hook NotificationActionsMgr

- (void)userNotificationCenter:(id)center
didReceiveNotificationResponse:(id)response
         withCompletionHandler:(void (^)(void))completionHandler {
    if (WCAtlasHandleNotificationResponse(response, completionHandler)) {
        return;
    }
    %orig;
}

%end

%hook MicroMessengerAppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    WCAtlasMomentsPrewarmCancel();
    WCAtlasBackgroundKeeperEnterBackground();
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    WCAtlasBackgroundKeeperWillEnterForeground();
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig(application);
    WCAtlasMomentsPrewarmIfNeeded();
    WCAtlasMomentsReminderTick();
    WCAtlasMomentsInteractionReminderTick();
}

- (void)careEnoughForTheLiving {
    %orig;
    WCAtlasMomentsReminderTick();
    WCAtlasMomentsInteractionReminderTick();
}

- (void)userNotificationCenter:(id)center
didReceiveNotificationResponse:(id)response
         withCompletionHandler:(void (^)(void))completionHandler {
    if (WCAtlasHandleNotificationResponse(response, completionHandler)) {
        return;
    }
    %orig;
}

%end

%hook WCNotificationCenterMgr

- (unsigned int)getUnReadMessageCount {
    unsigned int count = %orig;
    WCAtlasMomentsInteractionObserveUnreadCount(self, count);
    return count;
}

- (id)getLastUnReadMessage {
    id message = %orig;
    WCAtlasMomentsInteractionObserveLastUnreadMessage(self, message);
    return message;
}

%end

%hook EditImageForwardAndEditLogicController

- (void)OnClickEditImageDoneBarButton {
    if (WCAtlasEnhancementEnabled(WCAtlasImageEditQuickSendEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"image-edit");
        WCAtlasCurrentEditImageLogicController = self;
        (void)WCAtlasConversationUserNameForEditLogic(self);
        (void)WCAtlasEditPresenterController(self);
        objc_setAssociatedObject(self, &WCAtlasEditedImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    %orig;
}

%end

%hook EditImageAttr

- (void)setEditedImage:(id)value {
    %orig;
    if (!WCAtlasEnhancementEnabled(WCAtlasImageEditQuickSendEnabledKey)) return;
    UIImage *image = WCAtlasImageFromEditValue(value, 0);
    id logic = WCAtlasCurrentEditImageLogicController;
    if (image && logic) {
        WCAtlasCacheEditedImage(logic, image, @"setEditedImage:");
        WCAtlasResumePendingQuickSendIfReady(logic);
    }
}

- (void)setEditedImages:(id)value {
    %orig;
    if (!WCAtlasEnhancementEnabled(WCAtlasImageEditQuickSendEnabledKey)) return;
    UIImage *image = WCAtlasImageFromEditValue(value, 0);
    id logic = WCAtlasCurrentEditImageLogicController;
    if (image && logic) {
        WCAtlasCacheEditedImage(logic, image, @"setEditedImages:");
        WCAtlasResumePendingQuickSendIfReady(logic);
    }
}

%end

%hook WCActionSheet

- (void)showInView:(UIView *)view {
    id permissionsDataItem = WCAtlasPendingMomentsPermissionDataItem;
    if (permissionsDataItem) {
        @try {
            (void)WCAtlasConfigureMomentsPermissionsActionSheet(self, permissionsDataItem);
        } @catch (__unused NSException *exception) {
        }
    }
    BOOL hasForward = [self isContainButtonTitle:@"转发给朋友"] || [self isContainButtonTitle:@"发送给朋友"];
    BOOL isEditedImageMenu = hasForward &&
                             [self isContainButtonTitle:@"收藏"] &&
                             [self isContainButtonTitle:@"保存图片"];
    if (WCAtlasEnhancementEnabled(WCAtlasImageEditQuickSendEnabledKey) && isEditedImageMenu && ![self isContainButtonTitle:@"发送到当前会话"]) {
        Class logicClass = objc_getClass("EditImageForwardAndEditLogicController");
        id extendedDelegate = WCAtlasTweakSafeValue(self, @"delegateEx");
        id delegate = WCAtlasTweakSafeValue(self, @"delegate");
        id logic = logicClass && [extendedDelegate isKindOfClass:logicClass]
            ? extendedDelegate
            : (logicClass && [delegate isKindOfClass:logicClass] ? delegate : nil);
        NSString *conversationUserName = WCAtlasConversationUserNameForEditLogic(logic);
        (void)WCAtlasEditPresenterController(logic);
        id conversationContact = WCAtlasContactForUserName(conversationUserName);
        if (logic && conversationUserName.length > 0 && conversationContact) {
            __weak id weakLogic = logic;
            [self addButtonWithTitle:@"发送到当前会话" eventAction:^{
                id strongLogic = weakLogic;
                if (!strongLogic) { WCAtlasShowTransientMessage(@"发送失败：图片编辑会话已经结束", NO); return; }
                // WeChat writes the final image shortly after the action callback on
                // some versions. Send immediately when ready, otherwise resume from
                // EditImageAttr's setter without leaving the official editor flow.
                WCAtlasBeginQuickSend(strongLogic);
            }];
        }
    }
    WCAtlasPrepareMomentsHighQualityMenu(self);
    %orig;
    if (WCAtlasPendingMomentsPermissionDataItem == permissionsDataItem) WCAtlasPendingMomentsPermissionDataItem = nil;
}

%end

%hook WCTimeLineViewController

- (void)showPhotoAlert:(id)context {
    id previousController = WCAtlasPendingMomentsCameraController;
    WCAtlasPendingMomentsCameraController = WCAtlasEnhancementEnabled(WCAtlasMomentsOriginalMediaPostEnabledKey)
        ? self : nil;
    @try {
        %orig(context);
    } @finally {
        WCAtlasPendingMomentsCameraController = previousController;
    }
}

%end

%hook WCCommentDetailViewControllerFB

- (void)viewDidLoad {
    WCAtlasActiveMomentsDetailController = self;
    %orig;
}

- (void)viewWillAppear:(BOOL)animated {
    WCAtlasActiveMomentsDetailController = self;
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (WCAtlasActiveMomentsDetailController == self) WCAtlasActiveMomentsDetailController = nil;
}

%end

%hook SharePreConfirmSheetView

- (void)onConfirmButtonClick {
    id owner = WCAtlasTweakSafeValue(self, @"delegate") ?: WCAtlasTweakSafeValue(self, @"msgLogicController");
    for (id session in [WCAtlasActiveQuickSendSessions() copy]) {
        if (WCAtlasTweakSafeValue(session, @"forwardLogic") == owner) {
            WCAtlasTweakSetValue(session, @"sendButtonTapped", @YES);
        }
    }
    %orig;
}

- (void)onCancelButtonClick {
    id owner = WCAtlasTweakSafeValue(self, @"delegate") ?: WCAtlasTweakSafeValue(self, @"msgLogicController");
    NSArray *sessions = [WCAtlasActiveQuickSendSessions() copy];
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id session in sessions) {
            if (![WCAtlasTweakSafeValue(session, @"finished") boolValue] &&
                WCAtlasTweakSafeValue(session, @"forwardLogic") == owner) {
                SEL selector = NSSelectorFromString(@"OnForwardMessageCancel:");
                if ([session respondsToSelector:selector]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(session, selector, owner);
                }
            }
        }
    });
}

%end

%hook MoreViewController

- (void)addFunctionSection {
    %orig;
    WCAtlasInstallPluginManagerEntry(self);
    WCAtlasCompatibilityMarkTriggered(@"plugin-manager");
}

%new
- (void)pushPluginController {
    WCAtlasPushPluginManager(self);
}

- (void)addCardsIfNeededToSection:(id)section {
    (void)section;
    WCAtlasRecordMeMenuTitle(@"小店与卡包");
    if (WCAtlasHidesMeMenuTitle(@"小店与卡包")) {
        WCAtlasCompatibilityMarkTriggered(@"me-menu-visibility");
        return;
    }
    %orig;
}

- (void)addEmoticonsIfNeededToSection:(id)section {
    (void)section;
    WCAtlasRecordMeMenuTitle(@"表情");
    if (WCAtlasHidesMeMenuTitle(@"表情")) {
        WCAtlasCompatibilityMarkTriggered(@"me-menu-visibility");
        return;
    }
    %orig;
}

- (id)createFinderEntranceCellConfig:(CGRect)frame {
    WCAtlasRecordMeMenuTitle(@"作品");
    if (WCAtlasHidesMeMenuTitle(@"作品")) {
        WCAtlasCompatibilityMarkTriggered(@"me-menu-visibility");
        return nil;
    }
    return %orig(frame);
}

%end

%hook VoiceMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *originalItems = %orig;
    originalItems = WCAtlasOperationMenuItemsWithQuickReply(self, originalItems);
    if (!WCAtlasEnhancementEnabled(WCAtlasVoiceForwardEnabledKey) ||
        ![originalItems isKindOfClass:[NSArray class]]) return originalItems;
    for (id item in originalItems) {
        if ([[WCAtlasTweakSafeValue(item, @"title") description] containsString:@"转发"]) return originalItems;
    }
    SEL selector = NSSelectorFromString(@"forwardMenuItem");
    if (![self respondsToSelector:selector]) return originalItems;
    id forwardItem = ((id (*)(id, SEL))objc_msgSend)(self, selector);
    if (!forwardItem) return originalItems;
    WCAtlasCompatibilityMarkTriggered(@"voice-forward");
    return [originalItems arrayByAddingObject:forwardItem];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(wcatlas_addToQuickReply:)) return WCAtlasMessageCanAddToQuickReply(WCAtlasMessageWrapForCell(self));
    if (WCAtlasEnhancementEnabled(WCAtlasVoiceForwardEnabledKey) &&
        (action == NSSelectorFromString(@"onForward:") ||
         action == NSSelectorFromString(@"doForward") ||
         action == NSSelectorFromString(@"onClickForwardMenu:"))) {
        return YES;
    }
    return %orig;
}

%new
- (void)wcatlas_addToQuickReply:(id)sender {
    (void)sender;
    WCAtlasAddMessageToQuickReply(self);
}

- (void)layoutSubviews {
    %orig;
    id message = WCAtlasImageJokerMessageForObject(self);
    WCAtlasScheduleVoiceTranscription(self, message);
}

%end

%hook ForwardMessageLogicController

- (void)ForwardMsg:(id)message ToContact:(id)contact {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(message ? @[message] : @[],
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && message) return;
    %orig(message, contact);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact batchRevokeScene:(NSInteger)scene {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact, scene);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact WithRevokeBatchId:(id)batchID {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact, batchID);
}

- (void)forwardMsgList:(NSArray *)messages toContacts:(NSArray *)contacts {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts);
}

- (void)forwardNoConfirmForMsgList:(NSArray *)messages toContacts:(NSArray *)contacts {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts);
}

- (void)forwardNoConfirmForMsgList:(NSArray *)messages
                        toContacts:(NSArray *)contacts
                withBatchSendScene:(NSInteger)scene {
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts, scene);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, WCAtlasVoiceForwardFilteredOrigins(origins, handled), contacts, ignoreTips);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips
       showConfirmView:(BOOL)showConfirmView {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining,
          WCAtlasVoiceForwardFilteredOrigins(origins, handled),
          contacts,
          ignoreTips,
          showConfirmView);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips
       showConfirmView:(BOOL)showConfirmView
      batchRevokeScene:(NSInteger)scene {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCAtlasForwardMessagesBySendingVoices(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining,
          WCAtlasVoiceForwardFilteredOrigins(origins, handled),
          contacts,
          ignoreTips,
          showConfirmView,
          scene);
}

%end

%hook MMScreenShotViewController

- (void)show {
    if (WCAtlasEnhancementEnabled(WCAtlasHideScreenshotForwardKey)) {
        WCAtlasCompatibilityMarkTriggered(@"hide-screenshot-forward");
        return;
    }
    %orig;
}

%end

%hook UIImageView

- (void)setAccessibilityLabel:(NSString *)label {
    %orig;
    if ([label isEqualToString:@"免打扰"]) WCAtlasUpdateChatMuteImageView(self);
}

- (void)didMoveToWindow {
    %orig;
    if ([self.accessibilityLabel isEqualToString:@"免打扰"]) WCAtlasUpdateChatMuteImageView(self);
}

- (void)setHidden:(BOOL)hidden {
    if (!hidden && WCAtlasShouldKeepManagedChatMuteImageViewHidden(self)) {
        %orig(YES);
        return;
    }
    %orig;
}

%end

static BaseMsgContentViewController *WCAtlasSendConfirmationSourceControllerForTarget(NSString *target) {
    BaseMsgContentViewController *controller = WCAtlasSendConfirmationChatController;
    if (!controller || controller.isMovingFromParentViewController || controller.isBeingDismissed) return nil;
    if (controller.navigationController && controller.navigationController.topViewController != controller) return nil;
    UITabBarController *tabController = controller.tabBarController;
    if (tabController && tabController.selectedViewController != controller &&
        tabController.selectedViewController != controller.navigationController) return nil;
    return [WCAtlasChatUserName(controller) isEqualToString:target] ? controller : nil;
}

static UIViewController *WCAtlasSendConfirmationPresenterForTarget(NSString *target) {
    if (!NSThread.isMainThread || UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
        target.length == 0 || !WCAtlasSendConfirmationIsProtectedConversation(target)) return nil;
    BaseMsgContentViewController *source = WCAtlasSendConfirmationSourceControllerForTarget(target);
    if (!source) return nil;
    UIViewController *presentationRoot = source.tabBarController ?: source.navigationController ?: source;
    return presentationRoot.view.window ? presentationRoot : nil;
}

static NSString *WCAtlasSendConfirmationTextSummary(id wrap) {
    NSString *content = WCAtlasTweakSafeValue(wrap, @"m_nsContent");
    if (![content isKindOfClass:NSString.class]) content = @"";
    if (content.length > 60) content = [[content substringToIndex:60] stringByAppendingString:@"…"];
    return content.length > 0 ? [NSString stringWithFormat:@"文字：%@", content] : @"即将发送文字消息。";
}

static BOOL WCAtlasSendConfirmationMessageIsAppEmoticon(id wrap) {
    if ([WCAtlasTweakSafeValue(wrap, @"m_uiMessageType") integerValue] != 0x31) return NO;
    NSString *md5 = WCAtlasTweakSafeValue(wrap, @"m_nsEmoticonMD5");
    if ([md5 isKindOfClass:NSString.class] && md5.length > 0) return YES;
    NSString *content = WCAtlasTweakSafeValue(wrap, @"m_nsContent");
    if (![content isKindOfClass:NSString.class] || content.length == 0) return NO;
    return [content rangeOfString:@"<emoticonmd5>" options:NSCaseInsensitiveSearch].location != NSNotFound ||
           [content rangeOfString:@"<emoji" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL WCAtlasSendConfirmationValidateTarget(NSString *target) {
    return UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
           WCAtlasSendConfirmationIsProtectedConversation(target) &&
           WCAtlasSendConfirmationSourceControllerForTarget(target) != nil;
}

static void WCAtlasArmImageSendConfirmationBypass(NSString *target) {
    WCAtlasSendConfirmationImageBypassUsername = [target copy];
    WCAtlasSendConfirmationImageBypassDeadline = CACurrentMediaTime() + 3.0;
}

static BOOL WCAtlasConsumeImageSendConfirmationBypass(NSString *target) {
    CFTimeInterval now = CACurrentMediaTime();
    BOOL matches = target.length > 0 &&
        [WCAtlasSendConfirmationImageBypassUsername isEqualToString:target] &&
        now <= WCAtlasSendConfirmationImageBypassDeadline;
    if (matches || now > WCAtlasSendConfirmationImageBypassDeadline) {
        WCAtlasSendConfirmationImageBypassUsername = nil;
        WCAtlasSendConfirmationImageBypassDeadline = 0.0;
    }
    return matches;
}

static void WCAtlasArmVideoSendConfirmationBypass(NSString *target) {
    WCAtlasSendConfirmationVideoBypassUsername = [target copy];
    WCAtlasSendConfirmationVideoBypassDeadline = CACurrentMediaTime() + 3.0;
}

static BOOL WCAtlasConsumeVideoSendConfirmationBypass(NSString *target) {
    CFTimeInterval now = CACurrentMediaTime();
    BOOL matches = target.length > 0 &&
        [WCAtlasSendConfirmationVideoBypassUsername isEqualToString:target] &&
        now <= WCAtlasSendConfirmationVideoBypassDeadline;
    if (matches || now > WCAtlasSendConfirmationVideoBypassDeadline) {
        WCAtlasSendConfirmationVideoBypassUsername = nil;
        WCAtlasSendConfirmationVideoBypassDeadline = 0.0;
    }
    return matches;
}

static NSString *WCAtlasChatTTSPlainText(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSAttributedString.class]) return [(NSAttributedString *)value string];
    for (NSString *selectorName in @[@"text", @"string", @"attributedText"]) {
        id nested = WCAtlasTweakSafeValue(value, selectorName);
        if (nested != value) {
            NSString *plainText = [nested isKindOfClass:NSString.class] ? nested :
                ([nested isKindOfClass:NSAttributedString.class] ? [(NSAttributedString *)nested string] : nil);
            if (plainText.length > 0) return plainText;
        }
    }
    return nil;
}

static BOOL WCAtlasTryConsumeChatTTSText(MMInputToolView *toolView, id value) {
    NSString *plainText = WCAtlasChatTTSPlainText(value);
    if (!WCAtlasEnhancementEnabled(WCAtlasChatTTSEnabledKey) || plainText.length == 0) return NO;
    UIViewController *controller = WCAtlasPrivateChatControllerForInputToolView(toolView);
    NSString *userName = WCAtlasPrivateChatUserNameForInputToolView(toolView);
    __weak MMInputToolView *weakToolView = toolView;
    NSString *triggerCommand = [plainText copy];
    return WCAtlasChatTTSConsumeTriggeredText(controller, userName, plainText, ^{
        MMInputToolView *strongToolView = weakToolView;
        NSString *currentText = WCAtlasChatTTSPlainText(
            [strongToolView respondsToSelector:@selector(text)] ? [strongToolView text] : nil);
        if ([currentText isEqualToString:triggerCommand] &&
            [strongToolView respondsToSelector:@selector(resetText)]) {
            [strongToolView resetText];
        }
    }, ^(NSString *message, BOOL success) {
        WCAtlasShowChatTTSHint(weakToolView, message, success);
    });
}

static void (*WCAtlasOriginalChatTTSOnClickVoid)(id, SEL, id);
static id (*WCAtlasOriginalChatTTSOnClickObject)(id, SEL, id);
static BOOL (*WCAtlasOriginalChatTTSOnClickInteger)(id, SEL, id);
static void (*WCAtlasOriginalChatTTSEnterVoid)(id, SEL, id);
static id (*WCAtlasOriginalChatTTSEnterObject)(id, SEL, id);
static BOOL (*WCAtlasOriginalChatTTSEnterInteger)(id, SEL, id);

static void WCAtlasChatTTSOnClickVoid(id self, SEL cmd, id value) {
    if (!WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value))
        WCAtlasOriginalChatTTSOnClickVoid(self, cmd, value);
}
static id WCAtlasChatTTSOnClickObject(id self, SEL cmd, id value) {
    return WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value)
        ? nil : WCAtlasOriginalChatTTSOnClickObject(self, cmd, value);
}
static BOOL WCAtlasChatTTSOnClickInteger(id self, SEL cmd, id value) {
    return WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value)
        ? NO : WCAtlasOriginalChatTTSOnClickInteger(self, cmd, value);
}
static void WCAtlasChatTTSEnterVoid(id self, SEL cmd, id value) {
    if (!WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value))
        WCAtlasOriginalChatTTSEnterVoid(self, cmd, value);
}
static id WCAtlasChatTTSEnterObject(id self, SEL cmd, id value) {
    return WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value)
        ? nil : WCAtlasOriginalChatTTSEnterObject(self, cmd, value);
}
static BOOL WCAtlasChatTTSEnterInteger(id self, SEL cmd, id value) {
    return WCAtlasTryConsumeChatTTSText((MMInputToolView *)self, value)
        ? NO : WCAtlasOriginalChatTTSEnterInteger(self, cmd, value);
}

static BOOL WCAtlasChatTTSMethodHasObjectArgument(Method method) {
    if (!method || method_getNumberOfArguments(method) != 3) return NO;
    char type[16] = {0};
    method_getArgumentType(method, 2, type, sizeof(type));
    const char *cursor = type;
    while (*cursor && strchr("rnNoORV", *cursor)) cursor++;
    return *cursor == '@' || *cursor == '#';
}

static void WCAtlasInstallChatTTSSendEntryHooks(void) {
    Class inputClass = NSClassFromString(@"MMInputToolView");
    if (!inputClass) return;
    struct WCAtlasChatTTSEntry {
        __unsafe_unretained NSString *selectorName;
        IMP voidReplacement;
        IMP objectReplacement;
        IMP integerReplacement;
        IMP *original;
    } entries[] = {
        {@"onClickTextViewSendText:", (IMP)WCAtlasChatTTSOnClickVoid,
         (IMP)WCAtlasChatTTSOnClickObject, (IMP)WCAtlasChatTTSOnClickInteger,
         (IMP *)&WCAtlasOriginalChatTTSOnClickVoid},
        {@"TextViewDidEnter:", (IMP)WCAtlasChatTTSEnterVoid,
         (IMP)WCAtlasChatTTSEnterObject, (IMP)WCAtlasChatTTSEnterInteger,
         (IMP *)&WCAtlasOriginalChatTTSEnterVoid}
    };
    for (NSUInteger index = 0; index < sizeof(entries) / sizeof(entries[0]); index++) {
        SEL selector = NSSelectorFromString(entries[index].selectorName);
        Method method = class_getInstanceMethod(inputClass, selector);
        if (!WCAtlasChatTTSMethodHasObjectArgument(method)) continue;
        IMP replacement = NULL;
        if (WCAtlasMethodReturnsVoid(method)) replacement = entries[index].voidReplacement;
        else if (WCAtlasMethodReturnsObject(method)) replacement = entries[index].objectReplacement;
        else if (WCAtlasMethodReturnsInteger(method)) replacement = entries[index].integerReplacement;
        if (!replacement) continue;
        MSHookMessageEx(inputClass, selector, replacement, entries[index].original);
        if (index == 0) {
            WCAtlasOriginalChatTTSOnClickObject = (id (*)(id, SEL, id))WCAtlasOriginalChatTTSOnClickVoid;
            WCAtlasOriginalChatTTSOnClickInteger = (BOOL (*)(id, SEL, id))WCAtlasOriginalChatTTSOnClickVoid;
        } else {
            WCAtlasOriginalChatTTSEnterObject = (id (*)(id, SEL, id))WCAtlasOriginalChatTTSEnterVoid;
            WCAtlasOriginalChatTTSEnterInteger = (BOOL (*)(id, SEL, id))WCAtlasOriginalChatTTSEnterVoid;
        }
    }
}

%hook MMInputToolView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        WCAtlasApplyChatInputRoundingToToolView(self);
    }
    WCAtlasSynchronizeQuickReplyPlusGesture(self);
    WCAtlasSynchronizeChatTTSGesture(self);
}

- (void)layoutSubviews {
    %orig;
    WCAtlasSynchronizeChatTTSGesture(self);
}

%new
- (void)wcatlas_handleQuickReplyPlusLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    UIView *candidate = [self hitTest:[recognizer locationInView:self] withEvent:nil];
    UIView *sendButtonView = WCAtlasTweakValueForSelectorNames(self, @[@"sendButton", @"_sendButton"]);
    BOOL sendControl = NO;
    while (candidate && candidate != self) {
        if (candidate == sendButtonView) {
            sendControl = YES;
            break;
        }
        if ([candidate isKindOfClass:UIControl.class]) {
            NSMutableString *semanticText = [NSMutableString string];
            for (NSString *value in @[candidate.accessibilityLabel ?: @"",
                                      candidate.accessibilityIdentifier ?: @"",
                                      [candidate isKindOfClass:UIButton.class] ? [(UIButton *)candidate currentTitle] ?: @"" : @""]) {
                if (value.length > 0) [semanticText appendFormat:@" %@", value.lowercaseString];
            }
            sendControl = [semanticText containsString:@"发送"] || [semanticText containsString:@"send"];
            if (sendControl) break;
        }
        candidate = candidate.superview;
    }
    if (sendControl) return;
    BaseMsgContentViewController *controller = WCAtlasResolveVisibleChatController();
    if (!controller.view.window) return;
    BOOL quickReplyEnabled = WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey);
    if (quickReplyEnabled) {
        WCAtlasPresentQuickReplyLibrary(controller);
    }
}

%new
- (void)wcatlas_handleChatTTSLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCAtlasEnhancementEnabled(WCAtlasChatTTSEnabledKey)) return;
    UIViewController *controller = WCAtlasPrivateChatControllerForInputToolView(self);
    NSString *userName = WCAtlasPrivateChatUserNameForInputToolView(self);
    if (!controller.viewIfLoaded.window || userName.length == 0) {
        WCAtlasShowTransientMessage(@"当前页面不是可用的聊天会话", NO);
        return;
    }
    WCAtlasPresentChatTTSPanel(controller, userName, nil, ^(NSString *message, BOOL success) {
        WCAtlasShowTransientMessage(message, success);
    });
}

- (void)sendMsgWithText:(id)text {
    if (WCAtlasTryConsumeChatTTSText(self, text)) return;
    %orig(text);
}

- (id)onTapSendButton {
    id value = [self respondsToSelector:@selector(text)] ? [self text] : nil;
    if (WCAtlasTryConsumeChatTTSText(self, value)) return nil;
    return %orig;
}

%end

%hook MMHeadImageView

- (void)setTargetForDoubleClick:(id)target action:(SEL)action {
    BOOL nativeAssignment = !WCAtlasUpdatingAvatarNativeDoubleTap;
    if (nativeAssignment) {
        if (target && action) {
            WCAtlasWeakObjectBox *box = [WCAtlasWeakObjectBox new];
            box.object = target;
            objc_setAssociatedObject(self, &WCAtlasAvatarNativeDoubleTapTargetKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &WCAtlasAvatarNativeDoubleTapActionKey,
                                     NSStringFromSelector(action), OBJC_ASSOCIATION_COPY_NONATOMIC);
        } else {
            objc_setAssociatedObject(self, &WCAtlasAvatarNativeDoubleTapTargetKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &WCAtlasAvatarNativeDoubleTapActionKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
    }
    %orig(target, action);
    if (nativeAssignment && self.window) {
        __weak MMHeadImageView *weakHeadView = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            MMHeadImageView *headView = weakHeadView;
            CommonMessageCellView *cell = headView ? WCAtlasAvatarMessageCellForView(headView) : nil;
            if (cell.window) WCAtlasSynchronizeAvatarQuickGesture(cell);
        });
    }
}

- (void)didMoveToSuperview {
    %orig;
    __weak MMHeadImageView *weakHeadView = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMHeadImageView *headView = weakHeadView;
        CommonMessageCellView *cell = headView ? WCAtlasAvatarMessageCellForView(headView) : nil;
        if (cell.window) WCAtlasSynchronizeAvatarQuickGesture(cell);
    });
}

- (void)layoutSubviews {
    %orig;
    if (WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(self)) {
        id imageView = WCAtlasTweakValueForSelectorNames(self, @[@"headImageView"]);
        if ([imageView isKindOfClass:UIImageView.class]) {
            ((UIImageView *)imageView).contentMode = UIViewContentModeScaleAspectFit;
        }
    }
    WCAtlasApplyGlobalAvatarRoundingToHeadView(self);
    NSString *userName = WCAtlasTweakValueForSelectorNames(self, @[@"nsUsrName"]);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(userName)) {
        id imageView = WCAtlasTweakValueForSelectorNames(self, @[@"headImageView"]);
        if ([imageView isKindOfClass:UIImageView.class]) {
            UIImage *image = WCAtlasHomeCategoryIconImageForUserName(userName);
            BOOL custom = image != WCAtlasHomeCategoryIconImage();
            ((UIImageView *)imageView).image = image;
            ((UIImageView *)imageView).contentMode = custom ? UIViewContentModeScaleAspectFill
                                                            : UIViewContentModeScaleAspectFit;
            ((UIImageView *)imageView).clipsToBounds = custom;
            ((UIImageView *)imageView).layer.cornerRadius = custom
                ? CGRectGetHeight(((UIImageView *)imageView).bounds) * 0.2 : 0.0;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasApplyGlobalAvatarRoundingToHeadView(self);
    CommonMessageCellView *cell = WCAtlasAvatarMessageCellForView(self);
    if (cell.window) WCAtlasSynchronizeAvatarQuickGesture(cell);
}

- (void)setConerSize:(unsigned int)cornerSize {
    if (WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(self)) {
        %orig(cornerSize);
        return;
    }
    %orig(WCAtlasGlobalAvatarScaledCornerSize(cornerSize));
}

%end

%hook FakeHeadImageView

- (void)layoutSubviews {
    %orig;
    if (WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(self)) {
        id imageView = WCAtlasTweakValueForSelectorNames(self, @[@"headImageView"]);
        if ([imageView isKindOfClass:UIImageView.class]) {
            ((UIImageView *)imageView).contentMode = UIViewContentModeScaleAspectFit;
        }
    }
    WCAtlasApplyGlobalAvatarRoundingToHeadView(self);
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasApplyGlobalAvatarRoundingToHeadView(self);
}

- (void)setConerSize:(unsigned int)cornerSize {
    if (WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(self)) {
        %orig(cornerSize);
        return;
    }
    %orig(WCAtlasGlobalAvatarScaledCornerSize(cornerSize));
}

%end

%hook MMGrowTextView

- (void)textViewDidChange:(id)textView {
    %orig(textView);
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasSynchronizeInputSwipeActions(self);
}

%new
- (void)wcatlas_handleInputSwipeLeft:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded || !WCAtlasEnhancementEnabled(WCAtlasInputSwipeActionsEnabledKey)) return;
    UITextView *textView = WCAtlasInnerTextView(self);
    WCAtlasTweakSetValue(self, @"text", @"");
    if (textView) {
        textView.text = @"";
        textView.selectedRange = NSMakeRange(0, 0);
        SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
        if ([self respondsToSelector:changeSelector]) ((void (*)(id, SEL, id))objc_msgSend)(self, changeSelector, textView);
    }
}

%new
- (void)wcatlas_handleInputSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded || !WCAtlasEnhancementEnabled(WCAtlasInputSwipeActionsEnabledKey)) return;
    UITextView *textView = WCAtlasInnerTextView(self);
    if (textView) {
        [textView becomeFirstResponder];
        [textView paste:nil];
        return;
    }
    NSString *pasteText = UIPasteboard.generalPasteboard.string;
    if (pasteText.length == 0) return;
    NSString *currentText = WCAtlasTweakSafeValue(self, @"text");
    if (![currentText isKindOfClass:[NSString class]]) currentText = @"";
    WCAtlasTweakSetValue(self, @"text", [currentText stringByAppendingString:pasteText]);
}

%end

static NSString *WCAtlasChatUserName(id controller) {
    return WCAtlasPrivateChatUserName(controller);
}

static MMGrowTextView *WCAtlasFindGrowTextView(UIView *view) {
    if (!view) return nil;
    Class growTextClass = objc_getClass("MMGrowTextView");
    if (growTextClass && [view isKindOfClass:growTextClass]) return (MMGrowTextView *)view;
    for (UIView *subview in view.subviews) {
        MMGrowTextView *match = WCAtlasFindGrowTextView(subview);
        if (match) return match;
    }
    return nil;
}

static BOOL WCAtlasInsertQuickReplyText(BaseMsgContentViewController *controller, NSString *text) {
    if (!controller.view.window || text.length == 0) return NO;
    MMGrowTextView *growTextView = WCAtlasFindGrowTextView(controller.view);
    UITextView *textView = WCAtlasInnerTextView(growTextView);
    if (!growTextView || !textView) return NO;
    UITextRange *selection = textView.selectedTextRange;
    if (selection) {
        [textView replaceRange:selection withText:text];
    } else {
        NSString *existing = textView.text ?: @"";
        textView.text = [existing stringByAppendingString:text];
        textView.selectedRange = NSMakeRange(textView.text.length, 0);
    }
    SEL changedSelector = sel_registerName("textViewDidChange:");
    if ([growTextView respondsToSelector:changedSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(growTextView, changedSelector, textView);
    }
    [textView becomeFirstResponder];
    return YES;
}

static BOOL WCAtlasSendQuickReplyTextNow(BaseMsgContentViewController *controller,
                                       NSString *lockedUserName,
                                       NSString *text) {
    if (!controller.view.window || ![WCAtlasChatUserName(controller) isEqualToString:lockedUserName] || text.length == 0) return NO;
    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    id manager = WCAtlasMessageManager();
    SEL sendSelector = sel_registerName("AddMsg:MsgWrap:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector] ||
        !manager || ![manager respondsToSelector:sendSelector]) return NO;
    id wrap = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([wrapClass alloc], initSelector, 1);
    if (!wrap) return NO;
    NSUInteger now = (NSUInteger)NSDate.date.timeIntervalSince1970;
    WCAtlasTweakSetValue(wrap, @"m_nsFromUsr", WCAtlasCurrentUserWXID() ?: @"");
    WCAtlasTweakSetValue(wrap, @"m_nsToUsr", lockedUserName);
    WCAtlasTweakSetValue(wrap, @"m_nsContent", text);
    WCAtlasTweakSetValue(wrap, @"m_uiStatus", @1);
    WCAtlasTweakSetValue(wrap, @"m_uiCreateTime", @(now));
    objc_setAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id))objc_msgSend)(manager, sendSelector, lockedUserName, wrap);
    return YES;
}

static void WCAtlasSendQuickReplyTextWithConfirmation(BaseMsgContentViewController *controller,
                                                     NSString *lockedUserName,
                                                     NSString *text) {
    __weak BaseMsgContentViewController *weakController = controller;
    dispatch_block_t sendAction = ^{
        BaseMsgContentViewController *strongController = weakController;
        if (!WCAtlasSendQuickReplyTextNow(strongController, lockedUserName, text)) {
            WCAtlasShowTransientMessage(@"快捷回复发送失败，会话或发送接口已失效", NO);
        }
    };
    NSString *preview = text.length > 60 ? [[text substringToIndex:60] stringByAppendingString:@"…"] : text;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(controller,
                                                      lockedUserName,
                                                      [NSString stringWithFormat:@"文字：%@", preview],
                                                      ^BOOL{
        BaseMsgContentViewController *strongController = weakController;
        return strongController.view.window &&
               [WCAtlasChatUserName(strongController) isEqualToString:lockedUserName];
    }, sendAction);
    if (!held) sendAction();
}

@interface WCAtlasMaterialSendSession : NSObject
@property (nonatomic, strong) id logic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@end

@implementation WCAtlasMaterialSendSession
@end

static NSMutableSet<WCAtlasMaterialSendSession *> *WCAtlasActiveMaterialSendSessions(void) {
    static NSMutableSet<WCAtlasMaterialSendSession *> *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

static BOOL WCAtlasSendQuickReplyImageNow(BaseMsgContentViewController *controller,
                                        NSString *lockedUserName,
                                        NSString *path) {
    if (!controller.view.window || ![WCAtlasChatUserName(controller) isEqualToString:lockedUserName]) return NO;
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    id contact = WCAtlasContactForUserName(lockedUserName);
    Class providerClass = objc_getClass("PasteboardMsgProvider");
    Class forwardClass = objc_getClass("ForwardMessageLogicController");
    SEL makeSelector = sel_registerName("GetMessageFromImage:contact:");
    SEL sendSelector = sel_registerName("forwardNoConfirmForMsgList:toContacts:");
    if (!image || !contact || !providerClass || ![providerClass respondsToSelector:makeSelector] || !forwardClass) return NO;
    id message = ((id (*)(id, SEL, id, id))objc_msgSend)(providerClass, makeSelector, image, contact);
    if (message) objc_setAssociatedObject(message, &WCAtlasSendConfirmationNativeBypassKey, @YES,
                                          OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id logic = message ? [forwardClass new] : nil;
    if (!logic || ![logic respondsToSelector:sendSelector]) return NO;
    WCAtlasMaterialSendSession *session = [WCAtlasMaterialSendSession new];
    session.logic = logic;
    session.message = message;
    session.contact = contact;
    [WCAtlasActiveMaterialSendSessions() addObject:session];
    @try {
        ((void (*)(id, SEL, id, id))objc_msgSend)(logic, sendSelector, @[message], @[contact]);
    } @catch (__unused NSException *exception) {
        [WCAtlasActiveMaterialSendSessions() removeObject:session];
        return NO;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [WCAtlasActiveMaterialSendSessions() removeObject:session];
    });
    return YES;
}

static UIImage *WCAtlasQuickReplyVideoThumbnail(NSString *path) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(960.0, 960.0);
    CGImageRef frame = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 600) actualTime:NULL error:nil];
    if (!frame) return nil;
    UIImage *image = [UIImage imageWithCGImage:frame];
    CGImageRelease(frame);
    return image;
}

static id WCAtlasQuickReplyVideoLogicController(BaseMsgContentViewController *controller) {
    if (!controller) return nil;
    id candidate = WCAtlasTweakSafeValue(controller, @"m_delegate");
    if (!candidate) {
        SEL delegateSelector = sel_registerName("m_delegate");
        if ([controller respondsToSelector:delegateSelector]) {
            @try {
                candidate = ((id (*)(id, SEL))objc_msgSend)(controller, delegateSelector);
            } @catch (__unused NSException *exception) {
                candidate = nil;
            }
        }
    }
    if (candidate) return candidate;

    id manager = WCAtlasServiceForClass(objc_getClass("MMMsgLogicManager"));
    for (NSString *selectorName in @[@"getTopLogicController", @"topLogicController", @"GetCurrentLogicController"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![manager respondsToSelector:selector]) continue;
        @try {
            candidate = ((id (*)(id, SEL))objc_msgSend)(manager, selector);
        } @catch (__unused NSException *exception) {
            candidate = nil;
        }
        if (candidate) return candidate;
    }
    return nil;
}

static BOOL WCAtlasSendLocalVideoNow(BaseMsgContentViewController *controller,
                                   NSString *lockedUserName,
                                   NSString *path,
                                   UIImage *providedThumbnail,
                                   NSString **failureReason) {
    if (!controller.view.window || ![WCAtlasChatUserName(controller) isEqualToString:lockedUserName] ||
        ![NSFileManager.defaultManager fileExistsAtPath:path]) {
        if (failureReason) *failureReason = @"原会话或视频文件已失效";
        return NO;
    }
    id logicController = WCAtlasQuickReplyVideoLogicController(controller);
    if (!logicController) {
        if (failureReason) *failureReason = @"无法取得当前聊天的视频逻辑控制器";
        WCAtlasLog(@"快捷视频发送失败：BaseMsg=%@，未取得 m_delegate 或 MMMsgLogicManager controller",
                 NSStringFromClass(controller.class));
        return NO;
    }
    id imageController = WCAtlasTweakSafeValue(logicController, @"m_imageController");
    if (!imageController) {
        SEL getter = sel_registerName("m_imageController");
        if ([logicController respondsToSelector:getter]) {
            @try {
                imageController = ((id (*)(id, SEL))objc_msgSend)(logicController, getter);
            } @catch (__unused NSException *exception) {
                imageController = nil;
            }
        }
    }
    if (!imageController) {
        if (failureReason) *failureReason = @"当前聊天没有可用的视频发送控制器";
        WCAtlasLog(@"快捷视频发送失败：logic=%@，未取得 m_imageController",
                 NSStringFromClass([logicController class]));
        return NO;
    }
    SEL selector = sel_registerName("onShortVideoTaken:thumbImg:editVideoAttr:paramModel:");
    if (![imageController respondsToSelector:selector]) {
        if (failureReason) *failureReason = @"当前微信的视频发送方法已变化";
        WCAtlasLog(@"快捷视频发送失败：imageController=%@ 不响应 %@",
                 NSStringFromClass([imageController class]), NSStringFromSelector(selector));
        return NO;
    }
    UIImage *thumbnail = providedThumbnail;
    if (!thumbnail) thumbnail = WCAtlasQuickReplyVideoThumbnail(path);
    if (!thumbnail) {
        if (failureReason) *failureReason = @"无法生成视频缩略图";
        return NO;
    }
    @try {
        WCAtlasArmVideoSendConfirmationBypass(lockedUserName);
        ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(imageController, selector, path, thumbnail, nil, nil);
    } @catch (NSException *exception) {
        WCAtlasSendConfirmationVideoBypassUsername = nil;
        WCAtlasSendConfirmationVideoBypassDeadline = 0.0;
        if (failureReason) *failureReason = @"调用微信视频发送方法失败";
        WCAtlasLog(@"快捷视频发送异常：%@", exception.reason ?: exception.name);
        return NO;
    }
    return YES;
}

static BOOL WCAtlasSendQuickReplyVideoNow(BaseMsgContentViewController *controller,
                                        NSString *lockedUserName,
                                        NSString *path,
                                        WCAtlasQuickReplyItem *item,
                                        NSString **failureReason) {
    NSString *thumbnailPath = [WCAtlasQuickReplyStore.sharedStore absoluteThumbnailPathForItem:item];
    UIImage *thumbnail = thumbnailPath.length > 0 ? [UIImage imageWithContentsOfFile:thumbnailPath] : nil;
    return WCAtlasSendLocalVideoNow(controller, lockedUserName, path, thumbnail, failureReason);
}

static BOOL WCAtlasSendQuickReplyVoiceNow(BaseMsgContentViewController *controller,
                                        NSString *lockedUserName,
                                        NSString *path,
                                        WCAtlasQuickReplyItem *item) {
    if (!controller.view.window || ![WCAtlasChatUserName(controller) isEqualToString:lockedUserName] ||
        ![NSFileManager.defaultManager fileExistsAtPath:path]) return NO;
    Class messageWrapClass = objc_getClass("CMessageWrap");
    SEL initializer = sel_registerName("initWithMsgType:");
    if (!messageWrapClass || ![messageWrapClass instancesRespondToSelector:initializer]) return NO;
    id message = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([messageWrapClass alloc], initializer, 34);
    if (!message) return NO;
    WCAtlasTweakSetValue(message, @"m_uiMessageType", @34);
    id extendInfo = WCAtlasTweakSafeValue(message, @"m_extendInfoWithMsgType");
    NSNumber *voiceTime = [item.metadata[@"voiceTime"] respondsToSelector:@selector(unsignedIntegerValue)] ? item.metadata[@"voiceTime"] : nil;
    NSNumber *voiceFormat = [item.metadata[@"voiceFormat"] respondsToSelector:@selector(unsignedIntegerValue)] ? item.metadata[@"voiceFormat"] : nil;
    if (voiceTime.unsignedIntegerValue > 0) WCAtlasTweakSetValue(extendInfo, @"m_uiVoiceTime", voiceTime);
    if (voiceFormat) WCAtlasTweakSetValue(extendInfo, @"m_uiVoiceFormat", voiceFormat);
    WCAtlasTweakSetValue(extendInfo, @"m_uiVoiceForwardFlag", @1);
    return WCAtlasSendVoiceMessage(message, path, lockedUserName);
}

static id WCAtlasResolveQuickReplyMessageReference(WCAtlasQuickReplyItem *item) {
    NSString *sourceConversation = item.sourceConversation;
    unsigned long long localID = [item.metadata[@"localID"] unsignedLongLongValue];
    long long serverID = [item.metadata[@"serverID"] longLongValue];
    id manager = WCAtlasMessageManager();
    if (!manager || sourceConversation.length == 0) return nil;
    @try {
        SEL localSelector = NSSelectorFromString(@"GetMsg:LocalID:");
        Method localMethod = class_getInstanceMethod([manager class], localSelector);
        if (localID > 0 && localID <= UINT_MAX && [manager respondsToSelector:localSelector] &&
            localMethod && method_getNumberOfArguments(localMethod) == 4 &&
            WCAtlasMethodReturnsObject(localMethod) &&
            WCAtlasMethodArgumentIsObject(localMethod, 2) &&
            WCAtlasMethodArgumentIsIntegerScalar(localMethod, 3)) {
            id message = ((id (*)(id, SEL, id, unsigned int))objc_msgSend)(
                manager, localSelector, sourceConversation, (unsigned int)localID);
            if (message) return message;
        }
        SEL serverSelector = NSSelectorFromString(@"GetMsg:n64SvrID:");
        Method serverMethod = class_getInstanceMethod([manager class], serverSelector);
        if (serverID != 0 && [manager respondsToSelector:serverSelector] &&
            serverMethod && method_getNumberOfArguments(serverMethod) == 4 &&
            WCAtlasMethodReturnsObject(serverMethod) &&
            WCAtlasMethodArgumentIsObject(serverMethod, 2) &&
            WCAtlasMethodArgumentIsIntegerScalar(serverMethod, 3)) {
            return ((id (*)(id, SEL, id, long long))objc_msgSend)(
                manager, serverSelector, sourceConversation, serverID);
        }
    } @catch (NSException *exception) {
        WCAtlasLog(@"消息库回查原消息失败：%@", exception.reason ?: exception.name);
    }
    return nil;
}

static BOOL WCAtlasForwardQuickReplyMessageNow(BaseMsgContentViewController *controller,
                                              NSString *targetUserName,
                                              id message) {
    if (!controller.view.window || targetUserName.length == 0 || !message) return NO;
    NSInteger messageType = [WCAtlasTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (messageType == 34) return WCAtlasRepeatVoiceMessage(message, targetUserName);
    id contact = WCAtlasContactForUserName(targetUserName);
    Class forwardClass = objc_getClass("ForwardMessageLogicController");
    SEL forwardSelector = sel_registerName("forwardNoConfirmForMsgList:toContacts:");
    SEL delegateSelector = sel_registerName("setDelegate:");
    if (!contact || !forwardClass) return NO;
    Class utilityClass = objc_getClass("ForwardMsgUtil");
    SEL canForwardSelector = sel_registerName("canBeForwardWithMsg:");
    if ([utilityClass respondsToSelector:canForwardSelector] &&
        !((BOOL (*)(id, SEL, id))objc_msgSend)(utilityClass, canForwardSelector, message)) return NO;
    Method forwardMethod = class_getInstanceMethod(forwardClass, forwardSelector);
    Method delegateMethod = class_getInstanceMethod(forwardClass, delegateSelector);
    if (!forwardMethod || method_getNumberOfArguments(forwardMethod) != 4 ||
        !WCAtlasMethodArgumentIsObject(forwardMethod, 2) ||
        !WCAtlasMethodArgumentIsObject(forwardMethod, 3) ||
        !delegateMethod || method_getNumberOfArguments(delegateMethod) != 3 ||
        !WCAtlasMethodArgumentIsObject(delegateMethod, 2)) return NO;
    id logic = [forwardClass new];
    WCAtlasMessageRepeatSession *session = [WCAtlasMessageRepeatSession new];
    session.forwardLogic = logic;
    session.message = message;
    session.contact = contact;
    session.presenter = controller;
    ((void (*)(id, SEL, id))objc_msgSend)(logic, delegateSelector, session);
    [WCAtlasActiveQuickSendSessions() addObject:session];
    @try {
        ((void (*)(id, SEL, id, id))objc_msgSend)(logic, forwardSelector, @[message], @[contact]);
    } @catch (NSException *exception) {
        WCAtlasLog(@"消息库原消息转发失败：%@", exception.reason ?: exception.name);
        [session finishSession];
        return NO;
    }
    __weak WCAtlasMessageRepeatSession *weakSession = session;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCAtlasMessageRepeatSession *activeSession = weakSession;
        if (activeSession && !activeSession.finished) [activeSession finishSession];
    });
    return YES;
}

static void WCAtlasSendQuickReplyMessageReferenceWithConfirmation(BaseMsgContentViewController *controller,
                                                                 NSString *lockedUserName,
                                                                 WCAtlasQuickReplyItem *item) {
    id message = WCAtlasResolveQuickReplyMessageReference(item);
    if (!message) {
        WCAtlasShowTransientMessage(@"原聊天消息已不存在，无法发送", NO);
        return;
    }
    __weak BaseMsgContentViewController *weakController = controller;
    dispatch_block_t sendAction = ^{
        BaseMsgContentViewController *strongController = weakController;
        if (!WCAtlasForwardQuickReplyMessageNow(strongController, lockedUserName, message)) {
            WCAtlasShowTransientMessage(@"微信原生转发链暂不支持该消息", NO);
        }
    };
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(controller, lockedUserName,
                                                      item.text.length ? item.text : @"原消息", ^BOOL{
        BaseMsgContentViewController *strongController = weakController;
        return strongController.view.window &&
               [WCAtlasChatUserName(strongController) isEqualToString:lockedUserName];
    }, sendAction);
    if (!held) sendAction();
}

static BOOL WCAtlasSubmitSavedGroupInvitation(NSString *groupUserName,
                                             NSString *memberUserName,
                                             BOOL *supported) {
    WCAtlasPrivateGroupInvitationResult result =
        WCAtlasPrivateInviteGroupMember(groupUserName, memberUserName);
    if (supported) *supported = result != WCAtlasPrivateGroupInvitationResultUnsupported;
    return result == WCAtlasPrivateGroupInvitationResultSubmitted;
}

static void WCAtlasSendQuickReplyGroupInvitationWithConfirmation(BaseMsgContentViewController *controller,
                                                                NSString *lockedUserName,
                                                                WCAtlasQuickReplyItem *item) {
    NSString *groupUserName = [item.metadata[@"groupUserName"] isKindOfClass:NSString.class]
        ? item.metadata[@"groupUserName"] : item.text;
    if ([lockedUserName hasSuffix:@"@chatroom"] || [lockedUserName isEqualToString:@"filehelper"] ||
        [lockedUserName isEqualToString:WCAtlasCurrentUserWXID()]) {
        WCAtlasShowTransientMessage(@"群聊邀请只能在好友单聊中使用", NO);
        return;
    }
    __weak BaseMsgContentViewController *weakController = controller;
    dispatch_block_t sendAction = ^{
        BaseMsgContentViewController *strongController = weakController;
        if (!strongController.view.window ||
            ![WCAtlasChatUserName(strongController) isEqualToString:lockedUserName]) return;
        BOOL supported = NO;
        BOOL accepted = WCAtlasSubmitSavedGroupInvitation(groupUserName, lockedUserName, &supported);
        WCAtlasShowTransientMessage(supported ? (accepted ? @"已提交群聊邀请" : @"群聊邀请未被微信接受")
                                             : @"当前微信版本不支持群聊邀请",
                                  accepted);
    };
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(controller, lockedUserName,
        [NSString stringWithFormat:@"%@：邀请当前好友", item.title.length ? item.title : @"群聊邀请"],
        ^BOOL{
            BaseMsgContentViewController *strongController = weakController;
            return strongController.view.window &&
                [WCAtlasChatUserName(strongController) isEqualToString:lockedUserName];
        }, sendAction);
    if (!held) sendAction();
}

static void WCAtlasSendQuickReplyMediaWithConfirmation(BaseMsgContentViewController *controller,
                                                      NSString *lockedUserName,
                                                      WCAtlasQuickReplyItem *item) {
    NSString *path = [WCAtlasQuickReplyStore.sharedStore absoluteMediaPathForItem:item];
    if (path.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:path]) {
        WCAtlasShowTransientMessage(@"素材文件已丢失，请重新加入", NO);
        return;
    }
    __weak BaseMsgContentViewController *weakController = controller;
    dispatch_block_t sendAction = ^{
        BaseMsgContentViewController *strongController = weakController;
        NSString *failureReason = nil;
        BOOL sent = item.type == WCAtlasQuickReplyTypeImage
            ? WCAtlasSendQuickReplyImageNow(strongController, lockedUserName, path)
            : (item.type == WCAtlasQuickReplyTypeVideo
                ? WCAtlasSendQuickReplyVideoNow(strongController, lockedUserName, path, item, &failureReason)
                : WCAtlasSendQuickReplyVoiceNow(strongController, lockedUserName, path, item));
        if (!sent) WCAtlasShowTransientMessage(failureReason ?: @"微信媒体发送接口已变化，未发送素材", NO);
    };
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(controller,
                                                      lockedUserName,
                                                      item.type == WCAtlasQuickReplyTypeImage ? @"图片素材：1 张" :
                                                        (item.type == WCAtlasQuickReplyTypeVideo ? @"视频素材：1 个" : @"语音素材：1 条"),
                                                      ^BOOL{
        BaseMsgContentViewController *strongController = weakController;
        return strongController.view.window &&
               [WCAtlasChatUserName(strongController) isEqualToString:lockedUserName];
    }, sendAction);
    if (!held) sendAction();
}

static void WCAtlasPresentQuickReplyLibrary(BaseMsgContentViewController *controller) {
    if (!controller.view.window || !WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey)) return;
    NSString *lockedUserName = [WCAtlasChatUserName(controller) copy];
    if (lockedUserName.length == 0) {
        WCAtlasShowTransientMessage(@"无法识别当前会话", NO);
        return;
    }
    __weak BaseMsgContentViewController *weakController = controller;
    WCAtlasQuickReplyViewController *library = [[WCAtlasQuickReplyViewController alloc] initWithSelectionHandler:^(WCAtlasQuickReplyItem *item) {
        BaseMsgContentViewController *strongController = weakController;
        NSString *currentUserName = WCAtlasChatUserName(strongController);
        if (!strongController.view.window || ![currentUserName isEqualToString:lockedUserName]) {
            WCAtlasShowTransientMessage(@"原会话已离开，未使用快捷回复", NO);
            return;
        }
        if (item.type == WCAtlasQuickReplyTypeJavaScript) {
            [WCAtlasAutomationManager.sharedManager runJavaScript:item.text
                targetUserName:lockedUserName completion:^(NSString *result) {
                    WCAtlasShowTransientMessage(result, ![result hasPrefix:@"失败："]);
                }];
            return;
        }
        if (item.type == WCAtlasQuickReplyTypeText) {
            if (!WCAtlasInsertQuickReplyText(strongController, item.text)) {
                WCAtlasShowTransientMessage(@"无法写入当前输入框", NO);
            }
            return;
        }
        if (item.type == WCAtlasQuickReplyTypeMessageReference) {
            WCAtlasSendQuickReplyMessageReferenceWithConfirmation(strongController, lockedUserName, item);
            return;
        }
        if (item.type == WCAtlasQuickReplyTypeGroupInvitation) {
            WCAtlasSendQuickReplyGroupInvitationWithConfirmation(strongController, lockedUserName, item);
            return;
        }
        WCAtlasSendQuickReplyMediaWithConfirmation(strongController, lockedUserName, item);
    } directSendHandler:^(WCAtlasQuickReplyItem *item) {
        __weak BaseMsgContentViewController *delayedController = weakController;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BaseMsgContentViewController *strongController = delayedController;
            if (!strongController.view.window ||
                ![WCAtlasChatUserName(strongController) isEqualToString:lockedUserName]) {
                WCAtlasShowTransientMessage(@"原会话已离开，未发送快捷回复", NO);
                return;
            }
            if (item.type == WCAtlasQuickReplyTypeJavaScript) {
                [WCAtlasAutomationManager.sharedManager runJavaScript:item.text
                    targetUserName:lockedUserName completion:^(NSString *result) {
                        WCAtlasShowTransientMessage(result, ![result hasPrefix:@"失败："]);
                    }];
            } else if (item.type == WCAtlasQuickReplyTypeText) {
                if (item.text.length > 0) WCAtlasSendQuickReplyTextWithConfirmation(strongController, lockedUserName, item.text);
            } else if (item.type == WCAtlasQuickReplyTypeMessageReference) {
                WCAtlasSendQuickReplyMessageReferenceWithConfirmation(strongController, lockedUserName, item);
            } else if (item.type == WCAtlasQuickReplyTypeGroupInvitation) {
                WCAtlasSendQuickReplyGroupInvitationWithConfirmation(strongController, lockedUserName, item);
            } else {
                WCAtlasSendQuickReplyMediaWithConfirmation(strongController, lockedUserName, item);
            }
        });
    }];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:library];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [controller presentViewController:navigation animated:YES completion:nil];
}

static void WCAtlasRestoreChatTopBar(BaseMsgContentViewController *controller);
static void WCAtlasUpdateChatTopBar(BaseMsgContentViewController *controller);

@interface WCAtlasChatTopAvatarHostView : UIView
@property (nonatomic, strong) UIView *sourceView;
- (instancetype)initWithSourceView:(UIView *)sourceView;
@end

@implementation WCAtlasChatTopAvatarHostView

- (instancetype)initWithSourceView:(UIView *)sourceView {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    _sourceView = sourceView;
    _sourceView.translatesAutoresizingMaskIntoConstraints = YES;
    _sourceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _sourceView.userInteractionEnabled = NO;
    [self addSubview:_sourceView];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat radius = CGRectGetHeight(self.bounds) * 0.5;
    // The source is now a plain image view, so the former optical inset only
    // makes the avatar appear off-axis relative to the nickname and capsule.
    CGRect imageFrame = self.bounds;
    CGFloat imageRadius = CGRectGetHeight(imageFrame) * 0.5;
    self.layer.cornerRadius = radius;
    self.sourceView.frame = imageFrame;
    self.sourceView.clipsToBounds = YES;
    self.sourceView.layer.cornerRadius = imageRadius;
    self.sourceView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.sourceView layoutIfNeeded];

    UIImageView *imageView = [self.sourceView isKindOfClass:UIImageView.class]
        ? (UIImageView *)self.sourceView
        : WCAtlasTweakValueForSelectorNames(self.sourceView, @[@"headImageView", @"imageView"]);
    if ([imageView isKindOfClass:UIImageView.class]) {
        imageView.frame = self.sourceView.bounds;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        // Match the host/WCPulse avatar behavior: preserve the complete image
        // inside the circular viewport instead of zooming and center-cropping.
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = imageRadius;
        imageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

@end

static CGFloat WCAtlasChatTopClampedValue(NSString *key, CGFloat fallback,
                                       CGFloat minimum, CGFloat maximum) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
    CGFloat value = [stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : fallback;
    if (!isfinite(value)) value = fallback;
    return MIN(maximum, MAX(minimum, value));
}

static CGFloat WCAtlasChatTopAvatarSize(void) {
    return WCAtlasChatTopClampedValue(WCAtlasChatTopBarAvatarSizeKey, 30.0, 24.0, 34.0);
}

static CGFloat WCAtlasChatTopNicknameSize(void) {
    return WCAtlasChatTopClampedValue(WCAtlasChatTopBarNicknameSizeKey, 15.0, 12.0, 18.0);
}

static CGFloat WCAtlasChatTopLeftCapsuleHeight(void) {
    return MAX(38.0, WCAtlasChatTopAvatarSize() + 8.0);
}

static UIImageView *WCAtlasChatTopPlainAvatarImageView(UIImage *image) {
    if (![image isKindOfClass:UIImage.class]) return nil;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.backgroundColor = UIColor.clearColor;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.clipsToBounds = YES;
    return imageView;
}

static UIView *WCAtlasChatTopAvatarView(id contact, NSString *userName) {
    // Do not embed MMHeadImageView when the contact image is already available:
    // that host view applies its own crop while being resized and makes square
    // avatars look optically zoomed inside our second circular viewport.
    UIImage *contactImage = WCAtlasPrivateContactAvatarImage(contact);
    UIImageView *plainImageView = WCAtlasChatTopPlainAvatarImageView(contactImage);
    if (plainImageView) return plainImageView;

    UIView *view = WCAtlasPrivateContactAvatarView(contact, userName, NO);
    if (view) {
        id hostedImageView = [view isKindOfClass:UIImageView.class]
            ? view : WCAtlasTweakValueForSelectorNames(view, @[@"headImageView", @"imageView"]);
        UIImage *hostedImage = [hostedImageView isKindOfClass:UIImageView.class]
            ? ((UIImageView *)hostedImageView).image : nil;
        plainImageView = WCAtlasChatTopPlainAvatarImageView(hostedImage);
        if (plainImageView) return plainImageView;
        return view;
    }
    UIImageView *fallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    fallback.tintColor = UIColor.tertiaryLabelColor;
    fallback.contentMode = UIViewContentModeScaleAspectFit;
    return fallback;
}

static NSString *WCAtlasChatTopDisplayName(BaseMsgContentViewController *controller, id contact) {
    for (NSString *value in @[
        WCAtlasPrivateContactRemark(contact) ?: @"",
        WCAtlasPrivateContactNickname(contact) ?: @"",
        WCAtlasPrivateContactAlias(contact) ?: @""
    ]) {
        if (value.length > 0) {
            objc_setAssociatedObject(controller, &WCAtlasChatTopStableDisplayNameKey,
                                     value, OBJC_ASSOCIATION_COPY_NONATOMIC);
            return value;
        }
    }
    NSString *stableName = objc_getAssociatedObject(controller, &WCAtlasChatTopStableDisplayNameKey);
    BOOL typing = [objc_getAssociatedObject(controller, &WCAtlasChatTopTypingActiveKey) boolValue];
    if (typing && stableName.length > 0) return stableName;
    NSString *title = controller.navigationItem.title ?: controller.title;
    if (title.length > 0 && ![title containsString:@"正在输入"]) {
        objc_setAssociatedObject(controller, &WCAtlasChatTopStableDisplayNameKey,
                                 title, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return title;
    }
    return stableName.length > 0 ? stableName : @"聊天";
}

static BOOL WCAtlasChatTitleViewShowsTypingStatus(id titleView) {
    if ([titleView isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)titleView).text;
        return [text isKindOfClass:NSString.class] && [text containsString:@"正在输入"];
    }
    if (![titleView isKindOfClass:UIView.class]) return NO;
    for (UIView *subview in ((UIView *)titleView).subviews) {
        if (WCAtlasChatTitleViewShowsTypingStatus(subview)) return YES;
    }
    return NO;
}

static BOOL WCAtlasSetChatTypingState(BaseMsgContentViewController *controller, id titleView) {
    BOOL typing = WCAtlasChatTitleViewShowsTypingStatus(titleView);
    BOOL previous = [objc_getAssociatedObject(controller, &WCAtlasChatTopTypingActiveKey) boolValue];
    if (typing == previous) return NO;
    objc_setAssociatedObject(controller, &WCAtlasChatTopTypingActiveKey,
                             @(typing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static UIButton *WCAtlasChatTopCapsuleButton(UIImage *image, NSString *accessibilityLabel);

static CGFloat WCAtlasChatGlassPercent(NSString *key, CGFloat fallback,
                                     CGFloat minimum, CGFloat maximum) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
    CGFloat value = [stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : fallback;
    return MIN(maximum, MAX(minimum, value));
}

static UIView *WCAtlasChatTopGlassContainer(CGFloat cornerRadius, UIView **contentViewOut) {
    WCAtlasGlassCapsuleView *container = [WCAtlasGlassCapsuleView new];
    container.capsuleCornerRadius = cornerRadius;
    objc_setAssociatedObject(container, &WCAtlasChatTopGlassEffectMarkerKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIVisualEffectView *effectView = container.effectView;
    CGFloat blurIntensity = WCAtlasChatGlassPercent(WCAtlasChatGlassBlurIntensityKey,
                                                  100.0, 20.0, 100.0) / 100.0;
    NSInteger glassStyle = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasChatGlassStyleKey];
    if (glassStyle == 1) [container configurePseudoLiquidWithBlurIntensity:blurIntensity];
    else [container configureFrostedGlassWithBlurIntensity:blurIntensity];
    objc_setAssociatedObject(effectView, &WCAtlasChatTopGlassEffectMarkerKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (contentViewOut) *contentViewOut = container.contentView;
    return container;
}

static UIBarButtonItem *WCAtlasChatTopProfileItem(BaseMsgContentViewController *controller,
                                                UIBarButtonItem *backItem) {
    id contact = WCAtlasPrivateChatContact(controller);
    NSString *userName = WCAtlasChatUserName(controller);
    NSString *displayName = WCAtlasChatTopDisplayName(controller, contact);
    CGFloat availableWidth = MIN(205.0, CGRectGetWidth(UIScreen.mainScreen.bounds) - 130.0);
    CGFloat avatarSize = WCAtlasChatTopAvatarSize();
    CGFloat nicknameSize = WCAtlasChatTopNicknameSize();
    CGFloat capsuleHeight = WCAtlasChatTopLeftCapsuleHeight();

    UIView *content = nil;
    UIView *container = WCAtlasChatTopGlassContainer(capsuleHeight / 2.0, &content);

    UIImageSymbolConfiguration *backConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                      weight:UIImageSymbolWeightMedium];
    UIImage *backImage = [UIImage systemImageNamed:@"chevron.left"
                                  withConfiguration:backConfiguration];
    UIButton *backButton = WCAtlasChatTopCapsuleButton(backImage, backItem.accessibilityLabel ?: @"返回");
    WCAtlasBarButtonActionProxy *backProxy = [WCAtlasBarButtonActionProxy new];
    backProxy.originalItem = backItem;
    backProxy.fallbackController = controller;
    backProxy.popsNavigationController = YES;
    [backButton addTarget:backProxy action:@selector(invoke:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:backButton];
    objc_setAssociatedObject(controller, &WCAtlasChatTopBackProxyKey, backProxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *avatarSource = WCAtlasChatTopAvatarView(contact, userName);
    WCAtlasExcludeHeadViewFromGlobalAvatarRounding(avatarSource);
    WCAtlasChatTopAvatarHostView *avatar = [[WCAtlasChatTopAvatarHostView alloc]
        initWithSourceView:avatarSource];
    [content addSubview:avatar];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = displayName;
    UIFont *nicknameFont = [UIFont systemFontOfSize:nicknameSize weight:UIFontWeightRegular];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:nicknameFont];
    label.adjustsFontForContentSizeCategory = YES;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.78;
    label.textColor = UIColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.accessibilityLabel = displayName;
    [content addSubview:label];

    BOOL typing = [objc_getAssociatedObject(controller, &WCAtlasChatTopTypingActiveKey) boolValue];
    UILabel *typingIndicator = nil;
    if (typing) {
        typingIndicator = [UILabel new];
        typingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        typingIndicator.text = @"•••";
        typingIndicator.font = [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold];
        typingIndicator.textColor = UIColor.systemGreenColor;
        typingIndicator.accessibilityLabel = @"对方正在输入";
        typingIndicator.isAccessibilityElement = YES;
        [typingIndicator setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisHorizontal];
        [content addSubview:typingIndicator];
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @0.35;
        pulse.toValue = @1.0;
        pulse.duration = 0.65;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        [typingIndicator.layer addAnimation:pulse forKey:@"wcatlas.typing-pulse"];
    }

    CGFloat labelWidth = ceil([displayName sizeWithAttributes:@{NSFontAttributeName: label.font}].width);
    CGFloat avatarDelta = avatarSize - 30.0;
    CGFloat typingWidth = typing ? 22.0 : 0.0;
    CGFloat width = MIN(availableWidth, MAX(96.0 + avatarDelta,
                                           85.0 + avatarDelta + labelWidth + typingWidth));

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [container.widthAnchor constraintEqualToConstant:width],
        [container.heightAnchor constraintEqualToConstant:capsuleHeight],
        [backButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [backButton.topAnchor constraintEqualToAnchor:content.topAnchor],
        [backButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [backButton.widthAnchor constraintEqualToConstant:36.0],
        [avatar.leadingAnchor constraintEqualToAnchor:backButton.trailingAnchor constant:1.0],
        [avatar.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:avatarSize],
        [avatar.heightAnchor constraintEqualToConstant:avatarSize],
        [label.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:8.0],
        [label.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
    ]];
    if (typingIndicator) {
        [constraints addObjectsFromArray:@[
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:typingIndicator.leadingAnchor constant:-4.0],
            [typingIndicator.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-10.0],
            [typingIndicator.centerYAnchor constraintEqualToAnchor:content.centerYAnchor constant:1.0],
        ]];
    } else {
        [constraints addObject:[label.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-10.0]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    UILongPressGestureRecognizer *confirmationGesture = [[UILongPressGestureRecognizer alloc]
        initWithTarget:controller action:@selector(wcatlas_toggleSendConfirmation:)];
    confirmationGesture.minimumPressDuration = 0.55;
    [container addGestureRecognizer:confirmationGesture];
    return [[UIBarButtonItem alloc] initWithCustomView:container];
}

static UIButton *WCAtlasChatTopCapsuleButton(UIImage *image, NSString *accessibilityLabel) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = accessibilityLabel;
    return button;
}

static id WCAtlasOfficialChatSearchHost(BaseMsgContentViewController *controller) {
    if (!controller) return nil;
    UINavigationController *navigationController = controller.navigationController;
    return (!navigationController || navigationController.topViewController == controller)
        ? controller : nil;
}

static id WCAtlasNativeChatSearchHelper(BaseMsgContentViewController *controller,
                                      BOOL createIfMissing) {
    if (!controller) return nil;
    id helper = WCAtlasTweakSafeValue(controller, @"m_oMsgSearchHelper");
    if (!helper) helper = WCAtlasExactIvarValue(controller, @"m_oMsgSearchHelper");
    if (helper || !createIfMissing) return helper;

    SEL selector = NSSelectorFromString(@"initMsgSearchHelper:");
    Method method = class_getInstanceMethod([controller class], selector);
    if (![controller respondsToSelector:selector] ||
        method_getNumberOfArguments(method) != 3 ||
        !WCAtlasMethodArgumentIsIntegerScalar(method, 2)) return nil;
    @try {
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(controller, selector, (NSUInteger)0);
    } @catch (__unused NSException *exception) {
        return nil;
    }
    helper = WCAtlasTweakSafeValue(controller, @"m_oMsgSearchHelper");
    return helper ?: WCAtlasExactIvarValue(controller, @"m_oMsgSearchHelper");
}

static id WCAtlasNativeChatSearcher(id helper) {
    if (!helper) return nil;
    id searcher = WCAtlasTweakSafeValue(helper, @"searcher");
    if (!searcher) {
        SEL selector = NSSelectorFromString(@"getSearcher");
        if ([helper respondsToSelector:selector]) {
            searcher = ((id (*)(id, SEL))objc_msgSend)(helper, selector);
        }
    }
    return searcher ?: WCAtlasExactIvarValue(helper, @"_searcher");
}

static void WCAtlasSetChatSearchInteractivePop(BaseMsgContentViewController *controller,
                                             BOOL enabled) {
    SEL selector = NSSelectorFromString(@"setM_bInteractivePopEnabled:");
    Method method = class_getInstanceMethod([controller class], selector);
    if (![controller respondsToSelector:selector] ||
        method_getNumberOfArguments(method) != 3 ||
        !WCAtlasMethodArgumentIsIntegerScalar(method, 2)) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, selector, enabled);
}

static void WCAtlasRemoveChatSearchEdgePan(BaseMsgContentViewController *controller) {
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(controller, &WCAtlasChatSearchEdgePanKey);
    if (recognizer.view) [recognizer.view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(controller, &WCAtlasChatSearchEdgePanKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSArray<UIView *> *WCAtlasOfficialChatSearchChromeViews(id searcher) {
    if (!searcher) return @[];
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (NSString *key in @[@"searchBar", @"searchBarNotInSearcher", @"searchContainerView"]) {
        id value = WCAtlasTweakSafeValue(searcher, key);
        if ([value isKindOfClass:UIView.class] && ![views containsObject:value]) {
            [views addObject:value];
        }
    }
    return views;
}

static void WCAtlasSetOfficialChatSearchChromeHidden(id searcher, BOOL hidden) {
    for (UIView *view in WCAtlasOfficialChatSearchChromeViews(searcher)) {
        if (hidden) [view endEditing:YES];
        view.hidden = hidden;
        view.alpha = hidden ? 0.0 : 1.0;
        view.userInteractionEnabled = !hidden;
    }
}

static void WCAtlasHideOfficialChatSearchChrome(BaseMsgContentViewController *controller,
                                              id searcher) {
    if (!controller || !searcher) return;
    UIView *searchBar = WCAtlasTweakSafeValue(searcher, @"searchBar");
    WCAtlasSetOfficialChatSearchChromeHidden(searcher, YES);
    if (![searchBar isKindOfClass:UIView.class]) return;

    // The stock search bar sits inside one or two private wrapper views. The
    // narrow strip reported after dismissal is one of those wrappers retaining
    // its background. Hide only ancestors below the chat controller root.
    UIView *ancestor = searchBar.superview;
    for (NSUInteger depth = 0; ancestor && depth < 3; depth++) {
        if (ancestor == controller.view || ancestor == controller.navigationController.view) break;
        // Do not hide the navigation bar itself. Only the private wrappers
        // immediately surrounding WCSearchBar belong to this search session.
        if ([ancestor isKindOfClass:UINavigationBar.class]) break;
        ancestor.hidden = YES;
        ancestor.alpha = 0.0;
        ancestor.userInteractionEnabled = NO;
        ancestor = ancestor.superview;
    }
}

static void WCAtlasCleanupOfficialChatSearch(BaseMsgContentViewController *controller) {
    if (!controller || ![objc_getAssociatedObject(controller, &WCAtlasChatSearchActiveKey) boolValue] ||
        [objc_getAssociatedObject(controller, &WCAtlasChatSearchCleanupKey) boolValue]) return;
    objc_setAssociatedObject(controller, &WCAtlasChatSearchCleanupKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasRemoveChatSearchEdgePan(controller);

    id helper = WCAtlasNativeChatSearchHelper(controller, NO);
    id searcher = WCAtlasNativeChatSearcher(helper);
    WCAtlasHideOfficialChatSearchChrome(controller, searcher);
    SEL activeSelector = NSSelectorFromString(@"setActive:animated:completion:");
    SEL searchActiveSelector = NSSelectorFromString(@"isSeachActive");
    BOOL closedThroughSearcher = NO;
    if ([searcher respondsToSelector:activeSelector]) {
        // Presence of WCSearcher's active-state API means it owns dismissal.
        // If it already reports inactive, do not call MsgSearchHelper's
        // finishSearch a second time from viewWillAppear.
        closedThroughSearcher = YES;
        BOOL searchActive = YES;
        if ([searcher respondsToSelector:searchActiveSelector]) {
            searchActive = ((BOOL (*)(id, SEL))objc_msgSend)(searcher, searchActiveSelector);
        }
        if (searchActive) {
            @try {
                ((void (*)(id, SEL, BOOL, BOOL, id))objc_msgSend)(searcher, activeSelector,
                                                                 NO, NO, nil);
            } @catch (__unused NSException *exception) {
                closedThroughSearcher = NO;
            }
        }
    }
    SEL finishSelector = NSSelectorFromString(@"finishSearch");
    if (!closedThroughSearcher && [helper respondsToSelector:finishSelector]) {
        @try {
            ((void (*)(id, SEL))objc_msgSend)(helper, finishSelector);
        } @catch (__unused NSException *exception) {
        }
    }
    __weak BaseMsgContentViewController *weakController = controller;
    __weak id weakSearcher = searcher;
    for (NSNumber *delay in @[@0.0, @0.12, @0.35]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BaseMsgContentViewController *strongController = weakController;
            id strongSearcher = weakSearcher;
            if (strongController && strongSearcher) {
                WCAtlasHideOfficialChatSearchChrome(strongController, strongSearcher);
            }
        });
    }
    WCAtlasSetChatSearchInteractivePop(controller, YES);
    objc_setAssociatedObject(controller, &WCAtlasChatSearchTransitionKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasChatSearchActiveKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasChatSearchCleanupKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL WCAtlasOpenOfficialChatSearch(BaseMsgContentViewController *controller, id sender) {
    (void)sender;
    id searchHost = WCAtlasOfficialChatSearchHost(controller);
    if (!searchHost) return NO;

    // WCRefine reuses WeChat's controller-owned helper. Creating and retaining
    // another helper leaves two independent delegate/dismiss lifecycles and is
    // the source of the stale search bar and cancel-time crash.
    id helper = WCAtlasNativeChatSearchHelper(searchHost, YES);
    if (!helper) return NO;
    SEL panCancelSelector = NSSelectorFromString(@"setBUsePanCancelGesture:");
    if ([helper respondsToSelector:panCancelSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(helper, panCancelSelector, YES);
    }
    id searcher = WCAtlasNativeChatSearcher(helper);

    WCAtlasSetOfficialChatSearchChromeHidden(searcher, NO);
    UIView *searchBar = WCAtlasTweakSafeValue(searcher, @"searchBar");
    if ([searchBar isKindOfClass:UIView.class]) {
        searchBar.hidden = NO;
        searchBar.alpha = 1.0;
        searchBar.userInteractionEnabled = YES;
        UIView *ancestor = searchBar.superview;
        for (NSUInteger depth = 0; ancestor && depth < 3; depth++) {
            if (ancestor == controller.view || ancestor == controller.navigationController.view) break;
            ancestor.hidden = NO;
            ancestor.alpha = 1.0;
            ancestor.userInteractionEnabled = YES;
            ancestor = ancestor.superview;
        }
    }

    SEL pushSelector = NSSelectorFromString(@"pushSearchControllerWithCompletion:");
    SEL activeSelector = NSSelectorFromString(@"setActive:animated:completion:");
    if (![searcher respondsToSelector:pushSelector] &&
        ![searcher respondsToSelector:activeSelector]) return NO;
    if (objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalLeftItemsKey)) {
        objc_setAssociatedObject(controller, &WCAtlasChatSearchTransitionKey,
                                 @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasRestoreChatTopBar(controller);
    }
    WCAtlasSetChatSearchInteractivePop(controller, NO);
    objc_setAssociatedObject(controller, &WCAtlasChatSearchActiveKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc]
        initWithTarget:controller action:@selector(wcatlas_handleChatSearchEdgePan:)];
    edgePan.edges = UIRectEdgeLeft;
    [controller.view addGestureRecognizer:edgePan];
    objc_setAssociatedObject(controller, &WCAtlasChatSearchEdgePanKey, edgePan,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        if ([searcher respondsToSelector:pushSelector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(searcher, pushSelector, nil);
        } else {
            ((void (*)(id, SEL, BOOL, BOOL, id))objc_msgSend)(searcher, activeSelector,
                                                             YES, NO, nil);
        }
    } @catch (__unused NSException *exception) {
        WCAtlasCleanupOfficialChatSearch(controller);
        return NO;
    }
    return YES;
}

static UIImage *WCAtlasChatSearchImage(void) {
    UIImage *image = [UIImage imageNamed:@"icons_outlined_search"];
    return image ?: [UIImage systemImageNamed:@"magnifyingglass"];
}

static UIImage *WCAtlasChatCapsuleSearchImage(void) {
    UIImage *image = WCAtlasChatSearchImage();
    if (!image) return nil;
    CGSize size = CGSizeMake(18.0, 18.0);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *resized = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        [image drawInRect:(CGRect){CGPointZero, size}];
    }];
    return [resized imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIBarButtonItem *WCAtlasOfficialChatSearchBarButton(BaseMsgContentViewController *controller) {
    Class utilityClass = NSClassFromString(@"MMUICommonUtil");
    SEL factorySelector = NSSelectorFromString(@"getBarButtonWithImageName:target:action:style:accessibility:");
    Method factoryMethod = utilityClass ? class_getClassMethod(utilityClass, factorySelector) : NULL;
    if (factoryMethod && method_getNumberOfArguments(factoryMethod) == 7 &&
        WCAtlasMethodReturnsObject(factoryMethod) &&
        WCAtlasMethodArgumentIsObject(factoryMethod, 2) &&
        WCAtlasMethodArgumentIsObject(factoryMethod, 3) &&
        WCAtlasMethodArgumentIsSelector(factoryMethod, 4) &&
        WCAtlasMethodArgumentIsIntegerScalar(factoryMethod, 5) &&
        WCAtlasMethodArgumentIsObject(factoryMethod, 6)) {
        id item = ((id (*)(id, SEL, id, id, SEL, NSInteger, id))objc_msgSend)(
            utilityClass, factorySelector, @"icons_outlined_search", controller,
            @selector(wcatlas_openChatSearch:), 2, @"search");
        if ([item isKindOfClass:[UIBarButtonItem class]]) return item;
    }
    return [[UIBarButtonItem alloc] initWithImage:WCAtlasChatSearchImage()
                                            style:UIBarButtonItemStylePlain
                                           target:controller
                                           action:@selector(wcatlas_openChatSearch:)];
}

static UIBarButtonItem *WCAtlasChatTopCapsuleItem(BaseMsgContentViewController *controller,
                                                UIBarButtonItem *moreItem) {
    if (!moreItem) return nil;
    UIView *content = nil;
    CGFloat capsuleHeight = MAX(36.0, WCAtlasChatTopLeftCapsuleHeight() - 2.0);
    UIView *capsule = WCAtlasChatTopGlassContainer(capsuleHeight / 2.0, &content);

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    [content addSubview:stack];

    UIImage *moreImage = moreItem.image ?: [UIImage systemImageNamed:@"ellipsis"];
    UIButton *more = WCAtlasChatTopCapsuleButton(moreImage, moreItem.accessibilityLabel ?: @"更多");
    WCAtlasBarButtonActionProxy *proxy = [WCAtlasBarButtonActionProxy new];
    proxy.originalItem = moreItem;
    objc_setAssociatedObject(controller, &WCAtlasChatTopMoreProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [more addTarget:proxy action:@selector(invoke:) forControlEvents:UIControlEventTouchUpInside];
    if (moreItem.menu) {
        more.menu = moreItem.menu;
        more.showsMenuAsPrimaryAction = YES;
    }
    BOOL includesSearch = WCAtlasEnhancementEnabled(WCAtlasChatSearchButtonEnabledKey);
    if (includesSearch) {
        UIButton *search = WCAtlasChatTopCapsuleButton(WCAtlasChatCapsuleSearchImage(), @"搜索聊天记录");
        [search addTarget:controller action:@selector(wcatlas_openChatSearch:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:search];
    }
    [stack addArrangedSubview:more];
    [NSLayoutConstraint activateConstraints:@[
        [capsule.widthAnchor constraintEqualToConstant:includesSearch ? 76.0 : 40.0],
        [capsule.heightAnchor constraintEqualToConstant:capsuleHeight],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    ]];
    return [[UIBarButtonItem alloc] initWithCustomView:capsule];
}

static UINavigationBarAppearance *WCAtlasTransparentChatTopAppearance(void) {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.backgroundEffect = nil;
    appearance.shadowColor = UIColor.clearColor;
    return appearance;
}

static void WCAtlasApplyTransparentChatTopAppearance(BaseMsgContentViewController *controller) {
    UINavigationItem *navigationItem = controller.navigationItem;
    UINavigationBarAppearance *appearance = WCAtlasTransparentChatTopAppearance();
    navigationItem.standardAppearance = appearance;
    navigationItem.compactAppearance = appearance;
    navigationItem.scrollEdgeAppearance = appearance;
    if (@available(iOS 15.0, *)) navigationItem.compactScrollEdgeAppearance = appearance;

    UINavigationBar *navigationBar = controller.navigationController.navigationBar;
    if (navigationBar) {
        navigationBar.standardAppearance = appearance;
        navigationBar.compactAppearance = appearance;
        navigationBar.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) navigationBar.compactScrollEdgeAppearance = appearance;
        navigationBar.translucent = YES;
    }
    controller.edgesForExtendedLayout |= UIRectEdgeTop;
    controller.extendedLayoutIncludesOpaqueBars = YES;
}

static BOOL WCAtlasIsNavigationBarBackgroundView(UIView *view) {
    if (objc_getAssociatedObject(view, &WCAtlasChatTopGlassEffectMarkerKey)) return NO;
    NSString *className = NSStringFromClass(view.class);
    return [view isKindOfClass:[UIVisualEffectView class]] ||
           [className containsString:@"Background"] ||
           [className containsString:@"Backdrop"] ||
           [className containsString:@"Material"];
}

static BOOL WCAtlasViewContainsChatTopContent(UIView *view) {
    if (!view) return NO;
    if (objc_getAssociatedObject(view, &WCAtlasChatTopGlassEffectMarkerKey)) return YES;
    NSString *className = NSStringFromClass(view.class);
    if ([className containsString:@"ContentView"] || [className containsString:@"BarContent"]) return YES;
    for (UIView *subview in view.subviews) {
        if (WCAtlasViewContainsChatTopContent(subview)) return YES;
    }
    return NO;
}

static UIView *WCAtlasFirstDescendantOfClass(UIView *view, Class targetClass) {
    if (!view || !targetClass) return nil;
    if ([view isKindOfClass:targetClass]) return view;
    for (UIView *subview in view.subviews) {
        UIView *match = WCAtlasFirstDescendantOfClass(subview, targetClass);
        if (match) return match;
    }
    return nil;
}

static BOOL WCAtlasViewContainsVisualEffect(UIView *view) {
    if (!view) return NO;
    if ([view isKindOfClass:[UIVisualEffectView class]]) return YES;
    for (UIView *subview in view.subviews) {
        if (WCAtlasViewContainsVisualEffect(subview)) return YES;
    }
    return NO;
}

static void WCAtlasSetChatNavigationBackgroundHidden(UIView *view, BOOL hidden) {
    if (!view) return;
    if (objc_getAssociatedObject(view, &WCAtlasChatTopGlassEffectMarkerKey)) return;
    if (WCAtlasIsNavigationBarBackgroundView(view)) {
        NSNumber *originalAlpha = objc_getAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalAlphaKey);
        NSNumber *originalHidden = objc_getAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalHiddenKey);
        if (hidden) {
            if (!originalAlpha) {
                objc_setAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalAlphaKey,
                                         @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalHiddenKey,
                                         @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            view.hidden = YES;
            view.alpha = 0.0;
        } else if (originalAlpha) {
            view.alpha = originalAlpha.doubleValue;
            view.hidden = originalHidden.boolValue;
            objc_setAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalAlphaKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &WCAtlasChatTopBackgroundOriginalHiddenKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    for (UIView *subview in view.subviews) {
        WCAtlasSetChatNavigationBackgroundHidden(subview, hidden);
    }
}

static void WCAtlasSetChatNavigationDirectBackgroundsHidden(UINavigationBar *navigationBar, BOOL hidden) {
    if (!navigationBar) return;
    for (UIView *subview in navigationBar.subviews) {
        if (WCAtlasViewContainsChatTopContent(subview)) continue;
        NSNumber *originalAlpha = objc_getAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalAlphaKey);
        NSNumber *originalHidden = objc_getAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalHiddenKey);
        if (hidden) {
            if (!originalAlpha) {
                objc_setAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalAlphaKey,
                                         @(subview.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalHiddenKey,
                                         @(subview.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            subview.hidden = YES;
            subview.alpha = 0.0;
        } else if (originalAlpha) {
            subview.alpha = originalAlpha.doubleValue;
            subview.hidden = originalHidden.boolValue;
            objc_setAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalAlphaKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(subview, &WCAtlasChatTopBackgroundOriginalHiddenKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

static void WCAtlasSetChatNavigationHostTransparent(UIView *hostView, BOOL transparent);
static void WCAtlasSetChatNavigationContainerClear(UIView *view, BOOL clear);

static void WCAtlasSetChatTopFadeMask(UIView *backgroundView, BOOL enabled) {
    if (!backgroundView) return;
    id originalMask = objc_getAssociatedObject(backgroundView, &WCAtlasChatTopOriginalBackgroundMaskKey);
    if (enabled) {
        if (!originalMask) {
            objc_setAssociatedObject(backgroundView, &WCAtlasChatTopOriginalBackgroundMaskKey,
                                     backgroundView.layer.mask ?: NSNull.null,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CAGradientLayer *fadeMask = objc_getAssociatedObject(backgroundView, &WCAtlasChatTopFadeBackgroundMaskKey);
        if (!fadeMask) {
            fadeMask = [CAGradientLayer layer];
            fadeMask.startPoint = CGPointMake(0.5, 0.0);
            fadeMask.endPoint = CGPointMake(0.5, 1.0);
            fadeMask.colors = @[(id)UIColor.blackColor.CGColor,
                                (id)[UIColor.blackColor colorWithAlphaComponent:0.55].CGColor,
                                (id)[UIColor.blackColor colorWithAlphaComponent:0.18].CGColor,
                                (id)[UIColor.blackColor colorWithAlphaComponent:0.04].CGColor,
                                (id)UIColor.clearColor.CGColor,
                                (id)UIColor.clearColor.CGColor];
            fadeMask.locations = @[@0.0, @0.15, @0.30, @0.40, @0.45, @1.0];
            objc_setAssociatedObject(backgroundView, &WCAtlasChatTopFadeBackgroundMaskKey,
                                     fadeMask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        fadeMask.frame = backgroundView.bounds;
        backgroundView.layer.mask = fadeMask;
    } else if (originalMask) {
        backgroundView.layer.mask = originalMask == NSNull.null ? nil : originalMask;
        objc_setAssociatedObject(backgroundView, &WCAtlasChatTopOriginalBackgroundMaskKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(backgroundView, &WCAtlasChatTopFadeBackgroundMaskKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasSetVisualEffectsTopFade(UIView *view, BOOL enabled) {
    if (!view) return;
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *effectView = (UIVisualEffectView *)view;
        id originalEffect = objc_getAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectKey);
        id originalMask = objc_getAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectMaskKey);
        if (enabled) {
            if (!originalEffect) {
                objc_setAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectKey,
                                         effectView.effect ?: NSNull.null,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectMaskKey,
                                         effectView.layer.mask ?: NSNull.null,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (!effectView.effect) {
                effectView.effect = originalEffect && originalEffect != NSNull.null
                    ? originalEffect
                    : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
            }
            effectView.layer.mask = originalMask == NSNull.null ? nil : originalMask;
            WCAtlasSetChatNavigationContainerClear(effectView, YES);
        } else if (originalEffect) {
            effectView.effect = originalEffect == NSNull.null ? nil : originalEffect;
            effectView.layer.mask = originalMask == NSNull.null ? nil : originalMask;
            WCAtlasSetChatNavigationContainerClear(effectView, NO);
            objc_setAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(effectView, &WCAtlasChatTopOriginalVisualEffectMaskKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    for (UIView *subview in view.subviews) {
        WCAtlasSetVisualEffectsTopFade(subview, enabled);
    }
}

static void WCAtlasSetChatContentNavigationBackgroundTransparent(BaseMsgContentViewController *controller,
                                                                BOOL transparent) {
    UIView *contentNavigationBar = objc_getAssociatedObject(controller, &WCAtlasChatTopContentNavigationBarKey);
    if (transparent && (!contentNavigationBar || !contentNavigationBar.superview)) {
        Class contentNavigationBarClass = NSClassFromString(@"MMNewMsgContentNavBar");
        contentNavigationBar = WCAtlasFirstDescendantOfClass(controller.view, contentNavigationBarClass);
        if (!contentNavigationBar) {
            contentNavigationBarClass = NSClassFromString(@"MMMsgContentNavBar");
            contentNavigationBar = WCAtlasFirstDescendantOfClass(controller.view, contentNavigationBarClass);
        }
        if (contentNavigationBar) {
            objc_setAssociatedObject(controller, &WCAtlasChatTopContentNavigationBarKey,
                                     contentNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    if (!contentNavigationBar) return;
    WCAtlasSetChatNavigationHostTransparent(contentNavigationBar, transparent);
    WCAtlasSetChatNavigationContainerClear(contentNavigationBar, transparent);
    for (UIView *subview in contentNavigationBar.subviews) {
        BOOL fillsTopBar = CGRectGetWidth(subview.bounds) >= CGRectGetWidth(contentNavigationBar.bounds) - 1.0 &&
                           CGRectGetHeight(subview.bounds) >= CGRectGetHeight(contentNavigationBar.bounds) - 1.0;
        if (fillsTopBar && WCAtlasViewContainsVisualEffect(subview)) {
            WCAtlasSetChatNavigationContainerClear(subview, transparent);
            WCAtlasSetVisualEffectsTopFade(subview, transparent);
            WCAtlasSetChatTopFadeMask(subview, transparent);
            for (UIView *backgroundSubview in subview.subviews) {
                if (CGRectGetHeight(backgroundSubview.bounds) <= 1.0) {
                    WCAtlasSetChatNavigationContainerClear(backgroundSubview, transparent);
                    WCAtlasSetChatNavigationBackgroundHidden(backgroundSubview, transparent);
                }
            }
        }
    }
    if (!transparent) {
        objc_setAssociatedObject(controller, &WCAtlasChatTopContentNavigationBarKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasSetChatNavigationHostTransparent(UIView *hostView, BOOL transparent) {
    if (!hostView) return;
    NSNumber *originalClips = objc_getAssociatedObject(hostView, &WCAtlasChatTopOriginalClipsToBoundsKey);
    NSNumber *originalBorder = objc_getAssociatedObject(hostView, &WCAtlasChatTopOriginalBorderWidthKey);
    NSNumber *originalCorner = objc_getAssociatedObject(hostView, &WCAtlasChatTopOriginalCornerRadiusKey);
    if (transparent) {
        if (!originalClips) {
            objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalClipsToBoundsKey,
                                     @(hostView.clipsToBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalBorderWidthKey,
                                     @(hostView.layer.borderWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalCornerRadiusKey,
                                     @(hostView.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        hostView.clipsToBounds = NO;
        hostView.layer.borderWidth = 0.0;
        hostView.layer.cornerRadius = 0.0;
    } else if (originalClips) {
        hostView.clipsToBounds = originalClips.boolValue;
        hostView.layer.borderWidth = originalBorder.doubleValue;
        hostView.layer.cornerRadius = originalCorner.doubleValue;
        objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalClipsToBoundsKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalBorderWidthKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(hostView, &WCAtlasChatTopOriginalCornerRadiusKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasSetChatNavigationContainerClear(UIView *view, BOOL clear) {
    if (!view) return;
    id originalColor = objc_getAssociatedObject(view, &WCAtlasChatTopContainerOriginalBackgroundColorKey);
    if (clear) {
        if (!originalColor) {
            objc_setAssociatedObject(view, &WCAtlasChatTopContainerOriginalBackgroundColorKey,
                                     view.backgroundColor ?: NSNull.null,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        view.backgroundColor = UIColor.clearColor;
    } else if (originalColor) {
        view.backgroundColor = originalColor == NSNull.null ? nil : originalColor;
        objc_setAssociatedObject(view, &WCAtlasChatTopContainerOriginalBackgroundColorKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasApplyChatNavigationBackgroundWithNavigation(BaseMsgContentViewController *controller,
                                                              UINavigationController *navigationController,
                                                              BOOL hidden) {
    WCAtlasSetChatContentNavigationBackgroundTransparent(controller, hidden);
    UINavigationBar *navigationBar = navigationController.navigationBar;
    WCAtlasSetChatNavigationHostTransparent(navigationBar, hidden);
    WCAtlasSetChatNavigationHostTransparent(navigationBar.superview, hidden);
    WCAtlasSetChatNavigationBackgroundHidden(navigationBar, hidden);
    WCAtlasSetChatNavigationDirectBackgroundsHidden(navigationBar, hidden);
    UIView *navigationRoot = navigationController.view;
    UIView *view = navigationBar;
    for (NSUInteger depth = 0; view && depth < 4; depth++, view = view.superview) {
        WCAtlasSetChatNavigationContainerClear(view, hidden);
        for (UIView *sibling in view.superview.subviews) {
            if (sibling != view && WCAtlasIsNavigationBarBackgroundView(sibling)) {
                WCAtlasSetChatNavigationBackgroundHidden(sibling, hidden);
            }
        }
        if (view == navigationRoot) break;
    }
}

static void WCAtlasApplyChatNavigationBackground(BaseMsgContentViewController *controller, BOOL hidden) {
    WCAtlasApplyChatNavigationBackgroundWithNavigation(controller,
                                                     controller.navigationController,
                                                     hidden);
}

static void WCAtlasRestoreChatNavigationPresentationWithNavigation(BaseMsgContentViewController *controller,
                                                                  UINavigationController *navigationController) {
    UINavigationBar *navigationBar = navigationController.navigationBar;
    id standardAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationStandardAppearanceKey);
    id compactAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationCompactAppearanceKey);
    id scrollEdgeAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationScrollEdgeAppearanceKey);
    id compactScrollEdgeAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationCompactScrollEdgeAppearanceKey);
    NSNumber *translucent = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationTranslucentKey);
    if (navigationBar && standardAppearance) {
        navigationBar.standardAppearance = standardAppearance == NSNull.null ? nil : standardAppearance;
        navigationBar.compactAppearance = compactAppearance == NSNull.null ? nil : compactAppearance;
        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance == NSNull.null ? nil : scrollEdgeAppearance;
        if (@available(iOS 15.0, *)) {
            navigationBar.compactScrollEdgeAppearance = compactScrollEdgeAppearance == NSNull.null ? nil : compactScrollEdgeAppearance;
        }
        navigationBar.translucent = translucent.boolValue;
    }
    NSNumber *edges = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalEdgesForExtendedLayoutKey);
    NSNumber *includesOpaqueBars = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalExtendedLayoutIncludesOpaqueBarsKey);
    if (edges) controller.edgesForExtendedLayout = (UIRectEdge)edges.unsignedIntegerValue;
    if (includesOpaqueBars) controller.extendedLayoutIncludesOpaqueBars = includesOpaqueBars.boolValue;
    WCAtlasApplyChatNavigationBackgroundWithNavigation(controller, navigationController, NO);
}

static void WCAtlasRestoreChatNavigationPresentation(BaseMsgContentViewController *controller) {
    WCAtlasRestoreChatNavigationPresentationWithNavigation(controller,
                                                         controller.navigationController);
}

static UIBarButtonItem *WCAtlasNativeChatMoreItem(BaseMsgContentViewController *controller) {
    SEL selector = NSSelectorFromString(@"getRightBarButton");
    if ([controller respondsToSelector:selector]) {
        @try {
            id item = ((id (*)(id, SEL))objc_msgSend)(controller, selector);
            if ([item isKindOfClass:[UIBarButtonItem class]]) return item;
        } @catch (__unused NSException *exception) {
        }
    }
    UIBarButtonItem *installed = objc_getAssociatedObject(controller, &WCAtlasChatTopCapsuleItemKey);
    for (UIBarButtonItem *item in controller.navigationItem.rightBarButtonItems) {
        if (item != installed) return item;
    }
    NSArray *original = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalRightItemsKey);
    return original.firstObject;
}

static void WCAtlasRemoveStandaloneChatSearchButton(BaseMsgContentViewController *controller) {
    UIBarButtonItem *searchItem = objc_getAssociatedObject(controller, &WCAtlasChatSearchItemKey);
    if (!searchItem) return;
    NSMutableArray *rightItems = [controller.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    [rightItems removeObjectIdenticalTo:searchItem];
    controller.navigationItem.rightBarButtonItems = rightItems;
    objc_setAssociatedObject(controller, &WCAtlasChatSearchItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasUpdateStandaloneChatSearchButton(BaseMsgContentViewController *controller) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatSearchButtonEnabledKey)) {
        WCAtlasRemoveStandaloneChatSearchButton(controller);
        return;
    }
    UIBarButtonItem *installed = objc_getAssociatedObject(controller, &WCAtlasChatSearchItemKey);
    NSArray *currentItems = controller.navigationItem.rightBarButtonItems ?: @[];
    if (installed && [currentItems containsObject:installed]) return;

    NSMutableArray *rightItems = [currentItems mutableCopy] ?: [NSMutableArray array];
    if (installed) [rightItems removeObjectIdenticalTo:installed];
    UIBarButtonItem *searchItem = WCAtlasOfficialChatSearchBarButton(controller);
    if (!searchItem) return;
    [rightItems addObject:searchItem];
    controller.navigationItem.rightBarButtonItems = rightItems;
    objc_setAssociatedObject(controller, &WCAtlasChatSearchItemKey,
                             searchItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasCaptureOriginalChatNavigationPresentationIfNeeded(BaseMsgContentViewController *controller) {
    UINavigationBar *navigationBar = controller.navigationController.navigationBar;
    if (navigationBar &&
        !objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationStandardAppearanceKey)) {
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationStandardAppearanceKey,
                                 navigationBar.standardAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationCompactAppearanceKey,
                                 navigationBar.compactAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationScrollEdgeAppearanceKey,
                                 navigationBar.scrollEdgeAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (@available(iOS 15.0, *)) {
            objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationCompactScrollEdgeAppearanceKey,
                                     navigationBar.compactScrollEdgeAppearance ?: NSNull.null,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalNavigationTranslucentKey,
                                 @(navigationBar.translucent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalEdgesForExtendedLayoutKey)) {
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalEdgesForExtendedLayoutKey,
                                 @((NSUInteger)controller.edgesForExtendedLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalExtendedLayoutIncludesOpaqueBarsKey,
                                 @(controller.extendedLayoutIncludesOpaqueBars), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasRestoreChatTopBar(BaseMsgContentViewController *controller) {
    NSArray *originalLeft = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalLeftItemsKey);
    if (!originalLeft) return;
    NSArray *originalRight = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalRightItemsKey) ?: @[];
    id originalTitleView = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalTitleViewKey);
    NSNumber *originalSupplement = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalSupplementKey);
    controller.navigationItem.leftBarButtonItems = originalLeft;
    controller.navigationItem.rightBarButtonItems = originalRight;
    controller.navigationItem.titleView = originalTitleView == NSNull.null ? nil : originalTitleView;
    controller.navigationItem.leftItemsSupplementBackButton = originalSupplement.boolValue;
    id standardAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalStandardAppearanceKey);
    id compactAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalCompactAppearanceKey);
    id scrollEdgeAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalScrollEdgeAppearanceKey);
    id compactScrollEdgeAppearance = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalCompactScrollEdgeAppearanceKey);
    controller.navigationItem.standardAppearance = standardAppearance == NSNull.null ? nil : standardAppearance;
    controller.navigationItem.compactAppearance = compactAppearance == NSNull.null ? nil : compactAppearance;
    controller.navigationItem.scrollEdgeAppearance = scrollEdgeAppearance == NSNull.null ? nil : scrollEdgeAppearance;
    if (@available(iOS 15.0, *)) {
        controller.navigationItem.compactScrollEdgeAppearance = compactScrollEdgeAppearance == NSNull.null ? nil : compactScrollEdgeAppearance;
    }
    WCAtlasRestoreChatNavigationPresentation(controller);
    const void *keys[] = {&WCAtlasChatTopProfileItemKey, &WCAtlasChatTopCapsuleItemKey,
                          &WCAtlasChatTopOriginalLeftItemsKey, &WCAtlasChatTopOriginalRightItemsKey,
                          &WCAtlasChatTopOriginalTitleViewKey, &WCAtlasChatTopOriginalSupplementKey,
                          &WCAtlasChatTopMoreProxyKey, &WCAtlasChatTopBackProxyKey,
                          &WCAtlasChatTopOriginalStandardAppearanceKey,
                          &WCAtlasChatTopOriginalCompactAppearanceKey,
                          &WCAtlasChatTopOriginalScrollEdgeAppearanceKey,
                          &WCAtlasChatTopOriginalCompactScrollEdgeAppearanceKey,
                          &WCAtlasChatTopPlaceholderTitleViewKey,
                          &WCAtlasChatTopOriginalNavigationStandardAppearanceKey,
                          &WCAtlasChatTopOriginalNavigationCompactAppearanceKey,
                          &WCAtlasChatTopOriginalNavigationScrollEdgeAppearanceKey,
                          &WCAtlasChatTopOriginalNavigationCompactScrollEdgeAppearanceKey,
                          &WCAtlasChatTopOriginalNavigationTranslucentKey,
                          &WCAtlasChatTopOriginalEdgesForExtendedLayoutKey,
                          &WCAtlasChatTopOriginalExtendedLayoutIncludesOpaqueBarsKey};
    for (NSUInteger index = 0; index < sizeof(keys) / sizeof(keys[0]); index++) {
        objc_setAssociatedObject(controller, keys[index], nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCAtlasUpdateChatTopBar(BaseMsgContentViewController *controller) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatTopBarCapsuleEnabledKey)) {
        WCAtlasRestoreChatTopBar(controller);
        WCAtlasUpdateStandaloneChatSearchButton(controller);
        return;
    }
    WCAtlasRemoveStandaloneChatSearchButton(controller);
    WCAtlasCaptureOriginalChatNavigationPresentationIfNeeded(controller);
    UINavigationItem *navigationItem = controller.navigationItem;
    NSArray *originalLeft = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalLeftItemsKey);
    if (!originalLeft) {
        originalLeft = navigationItem.leftBarButtonItems ?: @[];
        NSMutableArray *originalRight = [navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalLeftItemsKey, originalLeft, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalRightItemsKey, originalRight, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalTitleViewKey,
                                 navigationItem.titleView ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalSupplementKey,
                                 @(navigationItem.leftItemsSupplementBackButton), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalStandardAppearanceKey,
                                 navigationItem.standardAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalCompactAppearanceKey,
                                 navigationItem.compactAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalScrollEdgeAppearanceKey,
                                 navigationItem.scrollEdgeAppearance ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (@available(iOS 15.0, *)) {
            objc_setAssociatedObject(controller, &WCAtlasChatTopOriginalCompactScrollEdgeAppearanceKey,
                                     navigationItem.compactScrollEdgeAppearance ?: NSNull.null,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    NSArray<UIBarButtonItem *> *originalRight = objc_getAssociatedObject(controller, &WCAtlasChatTopOriginalRightItemsKey) ?: @[];
    UIBarButtonItem *moreItem = WCAtlasNativeChatMoreItem(controller) ?: originalRight.firstObject;
    NSArray *remainingRight = @[];

    UIBarButtonItem *backItem = originalLeft.firstObject;
    NSArray *remainingLeft = originalLeft.count > 1
        ? [originalLeft subarrayWithRange:NSMakeRange(1, originalLeft.count - 1)] : @[];
    UIBarButtonItem *profileItem = WCAtlasChatTopProfileItem(controller, backItem);
    NSMutableArray *leftItems = [NSMutableArray arrayWithObject:profileItem];
    [leftItems addObjectsFromArray:remainingLeft];
    navigationItem.leftItemsSupplementBackButton = NO;
    navigationItem.leftBarButtonItems = leftItems;
    UIView *placeholderTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    navigationItem.titleView = placeholderTitleView;
    objc_setAssociatedObject(controller, &WCAtlasChatTopPlaceholderTitleViewKey,
                             placeholderTitleView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasApplyTransparentChatTopAppearance(controller);
    WCAtlasApplyChatNavigationBackground(controller, YES);
    objc_setAssociatedObject(controller, &WCAtlasChatTopProfileItemKey, profileItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIBarButtonItem *capsuleItem = WCAtlasChatTopCapsuleItem(controller, moreItem);
    NSMutableArray *rightItems = [NSMutableArray array];
    if (capsuleItem) [rightItems addObject:capsuleItem];
    [rightItems addObjectsFromArray:remainingRight];
    navigationItem.rightBarButtonItems = rightItems;
    objc_setAssociatedObject(controller, &WCAtlasChatTopCapsuleItemKey, capsuleItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasRefreshChatTopBarAfterWechatUpdate(BaseMsgContentViewController *controller) {
    if (!WCAtlasEnhancementEnabled(WCAtlasChatTopBarCapsuleEnabledKey)) {
        WCAtlasUpdateStandaloneChatSearchButton(controller);
        return;
    }
    if (!controller.isViewLoaded || !controller.view.window) return;
    if (controller.navigationController.topViewController != controller) return;
    UIBarButtonItem *profileItem = objc_getAssociatedObject(controller, &WCAtlasChatTopProfileItemKey);
    UIBarButtonItem *capsuleItem = objc_getAssociatedObject(controller, &WCAtlasChatTopCapsuleItemKey);
    UIView *placeholderTitleView = objc_getAssociatedObject(controller, &WCAtlasChatTopPlaceholderTitleViewKey);
    BOOL profileMissing = !profileItem || ![controller.navigationItem.leftBarButtonItems containsObject:profileItem];
    BOOL capsuleMissing = capsuleItem && ![controller.navigationItem.rightBarButtonItems containsObject:capsuleItem];
    BOOL titleWasReplaced = !placeholderTitleView || controller.navigationItem.titleView != placeholderTitleView;
    if (profileMissing || capsuleMissing || titleWasReplaced) WCAtlasUpdateChatTopBar(controller);
    WCAtlasApplyTransparentChatTopAppearance(controller);
    WCAtlasApplyChatNavigationBackground(controller, YES);
}

static BOOL WCAtlasJumpToReferencedMessage(CommonMessageCellView *cell) {
    if (!WCAtlasEnhancementEnabled(WCAtlasQuoteJumpEnabledKey)) return NO;
    id viewModel = WCAtlasTweakValueForSelectorNames(cell, @[@"viewModel", @"_viewModel"]);
    id message = WCAtlasImageJokerMessageForObject(cell);
    if (!message) {
        message = WCAtlasTweakValueForSelectorNames(viewModel,
            @[@"messageWrap", @"getMessageWrap", @"getCurrentMessageWrap", @"msgWrap"]);
    }
    id referencedMessage = nil;
    for (id object in @[message ?: NSNull.null, viewModel ?: NSNull.null, cell]) {
        if (object == NSNull.null) continue;
        for (NSString *key in @[@"referHostMsg", @"referingMessageWrap", @"replyingMessageWrap"]) {
            referencedMessage = WCAtlasTweakSafeValue(object, key);
            if (referencedMessage) break;
        }
        if (referencedMessage) break;
    }
    if (!referencedMessage) return NO;
    UIViewController *controller = WCAtlasJokerPresenterForCell(cell) ?: WCAtlasVisibleChatController;
    for (NSString *selectorName in @[@"returnToOriginalMsg:", @"locateToMsg:"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([controller respondsToSelector:selector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, referencedMessage);
            WCAtlasCompatibilityMarkTriggered(@"quote-jump");
            return YES;
        }
    }
    if ([cell respondsToSelector:@selector(onReturnToOriginalMsg)]) {
        ((void (*)(id, SEL))objc_msgSend)(cell, @selector(onReturnToOriginalMsg));
        WCAtlasCompatibilityMarkTriggered(@"quote-jump");
        return YES;
    }
    return NO;
}

static void WCAtlasSetPinnedMessageDescendantBackgroundsClear(UIView *view,
                                                            UIView *glassView,
                                                            BOOL clear) {
    if (!view || view == glassView || [view isDescendantOfView:glassView]) return;
    id originalColor = objc_getAssociatedObject(view, &WCAtlasChatPinnedOriginalBackgroundColorKey);
    if (clear) {
        if (!originalColor) {
            objc_setAssociatedObject(view, &WCAtlasChatPinnedOriginalBackgroundColorKey,
                                     view.backgroundColor ?: NSNull.null,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        view.backgroundColor = UIColor.clearColor;
    } else if (originalColor) {
        view.backgroundColor = originalColor == NSNull.null ? nil : originalColor;
        objc_setAssociatedObject(view, &WCAtlasChatPinnedOriginalBackgroundColorKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIView *subview in view.subviews) {
        WCAtlasSetPinnedMessageDescendantBackgroundsClear(subview, glassView, clear);
    }
}

static void WCAtlasUpdatePinnedMessageGlass(UIView *tipsView) {
    if (!tipsView) return;
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasChatTopBarCapsuleEnabledKey);
    WCAtlasGlassCapsuleView *glassView = objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedBlurViewKey);
    if (!enabled) {
        WCAtlasSetPinnedMessageDescendantBackgroundsClear(tipsView, glassView, NO);
        NSNumber *shadowOpacity = objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOpacityKey);
        if (shadowOpacity) {
            tipsView.layer.shadowOpacity = shadowOpacity.floatValue;
            tipsView.layer.shadowRadius = [objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowRadiusKey) doubleValue];
            tipsView.layer.shadowOffset = [objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOffsetKey) CGSizeValue];
            id shadowColor = objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowColorKey);
            tipsView.layer.shadowColor = shadowColor == NSNull.null ? nil : (__bridge CGColorRef)shadowColor;
            tipsView.layer.borderWidth = [objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalBorderWidthKey) doubleValue];
            id borderColor = objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalBorderColorKey);
            tipsView.layer.borderColor = borderColor == NSNull.null ? nil : (__bridge CGColorRef)borderColor;
            objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOpacityKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [glassView removeFromSuperview];
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedBlurViewKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!objc_getAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOpacityKey)) {
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOpacityKey, @(tipsView.layer.shadowOpacity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowRadiusKey, @(tipsView.layer.shadowRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowOffsetKey, [NSValue valueWithCGSize:tipsView.layer.shadowOffset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalShadowColorKey, tipsView.layer.shadowColor ? (__bridge id)tipsView.layer.shadowColor : NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalBorderWidthKey, @(tipsView.layer.borderWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedOriginalBorderColorKey, tipsView.layer.borderColor ? (__bridge id)tipsView.layer.borderColor : NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    tipsView.layer.shadowOpacity = 0.0;
    tipsView.layer.shadowRadius = 0.0;
    tipsView.layer.shadowOffset = CGSizeZero;
    tipsView.layer.shadowColor = UIColor.clearColor.CGColor;
    tipsView.layer.borderWidth = 0.0;
    tipsView.layer.borderColor = UIColor.clearColor.CGColor;

    if (!glassView) {
        glassView = [WCAtlasGlassCapsuleView new];
        // This backdrop is positioned from MMMsgCommonTipsView's runtime bounds.
        // Keep it out of Auto Layout so an ambiguous constraint pass cannot
        // stretch it to the expanded pinned-message container.
        glassView.translatesAutoresizingMaskIntoConstraints = YES;
        glassView.userInteractionEnabled = NO;
        objc_setAssociatedObject(glassView, &WCAtlasChatTopGlassEffectMarkerKey,
                                 @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tipsView, &WCAtlasChatPinnedBlurViewKey,
                                 glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat blurIntensity = WCAtlasChatGlassPercent(WCAtlasChatGlassBlurIntensityKey,
                                                  100.0, 20.0, 100.0) / 100.0;
    // The pinned row has an expanding host view. Liquid highlight/rim layers
    // visually leak when that host changes height, so this row deliberately
    // stays on the stable frosted material regardless of the top-bar style.
    [glassView configureFrostedGlassWithBlurIntensity:blurIntensity];
    // MMMsgCommonTipsView expands its own bounds to host the pinned-message list.
    // The glass belongs only to the fixed header row; following the full height
    // makes the material spill over the conversation while that list is open.
    CGRect tipsBounds = tipsView.bounds;
    CGFloat glassHeight = MIN(CGRectGetHeight(tipsBounds), 40.0);
    glassView.frame = CGRectMake(CGRectGetMinX(tipsBounds) + 8.0,
                                CGRectGetMinY(tipsBounds),
                                MAX(0.0, CGRectGetWidth(tipsBounds) - 16.0),
                                glassHeight);
    glassView.capsuleCornerRadius = glassHeight * 0.5;
    glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    glassView.clipsToBounds = YES;
    glassView.layer.masksToBounds = YES;
    [glassView setNeedsLayout];
    [glassView layoutIfNeeded];
    if (glassView.superview != tipsView) {
        [tipsView insertSubview:glassView atIndex:0];
    } else {
        [tipsView sendSubviewToBack:glassView];
    }
    WCAtlasSetPinnedMessageDescendantBackgroundsClear(tipsView, glassView, YES);
}

static char WCAtlasRawContactIDKey;
static char WCAtlasProfileContactKey;
static char WCAtlasProfileIsGroupKey;
static char WCAtlasProfileChatRoomKey;
static char WCAtlasRawContactIDCellMarkerKey;
static char WCAtlasProfileMessageBlockCellMarkerKey;
static char WCAtlasProfileSendConfirmationCellMarkerKey;

static NSUInteger WCAtlasCallUnsignedSelector(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return 0;
    @try {
        return ((NSUInteger (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return 0;
    }
}

static id WCAtlasRawProfileValue(id object, NSArray<NSString *> *names) {
    if (!object) return nil;
    id value = WCAtlasTweakValueForSelectorNames(object, names);
    if (value) return value;
    for (NSString *name in names) {
        value = WCAtlasTweakSafeValue(object, name);
        if (value) return value;
    }
    return nil;
}

static NSArray *WCAtlasTableSections(id tableInfo) {
    if ([tableInfo isKindOfClass:NSArray.class]) return tableInfo;
    id sections = WCAtlasRawProfileValue(tableInfo,
                                       @[@"sections", @"m_arrSections", @"sectionArray", @"allSections"]);
    return [sections isKindOfClass:NSArray.class] ? sections : nil;
}

static id WCAtlasTableSectionAtIndex(id tableInfo, NSUInteger index) {
    for (NSString *name in @[@"getSectionAt:", @"sectionAtIndex:"]) {
        SEL selector = NSSelectorFromString(name);
        if (!tableInfo || ![tableInfo respondsToSelector:selector]) continue;
        @try {
            id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(tableInfo, selector, index);
            if (section) return section;
        } @catch (__unused NSException *exception) {
        }
    }
    NSArray *sections = WCAtlasTableSections(tableInfo);
    return index < sections.count ? sections[index] : nil;
}

static NSArray *WCAtlasTableCells(id section) {
    id cells = WCAtlasRawProfileValue(section,
                                    @[@"getAllCells", @"cells", @"m_arrCells", @"cellArray", @"allCells"]);
    return [cells isKindOfClass:NSArray.class] ? cells : nil;
}

static id WCAtlasTableCellAtIndex(id section, NSUInteger index) {
    for (NSString *name in @[@"getCellAt:", @"cellAtIndex:"]) {
        SEL selector = NSSelectorFromString(name);
        if (![section respondsToSelector:selector]) continue;
        @try {
            return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(section, selector, index);
        } @catch (__unused NSException *exception) {
        }
    }
    NSArray *cells = WCAtlasTableCells(section);
    return [cells isKindOfClass:NSArray.class] && index < cells.count ? cells[index] : nil;
}

static NSUInteger WCAtlasTableCellCount(id section) {
    for (NSString *name in @[@"getCellCount", @"cellCount"]) {
        SEL selector = NSSelectorFromString(name);
        if (![section respondsToSelector:selector]) continue;
        @try {
            return ((NSUInteger (*)(id, SEL))objc_msgSend)(section, selector);
        } @catch (__unused NSException *exception) {
        }
    }
    NSArray *cells = WCAtlasTableCells(section);
    return [cells isKindOfClass:NSArray.class] ? cells.count : 0;
}

static NSString *WCAtlasTableCellTitle(id cell) {
    id title = WCAtlasRawProfileValue(cell, @[@"title", @"m_title", @"leftTitle", @"text"]);
    if ([title isKindOfClass:NSString.class]) return title;
    UILabel *label = WCAtlasRawProfileValue(cell, @[@"titleLabel", @"m_titleLabel", @"leftLabel"]);
    if ([label isKindOfClass:UILabel.class]) return label.text;

    // Newer WeChat table cells keep their visible title in
    // cellConfig.leftConfig.title instead of exposing it on the cell itself.
    id cellConfig = WCAtlasRawProfileValue(cell, @[@"cellConfig", @"m_cellConfig"]);
    id leftConfig = WCAtlasRawProfileValue(cellConfig, @[@"leftConfig", @"m_leftConfig"]);
    title = WCAtlasRawProfileValue(leftConfig, @[@"title", @"text"]);
    return [title isKindOfClass:NSString.class] ? title : nil;
}

static void WCAtlasCollectLabels(UIView *view, NSMutableArray<UILabel *> *labels) {
    if ([view isKindOfClass:UILabel.class] && [(UILabel *)view text].length > 0) {
        [labels addObject:(UILabel *)view];
    }
    for (UIView *subview in view.subviews) WCAtlasCollectLabels(subview, labels);
}

static NSString *WCAtlasTableCellLeftmostText(id cell) {
    if (![cell isKindOfClass:UIView.class]) return nil;
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    WCAtlasCollectLabels(cell, labels);
    UILabel *leftmost = nil;
    for (UILabel *label in labels) {
        if (!leftmost || CGRectGetMinX(label.frame) < CGRectGetMinX(leftmost.frame)) leftmost = label;
    }
    return leftmost.text;
}

static NSString *WCAtlasTableCellRightText(id cell, NSString *title) {
    for (NSString *name in @[@"rightValue", @"m_rightValue", @"detail", @"value", @"rightText"]) {
        id value = WCAtlasRawProfileValue(cell, @[name]);
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![value isEqualToString:title]) return value;
    }
    for (NSString *name in @[@"detailTextLabel", @"rightLabel", @"m_rightLabel", @"valueLabel"]) {
        UILabel *label = WCAtlasRawProfileValue(cell, @[name]);
        if ([label isKindOfClass:UILabel.class] && label.text.length > 0 && ![label.text isEqualToString:title]) return label.text;
    }
    id cellConfig = WCAtlasRawProfileValue(cell, @[@"cellConfig", @"m_cellConfig"]);
    id rightConfig = WCAtlasRawProfileValue(cellConfig, @[@"rightConfig", @"m_rightConfig"]);
    id configured = WCAtlasRawProfileValue(rightConfig, @[@"title", @"text", @"value"]);
    if ([configured isKindOfClass:NSString.class] && [configured length] > 0 && ![configured isEqualToString:title]) return configured;
    if ([cell isKindOfClass:UIView.class]) {
        NSMutableArray<UILabel *> *labels = [NSMutableArray array];
        WCAtlasCollectLabels(cell, labels);
        UILabel *rightmost = nil;
        for (UILabel *label in labels) {
            if ([label.text isEqualToString:title]) continue;
            if (!rightmost || CGRectGetMinX(label.frame) > CGRectGetMinX(rightmost.frame)) rightmost = label;
        }
        if (rightmost.text.length > 0) return rightmost.text;
    }
    return nil;
}

static NSString *WCAtlasAdditionDaysValue(NSString *title, NSString *value) {
    if (![title containsString:@"添加时间"] || value.length == 0) return nil;
    NSArray<NSDictionary *> *formats = @[
        @{ @"format": @"yyyy年M月d日 HH:mm:ss", @"approximate": @NO },
        @{ @"format": @"yyyy年M月d日 HH:mm", @"approximate": @NO },
        @{ @"format": @"yyyy年M月d日", @"approximate": @NO },
        @{ @"format": @"yyyy-MM-dd HH:mm:ss", @"approximate": @NO },
        @{ @"format": @"yyyy-MM-dd HH:mm", @"approximate": @NO },
        @{ @"format": @"yyyy-MM-dd", @"approximate": @NO },
        @{ @"format": @"yyyy/MM/dd HH:mm:ss", @"approximate": @NO },
        @{ @"format": @"yyyy/MM/dd HH:mm", @"approximate": @NO },
        @{ @"format": @"yyyy/MM/dd", @"approximate": @NO },
        @{ @"format": @"yyyy年M月", @"approximate": @YES },
        @{ @"format": @"yyyy-MM", @"approximate": @YES },
        @{ @"format": @"yyyy/MM", @"approximate": @YES },
    ];
    NSDate *date = nil;
    BOOL approximate = NO;
    for (NSDictionary *entry in formats) {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        formatter.timeZone = NSTimeZone.localTimeZone;
        formatter.dateFormat = entry[@"format"];
        formatter.lenient = NO;
        date = [formatter dateFromString:value];
        if (date) {
            approximate = [entry[@"approximate"] boolValue];
            break;
        }
    }
    if (!date) return nil;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    if (approximate) date = [calendar dateByAddingUnit:NSCalendarUnitDay value:14 toDate:date options:0] ?: date;
    NSDate *start = [calendar startOfDayForDate:date];
    NSDate *today = [calendar startOfDayForDate:NSDate.date];
    NSInteger days = [calendar components:NSCalendarUnitDay fromDate:start toDate:today options:0].day;
    if (days < 0) return nil;
    return [NSString stringWithFormat:@"%@%ld 天", approximate ? @"约 " : @"", (long)days];
}

static uint32_t WCAtlasContactAddTime(id contact) {
    if (!contact) return 0;
    // WCPulse 1.7-2 hooks the official profile row and reads m_uiAddCreateTime.
    // Prefer that server-populated value; retain the local field only as a
    // compatibility fallback for host versions that do not expose it.
    for (NSString *name in @[@"m_uiAddCreateTime", @"m_uiLocalAddContactTime"]) {
        SEL selector = NSSelectorFromString(name);
        if (![contact respondsToSelector:selector]) continue;
        @try {
            uint32_t value = ((uint32_t (*)(id, SEL))objc_msgSend)(contact, selector);
            if (value > 0) return value;
        } @catch (__unused NSException *exception) {}
    }
    return 0;
}

static NSString *WCAtlasContactAddTimeValue(id contact) {
    uint32_t timestamp = WCAtlasContactAddTime(contact);
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    // The host getter is a 32-bit scalar. Only render values that are valid
    // Unix seconds, so a future host format change degrades to an empty row.
    if (timestamp < 946684800U || timestamp > now + 24.0 * 60.0 * 60.0) return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    formatter.timeZone = NSTimeZone.localTimeZone;
    formatter.dateFormat = @"yyyy年M月d日 HH:mm:ss";
    NSString *text = [formatter stringFromDate:date];
    return text;
}

static NSString *WCAtlasContactAddDaysValue(id contact) {
    uint32_t timestamp = WCAtlasContactAddTime(contact);
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (timestamp < 946684800U || timestamp > now + 24.0 * 60.0 * 60.0) return nil;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSInteger days = [calendar components:NSCalendarUnitDay
                                  fromDate:[calendar startOfDayForDate:date]
                                    toDate:[calendar startOfDayForDate:NSDate.date]
                                   options:0].day;
    return days >= 0 ? [NSString stringWithFormat:@"%ld 天", (long)days] : nil;
}

static id WCAtlasCallCompatibleObjectGetter(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2 || !WCAtlasMethodReturnsObject(method)) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSArray *WCAtlasOfficialRelatedGroups(id controller) {
    id logic = WCAtlasRawProfileValue(controller,
                                    @[@"m_relatedGroupLogic", @"relatedGroupLogic"]);
    if (!logic) logic = objc_getAssociatedObject(controller, &WCAtlasOfficialRelatedGroupLogicKey);
    // WCPulse 1.7-2 reads ContactRelatedGroupLogic through this no-argument
    // object getter for non-friends. Fall back to the backing ivar for host
    // versions where the getter is unavailable.
    id officialGroups = WCAtlasCallCompatibleObjectGetter(logic, @"getContactRelatedGroup");
    if ([officialGroups isKindOfClass:NSArray.class]) return officialGroups;
    if ([officialGroups isKindOfClass:NSSet.class]) return [officialGroups allObjects];
    id groups = WCAtlasRawProfileValue(logic, @[@"_arrRelatedGroup"]);
    if ([groups isKindOfClass:NSArray.class]) return groups;
    if ([groups isKindOfClass:NSSet.class]) return [groups allObjects];
    if ([WCAtlasRawProfileValue(logic, @[@"_bSearchDone"]) boolValue]) return @[];
    return nil;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasOfficialSocialInformationRows(id controller) {
    id tableInfo = WCAtlasRawProfileValue(controller, @[@"m_tableViewInfo", @"tableViewInfo"]);
    NSUInteger sectionCount = WCAtlasCallUnsignedSelector(tableInfo, @"getSectionCount");
    if (sectionCount == 0) sectionCount = WCAtlasTableSections(tableInfo).count;
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableSet *titles = [NSMutableSet set];
    for (NSUInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++) {
        id section = WCAtlasTableSectionAtIndex(tableInfo, sectionIndex);
        NSUInteger cellCount = WCAtlasTableCellCount(section);
        for (NSUInteger cellIndex = 0; cellIndex < cellCount; cellIndex++) {
            id cell = WCAtlasTableCellAtIndex(section, cellIndex);
            NSString *title = [WCAtlasTableCellTitle(cell)
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (title.length == 0) {
                title = [WCAtlasTableCellLeftmostText(cell)
                    stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            }
            NSString *value = [WCAtlasTableCellRightText(cell, title)
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (title.length == 0 || value.length == 0 || [titles containsObject:title]) continue;
            [titles addObject:title];
            [rows addObject:@{ @"title": title, @"value": value }];
            NSString *days = WCAtlasAdditionDaysValue(title, value);
            if (days.length > 0 && ![titles containsObject:@"添加天数"]) {
                [titles addObject:@"添加天数"];
                [rows addObject:@{ @"title": @"添加天数", @"value": days }];
            }
        }
    }
    NSArray *relatedGroups = WCAtlasOfficialRelatedGroups(controller);
    if (relatedGroups != nil && ![titles containsObject:@"共同群聊"]) {
        [rows addObject:@{ @"title": @"共同群聊",
                           @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)relatedGroups.count] }];
    }
    return rows;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasMergeInfoCardRows(NSArray *baseRows,
                                                                                NSArray *officialRows) {
    BOOL friendCard = NO;
    BOOL allowsCommonGroups = NO;
    for (NSDictionary *row in baseRows ?: @[]) {
        NSString *title = row[@"title"];
        if ([title isEqualToString:@"原始号码"]) friendCard = YES;
        if ([title isEqualToString:@"共同群聊"]) allowsCommonGroups = YES;
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableSet *titles = [NSMutableSet set];
    // The direct m_uiAddCreateTime rendering preserves seconds and must win
    // over a coarser native table value. Other official values still replace
    // locally computed placeholders when they arrive asynchronously.
    NSMutableArray *combined = [NSMutableArray array];
    for (NSDictionary *row in baseRows ?: @[]) {
        NSString *title = row[@"title"];
        if ([title isEqualToString:@"添加时间"] || [title isEqualToString:@"添加天数"]) {
            [combined addObject:row];
        }
    }
    [combined addObjectsFromArray:officialRows ?: @[]];
    [combined addObjectsFromArray:baseRows ?: @[]];
    for (NSDictionary *row in combined) {
        NSString *title = row[@"title"];
        NSString *value = row[@"value"];
        if (title.length == 0 || value.length == 0 || [titles containsObject:title]) continue;
        [titles addObject:title];
        [rows addObject:@{ @"title": title, @"value": value }];
    }
    if (friendCard) {
        NSArray<NSString *> *order = @[@"昵称", @"备注", @"微信号", @"原始号码",
                                       @"添加时间", @"添加天数", @"共同群聊"];
        NSMutableDictionary<NSString *, NSDictionary *> *rowsByTitle = [NSMutableDictionary dictionary];
        for (NSDictionary *row in rows) {
            NSString *title = row[@"title"];
            if ([order containsObject:title] && !rowsByTitle[title]) rowsByTitle[title] = row;
        }
        NSMutableArray *orderedRows = [NSMutableArray arrayWithCapacity:order.count];
        for (NSString *title in order) {
            if ([title isEqualToString:@"共同群聊"] && !allowsCommonGroups) continue;
            NSDictionary *row = rowsByTitle[title];
            if (row) [orderedRows addObject:row];
        }
        return orderedRows;
    }
    return rows;
}

static void WCAtlasRefreshInfoCardFromOfficialController(id officialController) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasRefreshInfoCardFromOfficialController(officialController); });
        return;
    }
    WCAtlasWeakObjectBox *box = objc_getAssociatedObject(officialController, &WCAtlasOfficialInfoCardBoxKey);
    WCAtlasContactInfoCardViewController *card = [box.object isKindOfClass:WCAtlasContactInfoCardViewController.class]
        ? box.object : nil;
    NSArray *baseRows = objc_getAssociatedObject(officialController, &WCAtlasOfficialInfoBaseRowsKey) ?: @[];
    if (card) {
        [card updateRows:WCAtlasMergeInfoCardRows(baseRows,
            WCAtlasOfficialSocialInformationRows(officialController))];
        id contact = objc_getAssociatedObject(officialController, &WCAtlasProfileContactKey);
        NSString *username = WCAtlasPrivateContactUserName(contact);
        WCAtlasConfigureInfoCardDetailActions(card, contact, nil, username, officialController);
    }
}

static BOOL WCAtlasSectionContainsRawIDCell(id section, NSString *title) {
    NSUInteger count = WCAtlasTableCellCount(section);
    for (NSUInteger index = 0; index < count; index++) {
        id cell = WCAtlasTableCellAtIndex(section, index);
        if ([objc_getAssociatedObject(cell, &WCAtlasRawContactIDCellMarkerKey) boolValue]) return YES;
        NSString *marker = WCAtlasTweakSafeValue(cell, @"userInfo");
        if ([marker isKindOfClass:NSString.class] && [marker hasPrefix:@"wcatlas_profile_raw_"]) return YES;
        NSString *cellTitle = WCAtlasTableCellTitle(cell);
        if ([cellTitle isEqualToString:title] || [cellTitle isEqualToString:@"原始 ID"] ||
            [cellTitle isEqualToString:@"原始群号码"]) return YES;
    }
    return NO;
}

static id WCAtlasCreateRawIDCell(id target, NSString *title, NSString *rawID) {
    Class cellClass = NSClassFromString(@"WCTableViewCellManager");
    SEL copyFactory = NSSelectorFromString(@"normalCellForSel:target:title:rightValue:canRightValueCopy:");
    SEL basicFactory = NSSelectorFromString(@"normalCellForSel:target:title:rightValue:");
    id cell = nil;
    if ([cellClass respondsToSelector:copyFactory]) {
        cell = ((id (*)(id, SEL, SEL, id, NSString *, NSString *, BOOL))objc_msgSend)(cellClass,
                                                                                     copyFactory,
                                                                                     @selector(wcatlas_openInfoCard),
                                                                                     target,
                                                                                     title,
                                                                                     @"查看",
                                                                                     NO);
    } else if ([cellClass respondsToSelector:basicFactory]) {
        cell = ((id (*)(id, SEL, SEL, id, NSString *, NSString *))objc_msgSend)(cellClass,
                                                                                basicFactory,
                                                                                @selector(wcatlas_openInfoCard),
                                                                                target,
                                                                                title,
                                                                                @"查看");
    }
    if (cell) {
        WCAtlasTweakSetValue(cell, @"userInfo", @"wcatlas_profile_info_card_cell");
        SEL heightSelector = NSSelectorFromString(@"setFCellHeight:");
        if ([cell respondsToSelector:heightSelector]) {
            ((void (*)(id, SEL, CGFloat))objc_msgSend)(cell, heightSelector, 56.0);
        }
    }
    return cell;
}

static BOOL WCAtlasInsertRawIDCell(id section, id cell, NSUInteger index) {
    if (!section || !cell) return NO;
    NSUInteger count = WCAtlasTableCellCount(section);
    if (index == NSNotFound || index > count) index = count;
    SEL insertSelector = NSSelectorFromString(@"insertCell:At:");
    SEL addSelector = NSSelectorFromString(@"addCell:");
    if ([section respondsToSelector:insertSelector]) {
        ((void (*)(id, SEL, id, NSUInteger))objc_msgSend)(section, insertSelector, cell, index);
        return YES;
    }
    if ([section respondsToSelector:addSelector] && index == count) {
        ((void (*)(id, SEL, id))objc_msgSend)(section, addSelector, cell);
        return YES;
    }
    NSArray *cells = WCAtlasTableCells(section);
    if ([cells isKindOfClass:NSMutableArray.class]) {
        [(NSMutableArray *)cells insertObject:cell atIndex:MIN(index, cells.count)];
        return YES;
    }
    return NO;
}

static BOOL WCAtlasProfileSectionContainsMarker(id section, const void *markerKey, NSString *title) {
    NSUInteger count = WCAtlasTableCellCount(section);
    for (NSUInteger index = 0; index < count; index++) {
        id cell = WCAtlasTableCellAtIndex(section, index);
        if ([objc_getAssociatedObject(cell, markerKey) boolValue]) return YES;
        if ([[WCAtlasTableCellTitle(cell) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
             isEqualToString:title]) return YES;
    }
    return NO;
}

static id WCAtlasCreateProfileSwitchCell(id target, SEL rowAction, SEL switchAction,
                                       NSString *title, BOOL enabled) {
    Class cellClass = NSClassFromString(@"WCTableViewCellManager");
    UISwitch *toggle = [UISwitch new];
    toggle.on = enabled;
    [toggle addTarget:target action:switchAction forControlEvents:UIControlEventValueChanged];
    SEL rightViewFactory = NSSelectorFromString(@"normalCellForSel:target:title:rightView:");
    if ([cellClass respondsToSelector:rightViewFactory]) {
        return ((id (*)(id, SEL, SEL, id, NSString *, UIView *))objc_msgSend)(cellClass,
                                                                              rightViewFactory,
                                                                              rowAction,
                                                                              rowAction ? target : nil,
                                                                              title,
                                                                              toggle);
    }
    return nil;
}

static id WCAtlasProfileFeatureTargetSection(id tableInfo, NSUInteger *insertionIndex) {
    NSUInteger sectionCount = WCAtlasCallUnsignedSelector(tableInfo, @"getSectionCount");
    if (sectionCount == 0) sectionCount = WCAtlasTableSections(tableInfo).count;
    id bestSection = nil;
    NSInteger bestScore = NSIntegerMin;
    NSUInteger bestIndex = NSNotFound;
    for (NSUInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++) {
        id section = WCAtlasTableSectionAtIndex(tableInfo, sectionIndex);
        NSUInteger cellCount = WCAtlasTableCellCount(section);
        NSInteger score = -((NSInteger)sectionIndex);
        NSUInteger index = cellCount;
        for (NSUInteger cellIndex = 0; cellIndex < cellCount; cellIndex++) {
            id cell = WCAtlasTableCellAtIndex(section, cellIndex);
            NSString *title = WCAtlasTableCellTitle(cell);
            if ([objc_getAssociatedObject(cell, &WCAtlasRawContactIDCellMarkerKey) boolValue] ||
                [title isEqualToString:@"原始号码"] || [title isEqualToString:@"原始群号码"]) {
                score += 200;
                index = cellIndex + 1;
            } else if ([title containsString:@"微信号"] || [title containsString:@"群聊名称"]) {
                score += 100;
                index = cellIndex + 1;
            } else if ([title containsString:@"朋友资料"] || [title containsString:@"群聊"] ||
                       [title containsString:@"备注"]) {
                score += 30;
            }
        }
        if (!bestSection || score > bestScore) {
            bestSection = section;
            bestScore = score;
            bestIndex = index;
        }
    }
    if (insertionIndex) *insertionIndex = bestIndex;
    return bestSection;
}

static void WCAtlasInjectProfileConversationSwitches(id controller, BOOL group) {
    if (!controller) return;
    NSArray<NSString *> *contactNames = group ?
        @[@"m_chatRoomContact", @"chatRoomContact", @"contact", @"m_contact"] :
        @[@"m_contact", @"contact", @"contactInfo", @"m_contactInfo"];
    id contact = WCAtlasRawProfileValue(controller, contactNames);
    NSString *username = WCAtlasPrivateContactUserName(contact);
    if (![username isKindOfClass:NSString.class] || username.length == 0) return;
    objc_setAssociatedObject(controller, &WCAtlasRawContactIDKey, username, OBJC_ASSOCIATION_COPY_NONATOMIC);

    id tableInfo = WCAtlasRawProfileValue(controller,
                                        @[@"m_tableViewInfo", @"tableViewInfo", @"m_tableViewMgr", @"tableViewMgr"]);
    NSUInteger insertionIndex = NSNotFound;
    id section = WCAtlasProfileFeatureTargetSection(tableInfo, &insertionIndex);
    if (!section) return;

    BOOL showBlockSwitch = WCAtlasEnhancementEnabled(WCAtlasMessageBlockEnabledKey) &&
                           [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasMessageBlockProfileSwitchEnabledKey];
    BOOL showConfirmSwitch = WCAtlasEnhancementEnabled(WCAtlasSendConfirmationEnabledKey) &&
                             [NSUserDefaults.standardUserDefaults boolForKey:WCAtlasSendConfirmationProfileSwitchEnabledKey];
    NSString *blockTitle = group ? @"屏蔽本群消息" : @"屏蔽此人消息";
    NSString *confirmTitle = group ? @"本群发送确认" : @"对其发送确认";
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL blocked = [defaults boolForKey:WCAtlasMessageBlockEnabledKey] &&
                   WCAtlasMessageBlockTypesForConversation(username).count > 0;
    if (showBlockSwitch && !WCAtlasProfileSectionContainsMarker(section, &WCAtlasProfileMessageBlockCellMarkerKey, blockTitle)) {
        id cell = WCAtlasCreateProfileSwitchCell(controller,
                                               NULL,
                                               @selector(wcatlas_toggleProfileMessageBlock:),
                                               blockTitle, blocked);
        if (cell) {
            objc_setAssociatedObject(cell, &WCAtlasProfileMessageBlockCellMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (WCAtlasInsertRawIDCell(section, cell, insertionIndex)) insertionIndex++;
        }
    }
    if (showConfirmSwitch &&
        !WCAtlasProfileSectionContainsMarker(section, &WCAtlasProfileSendConfirmationCellMarkerKey, confirmTitle)) {
        id cell = WCAtlasCreateProfileSwitchCell(controller, NULL,
                                               @selector(wcatlas_toggleProfileSendConfirmation:),
                                               confirmTitle, WCAtlasSendConfirmationIsProtectedConversation(username));
        if (cell) {
            objc_setAssociatedObject(cell, &WCAtlasProfileSendConfirmationCellMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            WCAtlasInsertRawIDCell(section, cell, insertionIndex);
        }
    }
}

static void WCAtlasSetProfileMessageBlocked(NSString *username, BOOL blocked) {
    WCAtlasMessageBlockSetTypesForConversation(username, blocked ? @[@"all"] : @[]);
}

static void WCAtlasConfigureInfoCardSwitches(WCAtlasContactInfoCardViewController *card,
                                           NSString *username,
                                           BOOL group) {
    if (!card || username.length == 0) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL showBlock = WCAtlasEnhancementEnabled(WCAtlasMessageBlockEnabledKey) &&
                     [defaults boolForKey:WCAtlasMessageBlockProfileSwitchEnabledKey];
    BOOL showConfirm = WCAtlasEnhancementEnabled(WCAtlasSendConfirmationEnabledKey) &&
                       [defaults boolForKey:WCAtlasSendConfirmationProfileSwitchEnabledKey];
    NSString *capturedUserName = [username copy];
    if (showBlock) {
        BOOL blocked = WCAtlasMessageBlockTypesForConversation(capturedUserName).count > 0;
        [card configureMessageBlockSwitchWithTitle:(group ? @"屏蔽本群消息" : @"屏蔽此人消息")
                                            enabled:blocked
                                            handler:^(BOOL enabled) {
            WCAtlasSetProfileMessageBlocked(capturedUserName, enabled);
        }];
    }
    if (showConfirm) {
        BOOL protectedConversation = WCAtlasSendConfirmationIsProtectedConversation(capturedUserName);
        [card configureSendConfirmationSwitchWithTitle:(group ? @"本群发送确认" : @"对其发送确认")
                                                  enabled:protectedConversation
                                                  handler:^(BOOL enabled) {
            WCAtlasSendConfirmationSetProtected(capturedUserName, enabled);
        }];
    }
}

static UIViewController *WCAtlasProfileOwnerViewController(id controller) {
    if ([controller isKindOfClass:UIViewController.class]) return controller;
    id candidate = WCAtlasRawProfileValue(controller,
                                        @[@"m_contactInfoViewController", @"contactInfoViewController",
                                          @"m_viewController", @"viewController", @"delegate"]);
    if ([candidate isKindOfClass:UIViewController.class]) return candidate;
    id tableInfo = WCAtlasRawProfileValue(controller,
                                        @[@"m_tableViewInfo", @"tableViewInfo", @"m_tableViewMgr", @"tableViewMgr"]);
    id tableView = WCAtlasRawProfileValue(tableInfo, @[@"getTableView", @"tableView", @"m_tableView"]);
    UIResponder *responder = [tableView isKindOfClass:UIView.class] ? tableView : nil;
    while ((responder = responder.nextResponder)) {
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    }
    return nil;
}

static void WCAtlasAddInfoCardRow(NSMutableArray<NSDictionary<NSString *, NSString *> *> *rows,
                                NSString *title,
                                id value) {
    NSString *text = [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
    if (title.length > 0 && text.length > 0) [rows addObject:@{ @"title": title, @"value": text }];
}

static NSArray<NSString *> *WCAtlasProfileStringList(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *part in [(NSString *)value componentsSeparatedByCharactersInSet:
                                [NSCharacterSet characterSetWithCharactersInString:@";,|"]]) {
            NSString *item = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (item.length > 0) [items addObject:item];
        }
        return items;
    }
    if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value) if ([item isKindOfClass:NSString.class] && [item length] > 0) [items addObject:item];
        return items;
    }
    return @[];
}

static void WCAtlasAddProfileMemberNamesFromValue(id value, NSMutableSet<NSString *> *names) {
    if (!value || !names) return;
    if ([value isKindOfClass:NSString.class]) {
        NSString *string = value;
        if ([string rangeOfString:@"<member" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NSArray<NSString *> *patterns = @[
                @"(?is)<userId>\\s*(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?\\s*</userId>",
                @"(?is)<username>\\s*(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?\\s*</username>",
                @"(?is)<UserName>\\s*(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?\\s*</UserName>",
                @"(?is)<member[^>]+(?:userId|username)=[\"']([^\"']+)[\"']"
            ];
            for (NSString *pattern in patterns) {
                NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
                for (NSTextCheckingResult *match in [expression matchesInString:string options:0
                                                                          range:NSMakeRange(0, string.length)]) {
                    if (match.numberOfRanges < 2) continue;
                    NSString *name = [[string substringWithRange:[match rangeAtIndex:1]]
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    if (name.length > 0) [names addObject:name];
                }
            }
            return;
        }
        for (NSString *part in [(NSString *)value componentsSeparatedByCharactersInSet:
                                [NSCharacterSet characterSetWithCharactersInString:@";,|"]]) {
            NSString *name = [part stringByTrimmingCharactersInSet:
                               NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (name.length > 0) [names addObject:name];
        }
        return;
    }
    if (![value conformsToProtocol:@protocol(NSFastEnumeration)]) return;
    @try {
        for (id item in value) {
            NSString *name = [item isKindOfClass:NSString.class]
                ? [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                : WCAtlasPrivateContactUserName(item);
            if (name.length > 0) [names addObject:name];
        }
    } @catch (__unused NSException *exception) {}
}

static NSSet<NSString *> *WCAtlasGroupMemberUserNames(id groupContact) {
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    id directValue = WCAtlasRawProfileValue(groupContact, @[@"m_nsChatRoomMemList"]);
    WCAtlasAddProfileMemberNamesFromValue(directValue, names);
    id roomData = WCAtlasRawProfileValue(groupContact, @[@"m_ChatRoomData"]);
    id nestedValue = WCAtlasRawProfileValue(roomData, @[@"m_nsChatRoomMemList"]);
    WCAtlasAddProfileMemberNamesFromValue(nestedValue, names);
    return (directValue || nestedValue) ? names : nil;
}

static NSArray *WCAtlasAllChatRoomContacts(void) {
    return WCAtlasPrivateGroupContactList();
}

static BOOL WCAtlasContactListMethodIsCompatible(id manager, SEL selector) {
    Method method = manager ? class_getInstanceMethod([manager class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 3) return NO;
    char returnType[8] = {0};
    char argumentType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    method_getArgumentType(method, 2, argumentType, sizeof(argumentType));
    return (returnType[0] == 'B' || returnType[0] == 'c') && argumentType[0] == '@';
}

static BOOL WCAtlasIsUsernameInContactList(id manager, SEL selector, NSString *userName, BOOL *available) {
    if (available) *available = NO;
    if (!manager || userName.length == 0 || !WCAtlasContactListMethodIsCompatible(manager, selector)) return NO;
    if (available) *available = YES;
    @try {
        return ((BOOL (*)(id, SEL, id))objc_msgSend)(manager, selector, userName);
    } @catch (__unused NSException *exception) {
        if (available) *available = NO;
        return NO;
    }
}

static NSInteger WCAtlasGroupFriendCount(id groupContact) {
    NSSet<NSString *> *memberNames = WCAtlasGroupMemberUserNames(groupContact);
    if (memberNames.count == 0) return -1;
    Class contactManagerClass = objc_getClass("CContactMgr");
    id contactManager = contactManagerClass ? WCAtlasServiceForClass(contactManagerClass) : nil;
    SEL membershipSelector = NSSelectorFromString(@"isInContactList:");
    if (!WCAtlasContactListMethodIsCompatible(contactManager, membershipSelector)) return -1;

    NSString *currentUserName = WCAtlasCurrentUserWXID();
    NSInteger friendCount = 0;
    BOOL available = YES;
    for (NSString *memberName in memberNames) {
        if (currentUserName.length > 0 && [memberName isEqualToString:currentUserName]) continue;
        BOOL isFriend = WCAtlasIsUsernameInContactList(contactManager, membershipSelector,
                                                     memberName, &available);
        if (!available) return -1;
        if (isFriend) friendCount++;
    }
    return friendCount;
}

static NSArray *WCAtlasCommonGroupContacts(NSString *userName) {
    if (userName.length == 0 || [userName hasSuffix:@"@chatroom"]) return nil;
    NSArray *groups = WCAtlasAllChatRoomContacts();
    if (!groups) return nil;
    NSMutableArray *matches = [NSMutableArray array];
    for (id groupContact in groups) {
        NSSet<NSString *> *memberNames = WCAtlasGroupMemberUserNames(groupContact);
        if ([memberNames containsObject:userName]) [matches addObject:groupContact];
    }
    return matches;
}

static NSInteger WCAtlasCommonGroupCount(NSString *userName) {
    NSArray *groups = WCAtlasCommonGroupContacts(userName);
    return groups ? (NSInteger)groups.count : -1;
}

static NSArray *WCAtlasGroupFriendContacts(id groupContact) {
    NSSet<NSString *> *memberNames = WCAtlasGroupMemberUserNames(groupContact);
    if (memberNames.count == 0) return nil;
    Class contactManagerClass = objc_getClass("CContactMgr");
    id contactManager = contactManagerClass ? WCAtlasServiceForClass(contactManagerClass) : nil;
    SEL membershipSelector = NSSelectorFromString(@"isInContactList:");
    if (!WCAtlasContactListMethodIsCompatible(contactManager, membershipSelector)) return nil;
    NSString *currentUserName = WCAtlasCurrentUserWXID();
    NSMutableArray *contacts = [NSMutableArray array];
    for (NSString *memberName in memberNames) {
        if ([memberName isEqualToString:currentUserName]) continue;
        BOOL available = NO;
        if (!WCAtlasIsUsernameInContactList(contactManager, membershipSelector, memberName, &available)) {
            if (!available) return nil;
            continue;
        }
        id contact = WCAtlasContactForUserName(memberName);
        if (contact) [contacts addObject:contact];
    }
    return contacts;
}

static NSArray<NSDictionary<NSString *, id> *> *WCAtlasInfoListRowsForContacts(NSArray *contacts) {
    NSMutableArray<NSDictionary<NSString *, id> *> *rows = [NSMutableArray array];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (id contact in contacts) {
        NSString *userName = WCAtlasPrivateContactUserName(contact);
        if (userName.length == 0 || [identifiers containsObject:userName]) continue;
        [identifiers addObject:userName];
        NSString *name = WCAtlasAvatarDisplayName(contact, userName);
        NSMutableDictionary<NSString *, id> *row = [@{ @"title": name.length > 0 ? name : userName,
                                                        @"value": userName } mutableCopy];
        UIImage *image = WCAtlasPrivateContactAvatarImage(contact);
        if (image) row[@"image"] = image;
        [rows addObject:row];
    }
    [rows sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"title"] localizedCaseInsensitiveCompare:right[@"title"]];
    }];
    return rows;
}

static NSArray *WCAtlasMergedContactCollections(NSArray *primary, NSArray *secondary) {
    NSMutableArray *merged = [NSMutableArray array];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (id contact in [(primary ?: @[]) arrayByAddingObjectsFromArray:secondary ?: @[]]) {
        NSString *userName = WCAtlasPrivateContactUserName(contact);
        if (userName.length == 0 || [identifiers containsObject:userName]) continue;
        [identifiers addObject:userName];
        [merged addObject:contact];
    }
    return merged;
}

static void WCAtlasConfigureInfoCardDetailActions(WCAtlasContactInfoCardViewController *card,
                                                id contact,
                                                id groupContact,
                                                NSString *username,
                                                id officialController) {
    if (!card) return;
    id resolvedGroupContact = groupContact;
    NSString *contactUserName = WCAtlasPrivateContactUserName(contact);
    if (!resolvedGroupContact && [contactUserName hasSuffix:@"@chatroom"]) resolvedGroupContact = contact;
    NSArray *friends = WCAtlasGroupFriendContacts(resolvedGroupContact);
    NSArray *friendRows = WCAtlasInfoListRowsForContacts(friends);
    if (friendRows.count > 0) {
        [card configureRowActionWithTitle:@"群内好友" handler:^(UIViewController *presenter) {
            WCAtlasInfoListViewController *list = [[WCAtlasInfoListViewController alloc]
                initWithTitle:@"群内好友" rows:friendRows];
            [list configureSelectionHandler:^(UIViewController *listPresenter, NSDictionary<NSString *,id> *row) {
                NSString *memberUserName = row[@"value"];
                id memberContact = WCAtlasContactForUserName(memberUserName);
                if (memberContact) WCAtlasOpenAvatarProfile(listPresenter, nil, memberContact);
                else WCAtlasShowTransientMessage(@"未获取到好友资料", NO);
            }];
            [presenter.navigationController pushViewController:list animated:YES];
        }];
    }

    if (username.length == 0 || [username hasSuffix:@"@chatroom"]) return;
    NSArray *localGroups = WCAtlasCommonGroupContacts(username);
    NSArray *officialGroups = officialController ? WCAtlasOfficialRelatedGroups(officialController) : nil;
    NSArray *groups = WCAtlasMergedContactCollections(localGroups, officialGroups);
    NSArray *groupRows = WCAtlasInfoListRowsForContacts(groups);
    if (groupRows.count > 0) {
        [card configureRowActionWithTitle:@"共同群聊" handler:^(UIViewController *presenter) {
            WCAtlasInfoListViewController *list = [[WCAtlasInfoListViewController alloc]
                initWithTitle:@"共同群聊" rows:groupRows];
            [list configureSelectionHandler:^(__unused UIViewController *listPresenter,
                                               NSDictionary<NSString *,id> *row) {
                NSString *groupUserName = row[@"value"];
                if ([groupUserName hasSuffix:@"@chatroom"]) WCAtlasOpenChatForUserName(groupUserName);
            }];
            [presenter.navigationController pushViewController:list animated:YES];
        }];
    }
}

static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasProfileInfoRows(id contact, BOOL group) {
    NSMutableArray *rows = [NSMutableArray array];
    WCAtlasAddInfoCardRow(rows, group ? @"原始群号码" : @"原始号码",
                       WCAtlasPrivateContactUserName(contact));
    if (group) {
        WCAtlasAddInfoCardRow(rows, @"群聊名称",
                           WCAtlasPrivateContactDisplayName(contact, nil));
        NSSet<NSString *> *memberNames = WCAtlasGroupMemberUserNames(contact);
        if (memberNames.count > 0) WCAtlasAddInfoCardRow(rows, @"群成员",
                                                        [NSString stringWithFormat:@"%lu 人",
                                                         (unsigned long)memberNames.count]);
        NSInteger friendCount = WCAtlasGroupFriendCount(contact);
        if (friendCount >= 0) WCAtlasAddInfoCardRow(rows, @"群内好友",
                                                   [NSString stringWithFormat:@"%ld 人", (long)friendCount]);
        WCAtlasAddInfoCardRow(rows, @"群主", WCAtlasRawProfileValue(contact,
            @[@"m_nsChatRoomOwner", @"m_nsOwner", @"ownerUserName", @"owner"]));
        NSArray *admins = WCAtlasProfileStringList(WCAtlasRawProfileValue(contact,
            @[@"m_nsChatRoomAdminList", @"m_nsAdminList", @"m_adminList", @"adminList", @"admins", @"m_arrAdmin"]));
        if (admins.count > 0) WCAtlasAddInfoCardRow(rows, @"管理员", [admins componentsJoinedByString:@"、"]);
        WCAtlasAddInfoCardRow(rows, @"群简介", WCAtlasRawProfileValue(contact, @[@"groupSummary"]));
        WCAtlasAddInfoCardRow(rows, @"群链接", WCAtlasRawProfileValue(contact, @[@"groupURL"]));
    } else {
        WCAtlasAddInfoCardRow(rows, @"昵称", WCAtlasPrivateContactNickname(contact));
        WCAtlasAddInfoCardRow(rows, @"备注", WCAtlasPrivateContactRemark(contact));
        WCAtlasAddInfoCardRow(rows, @"微信号", WCAtlasPrivateContactAlias(contact));
        NSString *userName = WCAtlasPrivateContactUserName(contact);
        WCAtlasAddInfoCardRow(rows, @"脱敏姓名",
            [[WCAtlasFriendRelationChecker sharedChecker] maskedRealNameForUserName:userName]);
        WCAtlasAddInfoCardRow(rows, @"添加时间", WCAtlasContactAddTimeValue(contact));
        WCAtlasAddInfoCardRow(rows, @"添加天数", WCAtlasContactAddDaysValue(contact));
        // The native related-group search exits early for non-friends. Seed the
        // row from the WCPulse-compatible session/contact scan, then merge any
        // official result that becomes available asynchronously.
        NSInteger commonCount = WCAtlasCommonGroupCount(userName);
        WCAtlasAddInfoCardRow(rows, @"共同群聊", commonCount >= 0
            ? [NSString stringWithFormat:@"%ld 个", (long)commonCount]
            : @"正在加载");
    }
    return rows;
}

static UIViewController *WCAtlasCreateOfficialSocialInformation(id contact) {
    if (!contact) return nil;
    Class controllerClass = NSClassFromString(@"SocialInfomationViewController");
    SEL setter = NSSelectorFromString(@"setM_contact:");
    UIViewController *controller = controllerClass ? [[controllerClass alloc] init] : nil;
    if (!controller || ![controller respondsToSelector:setter]) {
        return nil;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(controller, setter, contact);
    NSString *rawID = WCAtlasPrivateContactUserName(contact);
    objc_setAssociatedObject(controller, &WCAtlasProfileContactKey, contact, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasProfileIsGroupKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasRawContactIDKey, rawID, OBJC_ASSOCIATION_COPY_NONATOMIC);
    (void)controller.view;
    SEL reloadSelector = NSSelectorFromString(@"reloadTableView");
    if ([controller respondsToSelector:reloadSelector]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, reloadSelector);
    }
    id relatedGroupLogic = WCAtlasRawProfileValue(controller,
        @[@"m_relatedGroupLogic", @"relatedGroupLogic"]);
    if (!relatedGroupLogic) {
        Class logicClass = objc_getClass("ContactRelatedGroupLogic");
        SEL initializer = NSSelectorFromString(@"initWithContact:");
        Method initializerMethod = logicClass ? class_getInstanceMethod(logicClass, initializer) : NULL;
        if (initializerMethod && method_getNumberOfArguments(initializerMethod) == 3 &&
            WCAtlasMethodReturnsObject(initializerMethod)) {
            @try {
                relatedGroupLogic = ((id (*)(id, SEL, id))objc_msgSend)([logicClass alloc], initializer, contact);
            } @catch (__unused NSException *exception) {
                relatedGroupLogic = nil;
            }
        }
        if (relatedGroupLogic) {
            objc_setAssociatedObject(controller, &WCAtlasOfficialRelatedGroupLogicKey,
                                     relatedGroupLogic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    // AFN registers this exact no-argument selector on ContactRelatedGroupLogic
    // and its replacement preserves the original call before processing results.
    SEL searchSelector = NSSelectorFromString(@"trySearchRelatedGroup");
    Class logicClass = objc_getClass("ContactRelatedGroupLogic");
    Method searchMethod = logicClass ? class_getInstanceMethod(logicClass, searchSelector) : NULL;
    char returnType[8] = {0};
    if (searchMethod) method_getReturnType(searchMethod, returnType, sizeof(returnType));
    if (relatedGroupLogic && searchMethod && method_getNumberOfArguments(searchMethod) == 2 &&
        returnType[0] == 'v' && [relatedGroupLogic respondsToSelector:searchSelector]) {
        @try {
            ((void (*)(id, SEL))objc_msgSend)(relatedGroupLogic, searchSelector);
        } @catch (__unused NSException *exception) {}
        for (NSNumber *delay in @[@0.25, @0.75, @1.5, @3.0, @6.0, @10.0]) {
            __weak UIViewController *weakController = controller;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                UIViewController *strongController = weakController;
                if (strongController) WCAtlasRefreshInfoCardFromOfficialController(strongController);
            });
        }
    }
    return controller;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasGroupMemberInfoRows(id contact,
                                                                                   id groupContact,
                                                                                   NSString *userName) {
    NSMutableArray *rows = [NSMutableArray array];
    SEL displaySelector = NSSelectorFromString(@"getChatRoomMemberDisplayName:");
    if (groupContact && contact && [groupContact respondsToSelector:displaySelector]) {
        @try {
            id value = ((id (*)(id, SEL, id))objc_msgSend)(groupContact, displaySelector, contact);
            WCAtlasAddInfoCardRow(rows, @"群昵称", value);
        } @catch (__unused NSException *exception) {}
    }
    NSString *owner = WCAtlasRawProfileValue(groupContact,
        @[@"m_nsChatRoomOwner", @"m_nsOwner", @"ownerUserName", @"owner"]);
    NSArray *admins = WCAtlasProfileStringList(WCAtlasRawProfileValue(groupContact,
        @[@"m_nsChatRoomAdminList", @"m_nsAdminList", @"m_adminList", @"adminList", @"admins", @"m_arrAdmin"]));
    NSString *role = [owner isEqualToString:userName] ? @"群主"
        : ([admins containsObject:userName] ? @"管理员" : @"群成员");
    WCAtlasAddInfoCardRow(rows, @"群身份", role);
    NSInteger friendCount = WCAtlasGroupFriendCount(groupContact);
    if (friendCount >= 0) WCAtlasAddInfoCardRow(rows, @"群内好友",
                                               [NSString stringWithFormat:@"%ld 人", (long)friendCount]);
    return rows;
}

static NSString *WCAtlasGroupMemberInviterUserName(id groupContact, id memberContact,
                                                  NSString *memberUserName) {
    id chatRoomData = WCAtlasRawProfileValue(groupContact,
        @[@"m_ChatRoomData", @"m_chatRoomData", @"chatRoomData"]);
    SEL selector = NSSelectorFromString(@"getInviterNameForUsername:");
    Method method = chatRoomData ? class_getInstanceMethod([chatRoomData class], selector) : NULL;
    if (method && method_getNumberOfArguments(method) == 3 &&
        WCAtlasMethodReturnsObject(method) && WCAtlasMethodArgumentIsObject(method, 2)) {
        @try {
            id value = ((id (*)(id, SEL, id))objc_msgSend)(chatRoomData, selector, memberUserName);
            if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
        } @catch (__unused NSException *exception) {}
    }
    id fallback = WCAtlasRawProfileValue(memberContact,
        @[@"m_InviteUserName", @"m_inviteUserName", @"inviteUserName", @"inviterUserName"]);
    return [fallback isKindOfClass:NSString.class] && [fallback length] > 0 ? fallback : nil;
}

static NSInteger WCAtlasGroupMemberRemovalScene(id groupContact,
                                               id memberContact,
                                               NSString *memberUserName) {
    NSString *selfUserName = WCAtlasCurrentUserWXID();
    NSString *groupUserName = WCAtlasContactUserName(groupContact);
    if (!groupContact || !memberContact || ![groupUserName hasSuffix:@"@chatroom"] ||
        memberUserName.length == 0 || selfUserName.length == 0 ||
        [memberUserName isEqualToString:selfUserName]) return 0;

    Class groupManagerClass = NSClassFromString(@"CGroupMgr");
    id groupManager = groupManagerClass ? WCAtlasServiceForClass(groupManagerClass) : nil;
    SEL groupGetter = NSSelectorFromString(@"getContactByName:");
    Method groupGetterMethod = groupManager ? class_getInstanceMethod([groupManager class], groupGetter) : NULL;
    id resolvedGroupContact = groupContact;
    if (groupGetterMethod && method_getNumberOfArguments(groupGetterMethod) == 3 &&
        WCAtlasMethodReturnsObject(groupGetterMethod) &&
        WCAtlasMethodArgumentIsObject(groupGetterMethod, 2)) {
        @try {
            id value = ((id (*)(id, SEL, id))objc_msgSend)(groupManager, groupGetter, groupUserName);
            if (value) resolvedGroupContact = value;
        } @catch (__unused NSException *exception) {}
    }

    BOOL memberListAvailable = NO;
    BOOL isCurrentMember = NO;
    SEL memberListSelector = NSSelectorFromString(@"GetGroupMemberUserListByContact:");
    Method memberListMethod = groupManager
        ? class_getInstanceMethod([groupManager class], memberListSelector) : NULL;
    if (memberListMethod && method_getNumberOfArguments(memberListMethod) == 3 &&
        WCAtlasMethodReturnsObject(memberListMethod) &&
        WCAtlasMethodArgumentIsObject(memberListMethod, 2)) {
        @try {
            id list = ((id (*)(id, SEL, id))objc_msgSend)(groupManager,
                memberListSelector, resolvedGroupContact);
            if ([list isKindOfClass:NSArray.class]) {
                memberListAvailable = [(NSArray *)list count] > 0;
                isCurrentMember = [(NSArray *)list containsObject:memberUserName];
            }
        } @catch (__unused NSException *exception) {}
    }
    if (!memberListAvailable) {
        isCurrentMember = [WCAtlasGroupMemberUserNames(resolvedGroupContact) containsObject:memberUserName];
    }
    if (!isCurrentMember) return 0;

    NSString *owner = WCAtlasRawProfileValue(resolvedGroupContact,
        @[@"m_nsOwner", @"m_nsChatRoomOwner", @"ownerUserName", @"owner"]);
    if ([memberUserName isEqualToString:owner]) return 0;
    if ([selfUserName isEqualToString:owner]) return 1;

    NSArray<NSString *> *admins = WCAtlasProfileStringList(WCAtlasRawProfileValue(resolvedGroupContact,
        @[@"m_nsChatRoomAdminList", @"m_nsAdminList", @"adminList", @"admins"]));
    if ([admins containsObject:selfUserName]) return 1;

    NSString *inviter = WCAtlasGroupMemberInviterUserName(resolvedGroupContact,
                                                         memberContact,
                                                         memberUserName);
    return [inviter isEqualToString:selfUserName] ? 2 : 0;
}

static BOOL WCAtlasMethodArgumentIsIntegerScalar(Method method, unsigned int index) {
    if (!method || index >= method_getNumberOfArguments(method)) return NO;
    char type[16] = {0};
    method_getArgumentType(method, index, type, sizeof(type));
    const char *cursor = type;
    while (*cursor == 'r' || *cursor == 'n' || *cursor == 'N' || *cursor == 'o' ||
           *cursor == 'O' || *cursor == 'R' || *cursor == 'V') cursor++;
    return strchr("cCsSiIlLqQB", *cursor) != NULL;
}

static void WCAtlasConfirmRemoveGroupMember(UIViewController *presenter,
                                          id groupContact,
                                          id memberContact,
                                          NSString *memberUserName,
                                          NSInteger scene) {
    NSInteger currentScene = WCAtlasGroupMemberRemovalScene(groupContact, memberContact, memberUserName);
    if (!presenter || currentScene <= 0) {
        WCAtlasShowTransientMessage(@"当前无权移出该成员", NO);
        return;
    }
    scene = currentScene;
    NSString *groupUserName = WCAtlasContactUserName(groupContact);
    NSString *displayName = WCAtlasAvatarDisplayName(memberContact, memberUserName);
    NSString *message = [NSString stringWithFormat:@"确定将“%@”移出当前群聊？", displayName];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"移出群成员"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"移出" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        Class managerClass = NSClassFromString(@"CGroupMgr");
        id manager = managerClass ? WCAtlasServiceForClass(managerClass) : nil;
        SEL selector = NSSelectorFromString(@"DeleteGroupMember:withMemberList:scene:");
        if (![manager respondsToSelector:selector]) {
            selector = NSSelectorFromString(@"p_DeleteGroupMember:withMemberList:scene:");
        }
        Method method = manager ? class_getInstanceMethod([manager class], selector) : NULL;
        char returnType[8] = {0};
        if (method) method_getReturnType(method, returnType, sizeof(returnType));
        if (!method || method_getNumberOfArguments(method) != 5 ||
            (returnType[0] != 'B' && returnType[0] != 'c') ||
            !WCAtlasMethodArgumentIsObject(method, 2) ||
            !WCAtlasMethodArgumentIsObject(method, 3) ||
            !WCAtlasMethodArgumentIsIntegerScalar(method, 4)) {
            WCAtlasShowTransientMessage(@"当前微信版本不支持移出成员", NO);
            return;
        }
        BOOL accepted = NO;
        @try {
            accepted = ((BOOL (*)(id, SEL, id, id, NSInteger))objc_msgSend)(manager,
                selector, groupUserName, @[memberUserName], scene);
        } @catch (NSException *exception) {
            WCAtlasLog(@"移出群成员失败：%@", exception.reason ?: exception.name);
        }
        WCAtlasShowTransientMessage(accepted ? @"已提交移出请求" : @"移出成员失败", accepted);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void WCAtlasOpenProfileInfoCard(id controller) {
    id contact = objc_getAssociatedObject(controller, &WCAtlasProfileContactKey);
    BOOL group = [objc_getAssociatedObject(controller, &WCAtlasProfileIsGroupKey) boolValue];
    NSString *userName = WCAtlasPrivateContactUserName(contact);
    if (userName.length == 0) userName = objc_getAssociatedObject(controller, &WCAtlasRawContactIDKey);
    if (userName.length == 0) return;
    UIViewController *owner = WCAtlasProfileOwnerViewController(controller);
    UIViewController *officialController = !group ? WCAtlasCreateOfficialSocialInformation(contact) : nil;
    NSString *name = WCAtlasPrivateContactDisplayName(contact, nil);
    UIImage *avatar = WCAtlasPrivateContactAvatarImage(contact);
    NSString *chatRoomUserName = objc_getAssociatedObject(controller, &WCAtlasProfileChatRoomKey);
    NSMutableArray *rows = [WCAtlasProfileInfoRows(contact, group) mutableCopy];
    if (!group && [chatRoomUserName hasSuffix:@"@chatroom"]) {
        [rows addObject:@{ @"title": @"所在群聊", @"value": chatRoomUserName }];
        [rows addObjectsFromArray:WCAtlasGroupMemberInfoRows(contact,
            WCAtlasContactForUserName(chatRoomUserName), userName)];
    }
    NSArray *baseRows = [rows copy];
    NSArray *displayRows = WCAtlasMergeInfoCardRows(baseRows,
        officialController ? WCAtlasOfficialSocialInformationRows(officialController) : @[]);
    WCAtlasContactInfoCardViewController *card = [[WCAtlasContactInfoCardViewController alloc]
        initWithTitle:(!group && [chatRoomUserName hasSuffix:@"@chatroom"]) ? @"群成员详细信息" : @"详细信息"
               avatar:avatar
                 name:name ?: userName
             userName:userName
             rows:displayRows];
    if (officialController) {
        WCAtlasWeakObjectBox *box = [WCAtlasWeakObjectBox new];
        box.object = card;
        objc_setAssociatedObject(officialController, &WCAtlasOfficialInfoCardBoxKey,
                                 box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(officialController, &WCAtlasOfficialInfoBaseRowsKey,
                                 baseRows, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(card, &WCAtlasInfoCardOfficialControllerKey,
                                 officialController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasRefreshInfoCardFromOfficialController(officialController);
    }
    WCAtlasConfigureInfoCardSwitches(card, userName, group);
    id detailGroupContact = group ? contact : ([chatRoomUserName hasSuffix:@"@chatroom"]
        ? WCAtlasContactForUserName(chatRoomUserName) : nil);
    WCAtlasConfigureInfoCardDetailActions(card, contact, detailGroupContact,
                                        userName, officialController);
    if (owner.navigationController) [owner.navigationController pushViewController:card animated:YES];
    else if (owner) [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:card]
                                         animated:YES completion:nil];
}

static void WCAtlasInjectRawIDCell(id controller, BOOL group) {
    if (!WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey) || !controller) return;
    NSArray<NSString *> *contactNames = group ?
        @[@"m_chatRoomContact", @"chatRoomContact", @"contact", @"m_contact"] :
        @[@"m_contact", @"contact", @"contactInfo", @"m_contactInfo"];
    id contact = WCAtlasRawProfileValue(controller, contactNames);
    NSString *rawID = WCAtlasPrivateContactUserName(contact);
    if (![rawID isKindOfClass:NSString.class] || rawID.length == 0) return;

    id tableInfo = WCAtlasRawProfileValue(controller,
                                        @[@"m_tableViewInfo", @"tableViewInfo", @"m_tableViewMgr", @"tableViewMgr"]);
    NSUInteger sectionCount = WCAtlasCallUnsignedSelector(tableInfo, @"getSectionCount");
    if (sectionCount == 0) sectionCount = WCAtlasTableSections(tableInfo).count;
    if (!tableInfo || sectionCount == 0) return;
    objc_setAssociatedObject(controller, &WCAtlasProfileContactKey, contact, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasProfileIsGroupKey, @(group), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *chatRoomUserName = group ? rawID : WCAtlasRawProfileValue(controller,
        @[@"m_nsChatRoomUserName", @"sessionUserName"]);
    if (![chatRoomUserName hasSuffix:@"@chatroom"]) {
        chatRoomUserName = WCAtlasRawProfileValue(contact, @[@"m_nsChatRoomUserName", @"sessionUserName"]);
    }
    objc_setAssociatedObject(controller, &WCAtlasProfileChatRoomKey,
                             [chatRoomUserName hasSuffix:@"@chatroom"] ? chatRoomUserName : nil,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSString *title = @"详细信息";
    id targetSection = nil;
    NSUInteger targetIndex = NSNotFound;
    NSInteger targetScore = NSIntegerMin;
    for (NSUInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++) {
        id section = WCAtlasTableSectionAtIndex(tableInfo, sectionIndex);
        if (!section) continue;
        if (WCAtlasSectionContainsRawIDCell(section, title)) return;
        NSUInteger cellCount = WCAtlasTableCellCount(section);
        NSInteger sectionScore = -((NSInteger)sectionIndex);
        NSUInteger sectionTargetIndex = cellCount;
        for (NSUInteger cellIndex = 0; cellIndex < cellCount; cellIndex++) {
            NSString *cellTitle = WCAtlasTableCellTitle(WCAtlasTableCellAtIndex(section, cellIndex));
            if (cellTitle.length == 0) continue;
            if ([cellTitle containsString:@"微信号"] || [cellTitle containsString:@"群聊名称"]) {
                sectionScore += 100;
                sectionTargetIndex = cellIndex + 1;
            } else if ([cellTitle containsString:@"朋友资料"] || [cellTitle containsString:@"群聊"] ||
                       [cellTitle containsString:@"设置备注"] || [cellTitle containsString:@"备注"]) {
                sectionScore += 30;
            } else if ([cellTitle containsString:@"朋友圈"] || [cellTitle containsString:@"添加到通讯录"]) {
                sectionScore += 10;
            }
        }
        if (!targetSection || sectionScore > targetScore) {
            targetSection = section;
            targetIndex = sectionTargetIndex;
            targetScore = sectionScore;
        }
    }
    if (!targetSection) {
        targetSection = WCAtlasTableSectionAtIndex(tableInfo, 0);
        targetIndex = WCAtlasTableCellCount(targetSection);
    }
    id cell = WCAtlasCreateRawIDCell(controller, title, rawID);
    if (!cell || !targetSection) return;
    objc_setAssociatedObject(cell, &WCAtlasRawContactIDCellMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!WCAtlasInsertRawIDCell(targetSection, cell, targetIndex)) return;
    objc_setAssociatedObject(controller, &WCAtlasRawContactIDKey, rawID, OBJC_ASSOCIATION_COPY_NONATOMIC);
    WCAtlasCompatibilityMarkTriggered(@"raw-contact-id");
}

static id WCAtlasHomeSessionCellData(id owner, UITableView *tableView, NSIndexPath *indexPath) {
    return WCAtlasPrivateHomeSessionData(owner, tableView, indexPath);
}

static NSString *WCAtlasHomeSessionUserName(id data) {
    return WCAtlasPrivateHomeSessionUserName(data);
}

static BOOL WCAtlasHomeBooleanValue(id object, NSArray<NSString *> *names) {
    for (NSString *name in names) {
        SEL selector = NSSelectorFromString(name);
        if ([object respondsToSelector:selector]) {
            @try { return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector); }
            @catch (__unused NSException *exception) {}
        }
        id value = WCAtlasTweakSafeValue(object, name);
        if ([value respondsToSelector:@selector(boolValue)]) return [value boolValue];
    }
    return NO;
}

static BOOL WCAtlasHomeSessionMuted(id data) {
    if ([data respondsToSelector:NSSelectorFromString(@"isSilent")]) {
        return WCAtlasHomeBooleanValue(data, @[@"isSilent"]);
    }
    if ([data respondsToSelector:NSSelectorFromString(@"isChatStatusNotifyOpen")]) {
        return !WCAtlasHomeBooleanValue(data, @[@"isChatStatusNotifyOpen"]);
    }
    return WCAtlasHomeBooleanValue(data, @[@"m_bIsSilent", @"m_isSilent"]);
}

static void WCAtlasPushHomeController(id owner, id controller) {
    if (![owner isKindOfClass:UIViewController.class] || ![controller isKindOfClass:UIViewController.class]) return;
    UIViewController *presenter = owner;
    UINavigationController *navigationController = presenter.navigationController;
    if (navigationController) [navigationController pushViewController:controller animated:YES];
    else [presenter presentViewController:controller animated:YES completion:nil];
}

static id WCAtlasHomeActionOwner(id owner, UITableView *tableView) {
    if ([owner isKindOfClass:UIViewController.class]) return owner;
    UIResponder *responder = tableView;
    while ((responder = responder.nextResponder)) {
        if ([responder isKindOfClass:UIViewController.class]) return responder;
    }
    return owner;
}

static void WCAtlasOpenHomeRemark(id owner, id contact, BOOL group) {
    Class controllerClass = NSClassFromString(group ? @"ChatRoomRemarkEditViewController" : @"NewRemarkViewController");
    id controller = controllerClass ? [controllerClass new] : nil;
    if (!controller) return;
    WCAtlasTweakSetValue(controller, group ? @"chatRoomContact" : @"m_contact", contact);
    WCAtlasTweakSetValue(controller, group ? @"m_chatRoomContact" : @"contact", contact);
    SEL editSelector = NSSelectorFromString(@"setNeedEditState:");
    if ([controller respondsToSelector:editSelector]) ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, editSelector, YES);
    WCAtlasPushHomeController(owner, controller);
}

static void WCAtlasOpenHomeMoments(id owner, id contact) {
    Class controllerClass = NSClassFromString(@"WCListViewController");
    id controller = controllerClass ? [controllerClass new] : nil;
    if (!controller) return;
    WCAtlasTweakSetValue(controller, @"m_contact", contact);
    WCAtlasPushHomeController(owner, controller);
}

static id WCAtlasHomeSessionInfoController(id contact, BOOL group) {
    Class controllerClass = NSClassFromString(group ? @"ChatRoomInfoViewController" : @"AddContactToChatRoomViewController");
    id controller = controllerClass ? [controllerClass new] : nil;
    if (!controller) return nil;
    WCAtlasTweakSetValue(controller, group ? @"m_chatRoomContact" : @"m_contact", contact);
    return controller;
}

static NSMutableSet *WCAtlasRetainedHomeSessionControllers(void) {
    static NSMutableSet *controllers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controllers = [NSMutableSet set];
    });
    return controllers;
}

static void WCAtlasRetainHomeSessionController(id controller) {
    if (!controller) return;
    NSMutableSet *controllers = WCAtlasRetainedHomeSessionControllers();
    [controllers addObject:controller];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [controllers removeObject:controller];
    });
}

static void WCAtlasRefreshHomeSessionTable(UITableView *tableView) {
    if (!tableView) return;
    __weak UITableView *weakTableView = tableView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakTableView reloadData];
    });
}

static void WCAtlasSetHomeContactBoolean(id contact, NSString *selectorName, BOOL enabled) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!contact || ![contact respondsToSelector:selector]) return;
    @try {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(contact, selector, enabled);
    } @catch (__unused NSException *exception) {
    }
}

static void WCAtlasCommitHomeSessionToggle(id contact, BOOL group, NSString *selectorName, BOOL enabled) {
    id controller = WCAtlasHomeSessionInfoController(contact, group);
    SEL selector = NSSelectorFromString(selectorName);
    if (!controller || ![controller respondsToSelector:selector]) return;
    @try {
        WCAtlasRetainHomeSessionController(controller);
        // Loading the native settings controller lets WeChat initialize its
        // backing state before the private setting action is dispatched.
        (void)((id (*)(id, SEL))objc_msgSend)(controller, @selector(view));
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, selector, enabled);
        SEL willDisappear = @selector(viewWillDisappear:);
        SEL didDisappear = @selector(viewDidDisappear:);
        if ([controller respondsToSelector:willDisappear]) ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, willDisappear, YES);
        if ([controller respondsToSelector:didDisappear]) ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, didDisappear, YES);
    } @catch (__unused NSException *exception) {
    }
}

static void WCAtlasCommitHomeMuteToggle(id contact, BOOL group, BOOL muted) {
    BOOL desiredMuted = !muted;
    BOOL notifyOpen = !desiredMuted;
    WCAtlasSetHomeContactBoolean(contact, @"setChatStatusNotifyOpen:", notifyOpen);
    WCAtlasSetHomeContactBoolean(contact, @"setChatRoomNotify:", notifyOpen);
    WCAtlasCommitHomeSessionToggle(contact, group, @"setUpdateNotifyMuted:", desiredMuted);
}

typedef UISwipeActionsConfiguration *(*WCAtlasHomeLeadingSwipeIMP)(id, SEL, UITableView *, NSIndexPath *);

static NSMutableDictionary<NSString *, NSValue *> *WCAtlasHomeLeadingSwipeOriginalIMPs(void) {
    static NSMutableDictionary<NSString *, NSValue *> *implementations;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        implementations = [NSMutableDictionary dictionary];
    });
    return implementations;
}

static WCAtlasHomeLeadingSwipeIMP WCAtlasOriginalHomeLeadingSwipeForOwner(id owner) {
    for (Class candidate = object_getClass(owner); candidate; candidate = class_getSuperclass(candidate)) {
        NSValue *value = WCAtlasHomeLeadingSwipeOriginalIMPs()[NSStringFromClass(candidate)];
        if (value) return (WCAtlasHomeLeadingSwipeIMP)value.pointerValue;
    }
    return NULL;
}

static UISwipeActionsConfiguration *WCAtlasHomeLeadingSwipe(id owner, SEL selector,
                                                           UITableView *tableView,
                                                           NSIndexPath *indexPath) {
    WCAtlasHomeLeadingSwipeIMP original = WCAtlasOriginalHomeLeadingSwipeForOwner(owner);
    UISwipeActionsConfiguration *categoryActions =
        WCAtlasHomeCategoriesLeadingSwipeActions(owner, tableView, indexPath);
    if (categoryActions) return categoryActions;
    if (!WCAtlasEnhancementEnabled(WCAtlasHomeSwipeActionsEnabledKey)) {
        return original ? original(owner, selector, tableView, indexPath) : nil;
    }
    id data = WCAtlasHomeSessionCellData(owner, tableView, indexPath);
    NSString *userName = WCAtlasHomeSessionUserName(data);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(userName)) return nil;
    if (userName.length == 0) {
        WCAtlasLog(@"主页右滑：未取得会话数据，owner=%@ delegate=%@ row=%ld",
                 NSStringFromClass([owner class]),
                 NSStringFromClass([tableView.delegate class]),
                 (long)indexPath.row);
        return original ? original(owner, selector, tableView, indexPath) : nil;
    }
    id contact = WCAtlasContactForUserName(userName) ?: data;
    id actionOwner = WCAtlasHomeActionOwner(owner, tableView);
    BOOL group = [userName hasSuffix:@"@chatroom"];
    BOOL supportsMoments = !group &&
                           ![userName hasPrefix:@"gh_"] &&
                           ![userName isEqualToString:@"filehelper"] &&
                           ![userName isEqualToString:@"weixin"];
    id sessionInfo = WCAtlasTweakValueForSelectorNames(data, @[@"m_sessionInfo", @"sessionInfo"]) ?: data;
    BOOL muted = WCAtlasHomeSessionMuted(contact);
    BOOL top = WCAtlasHomeBooleanValue(sessionInfo, @[@"m_bIsTop", @"isTop"]);
    __weak UITableView *weakTableView = tableView;

    UIContextualAction *remark = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"备注"
                                                                        handler:^(__unused UIContextualAction *action,
                                                                                  __unused UIView *sourceView,
                                                                                  void (^completionHandler)(BOOL)) {
        WCAtlasOpenHomeRemark(actionOwner, contact, group);
        completionHandler(YES);
    }];
    remark.backgroundColor = UIColor.systemGrayColor;

    UIContextualAction *mute = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                        title:muted ? @"取消勿扰" : @"勿扰"
                                                                      handler:^(__unused UIContextualAction *action,
                                                                                __unused UIView *sourceView,
                                                                                void (^completionHandler)(BOOL)) {
        WCAtlasCommitHomeMuteToggle(contact, group, muted);
        WCAtlasRefreshHomeSessionTable(weakTableView);
        completionHandler(YES);
    }];
    mute.backgroundColor = UIColor.systemOrangeColor;

    UIContextualAction *pin = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                       title:top ? @"取消置顶" : @"置顶"
                                                                     handler:^(__unused UIContextualAction *action,
                                                                               __unused UIView *sourceView,
                                                                               void (^completionHandler)(BOOL)) {
        WCAtlasCommitHomeSessionToggle(contact, group, @"onTopSession:", !top);
        WCAtlasRefreshHomeSessionTable(weakTableView);
        completionHandler(YES);
    }];
    pin.backgroundColor = UIColor.systemBlueColor;

    NSMutableArray<UIContextualAction *> *actions = [NSMutableArray arrayWithObjects:remark, mute, pin, nil];
    if (group) {
        UIContextualAction *fold = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:@"折叠群聊"
                                                                           handler:^(__unused UIContextualAction *action,
                                                                                     __unused UIView *sourceView,
                                                                                     void (^completionHandler)(BOOL)) {
            WCAtlasCommitHomeSessionToggle(contact, YES, @"setChatBoxStatus:", YES);
            WCAtlasRefreshHomeSessionTable(weakTableView);
            completionHandler(YES);
        }];
        fold.backgroundColor = UIColor.systemPurpleColor;
        [actions insertObject:fold atIndex:1];
    } else if (supportsMoments) {
        UIContextualAction *moments = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:@"朋友圈"
                                                                             handler:^(__unused UIContextualAction *action,
                                                                                       __unused UIView *sourceView,
                                                                                       void (^completionHandler)(BOOL)) {
            WCAtlasOpenHomeMoments(actionOwner, contact);
            completionHandler(YES);
        }];
        moments.backgroundColor = UIColor.systemGreenColor;
        [actions insertObject:moments atIndex:1];
    }
    WCAtlasCompatibilityMarkTriggered(@"home-swipe-actions");
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:actions];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

static void WCAtlasInstallHomeLeadingSwipeOnClass(Class controllerClass) {
    SEL selector = NSSelectorFromString(@"tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:");
    if (!controllerClass) return;
    Method method = class_getInstanceMethod(controllerClass, selector);
    const char *types = "@@:@@";
    IMP currentImplementation = method ? method_getImplementation(method) : NULL;
    if (currentImplementation == (IMP)WCAtlasHomeLeadingSwipe) return;
    if (method) {
        types = method_getTypeEncoding(method) ?: types;
        WCAtlasHomeLeadingSwipeOriginalIMPs()[NSStringFromClass(controllerClass)] =
            [NSValue valueWithPointer:(const void *)currentImplementation];
    }
    // class_addMethod also handles an inherited implementation without mutating
    // the superclass. Only replace directly when this class already owns it.
    if (class_addMethod(controllerClass, selector, (IMP)WCAtlasHomeLeadingSwipe, types)) {
        return;
    }
    Method ownedMethod = class_getInstanceMethod(controllerClass, selector);
    if (!ownedMethod) return;
    method_setImplementation(ownedMethod, (IMP)WCAtlasHomeLeadingSwipe);
}

static void WCAtlasTryInstallHomeLeadingSwipe(void) {
    WCAtlasInstallHomeLeadingSwipeOnClass(objc_getClass("NewMainFrameViewController"));
}

static UITableView *WCAtlasHomeTableViewForController(id controller) {
    id tableView = WCAtlasTweakValueForSelectorNames(controller,
                                                    @[@"tableView", @"m_tableView", @"mainTableView", @"m_mainTableView"]);
    if ([tableView isKindOfClass:UITableView.class]) return tableView;
    UIView *rootView = [controller isKindOfClass:UIViewController.class] ? [controller view] : nil;
    if (!rootView) return nil;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:rootView];
    while (pending.count > 0) {
        UIView *candidate = pending.lastObject;
        [pending removeLastObject];
        if ([candidate isKindOfClass:UITableView.class] &&
            ([NSStringFromClass(candidate.class) containsString:@"MainFrame"] || !tableView)) {
            tableView = candidate;
            if ([NSStringFromClass(candidate.class) containsString:@"MainFrame"]) break;
        }
        [pending addObjectsFromArray:candidate.subviews];
    }
    return [tableView isKindOfClass:UITableView.class] ? tableView : nil;
}

__attribute__((constructor)) static void WCAtlasInstallHomeLeadingSwipe(void) {
    WCAtlasTryInstallHomeLeadingSwipe();
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasTryInstallHomeLeadingSwipe();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WCAtlasTryInstallHomeLeadingSwipe();
    });
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^(__unused NSNotification *note) {
        WCAtlasTryInstallHomeLeadingSwipe();
    }];
}

%hook NewMainFrameViewController

- (void)viewDidLoad {
    // Install before WeChat creates/assigns the table delegate. UIKit may cache
    // whether the delegate implements leading swipe actions during setup.
    WCAtlasInstallHomeLeadingSwipeOnClass(object_getClass(self));
    %orig;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UITableView *tableView = WCAtlasHomeTableViewForController(self);
    WCAtlasInstallHomeLeadingSwipeOnClass(object_getClass(self));
    if (tableView.delegate) WCAtlasInstallHomeLeadingSwipeOnClass(object_getClass(tableView.delegate));
    WCAtlasPrivateRefreshHomeSessionList();
}

- (void)handleSelectIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView {
    if (WCAtlasHomeCategoriesHandleSelection(self, tableView, indexPath)) return;
    %orig;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    id session = WCAtlasPrivateHomeSessionData(self, tableView, indexPath);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(WCAtlasPrivateHomeSessionUserName(session))) return;
    %orig;
}

- (void)onLogicDeleteSessionByUsername:(id)value {
    NSString *userName = [value isKindOfClass:NSString.class] ? value : WCAtlasPrivateHomeSessionUserName(value);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(userName)) return;
    %orig;
}

- (void)onLogicHideSession:(id)value {
    NSString *userName = [value isKindOfClass:NSString.class] ? value : WCAtlasPrivateHomeSessionUserName(value);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(userName)) return;
    %orig;
}

%end

%hook NewMainFrameCell

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    NSString *sessionUserName = WCAtlasPrivateHomeSessionUserName(self);
    if (WCAtlasHomeCategoriesIsSyntheticUserName(sessionUserName) &&
        [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) return NO;
    if (WCAtlasEnhancementEnabled(WCAtlasHomeSwipeActionsEnabledKey) &&
        [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:gestureRecognizer.view];
        // NewMainFrameCell owns a horizontal pan recognizer that can win before
        // UITableView's leading-swipe recognizer. Yield only for a deliberate
        // rightward horizontal gesture; vertical scrolling and native left
        // swipe actions continue through WeChat's original decision.
        if (velocity.x > 0.0 && fabs(velocity.x) > fabs(velocity.y)) return NO;
    }
    return %orig;
}

%end

%hook MainFrameItemView

- (void)layoutSubviews {
    %orig;
    WCAtlasHomeCategoriesLayoutUnreadBadge((UIView *)self);
}

%end

%hook MainFrameTableView

- (void)setDelegate:(id<UITableViewDelegate>)delegate {
    // UITableView caches optional delegate capabilities inside setDelegate:.
    // Install the leading-swipe selector before passing the delegate to WeChat,
    // otherwise the method works only when startup timing happens to be lucky.
    if (delegate) {
        WCAtlasInstallHomeLeadingSwipeOnClass(object_getClass(delegate));
    }
    %orig(delegate);
}

%end

%hook MainSessionMgr

- (void)updateMainSessionList {
    %orig;
    WCAtlasHomeCategoriesApplyToSessionManager(self);
}

- (void)updateMainSessionListNotify:(BOOL)notify {
    WCAtlasHomeCategoriesApplyToSessionManager(self);
    %orig(notify);
    WCAtlasHomeCategoriesApplyToSessionManager(self);
}

- (void)rebuildMainSessions {
    %orig;
    WCAtlasHomeCategoriesApplyToSessionManager(self);
}

%end

%hook MainFrameCellData

- (instancetype)initWithSessionInfo:(id)sessionInfo {
    id value = %orig;
    WCAtlasHomeCategoriesConfigureCellData(value);
    return value;
}

- (void)makeTextForNameLabel {
    %orig;
    WCAtlasHomeCategoriesConfigureCellData(self);
}

- (void)makeTextForMessageLabel {
    %orig;
    WCAtlasHomeCategoriesConfigureCellData(self);
}

- (void)updateData:(id)data {
    %orig;
    WCAtlasHomeCategoriesConfigureCellData(self);
}

- (void)updateDataFieldForUI {
    %orig;
    WCAtlasHomeCategoriesConfigureCellData(self);
}

%end

%hook WeixinContactInfoAssist

- (void)initData {
    %orig;
    WCAtlasInjectRawIDCell(self, NO);
    if (!WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey)) {
        WCAtlasInjectProfileConversationSwitches(self, NO);
    }
}

- (void)reloadTableView {
    %orig;
    WCAtlasInjectRawIDCell(self, NO);
    if (!WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey)) {
        WCAtlasInjectProfileConversationSwitches(self, NO);
    }
}

%new
- (void)wcatlas_copyRawContactID {
    NSString *rawID = objc_getAssociatedObject(self, &WCAtlasRawContactIDKey);
    if (rawID.length > 0) UIPasteboard.generalPasteboard.string = rawID;
}

%new
- (void)wcatlas_openInfoCard {
    WCAtlasOpenProfileInfoCard(self);
}

%new
- (void)wcatlas_toggleProfileMessageBlock:(UISwitch *)sender {
    WCAtlasSetProfileMessageBlocked(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%new
- (void)wcatlas_openProfileMessageBlockTypes {
    NSString *username = objc_getAssociatedObject(self, &WCAtlasRawContactIDKey);
    UIViewController *controller = WCAtlasMessageBlockTypeController(username);
    UIViewController *owner = WCAtlasProfileOwnerViewController(self);
    if (controller && owner) {
        if (owner.navigationController) [owner.navigationController pushViewController:controller animated:YES];
        else [owner presentViewController:controller animated:YES completion:nil];
    }
}

%new
- (void)wcatlas_toggleProfileSendConfirmation:(UISwitch *)sender {
    WCAtlasSendConfirmationSetProtected(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%end

%hook SocialInfomationViewController

- (void)onCRGDataUpdated {
    %orig;
    if (WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey)) {
        WCAtlasInjectProfileConversationSwitches(self, NO);
    }
    WCAtlasRefreshInfoCardFromOfficialController(self);
}

- (void)reloadTableView {
    %orig;
    if (WCAtlasEnhancementEnabled(WCAtlasShowRawContactIDEnabledKey)) {
        WCAtlasInjectProfileConversationSwitches(self, NO);
    }
    if (objc_getAssociatedObject(self, &WCAtlasOfficialInfoCardBoxKey)) {
        WCAtlasRefreshInfoCardFromOfficialController(self);
    }
}

%new
- (void)wcatlas_toggleProfileMessageBlock:(UISwitch *)sender {
    WCAtlasSetProfileMessageBlocked(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%new
- (void)wcatlas_openProfileMessageBlockTypes {
    NSString *username = objc_getAssociatedObject(self, &WCAtlasRawContactIDKey);
    UIViewController *controller = WCAtlasMessageBlockTypeController(username);
    if (controller) [self.navigationController pushViewController:controller animated:YES];
}

%new
- (void)wcatlas_toggleProfileSendConfirmation:(UISwitch *)sender {
    WCAtlasSendConfirmationSetProtected(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%end

%hook ChatRoomInfoViewController

- (void)initData {
    %orig;
    WCAtlasInjectRawIDCell(self, YES);
    WCAtlasInjectProfileConversationSwitches(self, YES);
}

- (void)reloadTableData {
    %orig;
    WCAtlasInjectRawIDCell(self, YES);
    WCAtlasInjectProfileConversationSwitches(self, YES);
}

- (void)reloadProfileTableData {
    %orig;
    WCAtlasInjectRawIDCell(self, YES);
    WCAtlasInjectProfileConversationSwitches(self, YES);
}

%new
- (void)wcatlas_copyRawContactID {
    NSString *rawID = objc_getAssociatedObject(self, &WCAtlasRawContactIDKey);
    if (rawID.length > 0) UIPasteboard.generalPasteboard.string = rawID;
}

%new
- (void)wcatlas_openInfoCard {
    WCAtlasOpenProfileInfoCard(self);
}

%new
- (void)wcatlas_toggleProfileMessageBlock:(UISwitch *)sender {
    WCAtlasSetProfileMessageBlocked(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%new
- (void)wcatlas_openProfileMessageBlockTypes {
    NSString *username = objc_getAssociatedObject(self, &WCAtlasRawContactIDKey);
    UIViewController *controller = WCAtlasMessageBlockTypeController(username);
    UIViewController *owner = WCAtlasProfileOwnerViewController(self);
    if (controller && owner) {
        if (owner.navigationController) [owner.navigationController pushViewController:controller animated:YES];
        else [owner presentViewController:controller animated:YES completion:nil];
    }
}

%new
- (void)wcatlas_toggleProfileSendConfirmation:(UISwitch *)sender {
    WCAtlasSendConfirmationSetProtected(objc_getAssociatedObject(self, &WCAtlasRawContactIDKey), sender.isOn);
}

%end

%hook SessionSelectController

- (void)setMaxSelectionCount:(NSUInteger)count {
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"multi-select-limit");
    }
    %orig(WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey) ? 999 : count);
}

- (BOOL)ignoreMaxSelectionLimit {
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"multi-select-limit");
        return YES;
    }
    return %orig;
}

- (BOOL)onShouldFilterContact:(id)contact {
    // Homepage categories are transient virtual sessions. They must never be
    // exposed as forwarding targets, even when the native selector reuses the
    // main-session snapshot for its recent-conversation section or search.
    if (WCAtlasHomeCategoriesShouldFilterSelectionObject(contact)) return YES;
    return %orig;
}

%end

%hook SessionSelectView

- (BOOL)filterContact:(id)contact {
    if (WCAtlasHomeCategoriesShouldFilterSelectionObject(contact)) return YES;
    return %orig;
}

- (BOOL)onFilterContactCandidate:(id)contact {
    if (WCAtlasHomeCategoriesShouldFilterSelectionObject(contact)) return YES;
    return %orig;
}

- (void)setRecentForwardContacts:(id)contacts {
    %orig(WCAtlasHomeCategoriesFilterSelectionObjects(contacts));
}

%end

%hook ShortVideoToolbar

- (CGFloat)sightCaptureMaxDuration {
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"multi-select-limit");
        return 999.0;
    }
    return %orig;
}

%end

%hook MMMsgCommonTipsView

- (void)layoutSubviews {
    %orig;
    WCAtlasUpdatePinnedMessageGlass((UIView *)self);
}

%end

%hook BaseMsgContentViewController

%new
- (void)wcatlas_openChatSearch:(id)sender {
    if (!WCAtlasOpenOfficialChatSearch(self, sender)) {
        WCAtlasShowTransientMessage(@"当前微信版本暂不支持聊天记录搜索", NO);
    }
}

%new
- (void)wcatlas_handleChatSearchEdgePan:(UIScreenEdgePanGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        ![objc_getAssociatedObject(self, &WCAtlasChatSearchActiveKey) boolValue]) return;
    UIView *gestureView = recognizer.view ?: self.view;
    CGPoint translation = [recognizer translationInView:gestureView];
    CGPoint velocity = [recognizer velocityInView:gestureView];
    if (translation.x > 44.0 || velocity.x > 260.0) {
        WCAtlasCleanupOfficialChatSearch(self);
    }
}

- (void)msgSearchBarCancel {
    if ([objc_getAssociatedObject(self, &WCAtlasChatSearchActiveKey) boolValue]) {
        WCAtlasCleanupOfficialChatSearch(self);
        return;
    }
    %orig;
}

%new
- (void)wcatlas_toggleSendConfirmation:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (!WCAtlasEnhancementEnabled(WCAtlasSendConfirmationEnabledKey)) {
        WCAtlasShowTransientMessage(@"请先在 WCAtlas 设置中开启发送前确认", NO);
        return;
    }
    NSString *username = WCAtlasChatUserName(self);
    if (username.length == 0) {
        WCAtlasShowTransientMessage(@"无法识别当前会话", NO);
        return;
    }
    BOOL protectedConversation = WCAtlasSendConfirmationIsProtectedConversation(username);
    WCAtlasSendConfirmationSetProtected(username, !protectedConversation);
    WCAtlasShowTransientMessage(protectedConversation ? @"已关闭当前会话发送确认" : @"已开启当前会话发送确认", YES);
}

- (NSUInteger)uiMultiSelectMaxCount {
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"multi-select-limit");
        return 9999;
    }
    return %orig;
}

- (NSUInteger)getMultiSelectMaxCount {
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectLimitEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"multi-select-limit");
        return 9999;
    }
    return %orig;
}

- (void)viewDidLoad {
    %orig;
    WCAtlasUpdateChatTopBar(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCAtlasMentionHighlightInstallHooks();
    WCAtlasCleanupOfficialChatSearch(self);
    objc_setAssociatedObject(self, &WCAtlasChatSearchTransitionKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasVisibleChatController = self;
    WCAtlasSendConfirmationChatController = self;
    WCAtlasUpdateChatTopBar(self);
}

- (void)updateTitleView:(id)titleView {
    BOOL typingChanged = WCAtlasSetChatTypingState(self, titleView);
    %orig(titleView);
    if (typingChanged) WCAtlasUpdateChatTopBar(self);
    else WCAtlasRefreshChatTopBarAfterWechatUpdate(self);
}

- (void)updateTitleView:(id)titleView ignoreAnimation:(BOOL)ignoreAnimation {
    BOOL typingChanged = WCAtlasSetChatTypingState(self, titleView);
    %orig(titleView, ignoreAnimation);
    if (typingChanged) WCAtlasUpdateChatTopBar(self);
    else WCAtlasRefreshChatTopBarAfterWechatUpdate(self);
}

- (void)ShowMultiSelectMoreOperation:(id)argument {
    WCAtlasCompatibilityMarkTriggered(@"multi-select-export");
    BOOL hasWCAtlasActions = WCAtlasChatMultiSelectActions((UIViewController *)self).count > 0;
    if (!hasWCAtlasActions) {
        %orig;
        return;
    }
    objc_setAssociatedObject(self, &WCAtlasChatExportBuildingMenuKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig;
    objc_setAssociatedObject(self, &WCAtlasChatExportBuildingMenuKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)scrollActionSheet:(id)sheet didSelecteItem:(id)item {
    NSString *identifier = WCAtlasTweakSafeValue(item, @"userInfo");
    BOOL isExportAction = NO;
    for (NSDictionary *action in WCAtlasChatMultiSelectActions((UIViewController *)self)) {
        if ([identifier isEqualToString:action[@"id"]]) { isExportAction = YES; break; }
    }
    if (isExportAction) {
        SEL dismissSelector = NSSelectorFromString(@"dismissAnimated:");
        if ([sheet respondsToSelector:dismissSelector]) ((void (*)(id, SEL, BOOL))objc_msgSend)(sheet, dismissSelector, YES);
        __weak UIViewController *weakController = (UIViewController *)self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WCAtlasHandleChatMultiSelectAction(weakController, identifier);
        });
        return;
    }
    %orig;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
    BOOL enteringOfficialSearch = [objc_getAssociatedObject(self, &WCAtlasChatSearchTransitionKey) boolValue];
    if (WCAtlasEnhancementEnabled(WCAtlasChatTopBarCapsuleEnabledKey) && !enteringOfficialSearch) {
        WCAtlasApplyTransparentChatTopAppearance(self);
        WCAtlasApplyChatNavigationBackground(self, YES);
        id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
        if (coordinator) {
            __weak BaseMsgContentViewController *weakController = self;
            __weak UINavigationController *weakNavigation = self.navigationController;
            [coordinator animateAlongsideTransition:nil
                                         completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                BaseMsgContentViewController *strongController = weakController;
                UINavigationController *navigationController = weakNavigation;
                if (!strongController) return;
                if (context.isCancelled) {
                    WCAtlasUpdateChatTopBar(strongController);
                } else {
                    WCAtlasRestoreChatNavigationPresentationWithNavigation(strongController,
                                                                         navigationController);
                }
            }];
        }
    }
    UIViewController *controller = (UIViewController *)self;
    if (controller.isMovingFromParentViewController || controller.isBeingDismissed) {
        if (WCAtlasSendConfirmationChatController == self) WCAtlasSendConfirmationChatController = nil;
        WCAtlasCancelPendingSendConfirmations();
        WCAtlasClearImageJokerOverrides();
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    objc_setAssociatedObject(self, &WCAtlasChatSearchTransitionKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasVisibleChatController = self;
    WCAtlasSendConfirmationChatController = self;
    __weak UIViewController *weakController = (UIViewController *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = weakController;
        if (controller.view.window) WCAtlasRefreshVisibleAntiRevokeCells();
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    WCAtlasRefreshChatTopBarAfterWechatUpdate(self);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    WCAtlasRestoreChatNavigationPresentation(self);
    if (WCAtlasVisibleChatController == self) WCAtlasVisibleChatController = nil;
}

- (void)dealloc {
    WCAtlasRemoveChatSearchEdgePan(self);
    if (WCAtlasSendConfirmationChatController == self) WCAtlasSendConfirmationChatController = nil;
    WCAtlasClearImageJokerOverrides();
    %orig;
}

%end

%hook MMScrollActionSheet

- (void)showInView:(UIView *)view {
    id delegate = WCAtlasTweakSafeValue(self, @"delegate");
    BOOL isExportMenu = [objc_getAssociatedObject(delegate, &WCAtlasChatExportBuildingMenuKey) boolValue];
    if (isExportMenu && WCAtlasChatMultiSelectActions((UIViewController *)delegate).count > 0) {
        NSArray *originalRows = WCAtlasTweakSafeValue(self, @"itemArray");
        if ([originalRows isKindOfClass:[NSArray class]] && originalRows.count > 0) {
            NSMutableArray *rows = [NSMutableArray arrayWithCapacity:originalRows.count];
            for (id originalRow in originalRows) {
                NSMutableArray *row = [originalRow isKindOfClass:[NSArray class]] ? [originalRow mutableCopy] : [NSMutableArray array];
                [rows addObject:row];
            }
            for (NSDictionary *action in WCAtlasChatMultiSelectActions((UIViewController *)delegate)) {
                BOOL exists = NO;
                for (NSArray *row in rows) {
                    for (id existingItem in row) {
                        if ([WCAtlasTweakSafeValue(existingItem, @"userInfo") isEqualToString:action[@"id"]]) { exists = YES; break; }
                    }
                    if (exists) break;
                }
                if (exists) continue;
                Class itemClass = NSClassFromString(@"MMScrollActionSheetItem");
                id exportItem = itemClass ? [itemClass new] : nil;
                if (!exportItem) continue;
                UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:21.0 weight:UIImageSymbolWeightRegular];
                UIImage *icon = [UIImage systemImageNamed:action[@"symbol"] withConfiguration:configuration];
                icon = [icon imageWithTintColor:UIColor.labelColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                WCAtlasTweakSetValue(exportItem, @"title", action[@"title"]);
                WCAtlasTweakSetValue(exportItem, @"iconImg", icon);
                WCAtlasTweakSetValue(exportItem, @"userInfo", action[@"id"]);
                [(NSMutableArray *)rows.firstObject addObject:exportItem];
            }
            WCAtlasTweakSetValue(self, @"itemArray", rows);
        }
    }
    %orig;
}

%end

%hook BaseMessageCellView

- (NSArray *)filteredMenuItems:(NSArray *)items {
    NSArray *filteredItems = %orig(items);
    filteredItems = WCAtlasOperationMenuItemsWithRepeat((CommonMessageCellView *)self, filteredItems);
    id message = WCAtlasMessageWrapForCell(self);
    if (WCAtlasMessageIsMusicCard(message)) {
        filteredItems = WCAtlasOperationMenuItemsWithMediaToVoice(self, filteredItems, WCAtlasMediaToVoiceKindMusic);
    } else if (WCAtlasMessageIsConvertibleAudioFile(message)) {
        filteredItems = WCAtlasOperationMenuItemsWithMediaToVoice(self, filteredItems, WCAtlasMediaToVoiceKindAudioFile);
    }
    if (WCAtlasEnhancementEnabled(WCAtlasLongPressMenuEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"long-press-menu");
    }
    return WCAtlasManagedLongPressMenuItems(filteredItems);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(wcatlas_repeatMessage:)) {
        return WCAtlasMessageCanRepeat((CommonMessageCellView *)self);
    }
    if (action == @selector(wcatlas_convertMusicToVoice:)) {
        return WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKindMusic) &&
               WCAtlasMessageIsMusicCard(WCAtlasMessageWrapForCell(self));
    }
    if (action == @selector(wcatlas_convertAudioFileToVoice:)) {
        return WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKindAudioFile) &&
               WCAtlasMessageIsConvertibleAudioFile(WCAtlasMessageWrapForCell(self));
    }
    return %orig;
}

%new
- (void)wcatlas_repeatMessage:(id)sender {
    (void)sender;
    if (!WCAtlasRepeatMessageWithConfirmation((CommonMessageCellView *)self)) {
        WCAtlasShowTransientMessage(@"这条消息暂时无法复读", NO);
    }
}

%new
- (void)wcatlas_convertMusicToVoice:(id)sender {
    (void)sender;
    WCAtlasPresentMediaToVoiceConfirmation(self, WCAtlasMediaToVoiceKindMusic);
}

%new
- (void)wcatlas_convertAudioFileToVoice:(id)sender {
    (void)sender;
    WCAtlasPresentMediaToVoiceConfirmation(self, WCAtlasMediaToVoiceKindAudioFile);
}

%end

%hook EmoticonPreviewWindowViewController

- (void)viewDidLoad {
    %orig;
    if (!WCAtlasEnhancementEnabled(WCAtlasEmoticonToSelfieEnabledKey) ||
        [objc_getAssociatedObject(self, &WCAtlasEmoticonPreviewLongPressKey) boolValue]) return;
    id popoverView = WCAtlasTweakValueForSelectorNames(self, @[@"popoverView"]);
    SEL addSelector = NSSelectorFromString(@"addLongPressTarget:action:");
    if (![popoverView respondsToSelector:addSelector]) return;
    ((void (*)(id, SEL, id, SEL))objc_msgSend)(popoverView, addSelector, self,
        NSSelectorFromString(@"wcatlas_handleEmoticonToSelfie:"));
    objc_setAssociatedObject(self, &WCAtlasEmoticonPreviewLongPressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)wcatlas_handleEmoticonToSelfie:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCAtlasEnhancementEnabled(WCAtlasEmoticonToSelfieEnabledKey)) return;
    if (WCAtlasSaveDataAsSelfieEmoticon(WCAtlasPreviewEmoticonData(self))) {
        WCAtlasLog(@"表情已提交到自拍表情添加流程");
    }
}

%end

%hook EmoticonMessageCellView

- (NSArray *)filteredMenuItems:(NSArray *)items {
    return WCAtlasMenuItemsWithEmoticonToSelfie(self, %orig(items), @"CExtendInfoOfEmoticon");
}

%new
- (void)wcatlas_saveEmoticonAsSelfie {
    if (WCAtlasEnhancementEnabled(WCAtlasEmoticonToSelfieEnabledKey)) {
        (void)WCAtlasSaveCellEmoticonAsSelfie(self, @"CExtendInfoOfEmoticon", YES);
    }
}

%end

%hook AppEmoticonMessageCellView

- (NSArray *)filteredMenuItems:(NSArray *)items {
    return WCAtlasMenuItemsWithEmoticonToSelfie(self, %orig(items), @"CExtendInfoOfAPP");
}

%new
- (void)wcatlas_saveEmoticonAsSelfie {
    if (WCAtlasEnhancementEnabled(WCAtlasEmoticonToSelfieEnabledKey)) {
        (void)WCAtlasSaveCellEmoticonAsSelfie(self, @"CExtendInfoOfAPP", NO);
    }
}

%end

%hook ImageMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    items = WCAtlasOperationMenuItemsWithImageJoker(self, items);
    return WCAtlasOperationMenuItemsWithQuickReply(self, items);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleImageMenuItem:)) {
        return WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey) && WCAtlasMessageWrapForCell(self) != nil;
    }
    if (action == @selector(wcatlas_addToQuickReply:)) return WCAtlasMessageCanAddToQuickReply(WCAtlasMessageWrapForCell(self));
    return %orig;
}

- (id)getCoverImage {
    UIImage *image = WCAtlasImageJokerImageForMessage(WCAtlasMessageWrapForCell(self));
    return image ?: %orig;
}

- (id)displayViewForImageBrowser {
    id displayView = %orig;
    UIImage *image = WCAtlasImageJokerImageForMessage(WCAtlasMessageWrapForCell(self));
    SEL imageSelector = NSSelectorFromString(@"setImage:");
    if (image && [displayView respondsToSelector:imageSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(displayView, imageSelector, image);
    }
    return displayView;
}

- (void)layoutContentView {
    %orig;
    UIImage *image = WCAtlasImageJokerImageForMessage(WCAtlasMessageWrapForCell(self));
    id imageView = WCAtlasTweakSafeValue(self, @"m_imageView");
    if (image && [imageView isKindOfClass:[UIImageView class]]) ((UIImageView *)imageView).image = image;
}

%new
- (void)joker_handleImageMenuItem:(id)sender {
    (void)sender;
    WCAtlasPresentImageJokerPickerForCell(self);
}

%new
- (void)wcatlas_addToQuickReply:(id)sender {
    (void)sender;
    WCAtlasAddMessageToQuickReply(self);
}

%end

%hook ImageMessageViewModel

- (UIImage *)thumbImage {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    return image ?: %orig;
}

- (UIImage *)maskedThumbImage {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    return image ?: %orig;
}

- (NSData *)imageData {
    NSData *data = WCAtlasImageJokerDataForMessage(WCAtlasImageJokerMessageForObject(self));
    return data ?: %orig;
}

- (BOOL)isImageExists {
    return WCAtlasImageJokerImageForObject(self) ? YES : %orig;
}

- (CGSize)thumbImageSize {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    if (!image) return %orig;
    CGSize displaySize = WCAtlasImageJokerDisplaySize(image);
    if (CGSizeEqualToSize(displaySize, CGSizeZero)) return %orig;
    return displaySize;
}

- (CGSize)measureContentViewSize:(CGSize)size {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    if (!image) return %orig(size);
    CGSize displaySize = WCAtlasImageJokerDisplaySize(image);
    if (CGSizeEqualToSize(displaySize, CGSizeZero)) return %orig(size);
    return displaySize;
}

%end

%hook MMImgDataItem_Message

- (NSData *)imageData {
    NSData *data = WCAtlasImageJokerDataForMessage(WCAtlasImageJokerMessageForObject(self));
    return data ?: %orig;
}

- (UIImage *)image {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    return image ?: %orig;
}

- (UIImage *)hdImage {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    return image ?: %orig;
}

- (NSString *)imagePath {
    NSString *path = WCAtlasImageJokerPathForMessage(WCAtlasImageJokerMessageForObject(self));
    return path ?: %orig;
}

- (NSString *)hdImagePath {
    NSString *path = WCAtlasImageJokerPathForMessage(WCAtlasImageJokerMessageForObject(self));
    return path ?: %orig;
}

- (BOOL)isHDImage {
    return WCAtlasImageJokerImageForObject(self) ? YES : %orig;
}

- (CGSize)hdImageSize {
    UIImage *image = WCAtlasImageJokerImageForObject(self);
    return image ? image.size : %orig;
}

%end

%hook CMessageWrap

+ (NSString *)getJpgPathOfMsgMiddleImg:(id)message {
    return WCAtlasImageJokerPathForMessage(message) ?: %orig(message);
}

+ (NSString *)getJpgPathOfMsgHDImg:(id)message {
    return WCAtlasImageJokerPathForMessage(message) ?: %orig(message);
}

+ (NSString *)getJpgPathOfMsgHdOrMiddleImg:(id)message {
    return WCAtlasImageJokerPathForMessage(message) ?: %orig(message);
}

+ (NSString *)getPathOfMsgImg:(id)message {
    return WCAtlasImageJokerPathForMessage(message) ?: %orig(message);
}

+ (UIImage *)getMsgMiddleImg:(id)message {
    return WCAtlasImageJokerImageForMessage(message) ?: %orig(message);
}

+ (UIImage *)getMsgHDImg:(id)message {
    return WCAtlasImageJokerImageForMessage(message) ?: %orig(message);
}

+ (UIImage *)getMsgHdOrMiddleImg:(id)message {
    return WCAtlasImageJokerImageForMessage(message) ?: %orig(message);
}

+ (NSData *)getMsgMiddleImgData:(id)message {
    return WCAtlasImageJokerDataForMessage(message) ?: %orig(message);
}

+ (NSData *)getMsgMiddleImgData:(id)message canUseHeif:(BOOL)canUseHeif {
    return WCAtlasImageJokerDataForMessage(message) ?: %orig(message, canUseHeif);
}

+ (NSData *)getMsgHDImgData:(id)message {
    return WCAtlasImageJokerDataForMessage(message) ?: %orig(message);
}

+ (NSData *)getMsgHdOrMiddleImgData:(id)message {
    return WCAtlasImageJokerDataForMessage(message) ?: %orig(message);
}

+ (NSData *)getMsgHdOrMiddleImgData:(id)message canUseHeif:(BOOL)canUseHeif {
    return WCAtlasImageJokerDataForMessage(message) ?: %orig(message, canUseHeif);
}

%end

%hook UploadVoiceWrap

- (void)setM_uiVoiceForwardFlag:(unsigned int)forwardFlag {
    %orig((WCAtlasVoiceRepeatUploadIsActive() || WCAtlasPrivateVoiceUploadCompatibilityActive()) ? 1 : forwardFlag);
}

%end

%hook UploadVoiceRequest

- (void)setForwardFlag:(unsigned int)forwardFlag {
    %orig((WCAtlasVoiceRepeatUploadIsActive() || WCAtlasPrivateVoiceUploadCompatibilityActive()) ? 1 : forwardFlag);
}

%end

%hook MMNewUploadVoiceMgr

- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part,
          localID,
          serverID,
          offset,
          length,
          voiceTime,
          createTime,
          endFlag,
          cancelFlag,
          voiceFormat,
          WCAtlasVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource,
          chatName);
}

%end

%hook UploadVoiceCDNMgr

- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part,
          localID,
          serverID,
          offset,
          length,
          voiceTime,
          createTime,
          endFlag,
          cancelFlag,
          voiceFormat,
          WCAtlasVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource,
          chatName);
}

%end


%hook TextMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    items = WCAtlasOperationMenuItemsWithJoker(self, items, NO);
    return WCAtlasOperationMenuItemsWithQuickReply(self, items);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey) && WCAtlasMessageCanJokerEdit(WCAtlasMessageWrapForCell(self));
    }
    if (action == @selector(wcatlas_addToQuickReply:)) return WCAtlasMessageCanAddToQuickReply(WCAtlasMessageWrapForCell(self));
    return %orig;
}

%new
- (void)joker_handleMenuItem:(id)sender {
    WCAtlasCompatibilityMarkTriggered(@"chat-joker");
    WCAtlasPresentJokerEditorForCell(self, NO);
}

%new
- (void)wcatlas_addToQuickReply:(id)sender {
    (void)sender;
    WCAtlasAddMessageToQuickReply(self);
}

%end

%hook AppMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    items = WCAtlasOperationMenuItemsWithJoker(self, items, NO);
    items = WCAtlasOperationMenuItemsWithMediaToVoice(self, items, WCAtlasMediaToVoiceKindMusic);
    return WCAtlasOperationMenuItemsWithQuickReply(self, items);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey) && WCAtlasMessageCanJokerEdit(WCAtlasMessageWrapForCell(self));
    }
    if (action == @selector(wcatlas_addToQuickReply:)) return WCAtlasMessageCanAddToQuickReply(WCAtlasMessageWrapForCell(self));
    if (action == @selector(wcatlas_convertMusicToVoice:)) {
        return WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKindMusic) &&
               WCAtlasMessageIsMusicCard(WCAtlasMessageWrapForCell(self));
    }
    return %orig;
}

%new
- (void)joker_handleMenuItem:(id)sender {
    WCAtlasCompatibilityMarkTriggered(@"chat-joker");
    WCAtlasPresentJokerEditorForCell(self, NO);
}

%new
- (void)wcatlas_addToQuickReply:(id)sender {
    (void)sender;
    WCAtlasAddMessageToQuickReply(self);
}

%new
- (void)wcatlas_convertMusicToVoice:(id)sender {
    (void)sender;
    WCAtlasPresentMediaToVoiceConfirmation(self, WCAtlasMediaToVoiceKindMusic);
}

%end

%hook VideoMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    return WCAtlasOperationMenuItemsWithMediaToVoice(self, items, WCAtlasMediaToVoiceKindVideo);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(wcatlas_convertVideoToVoice:)) {
        return WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKindVideo) && WCAtlasMessageWrapForCell(self) != nil;
    }
    return %orig;
}

%new
- (void)wcatlas_convertVideoToVoice:(id)sender {
    (void)sender;
    WCAtlasPresentMediaToVoiceConfirmation(self, WCAtlasMediaToVoiceKindVideo);
}

%end

%hook AppFileMessageCellViewV2

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    items = WCAtlasOperationMenuItemsWithMediaToVoice(self, items, WCAtlasMediaToVoiceKindAudioFile);
    return WCAtlasOperationMenuItemsWithQuickReply(self, items);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(wcatlas_addToQuickReply:)) return WCAtlasMessageCanAddToQuickReply(WCAtlasMessageWrapForCell(self));
    if (action == @selector(wcatlas_convertAudioFileToVoice:)) {
        return WCAtlasMediaToVoiceKindEnabled(WCAtlasMediaToVoiceKindAudioFile) &&
               WCAtlasMessageIsConvertibleAudioFile(WCAtlasMessageWrapForCell(self));
    }
    return %orig;
}

%new
- (void)wcatlas_addToQuickReply:(id)sender {
    (void)sender;
    WCAtlasAddMessageToQuickReply(self);
}

%new
- (void)wcatlas_convertAudioFileToVoice:(id)sender {
    (void)sender;
    WCAtlasPresentMediaToVoiceConfirmation(self, WCAtlasMediaToVoiceKindAudioFile);
}

%end

%hook WCPayTransferMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    return WCAtlasOperationMenuItemsWithJoker(self, items, YES);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return WCAtlasEnhancementEnabled(WCAtlasChatJokerEnabledKey);
    }
    return %orig;
}

%new
- (void)joker_handleMenuItem:(id)sender {
    WCAtlasCompatibilityMarkTriggered(@"chat-joker");
    WCAtlasPresentJokerEditorForCell(self, YES);
}

%end

%hook WCTimeLineCellView

- (void)layoutSubviews {
    %orig;
    WCAtlasSynchronizeMomentsForwardButton(self);
}

- (void)editBlackList {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsQuickPermissionsKey)) {
        %orig;
        return;
    }
    id dataItem = WCAtlasMomentsValueForExactSelector(self, @"m_dataItem");
    if (WCAtlasMomentsUserNameForDataItem(dataItem).length == 0) {
        %orig;
        return;
    }
    WCAtlasCompatibilityMarkTriggered(@"moments-quick-permissions");
    WCAtlasPendingMomentsPermissionDataItem = dataItem;
    %orig;
    id capturedDataItem = dataItem;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (WCAtlasPendingMomentsPermissionDataItem == capturedDataItem) WCAtlasPendingMomentsPermissionDataItem = nil;
    });
}

- (void)initTimeLabel {
    %orig;
    WCAtlasApplyMomentsPreciseTime(self, YES);
}

- (void)updateWithDataItem:(id)dataItem actionAreaVM:(id)actionAreaVM {
    %orig(dataItem, actionAreaVM);
    WCAtlasCompatibilityMarkTriggered(@"moments-precise-time");
    WCAtlasApplyMomentsPreciseTime(self, YES);
    WCAtlasSynchronizeMomentsForwardButton(self);
}

- (void)initView {
    %orig;
    WCAtlasCompatibilityMarkTriggered(@"moments-like");
    WCAtlasSynchronizeMomentsCell(self);
    BOOL shouldReplaceOperateButton = WCAtlasEnhancementEnabled(WCAtlasMomentsQuickCommentKey) &&
                                      !WCAtlasMomentsIsNativeDetailContext(self);
    if (shouldReplaceOperateButton) {
        @try {
            UIView *operateButton = [self valueForKey:@"m_operateBtn"];
            if ([operateButton isKindOfClass:NSClassFromString(@"WCTimeLineOperateButtonView")]) {
                for (UIView *subview in operateButton.subviews) {
                    if ([subview isKindOfClass:[UIImageView class]]) subview.hidden = YES;
                }
                operateButton.tintColor = [UIColor darkGrayColor];
            }
        } @catch (__unused NSException *exception) {
            WCAtlasLog(@"当前微信版本无法调整朋友圈操作按钮外观");
        }
    } else {
        id operateButton = WCAtlasMomentsObjectForSelector(self, @"m_operateBtn");
        if ([operateButton isKindOfClass:[UIView class]]) {
            for (UIView *subview in [(UIView *)operateButton subviews]) {
                if ([subview isKindOfClass:[UIImageView class]]) subview.hidden = NO;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasSynchronizeMomentsCell(self);
    WCAtlasSynchronizeMomentsForwardButton(self);
}

%new
- (void)wcatlas_handleMomentsDoubleTap {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsDoubleTapLikeKey) ||
        WCAtlasMomentsIsNativeDetailContext(self)) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self onAccessibilityLike];
    WCAtlasShowMomentsHeart(self);
    WCAtlasPlayMomentsLikeHaptic(defaults);
    WCAtlasLog(@"已通过双击点赞朋友圈");
}

%new
- (void)wcatlas_handleMomentsForward:(id)sender {
    (void)sender;
    id dataItem = WCAtlasMomentsObjectForName(self, @"m_dataItem");
    UIViewController *presenter = WCAtlasJokerPresenterForCell(self);
    if (!WCAtlasMomentCanForward(dataItem) || !presenter) return;
    WCAtlasForwardMoment(dataItem, presenter);
}

%new
- (void)wcatlas_handleMomentsSaveImages:(id)sender {
    (void)sender;
    id dataItem = WCAtlasMomentsObjectForName(self, @"m_dataItem");
    UIViewController *presenter = WCAtlasJokerPresenterForCell(self);
    if (!WCAtlasMomentCanSaveMedia(dataItem) || !presenter) return;
    WCAtlasSaveMomentMedia(dataItem, presenter);
}

- (id)operateBtnImage:(BOOL)spring isSpringStyle:(BOOL)springStyle {
    if (WCAtlasEnhancementEnabled(WCAtlasMomentsQuickCommentKey) &&
        !WCAtlasMomentsIsNativeDetailContext(self)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
        return [[UIImage systemImageNamed:@"bubble.middle.bottom" withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return %orig;
}

%end

%hook WCTimeLineOperateButtonView

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (WCAtlasEnhancementEnabled(WCAtlasMomentsQuickCommentKey) &&
        !WCAtlasMomentsIsNativeDetailContext(self)) {
        WCAtlasMomentsDispatchingQuickComment = YES;
        @try {
            %orig;
        } @finally {
            WCAtlasMomentsDispatchingQuickComment = NO;
        }
        return;
    }
    %orig;
}

%end

%hook WCOperateFloatView

- (void)layoutSubviews {
    %orig;
    WCAtlasApplyMomentsFloatMenuSnapshot(self);
}

- (void)showWithItemData:(id)item tipPoint:(CGPoint)tipPoint {
    WCAtlasRestoreMomentsFloatMenu(self);
    objc_setAssociatedObject(self, &WCAtlasMomentsFloatSnapshotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &WCAtlasMomentsFloatDataItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (WCAtlasMomentsDispatchingQuickComment) {
        BOOL animationsEnabled = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        @try {
            %orig(item, tipPoint);
            if (!WCAtlasTriggerNativeMomentsComment(self)) [self hide];
        } @finally {
            [UIView setAnimationsEnabled:animationsEnabled];
        }
        return;
    }
    %orig(item, tipPoint);
    WCAtlasPrepareMomentsFloatMenu(self);
}

- (void)hide {
    UIButton *button = objc_getAssociatedObject(self, &WCAtlasMomentsFloatForwardButtonKey);
    UIButton *saveButton = objc_getAssociatedObject(self, &WCAtlasMomentsFloatSaveButtonKey);
    button.hidden = YES;
    saveButton.hidden = YES;
    WCAtlasRestoreMomentsFloatMenu(self);
    %orig;
}

%new
- (void)wcatlas_handleMomentsForward:(id)sender {
    (void)sender;
    id dataItem = objc_getAssociatedObject(self, &WCAtlasMomentsFloatDataItemKey);
    UIViewController *presenter = WCAtlasJokerPresenterForCell(self);
    if (!dataItem || !presenter) return;
    [self hide];
    WCAtlasForwardMoment(dataItem, presenter);
}

%new
- (void)wcatlas_handleMomentsSaveImages:(id)sender {
    (void)sender;
    id dataItem = objc_getAssociatedObject(self, &WCAtlasMomentsFloatDataItemKey);
    UIViewController *presenter = WCAtlasJokerPresenterForCell(self);
    if (!dataItem || !presenter) return;
    [self hide];
    WCAtlasSaveMomentMedia(dataItem, presenter);
}

%end

%hook MMThemeManager

- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet {
    id value = %orig(property, ruleSet);
    return WCAtlasScaledThemeValue(value, property, ruleSet);
}

- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet isAdapt:(BOOL)isAdapt {
    id value = %orig(property, ruleSet, isAdapt);
    return WCAtlasScaledThemeValue(value, property, ruleSet);
}

%end

%hook CLocalInfo

- (unsigned int)m_uiGlobalFontLevel {
    unsigned int value = %orig;
    return WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey) ? 1 : value;
}

- (unsigned int)m_uiWebviewFontLevel {
    unsigned int value = %orig;
    return WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey) ? 1 : value;
}

%end

%hook WKWebView

- (id)initWithFrame:(CGRect)frame configuration:(id)configuration {
    id webView = %orig(frame, configuration);
    WCAtlasApplyWebViewTextScale(webView);
    return webView;
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasApplyWebViewTextScale(self);
}

- (void)_setTextZoomFactor:(CGFloat)factor {
    if (WCAtlasEnhancementEnabled(WCAtlasPageScaleEnabledKey)) {
        factor = WCAtlasGlobalPageScaleFactor();
        WCAtlasCompatibilityMarkTriggered(@"page-scale");
    }
    %orig(factor);
}

%end

%hook WAThemeProxy

+ (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet {
    id value = %orig(property, ruleSet);
    return WCAtlasScaledThemeValue(value, property, ruleSet);
}

%end

%hook BaseMsgContentLogicController

- (void)SendTextMessage:(id)text {
    %orig(text);
}

- (void)SendTextMessage:(id)text replyingMessage:(id)replyingMessage isPasted:(BOOL)isPasted {
    %orig(text, replyingMessage, isPasted);
}

- (void)SendImageMessageByMMAsset:(id)asset {
    NSString *target = [self getCurrentChatName];
    if (WCAtlasConsumeRepeatSendConfirmationBypass(target, 3, YES)) {
        %orig(asset);
        return;
    }
    UIViewController *presenter = WCAtlasSendConfirmationPresenterForTarget(target);
    if (!presenter) {
        %orig(asset);
        return;
    }
    id retainedAsset = asset;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(presenter, target, @"图片：1 张", ^BOOL{
        return WCAtlasSendConfirmationValidateTarget(target);
    }, ^{
        WCAtlasArmImageSendConfirmationBypass(target);
        %orig(retainedAsset);
    });
    if (!held) %orig(asset);
}

%end

%hook WeixinContentLogicController

- (void)AddMsg:(id)message MsgWrap:(id)wrap {
    if ([objc_getAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey) boolValue]) {
        objc_setAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(message, wrap);
        return;
    }
    NSUInteger messageType = [WCAtlasTweakSafeValue(wrap, @"m_uiMessageType") unsignedIntegerValue];
    NSString *target = WCAtlasTweakSafeValue(wrap, @"m_nsToUsr");
    if (messageType != 3 || ![target isKindOfClass:NSString.class] ||
        WCAtlasConsumeImageSendConfirmationBypass(target) ||
        WCAtlasConsumeRepeatSendConfirmationBypass(target, 3, NO)) {
        %orig(message, wrap);
        return;
    }
    UIViewController *presenter = WCAtlasSendConfirmationPresenterForTarget(target);
    if (!presenter) {
        %orig(message, wrap);
        return;
    }
    id retainedMessage = message;
    id retainedWrap = wrap;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(presenter, target, @"图片：1 张", ^BOOL{
        return WCAtlasSendConfirmationValidateTarget(target);
    }, ^{
        %orig(retainedMessage, retainedWrap);
    });
    if (!held) %orig(message, wrap);
}

%end

%hook CMessageMgr

- (void)AddMsg:(NSString *)target MsgWrap:(CMessageWrap *)wrap {
    NSInteger messageType = [WCAtlasTweakSafeValue(wrap, @"m_uiMessageType") integerValue];
    if ([objc_getAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey) boolValue]) {
        objc_setAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(target, wrap);
        return;
    }
    BOOL appEmoticon = WCAtlasSendConfirmationMessageIsAppEmoticon(wrap);
    if (![target isKindOfClass:NSString.class] || (messageType != 1 && !appEmoticon)) {
        %orig(target, wrap);
        return;
    }
    if (WCAtlasConsumeRepeatSendConfirmationBypass(target, messageType, NO)) {
        %orig(target, wrap);
        return;
    }
    UIViewController *presenter = WCAtlasSendConfirmationPresenterForTarget(target);
    if (!presenter) {
        %orig(target, wrap);
        return;
    }
    NSString *summary = appEmoticon ? @"表情：1 个" : WCAtlasSendConfirmationTextSummary(wrap);
    NSString *retainedTarget = [target copy];
    CMessageWrap *retainedWrap = wrap;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(presenter, target, summary, ^BOOL{
        return WCAtlasSendConfirmationValidateTarget(retainedTarget);
    }, ^{
        %orig(retainedTarget, retainedWrap);
    });
    if (!held) %orig(target, wrap);
}

- (id)AddVideoMsg:(id)message ToUsr:(NSString *)target VideoInfo:(id)videoInfo {
    if (![target isKindOfClass:NSString.class] || WCAtlasConsumeVideoSendConfirmationBypass(target) ||
        WCAtlasConsumeRepeatSendConfirmationBypass(target, 43, NO)) {
        return %orig(message, target, videoInfo);
    }
    UIViewController *presenter = WCAtlasSendConfirmationPresenterForTarget(target);
    if (!presenter) return %orig(message, target, videoInfo);
    id retainedMessage = message;
    NSString *retainedTarget = [target copy];
    id retainedVideoInfo = videoInfo;
    BOOL held = WCAtlasPresentSendConfirmationIfNeeded(presenter, target, @"视频：1 个", ^BOOL{
        return WCAtlasSendConfirmationValidateTarget(retainedTarget);
    }, ^{
        id ignoredResult = %orig(retainedMessage, retainedTarget, retainedVideoInfo);
        (void)ignoredResult;
    });
    return held ? nil : %orig(message, target, videoInfo);
}

- (void)AsyncOnAddMsg:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap {
    %orig;
    BOOL deleted = WCAtlasDeleteBlockedIncomingMessage(self, sessionUserName, wrap);
    if (deleted) {
        WCAtlasCompatibilityMarkTriggered(@"message-block");
    } else WCAtlasAutomationHandleIncomingMessage(wrap);
}

- (void)AsyncOnAddMsgForSession:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap {
    %orig;
    BOOL deleted = WCAtlasDeleteBlockedIncomingMessage(self, sessionUserName, wrap);
    if (deleted) {
        WCAtlasCompatibilityMarkTriggered(@"message-block");
    } else WCAtlasAutomationHandleIncomingMessage(wrap);
}

- (void)AsyncOnAddMsgForSession:(NSString *)sessionUserName
                        MsgWrap:(CMessageWrap *)wrap
             NewMsgArriveNotify:(BOOL)notify {
    %orig;
    BOOL deleted = WCAtlasDeleteBlockedIncomingMessage(self, sessionUserName, wrap);
    if (deleted) {
        WCAtlasCompatibilityMarkTriggered(@"message-block");
    } else WCAtlasAutomationHandleIncomingMessage(wrap);
}

- (void)HandleMsgList:(NSString *)sessionUserName MsgList:(NSArray *)messages {
    %orig;
    if (![messages isKindOfClass:NSArray.class]) return;
    for (id message in messages) {
        BOOL deleted = WCAtlasDeleteBlockedIncomingMessage(self, sessionUserName, message);
        if (deleted) {
            WCAtlasCompatibilityMarkTriggered(@"message-block");
        } else WCAtlasAutomationHandleIncomingMessage(message);
    }
}

- (void)onNewSyncNotAddDBMessage:(CMessageWrap *)wrap {
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"anti-revoke"); });
    @try {
        if (WCAtlasHandleRevokeMessage(self, wrap)) return;
    } @catch (NSException *exception) {
        WCAtlasLog(@"防撤回兼容保护已回退微信原逻辑：%@", exception.reason ?: exception.name);
    }
    %orig;
    WCAtlasAutomationHandleIncomingMessage(wrap);
}

- (void)AddEmoticonMsg:(NSString *)message MsgWrap:(CMessageWrap *)wrap {
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"game-selector"); });
    BOOL repeatBypass = WCAtlasConsumeRepeatSendConfirmationBypass(message, 47, NO);
    if (repeatBypass) {
        %orig(message, wrap);
        return;
    }
    BOOL confirmationBypass = [objc_getAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey) boolValue];
    if (confirmationBypass) {
        objc_setAssociatedObject(wrap, &WCAtlasSendConfirmationNativeBypassKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        UIViewController *confirmationPresenter = WCAtlasSendConfirmationPresenterForTarget(message);
        if (confirmationPresenter) {
            NSString *retainedTarget = [message copy];
            CMessageWrap *retainedWrap = wrap;
            __weak typeof(self) weakManager = self;
            BOOL held = WCAtlasPresentSendConfirmationIfNeeded(confirmationPresenter,
                                                              retainedTarget,
                                                              @"表情：1 个",
                                                              ^BOOL{
                return WCAtlasSendConfirmationValidateTarget(retainedTarget);
            }, ^{
                id manager = weakManager;
                if (!manager) return;
                objc_setAssociatedObject(retainedWrap, &WCAtlasSendConfirmationNativeBypassKey, @YES,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                ((void (*)(id, SEL, id, id))objc_msgSend)(manager,
                                                          @selector(AddEmoticonMsg:MsgWrap:),
                                                          retainedTarget,
                                                          retainedWrap);
            });
            if (held) return;
        }
    }
    BOOL isGameMessage = wrap.m_uiMessageType == 47 && (wrap.m_uiGameType == 1 || wrap.m_uiGameType == 2);
    if (!WCAtlasEnhancementEnabled(WCAtlasGameSelectorKey) || !isGameMessage) {
        %orig;
        return;
    }
    if ([objc_getAssociatedObject(wrap, &WCAtlasGameSelectorPresentedKey) boolValue]) return;

    UIWindow *window = WCAtlasActiveApplicationWindow();
    UIViewController *presenter = WCAtlasTopControllerForLoginToast(window.rootViewController);
    if (!presenter.view.window) {
        %orig;
        return;
    }

    objc_setAssociatedObject(wrap, &WCAtlasGameSelectorPresentedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasGameSelectorViewController *selector = [WCAtlasGameSelectorViewController new];
    selector.sourceType = wrap.m_uiGameType == 1 ? @"猜拳" : @"骰子";
    selector.modalPresentationStyle = UIModalPresentationOverFullScreen;
    selector.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    selector.selectionHandler = ^(NSUInteger value, NSString *title) {
        NSString *gameMD5 = WCAtlasGameMD5ForContent(value);
        if (gameMD5.length > 0) wrap.m_nsEmoticonMD5 = gameMD5;
        wrap.m_uiGameContent = value;
        objc_setAssociatedObject(wrap, &WCAtlasGameSelectorPresentedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAtlasLog(@"小游戏结果已选择：%@（原始值 %lu）", title, (unsigned long)value);
        %orig(message, wrap);
    };
    selector.cancelHandler = ^{
        objc_setAssociatedObject(wrap, &WCAtlasGameSelectorPresentedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    };
    [presenter presentViewController:selector animated:NO completion:nil];
}

%end

%hook MMNewSessionMgr

- (id)GetSessionByUserName:(NSString *)userName {
    id syntheticSession = WCAtlasHomeCategoriesIsSyntheticUserName(userName)
        ? WCAtlasPrivateHomeCategorySession(userName) : nil;
    if (syntheticSession) return syntheticSession;
    return %orig;
}

- (void)fulFillSession:(id)session {
    if (WCAtlasHomeCategoriesIsSyntheticUserName(WCAtlasPrivateHomeSessionUserName(session))) return;
    %orig;
}

- (void)fulFillSession:(id)session loadDetails:(BOOL)loadDetails {
    if (WCAtlasHomeCategoriesIsSyntheticUserName(WCAtlasPrivateHomeSessionUserName(session))) return;
    %orig(session, loadDetails);
}

- (BOOL)isNeedSaveSessionInfo:(id)session {
    if (WCAtlasHomeCategoriesIsSyntheticUserName(WCAtlasPrivateHomeSessionUserName(session))) return NO;
    return %orig;
}

- (void)OnAddMsg:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap {
    if (WCAtlasShouldBlockIncomingMessage(sessionUserName, wrap)) {
        WCAtlasCompatibilityMarkTriggered(@"message-block");
        return;
    }
    %orig;
}

- (void)OnMsgNotAddDBNotify:(NSString *)sessionUserName MsgWrap:(CMessageWrap *)wrap {
    if (WCAtlasShouldBlockIncomingMessage(sessionUserName, wrap)) {
        WCAtlasCompatibilityMarkTriggered(@"message-block");
        return;
    }
    %orig;
}

%end

%hook CContactMgr

- (void)printContactImportantChangeData:(id)newContact oldContact:(id)oldContact {
    id snapshot = WCAtlasCaptureGroupMemberChange(newContact, oldContact);
    if (snapshot) WCAtlasCompatibilityMarkTriggered(@"group-member-reminder");
    %orig;
    if (snapshot) WCAtlasCompleteGroupMemberChange(snapshot, self, newContact);
}

%end

%hook WCDeviceStepObject

- (unsigned int)m7StepCount {
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"steps"); });
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (unsigned int)hkStepCount {
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (void)setM7StepCount:(unsigned int)value {
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    %orig(configuredValue > 0 ? configuredValue : value);
}

- (void)setHkStepCount:(unsigned int)value {
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    %orig(configuredValue > 0 ? configuredValue : value);
}

%end

%hook UploadDeviceStepReq

- (unsigned int)stepCount {
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"steps-upload"); });
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (unsigned int)m7StepCount {
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (unsigned int)hkStepCount {
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (void)setStepCount:(unsigned int)value {
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    %orig(configuredValue > 0 ? configuredValue : value);
}

- (void)setM7StepCount:(unsigned int)value {
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    %orig(configuredValue > 0 ? configuredValue : value);
}

- (void)setHkStepCount:(unsigned int)value {
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    %orig(configuredValue > 0 ? configuredValue : value);
}

%end

static id WCAtlasDirectMessageForViewModel(id viewModel) {
    if (!viewModel) return nil;
    id directContent = WCAtlasTweakSafeValue(viewModel, @"m_nsContent");
    if ([directContent isKindOfClass:NSString.class]) return viewModel;
    for (NSString *key in @[@"getCurrentMessageWrap", @"currentMessageWrap",
                            @"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap",
                            @"message", @"m_message"]) {
        id message = WCAtlasTweakSafeValue(viewModel, key);
        if (message) return message;
    }
    return nil;
}

static id WCAtlasMessageForCellViewModel(id viewModel) {
    id message = WCAtlasDirectMessageForViewModel(viewModel);
    if (message) return message;

    id parentModel = WCAtlasTweakSafeValue(viewModel, @"parentModel");
    message = WCAtlasDirectMessageForViewModel(parentModel);
    if (message) return message;
    return nil;
}

static NSString *WCAtlasMessageIdentityComponent(id message, NSArray<NSString *> *keys) {
    id value = nil;
    for (NSString *key in keys) {
        value = WCAtlasTweakSafeValue(message, key);
        if (value) break;
    }
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

static NSString *WCAtlasMessageIdentityForCell(CommonMessageCellView *cell) {
    id viewModel = WCAtlasTweakSafeValue(cell, @"viewModel");
    if (!viewModel) viewModel = WCAtlasTweakSafeValue(cell, @"m_viewModel");
    id message = WCAtlasMessageForCellViewModel(viewModel);
    if (!viewModel || !message) return nil;
    NSString *localID = WCAtlasMessageIdentityComponent(message, @[@"m_uiMesLocalID", @"localID"]);
    NSString *serverID = WCAtlasMessageIdentityComponent(message, @[@"m_n64MesSvrID", @"svrID"]);
    NSString *createTime = WCAtlasMessageIdentityComponent(message, @[@"m_uiCreateTime", @"createTime"]);
    NSString *fromUser = WCAtlasMessageIdentityComponent(message, @[@"m_nsFromUsr", @"fromUsr"]);
    NSString *toUser = WCAtlasMessageIdentityComponent(message, @[@"m_nsToUsr", @"toUsr"]);
    if (localID.length == 0 && serverID.length == 0 && createTime.length == 0) {
        return [NSString stringWithFormat:@"vm:%p|msg:%p",
                (__bridge void *)viewModel, (__bridge void *)message];
    }
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            localID ?: @"", serverID ?: @"", createTime ?: @"",
            fromUser ?: @"", toUser ?: @""];
}

static BOOL WCAtlasMessageIdentityMatchesCell(CommonMessageCellView *cell, NSString *expectedIdentity) {
    NSString *currentIdentity = WCAtlasMessageIdentityForCell(cell);
    return currentIdentity == expectedIdentity || [currentIdentity isEqualToString:expectedIdentity];
}

static void WCAtlasRemoveDuplicateAntiRevokeSideLabels(CommonMessageCellView *cell, UILabel *preferred) {
    // The prompt is always a direct child of the message cell. Keep cleanup
    // cheap because it also runs during native layoutSubviews callbacks.
    for (UIView *subview in cell.subviews.copy) {
        if (subview != preferred && [subview isKindOfClass:UILabel.class] &&
            [subview.accessibilityIdentifier isEqualToString:WCAtlasAntiRevokeSideLabelIdentifier]) {
            [subview removeFromSuperview];
        }
    }
}

static void WCAtlasInvalidateAntiRevokeSidePrompt(CommonMessageCellView *cell) {
    NSUInteger generation = [objc_getAssociatedObject(cell, &WCAtlasAntiRevokeSideRefreshGenerationKey) unsignedIntegerValue];
    objc_setAssociatedObject(cell, &WCAtlasAntiRevokeSideRefreshGenerationKey,
                             @(generation + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &WCAtlasAntiRevokeSideRefreshScheduledKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILabel *label = objc_getAssociatedObject(cell, &WCAtlasAntiRevokeSideLabelKey);
    WCAtlasRemoveDuplicateAntiRevokeSideLabels(cell, label);
    label.hidden = YES;
    label.text = nil;
}

%hook CommonMessageCellView

- (void)prepareForReuse {
    %orig;
    WCAtlasHideMessageTimeLabels(self);
    WCAtlasInvalidateAntiRevokeSidePrompt(self);
}

- (void)layoutSubviews {
    %orig;
    WCAtlasLayoutMessageTimeLabels(self);
    if (WCAtlasUsesAntiRevokeSidePrompt()) [self wcatlas_refreshAntiRevokeSidePrompt];
}

- (void)onHeadImageLongPressed:(id)sender {
    if (WCAtlasPerformingNativeAvatarLongPress) {
        %orig(sender);
        return;
    }
    NSInteger mode = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasAvatarQuickMenuGestureKey];
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasAvatarQuickMenuGestureKey) &&
                   mode == WCAtlasAvatarQuickMenuGestureLongPress;
    if (enabled && self.window) {
        UIView *headView = WCAtlasAvatarHeadViewForCell(self);
        if (!headView && [sender isKindOfClass:UIView.class]) headView = sender;
        if (!headView && [sender isKindOfClass:UIGestureRecognizer.class]) {
            headView = ((UIGestureRecognizer *)sender).view;
        }
        if (headView.window && WCAtlasPresentAvatarQuickMenu(self, headView)) return;
    }
    %orig(sender);
}

- (void)setViewModel:(id)viewModel {
    %orig;
    WCAtlasHideMessageTimeLabels(self);
    WCAtlasInvalidateAntiRevokeSidePrompt(self);
    WCAtlasScheduleMessageTimeRefresh(self);
    WCAtlasSynchronizeReplyGesture(self);
    WCAtlasSynchronizeAvatarQuickGesture(self);
    [self wcatlas_scheduleAntiRevokeSidePromptRefresh];
}

- (void)updateStatus {
    %orig;
    WCAtlasScheduleMessageTimeRefresh(self);
    [self wcatlas_scheduleAntiRevokeSidePromptRefresh];
}

- (void)updateNodeStatus {
    %orig;
    WCAtlasScheduleMessageTimeRefresh(self);
    [self wcatlas_scheduleAntiRevokeSidePromptRefresh];
}

- (void)didMoveToWindow {
    %orig;
    WCAtlasSynchronizeReplyGesture(self);
    WCAtlasSynchronizeAvatarQuickGesture(self);
    if (self.window) {
        WCAtlasScheduleMessageTimeRefresh(self);
        [self wcatlas_scheduleAntiRevokeSidePromptRefresh];
    } else {
        WCAtlasHideMessageTimeLabels(self);
        WCAtlasInvalidateAntiRevokeSidePrompt(self);
    }
}

- (void)handleTapReferMessage {
    if (WCAtlasJumpToReferencedMessage(self)) return;
    %orig;
}

- (void)handleTapForReferMsg:(id)sender {
    if (WCAtlasJumpToReferencedMessage(self)) return;
    %orig(sender);
}

%new
- (void)wcatlas_handleReplyPan:(UIPanGestureRecognizer *)recognizer {
    if (!WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey)) return;
    CGPoint translation = [recognizer translationInView:self];
    CGPoint velocity = [recognizer velocityInView:self];
    CGFloat triggerDistance = WCAtlasReplySwipeTriggerDistance();

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        BOOL rightward = velocity.x > 0.0;
        if (WCAtlasMessageSwipeAction(self, rightward) == WCAtlasReplySwipeActionNone) return;
        objc_setAssociatedObject(self, &WCAtlasReplyPanRightwardKey, @(rightward), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,
                                 &WCAtlasReplyOriginalTransformKey,
                                 [NSValue valueWithCGAffineTransform:self.transform],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,
                                 &WCAtlasReplyTransformSnapshotsKey,
                                 WCAtlasReplyTransformSnapshots(self),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        objc_setAssociatedObject(self, &WCAtlasReplyFeedbackGeneratorKey, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &WCAtlasReplyFeedbackTriggeredKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSValue *originalTransformValue = objc_getAssociatedObject(self, &WCAtlasReplyOriginalTransformKey);
    CGAffineTransform originalTransform = originalTransformValue
        ? originalTransformValue.CGAffineTransformValue
        : CGAffineTransformIdentity;
    BOOL rightward = [objc_getAssociatedObject(self, &WCAtlasReplyPanRightwardKey) boolValue];
    NSArray<WCAtlasReplyTransformSnapshot *> *snapshots = objc_getAssociatedObject(self, &WCAtlasReplyTransformSnapshotsKey);

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat distance = MAX(0.0, rightward ? translation.x : -translation.x);
        if (distance > triggerDistance) {
            distance = triggerDistance + MIN(10.0, (distance - triggerDistance) * 0.18);
        }
        CGFloat offset = rightward ? distance : -distance;
        if (snapshots.count) WCAtlasApplyReplyTransform(snapshots, offset);
        else self.transform = CGAffineTransformTranslate(originalTransform, offset, 0.0);
        if (distance >= triggerDistance &&
            ![objc_getAssociatedObject(self, &WCAtlasReplyFeedbackTriggeredKey) boolValue]) {
            UIImpactFeedbackGenerator *feedback = objc_getAssociatedObject(self, &WCAtlasReplyFeedbackGeneratorKey);
            [feedback impactOccurred];
            objc_setAssociatedObject(self, &WCAtlasReplyFeedbackTriggeredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    if (recognizer.state != UIGestureRecognizerStateEnded &&
        recognizer.state != UIGestureRecognizerStateCancelled &&
        recognizer.state != UIGestureRecognizerStateFailed) return;

    BOOL shouldTrigger = recognizer.state == UIGestureRecognizerStateEnded &&
                         fabs(translation.x) > fabs(translation.y) &&
                         (rightward
                              ? (translation.x >= triggerDistance || velocity.x >= 700.0)
                              : (translation.x <= -triggerDistance || velocity.x <= -700.0));
    __weak CommonMessageCellView *weakCell = self;
    if (shouldTrigger && self.window && WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CommonMessageCellView *cell = weakCell;
            if (!cell.window || !WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey)) return;
            WCAtlasReplySwipeAction currentAction = WCAtlasMessageSwipeAction(cell, rightward);
            WCAtlasPerformMessageGestureAction(cell, currentAction);
        });
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         if (snapshots.count) WCAtlasRestoreReplyTransforms(snapshots);
                         else weakCell.transform = originalTransform;
                     }
                     completion:^(BOOL finished) {
                         (void)finished;
                          CommonMessageCellView *cell = weakCell;
                          if (!cell) return;
                          objc_setAssociatedObject(cell, &WCAtlasReplyOriginalTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                          objc_setAssociatedObject(cell, &WCAtlasReplyTransformSnapshotsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                          objc_setAssociatedObject(cell, &WCAtlasReplyFeedbackGeneratorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                          objc_setAssociatedObject(cell, &WCAtlasReplyFeedbackTriggeredKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                          objc_setAssociatedObject(cell, &WCAtlasReplyPanRightwardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                      }];
}

%new
- (void)wcatlas_handleMessageTapAction:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized ||
        !self.window ||
        !WCAtlasEnhancementEnabled(WCAtlasReplySwipeEnabledKey)) return;
    NSString *selfKey = recognizer.numberOfTapsRequired >= 3
        ? WCAtlasMessageTripleTapSelfActionKey
        : WCAtlasMessageDoubleTapSelfActionKey;
    NSString *otherKey = recognizer.numberOfTapsRequired >= 3
        ? WCAtlasMessageTripleTapOtherActionKey
        : WCAtlasMessageDoubleTapOtherActionKey;
    WCAtlasReplySwipeAction action = WCAtlasMessageGestureAction(self, selfKey, otherKey);
    WCAtlasPerformMessageGestureAction(self, action);
}

%new
- (void)wcatlas_scheduleAntiRevokeSidePromptRefresh {
    UILabel *label = objc_getAssociatedObject(self, &WCAtlasAntiRevokeSideLabelKey);
    WCAtlasRemoveDuplicateAntiRevokeSideLabels(self, label);
    if (!WCAtlasUsesAntiRevokeSidePrompt()) {
        if (label) {
            label.hidden = YES;
            label.text = nil;
        }
        return;
    }
    if ([objc_getAssociatedObject(self, &WCAtlasAntiRevokeSideRefreshScheduledKey) boolValue]) return;
    objc_setAssociatedObject(self, &WCAtlasAntiRevokeSideRefreshScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSUInteger generation = [objc_getAssociatedObject(self, &WCAtlasAntiRevokeSideRefreshGenerationKey) unsignedIntegerValue];
    NSString *messageIdentity = WCAtlasMessageIdentityForCell(self);
    __weak CommonMessageCellView *weakCell = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        CommonMessageCellView *cell = weakCell;
        if (!cell) return;
        BOOL generationMatches = [objc_getAssociatedObject(cell, &WCAtlasAntiRevokeSideRefreshGenerationKey) unsignedIntegerValue] == generation;
        BOOL messageMatches = WCAtlasMessageIdentityMatchesCell(cell, messageIdentity);
        if (cell.window && generationMatches && messageMatches) [cell wcatlas_refreshAntiRevokeSidePrompt];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            CommonMessageCellView *delayedCell = weakCell;
            if (!delayedCell) return;
            if ([objc_getAssociatedObject(delayedCell, &WCAtlasAntiRevokeSideRefreshGenerationKey) unsignedIntegerValue] != generation) return;
            objc_setAssociatedObject(delayedCell, &WCAtlasAntiRevokeSideRefreshScheduledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (delayedCell.window && WCAtlasMessageIdentityMatchesCell(delayedCell, messageIdentity)) {
                [delayedCell wcatlas_refreshAntiRevokeSidePrompt];
            }
        });
    });
}

%new
- (void)wcatlas_refreshAntiRevokeSidePrompt {
    UILabel *label = objc_getAssociatedObject(self, &WCAtlasAntiRevokeSideLabelKey);
    WCAtlasRemoveDuplicateAntiRevokeSideLabels(self, label);
    BOOL useSidePromptStyle = WCAtlasUsesAntiRevokeSidePrompt();
    if (!useSidePromptStyle) {
        if (label) {
            label.hidden = YES;
            label.text = nil;
        }
        return;
    }
    id viewModel = WCAtlasTweakSafeValue(self, @"viewModel");
    if (!viewModel) viewModel = WCAtlasTweakSafeValue(self, @"m_viewModel");
    if (!WCAtlasShouldShowSplitMessageMetadata(viewModel, NO)) {
        if (label) {
            label.hidden = YES;
            label.text = nil;
        }
        return;
    }
    id message = WCAtlasMessageForCellViewModel(viewModel);
    NSString *prompt = WCAtlasAntiRevokeSidePromptForMessage(message);
    BOOL useSidePrompt = prompt.length > 0;
    if (!useSidePrompt) {
        if (label) {
            label.hidden = YES;
            label.text = nil;
        }
        return;
    }

    if (!label) {
        label = [UILabel new];
        label.userInteractionEnabled = NO;
        label.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightRegular];
        label.textColor = [UIColor tertiaryLabelColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.layer.zPosition = 1000.0;
        label.accessibilityIdentifier = WCAtlasAntiRevokeSideLabelIdentifier;
        [self addSubview:label];
        objc_setAssociatedObject(self, &WCAtlasAntiRevokeSideLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (label.superview != self) [self addSubview:label];
    label.accessibilityIdentifier = WCAtlasAntiRevokeSideLabelIdentifier;
    WCAtlasRemoveDuplicateAntiRevokeSideLabels(self, label);
    if (label.hidden) label.hidden = NO;
    if (label.alpha != 1.0) label.alpha = 1.0;
    if (![label.text isEqualToString:prompt]) label.text = prompt;
    UIColor *promptColor = WCAtlasDynamicColorForDefaultsKeys(WCAtlasAntiRevokeSideLightTextColorKey,
                                                            WCAtlasAntiRevokeSideDarkTextColorKey,
                                                            WCAtlasAntiRevokeSideTextColorKey,
                                                            UIColor.tertiaryLabelColor,
                                                            UIColor.tertiaryLabelColor);
    if (![label.textColor isEqual:promptColor]) label.textColor = promptColor;

    UIView *bubbleView = WCAtlasMessageSideAnchorView(self);
    if (!bubbleView) {
        if (!label.hidden) label.hidden = YES;
        return;
    }
    CGRect bubbleFrame = [bubbleView convertRect:bubbleView.bounds toView:self];
    if (CGRectIsNull(bubbleFrame) || CGRectIsInfinite(bubbleFrame) || CGRectIsEmpty(bubbleFrame) ||
        !CGRectIntersectsRect(bubbleFrame, CGRectInset(self.bounds, -80.0, -80.0))) {
        label.hidden = YES;
        return;
    }
    CGSize promptSize = [prompt sizeWithAttributes:@{ NSFontAttributeName: label.font }];
    CGFloat desiredWidth = MIN(160.0, MAX(36.0, ceil(promptSize.width) + 8.0));
    CGFloat labelHeight = 18.0;
    BOOL isSender = [WCAtlasTweakSafeValue(viewModel, @"isSender") boolValue];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id storedOffsetX = [defaults objectForKey:WCAtlasAntiRevokeSideOffsetXKey];
    id storedOffsetY = [defaults objectForKey:WCAtlasAntiRevokeSideOffsetYKey];
    CGFloat offsetX = storedOffsetX ? [storedOffsetX doubleValue] : 0.0;
    CGFloat offsetY = storedOffsetY ? [storedOffsetY doubleValue] : 10.0;
    CGFloat cellWidth = CGRectGetWidth(self.bounds);
    CGFloat gap = 7.0;
    CGFloat availableWidth = isSender ? CGRectGetMinX(bubbleFrame) - gap - 4.0
                                      : cellWidth - CGRectGetMaxX(bubbleFrame) - gap - 4.0;
    if (availableWidth < 36.0) {
        label.hidden = YES;
        return;
    }
    CGFloat labelWidth = MIN(desiredWidth, availableWidth);
    CGFloat x = isSender ? CGRectGetMinX(bubbleFrame) - labelWidth - gap + offsetX
                         : CGRectGetMaxX(bubbleFrame) + gap - offsetX;
    CGFloat sideMinimumX = isSender ? 4.0 : CGRectGetMaxX(bubbleFrame) + gap;
    CGFloat sideMaximumX = isSender ? CGRectGetMinX(bubbleFrame) - gap - labelWidth
                                    : cellWidth - labelWidth - 4.0;
    x = MIN(MAX(sideMinimumX, x), MAX(sideMinimumX, sideMaximumX));
    CGFloat y = CGRectGetMidY(bubbleFrame) - labelHeight * 0.5 + offsetY;
    y = MIN(MAX(0.0, y), MAX(0.0, CGRectGetHeight(self.bounds) - labelHeight));
    UILabel *messageTimeLabel = WCAtlasVisibleMessageTimeSideLabel(self);
    if (messageTimeLabel) {
        CGRect timeFrame = [messageTimeLabel.superview convertRect:messageTimeLabel.frame toView:self];
        CGRect proposed = CGRectMake(x, y, labelWidth, labelHeight);
        if (CGRectIntersectsRect(CGRectInset(proposed, -2.0, -2.0), timeFrame)) {
            CGFloat belowY = CGRectGetMaxY(timeFrame) + 2.0;
            CGFloat aboveY = CGRectGetMinY(timeFrame) - labelHeight - 2.0;
            CGFloat maximumY = MAX(0.0, CGRectGetHeight(self.bounds) - labelHeight);
            if (belowY <= maximumY) y = belowY;
            else if (aboveY >= 0.0) y = aboveY;
            else {
                label.hidden = YES;
                return;
            }
        }
    }
    CGRect targetFrame = CGRectIntegral(CGRectMake(x, y, labelWidth, labelHeight));
    if (!CGRectEqualToRect(label.frame, targetFrame)) label.frame = targetFrame;
    [self bringSubviewToFront:label];
}

%end

%hook SystemMessageCellView

- (void)layoutSubviews {
    %orig;
    BOOL wasApplied = [objc_getAssociatedObject(self, &WCAtlasAntiRevokeSystemColorAppliedKey) boolValue];
    if (!WCAtlasEnhancementEnabled(WCAtlasAntiRevokeKey) && !wasApplied) return;
    [self wcatlas_applyAntiRevokeTextColor];
}

%new
- (void)wcatlas_applyAntiRevokeTextColor {
    id viewModel = WCAtlasTweakSafeValue(self, @"viewModel");
    id message = WCAtlasTweakSafeValue(viewModel, @"messageWrap");
    id richTextView = [self respondsToSelector:@selector(getRichTextView)] ? [self getRichTextView] : WCAtlasTweakSafeValue(self, @"m_richTextView");
    if (!richTextView) return;
    UIColor *originalColor = objc_getAssociatedObject(richTextView, &WCAtlasAntiRevokeOriginalSystemTextColorKey);
    if (!originalColor) {
        id currentColor = WCAtlasTweakSafeValue(richTextView, @"textColor");
        if (![currentColor isKindOfClass:[UIColor class]]) currentColor = WCAtlasTweakSafeValue(richTextView, @"oTextColor");
        if ([currentColor isKindOfClass:[UIColor class]]) {
            originalColor = currentColor;
            objc_setAssociatedObject(richTextView, &WCAtlasAntiRevokeOriginalSystemTextColorKey, originalColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    BOOL shouldApply = WCAtlasEnhancementEnabled(WCAtlasAntiRevokeKey) && WCAtlasAntiRevokeIsLocalPromptMessage(message);
    UIColor *color = shouldApply
        ? WCAtlasDynamicColorForDefaultsKeys(WCAtlasAntiRevokeLocalLightTextColorKey,
                                           WCAtlasAntiRevokeLocalDarkTextColorKey,
                                           WCAtlasAntiRevokeLocalTextColorKey,
                                           UIColor.secondaryLabelColor,
                                           UIColor.secondaryLabelColor)
        : originalColor;
    if (color) {
        UIColor *currentColor = WCAtlasTweakSafeValue(richTextView, @"textColor");
        if (![currentColor isEqual:color]) {
            WCAtlasTweakSetValue(richTextView, @"textColor", color);
            WCAtlasTweakSetValue(richTextView, @"oTextColor", color);
            if ([richTextView isKindOfClass:[UIView class]]) [(UIView *)richTextView setNeedsDisplay];
        }
    }
    objc_setAssociatedObject(self, &WCAtlasAntiRevokeSystemColorAppliedKey,
                             shouldApply ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%hook WCDataItem

- (unsigned int)stepCount {
    unsigned int originalValue = %orig;
    unsigned int configuredValue = WCAtlasConfiguredDailyStepCount();
    return configuredValue > 0 ? configuredValue : originalValue;
}

- (BOOL)isAd {
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"ad-block"); });
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isVideoAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook RoomContentLogicController

- (NSArray *)getDefaultTitleTailSubViews {
    if (WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey)) {
        WCAtlasCompatibilityMarkTriggered(@"hide-chat-mute-icon");
        return @[];
    }
    return %orig;
}

- (id)getMemeberCountLabel {
    id label = %orig;
    if (WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey) && [label isKindOfClass:[UILabel class]]) {
        ((UILabel *)label).hidden = YES;
        ((UILabel *)label).text = @"";
    }
    return label;
}

- (CGFloat)GetTitleLabelOffset {
    if (WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey)) return 0.0;
    return %orig;
}

%end

static BOOL WCAtlasViewIsInsideNavigationChrome(UIView *view,
                                               BaseMsgContentViewController *controller) {
    UINavigationBar *navigationBar = controller.navigationController.navigationBar;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if (ancestor == navigationBar ||
            [NSStringFromClass(ancestor.class) containsString:@"NavigationBar"]) return YES;
    }
    return NO;
}

static void WCAtlasObserveTypingStatusLabel(MMUILabel *label, NSString *text) {
    BOOL typing = [text isKindOfClass:NSString.class] && [text containsString:@"正在输入"];
    BOOL tracked = [objc_getAssociatedObject(label, &WCAtlasChatTypingStatusLabelMarkerKey) boolValue];
    if (!typing && !tracked) return;

    if (typing && !label.window) {
        objc_setAssociatedObject(label, &WCAtlasChatTypingStatusLabelMarkerKey,
                                 @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    BaseMsgContentViewController *controller = WCAtlasResolveVisibleChatController();
    if (!controller) return;
    if (typing && !WCAtlasViewIsInsideNavigationChrome(label, controller)) {
        objc_setAssociatedObject(label, &WCAtlasChatTypingStatusLabelMarkerKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    objc_setAssociatedObject(label, &WCAtlasChatTypingStatusLabelMarkerKey,
                             typing ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!WCAtlasSetChatTypingState(controller, label)) return;
    __weak BaseMsgContentViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        BaseMsgContentViewController *strongController = weakController;
        if (strongController && strongController.view.window) WCAtlasUpdateChatTopBar(strongController);
    });
}

%hook MMUILabel

- (void)setText:(NSString *)text {
    NSString *contactsText = WCAtlasResponderIsInsideControllerClass(self, @"ContactsViewController")
        ? WCAtlasContactsCountTextForOriginal(text)
        : nil;
    if (contactsText.length > 0 && ![contactsText isEqualToString:text]) {
        WCAtlasCompatibilityMarkTriggered(@"contacts-count");
    }
    NSString *resolvedText = contactsText ?: text;
    %orig(resolvedText);
    WCAtlasObserveTypingStatusLabel(self, resolvedText);
}

- (void)didMoveToWindow {
    %orig;
    if (self.window && WCAtlasResponderIsInsideControllerClass(self, @"ContactsViewController")) {
        NSString *contactsText = WCAtlasContactsCountTextForOriginal(self.text);
        if (contactsText.length > 0 && ![contactsText isEqualToString:self.text]) self.text = contactsText;
    }
    WCAtlasObserveTypingStatusLabel(self, self.text);
}

%end

%hook TimeoutNumber

- (void)didMoveToSuperview {
    %orig;
    if (WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey) &&
        WCAtlasViewIsInsideWalletHeader((UIView *)self)) {
        WCAtlasInstallWalletLongPressIfNeeded((UIView *)self, self, @selector(wcatlas_walletHandleLongPress:));
    } else {
        WCAtlasRemoveWalletLongPressIfNeeded((UIView *)self);
    }
}

- (void)updateNumber:(unsigned long long)number {
    unsigned long long balanceFen = WCAtlasViewIsInsideWalletHeader((UIView *)self)
        ? WCAtlasWalletBalanceFenOverride()
        : 0;
    if (balanceFen > 0) {
        WCAtlasCompatibilityMarkTriggered(@"wallet-balance");
        %orig(balanceFen);
        return;
    }
    %orig(number);
}

- (void)defaultNumber:(unsigned long long)number {
    unsigned long long balanceFen = WCAtlasViewIsInsideWalletHeader((UIView *)self)
        ? WCAtlasWalletBalanceFenOverride()
        : 0;
    %orig(balanceFen > 0 ? balanceFen : number);
}

%new
- (void)wcatlas_walletHandleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan &&
        WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"wallet-balance");
        id headerView = WCAtlasWalletHeaderForView((UIView *)self);
        WCAtlasPresentWalletBalanceEditor(headerView);
    }
}

%end

%hook WCPayWalletEntryHeaderView

- (void)didMoveToSuperview {
    %orig;
    if (WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey)) {
        WCAtlasInstallWalletLongPressIfNeeded((UIView *)self, self, @selector(wcatlas_walletHeaderHandleLongPress:));
    } else {
        WCAtlasRemoveWalletLongPressIfNeeded((UIView *)self);
    }
    WCAtlasRefreshWalletHeaderBalance(self);
}

- (void)handleUpdateWalletBalance {
    %orig;
    WCAtlasRefreshWalletHeaderBalance(self);
}

- (void)setupTimeoutNumber {
    %orig;
    WCAtlasRefreshWalletHeaderBalance(self);
}

- (void)updateBalanceEntryView {
    %orig;
    WCAtlasRefreshWalletHeaderBalance(self);
}

- (void)updateBalanceAndRefreshView {
    %orig;
    WCAtlasRefreshWalletHeaderBalance(self);
}

%new
- (void)wcatlas_walletHeaderHandleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan &&
        WCAtlasEnhancementEnabled(WCAtlasWalletBalanceEnabledKey)) {
        WCAtlasCompatibilityMarkTriggered(@"wallet-balance");
        WCAtlasPresentWalletBalanceEditor(self);
    }
}

%end

%hook MMWebViewConfig

+ (BOOL)isEnableWebDebugFunctions {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return YES;
    return %orig;
}

%end

%hook NSURL

+ (instancetype)URLWithString:(NSString *)URLString {
    return %orig(WCAtlasAdBlockerRewrittenURLString(URLString));
}

%end

%hook WebviewJSEventHandler_adDataReport

- (void)handleJSEvent:(id)event HandlerFacade:(id)facade ExtraData:(id)extraData {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(event, facade, extraData);
}

%end

%hook WCAdvertiseStatMgr

- (id)getAdvertiseInfoForItem:(id)item {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return %orig(nil);
    return %orig(item);
}

- (void)logSphereViewWithSphereReportInfo:(id)reportInfo dataItem:(id)dataItem scene:(unsigned int)scene {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(reportInfo, dataItem, scene);
}

- (void)logSphereViewInDetailWithWrapInfo:(id)wrapInfo dataItem:(id)dataItem {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(wrapInfo, dataItem);
}

- (void)logSphereViewInTimeLineWithWrapInfo:(id)wrapInfo dataItem:(id)dataItem {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(wrapInfo, dataItem);
}

- (void)logHeadImageH5:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADBrandProfile:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADFloatView:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADPoiH5:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADH5:(id)value withUserInfo:(id)userInfo reportType:(unsigned int)reportType {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value, userInfo, reportType);
}

- (void)logADH5:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADDetail:(id)detail dataItem:(id)dataItem {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(detail, dataItem);
}

- (void)logADCommentLog:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)logADBodyLog:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)reportAllFeedsADLog {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig;
}

%end

%hook WAAppTaskSplashADConfig

- (BOOL)canShowSplashADWindow {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)launchShow {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook WAJSEventHandler_showSplashAd

- (void)handleJSEvent:(id)event {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(event);
}

%end

%hook WAJSEventHandler_showSplashAdMenu

- (void)handleJSEvent:(id)event {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(event);
}

%end

%hook BrandTLExptConfig

- (BOOL)isExptNotShowAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return YES;
    return %orig;
}

%end

%hook BSTLExptConfig

- (BOOL)isExptNotShowAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return YES;
    return %orig;
}

%end

%hook BrandTLFlutterViewController

- (BOOL)enableAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey) ? NO : enabled);
}

%end

%hook BoxBrandTLFlutterViewController

- (BOOL)enableAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey) ? NO : enabled);
}

%end

%hook BSTimelineFlutterViewController

- (BOOL)enableAd {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey) ? NO : enabled);
}

%end

%hook _TtC6WeChat19MagicAdBrandService

- (BOOL)isBrandTimelineOpen {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook MagicAdPushMgrService

- (void)onServiceInit {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig;
}

- (void)handleAdMsg:(id)message {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(message);
}

- (void)OnGetNewXmlMsg:(id)xml Type:(unsigned int)type MsgWrap:(id)message {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(xml, type, message);
}

- (id)getSpecificSlotMsg:(id)slot withBizName:(id)bizName {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig(slot, bizName);
}

%end


%hook BrandTimelineMsgMgr

- (NSArray *)getInsertedAdCardListWithLimit:(NSUInteger)limit {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return @[];
    return %orig(limit);
}

- (BOOL)isAdDataLegal:(id)data {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig(data);
}

- (BOOL)getAdCardExposeInToday {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return YES;
    return %orig;
}

%end

%hook BoxBrandTimelineMsgMgr

- (NSArray *)getInsertedAdCardListWithLimit:(NSUInteger)limit {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return @[];
    return %orig(limit);
}

- (BOOL)isAdDataLegal:(id)data {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig(data);
}

- (BOOL)getAdCardExposeInToday {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return YES;
    return %orig;
}

%end

%hook WAJSEventHandler_adOperateWXData

- (void)handleJSEvent:(id)event {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(event);
}

%end

%hook WCUserComment

- (BOOL)isAdvertiserComment {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isRefAdvertiserComment {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isAdPreferInfo {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isAtedAdvertiserComment {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isAdBossFirstComment {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isAdBossFirstLike {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (id)adExtInfo {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig;
}

- (void)setAdExtInfo:(id)info {
    %orig(WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey) ? nil : info);
}

%end

%hook BrandTLCanvasCardMgr

+ (BOOL)isAdRequestOpen {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

+ (BOOL)isAdCardOpen {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (void)handleBizAdNotifyNewXml:(id)xml {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(xml);
}

%end


%hook JailBreakHelper

+ (id)loadSetting {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig;
}

- (instancetype)init {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig;
}

+ (NSString *)getJailbreakPath {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig;
}

+ (NSString *)getJailbreakRootDir {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return nil;
    return %orig;
}

+ (BOOL)JailBroken {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)HasInstallJailbreakPluginInvalidIAPPurchase {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)HasInstallJailbreakPlugin:(id)plugin {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig(plugin);
}

- (BOOL)IsJailBreak {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

- (BOOL)isOverADay {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook CUtility

+ (BOOL)isBeingDebugged {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook TSEnvironment

+ (BOOL)isBeingDebugged {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return NO;
    return %orig;
}

%end

%hook ClientCheckMgr

- (void)reportAppList:(id)appList {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(appList);
}

- (void)checkHookWithSeq:(id)sequence {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(sequence);
}

- (void)checkHook:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

- (void)reportFileConsistency:(id)consistency
                     fileName:(id)fileName
                       offset:(unsigned long long)offset
                   bufferSize:(unsigned int)bufferSize
                          seq:(unsigned int)sequence {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(consistency, fileName, offset, bufferSize, sequence);
}

- (void)checkConsistency:(id)value {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig(value);
}

%end

%hook WCCrashBlockExtensionHandler

- (void)renewInfoForReport {
    if (WCAtlasEnhancementEnabled(WCAtlasAdBlockerKey)) return;
    %orig;
}

%end

static void WCAtlasApplyRedEnvelopeDetail(WCRedEnvelopesRedEnvelopesDetailViewController *controller) {
    id delegate = WCAtlasTweakValueForSelectorNames(controller, @[@"m_delegate"]) ?: WCAtlasTweakSafeValue(controller, @"m_delegate");
    Class logicClass = NSClassFromString(@"WCRedEnvelopesReceiveControlLogic");
    if (logicClass && ![delegate isKindOfClass:logicClass]) return;
    id data = WCAtlasTweakValueForSelectorNames(delegate, @[@"m_data"]) ?: WCAtlasTweakSafeValue(delegate, @"m_data");
    Class dataClass = NSClassFromString(@"WCRedEnvelopesControlData");
    if (dataClass && ![data isKindOfClass:dataClass]) return;
    id detail = WCAtlasTweakValueForSelectorNames(data, @[@"m_oWCRedEnvelopesDetailInfo"]) ?:
                WCAtlasTweakSafeValue(data, @"m_oWCRedEnvelopesDetailInfo");
    Class detailClass = NSClassFromString(@"WCRedEnvelopesDetailInfo");
    if (!detail || (detailClass && ![detail isKindOfClass:detailClass])) return;
    UILabel *nickNameLabel = WCAtlasTweakSafeValue(controller, @"nickNameLabel");
    UILabel *receivedInfoLabel = WCAtlasTweakSafeValue(controller, @"m_receivedInfoLable");
    if (![receivedInfoLabel isKindOfClass:[UILabel class]]) return;
    NSAttributedString *original = objc_getAssociatedObject(receivedInfoLabel, &WCAtlasRedEnvelopeOriginalAttributedTextKey);
    if (!original) {
        original = receivedInfoLabel.attributedText ?: [[NSAttributedString alloc] initWithString:receivedInfoLabel.text ?: @""];
        objc_setAssociatedObject(receivedInfoLabel, &WCAtlasRedEnvelopeOriginalAttributedTextKey,
                                 original, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    if (!WCAtlasEnhancementEnabled(WCAtlasRedEnvelopeDetailEnabledKey)) {
        receivedInfoLabel.attributedText = original;
        return;
    }
    if ([nickNameLabel isKindOfClass:[UILabel class]]) {
        NSString *nickName = nickNameLabel.text ?: @"";
        NSRange oldDetail = [nickName rangeOfString:@"\n(¥" options:NSBackwardsSearch];
        if (oldDetail.location != NSNotFound) nickName = [nickName substringToIndex:oldDetail.location];
        nickNameLabel.attributedText = nil;
        nickNameLabel.text = nickName;
    }
    SEL totalAmountSelector = NSSelectorFromString(@"m_lTotalAmount");
    SEL receivedAmountSelector = NSSelectorFromString(@"m_lRecAmount");
    SEL totalCountSelector = NSSelectorFromString(@"m_lTotalNum");
    SEL receivedCountSelector = NSSelectorFromString(@"m_lRecNum");
    long long totalAmount = [detail respondsToSelector:totalAmountSelector]
        ? ((long long (*)(id, SEL))objc_msgSend)(detail, totalAmountSelector)
        : [WCAtlasTweakSafeValue(detail, @"m_lTotalAmount") longLongValue];
    long long receivedAmount = [detail respondsToSelector:receivedAmountSelector]
        ? ((long long (*)(id, SEL))objc_msgSend)(detail, receivedAmountSelector)
        : [WCAtlasTweakSafeValue(detail, @"m_lRecAmount") longLongValue];
    long long totalCount = [detail respondsToSelector:totalCountSelector]
        ? ((long long (*)(id, SEL))objc_msgSend)(detail, totalCountSelector)
        : [WCAtlasTweakSafeValue(detail, @"m_lTotalNum") longLongValue];
    long long receivedCount = [detail respondsToSelector:receivedCountSelector]
        ? ((long long (*)(id, SEL))objc_msgSend)(detail, receivedCountSelector)
        : [WCAtlasTweakSafeValue(detail, @"m_lRecNum") longLongValue];
    double remainingAmount = MAX(0LL, totalAmount - receivedAmount) / 100.0;
    long long remainingCount = MAX(0LL, totalCount - receivedCount);
    NSString *displayText = [NSString stringWithFormat:@"总 %.2f元｜已领 %lld个｜剩余 %lld个 · %.2f元",
                             totalAmount / 100.0, receivedCount, remainingCount, remainingAmount];
    CGFloat size = [[NSUserDefaults standardUserDefaults] doubleForKey:WCAtlasRedEnvelopeDetailFontSizeKey];
    UIFont *font = [UIFont systemFontOfSize:size >= 10.0 && size <= 24.0 ? size : 14.0 weight:UIFontWeightRegular];
    UIColor *color = receivedInfoLabel.textColor ?: [UIColor colorWithWhite:1.0 alpha:0.7];
    receivedInfoLabel.numberOfLines = 1;
    receivedInfoLabel.textAlignment = [[NSUserDefaults standardUserDefaults] boolForKey:WCAtlasRedEnvelopeDetailCenterKey]
        ? NSTextAlignmentCenter
        : NSTextAlignmentNatural;
    receivedInfoLabel.attributedText = [[NSAttributedString alloc] initWithString:displayText
                                                                       attributes:@{NSFontAttributeName: font,
                                                                                    NSForegroundColorAttributeName: color}];
    CGRect frame = receivedInfoLabel.frame;
    frame.size.width = MAX(frame.size.width, 220.0);
    receivedInfoLabel.frame = frame;
    WCAtlasCompatibilityMarkTriggered(@"red-envelope-detail");
}

static BOOL WCAtlasPresentCallConfirmation(VoIPBubbleMessageCellView *cell, BOOL video) {
    UIWindow *window = WCAtlasActiveApplicationWindow();
    UIViewController *presenter = WCAtlasTopControllerForLoginToast(window.rootViewController);
    if (!presenter.view.window || presenter.presentedViewController) return NO;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:video ? @"发起视频通话？" : @"发起语音通话？"
                                                                   message:@"确认后将立即呼叫对方"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak VoIPBubbleMessageCellView *weakCell = cell;
    [alert addAction:[UIAlertAction actionWithTitle:@"呼叫" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        VoIPBubbleMessageCellView *strongCell = weakCell;
        if (!strongCell) return;
        const void *key = video ? &WCAtlasCallVideoConfirmedKey : &WCAtlasCallVoiceConfirmedKey;
        objc_setAssociatedObject(strongCell, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SEL selector = video ? @selector(startVideoVoip) : @selector(startVoiceVoip);
        ((void (*)(id, SEL))objc_msgSend)(strongCell, selector);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
    WCAtlasCompatibilityMarkTriggered(@"call-confirm");
    return YES;
}

%hook WCRedEnvelopesRedEnvelopesDetailViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCAtlasApplyRedEnvelopeDetail(self);
}

%end

%hook VoIPBubbleMessageCellView

- (void)startVoiceVoip {
    if ([objc_getAssociatedObject(self, &WCAtlasCallVoiceConfirmedKey) boolValue]) {
        objc_setAssociatedObject(self, &WCAtlasCallVoiceConfirmedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    if (!WCAtlasEnhancementEnabled(WCAtlasCallConfirmEnabledKey)) {
        %orig;
        return;
    }
    if (!WCAtlasPresentCallConfirmation(self, NO)) {
        %orig;
    }
}

- (void)startVideoVoip {
    if ([objc_getAssociatedObject(self, &WCAtlasCallVideoConfirmedKey) boolValue]) {
        objc_setAssociatedObject(self, &WCAtlasCallVideoConfirmedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    if (!WCAtlasEnhancementEnabled(WCAtlasCallConfirmEnabledKey)) {
        %orig;
        return;
    }
    if (!WCAtlasPresentCallConfirmation(self, YES)) {
        %orig;
    }
}

%end

%hook ScanQRCodeLogicController

- (void)onDetectCodesWithMarkDotInfoList:(id)list isCameraScan:(BOOL)isCameraScan {
    BOOL disguise = WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey);
    if (disguise) WCAtlasCompatibilityMarkTriggered(@"qr-camera-source");
    BOOL cameraScan = disguise ? YES : isCameraScan;
    %orig(list, cameraScan);
}

- (BOOL)isInScanSceneAndUseCameraScan {
    if (WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey)) return YES;
    return %orig;
}

- (NSInteger)fromScene {
    if (WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey)) return 1;
    return %orig;
}

- (NSInteger)m_sourceType {
    if (WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey)) return 0;
    return %orig;
}

- (NSInteger)fromRawScene {
    if (WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey)) return 0;
    return %orig;
}

- (NSInteger)picFrom {
    if (WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey)) return 0;
    return %orig;
}

- (void)setIsFromAlbum:(BOOL)isFromAlbum {
    BOOL value = WCAtlasEnhancementEnabled(WCAtlasQRCodeCameraSourceEnabledKey) ? NO : isFromAlbum;
    %orig(value);
}

%end

%hook MultiDeviceCardLoginContentView

- (void)layoutSubviews {
    %orig;
    WCAtlasCompatibilityMarkTriggered(@"device-login");
    if (!WCAtlasEnhancementEnabled(WCAtlasAutoDeviceLoginKey)) return;
    if ([objc_getAssociatedObject(self, &WCAtlasDeviceCardDidConfirmKey) boolValue]) return;
    objc_setAssociatedObject(self, &WCAtlasDeviceCardDidConfirmKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self onTapConfirmButton];
        WCAtlasLog(@"已自动确认多设备登录");
        WCAtlasShowTransientHUD(@"已自动确认设备登录", @"desktopcomputer");
    });
}

%end

static id (*WCAtlasOriginalRedEnvelopeInitWithData)(id, SEL, id) = NULL;
static id (*WCAtlasOriginalRedEnvelopeInitWithDataSceneType)(id, SEL, id, NSUInteger, NSUInteger) = NULL;
static void (*WCAtlasOriginalRedEnvelopeSetupWithData)(id, SEL, id) = NULL;
static void (*WCAtlasOriginalRedEnvelopeRefreshWithData)(id, SEL, id) = NULL;
static NSInteger (*WCAtlasOriginalRedEnvelopeSetupCurrentMode)(id, SEL) = NULL;
static void (*WCAtlasOriginalRedEnvelopeViewDidLoad)(id, SEL) = NULL;

static void WCAtlasApplyExclusiveRedEnvelopeContact(id controller, id data) {
    id contact = objc_getAssociatedObject(data, &WCAtlasExclusiveRedEnvelopeContactKey);
    if (!controller || !data || !contact) return;
    objc_setAssociatedObject(controller, &WCAtlasExclusiveRedEnvelopeViewContactKey,
                             contact, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCAtlasExclusiveRedEnvelopeViewDataKey,
                             data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SEL selector = NSSelectorFromString(@"setSelectedMemberContact:");
    if ([data respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(data, selector, contact);
    }
}

static BOOL WCAtlasRedEnvelopeControllerIsExclusive(id controller) {
    SEL selector = NSSelectorFromString(@"isExclusiveHbMode");
    return [controller respondsToSelector:selector] &&
           ((BOOL (*)(id, SEL))objc_msgSend)(controller, selector);
}

static void WCAtlasSetRedEnvelopeControllerMode(id controller, NSInteger mode) {
    SEL selector = NSSelectorFromString(@"setCurrentMode:");
    if ([controller respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(controller, selector, mode);
    }
}

static void WCAtlasSetExclusiveRedEnvelopeData(id data, id contact, NSInteger mode) {
    SEL modeSelector = NSSelectorFromString(@"setCurrentLaunchRedEnvMode:");
    if ([data respondsToSelector:modeSelector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(data, modeSelector, mode);
    }
    SEL contactSelector = NSSelectorFromString(@"setSelectedMemberContact:");
    if ([data respondsToSelector:contactSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(data, contactSelector, contact);
    }
}

static NSInteger WCAtlasSelectExclusiveRedEnvelopeMode(id controller,
                                                      NSInteger originalMode,
                                                      BOOL reloadContent) {
    id contact = objc_getAssociatedObject(controller, &WCAtlasExclusiveRedEnvelopeViewContactKey);
    id data = objc_getAssociatedObject(controller, &WCAtlasExclusiveRedEnvelopeViewDataKey);
    if (!contact || !data) return originalMode;
    if (reloadContent && WCAtlasRedEnvelopeControllerIsExclusive(controller)) return originalMode;

    for (NSInteger mode = 0; mode < 9; mode++) {
        WCAtlasSetRedEnvelopeControllerMode(controller, mode);
        if (!WCAtlasRedEnvelopeControllerIsExclusive(controller)) continue;
        WCAtlasSetRedEnvelopeControllerMode(controller, mode);
        WCAtlasSetExclusiveRedEnvelopeData(data, contact, mode);
        if (reloadContent) {
            SEL reloadSelector = NSSelectorFromString(@"reloadContentView");
            if ([controller respondsToSelector:reloadSelector]) {
                ((void (*)(id, SEL))objc_msgSend)(controller, reloadSelector);
            }
        }
        return mode;
    }
    if (!reloadContent) WCAtlasSetRedEnvelopeControllerMode(controller, originalMode);
    return originalMode;
}

static id WCAtlasRedEnvelopeInitWithData(id self, SEL command, id data) {
    WCAtlasPrepareExclusiveRedEnvelopeData(data);
    return WCAtlasOriginalRedEnvelopeInitWithData
        ? WCAtlasOriginalRedEnvelopeInitWithData(self, command, data) : nil;
}

static id WCAtlasRedEnvelopeInitWithDataSceneType(id self,
                                                SEL command,
                                                id data,
                                                NSUInteger scene,
                                                NSUInteger type) {
    WCAtlasPrepareExclusiveRedEnvelopeData(data);
    return WCAtlasOriginalRedEnvelopeInitWithDataSceneType
        ? WCAtlasOriginalRedEnvelopeInitWithDataSceneType(self, command, data, scene, type) : nil;
}

static void WCAtlasRedEnvelopeSetupWithData(id self, SEL command, id data) {
    WCAtlasApplyExclusiveRedEnvelopeContact(self, data);
    if (WCAtlasOriginalRedEnvelopeSetupWithData) {
        WCAtlasOriginalRedEnvelopeSetupWithData(self, command, data);
    }
}

static void WCAtlasRedEnvelopeRefreshWithData(id self, SEL command, id data) {
    WCAtlasApplyExclusiveRedEnvelopeContact(self, data);
    if (WCAtlasOriginalRedEnvelopeRefreshWithData) {
        WCAtlasOriginalRedEnvelopeRefreshWithData(self, command, data);
    }
}

static NSInteger WCAtlasRedEnvelopeSetupCurrentMode(id self, SEL command) {
    NSInteger originalMode = WCAtlasOriginalRedEnvelopeSetupCurrentMode
        ? WCAtlasOriginalRedEnvelopeSetupCurrentMode(self, command) : 0;
    return WCAtlasSelectExclusiveRedEnvelopeMode(self, originalMode, NO);
}

static void WCAtlasRedEnvelopeViewDidLoad(id self, SEL command) {
    if (WCAtlasOriginalRedEnvelopeViewDidLoad) WCAtlasOriginalRedEnvelopeViewDidLoad(self, command);
    (void)WCAtlasSelectExclusiveRedEnvelopeMode(self, 0, YES);
}

static const char *WCAtlasUnqualifiedMethodType(const char *type) {
    if (!type) return "";
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

static BOOL WCAtlasMethodReturnsVoid(Method method) {
    char *type = method ? method_copyReturnType(method) : NULL;
    BOOL matches = type && strcmp(WCAtlasUnqualifiedMethodType(type), @encode(void)) == 0;
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodArgumentIsObject(Method method, unsigned int index) {
    char *type = method ? method_copyArgumentType(method, index) : NULL;
    BOOL matches = WCAtlasUnqualifiedMethodType(type)[0] == '@';
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodArgumentIsSelector(Method method, unsigned int index) {
    char *type = method ? method_copyArgumentType(method, index) : NULL;
    BOOL matches = type && strcmp(WCAtlasUnqualifiedMethodType(type), @encode(SEL)) == 0;
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodReturnsObject(Method method) {
    char *type = method ? method_copyReturnType(method) : NULL;
    BOOL matches = WCAtlasUnqualifiedMethodType(type)[0] == '@';
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodTypeIsInteger(const char *type) {
    const char value = WCAtlasUnqualifiedMethodType(type)[0];
    return value && strchr("cCsSiIlLqQB", value) != NULL;
}

static BOOL WCAtlasMethodReturnsInteger(Method method) {
    char *type = method ? method_copyReturnType(method) : NULL;
    BOOL matches = WCAtlasMethodTypeIsInteger(type);
    if (type) free(type);
    return matches;
}

static BOOL WCAtlasMethodArgumentIsInteger(Method method, unsigned int index) {
    char *type = method ? method_copyArgumentType(method, index) : NULL;
    BOOL matches = WCAtlasMethodTypeIsInteger(type);
    if (type) free(type);
    return matches;
}

typedef void (*WCAtlasAudioDeviceStartedSuccessIMP)(id, SEL, uintptr_t);
static WCAtlasAudioDeviceStartedSuccessIMP WCAtlasOriginalAudioDeviceStartedSuccess;

static void WCAtlasAudioDeviceStartedSuccess(id self, SEL selector, uintptr_t value) {
    if (WCAtlasOriginalAudioDeviceStartedSuccess) {
        WCAtlasOriginalAudioDeviceStartedSuccess(self, selector, value);
    }
    WCAtlasCallAudioNotifyAudioDeviceStarted();
    if (!WCAtlasEnhancementEnabled(WCAtlasAutoSpeakerphoneEnabledKey)) return;
    SEL audioModeSelector = NSSelectorFromString(@"isAudioMode");
    if (![self respondsToSelector:audioModeSelector] ||
        !((BOOL (*)(id, SEL))objc_msgSend)(self, audioModeSelector)) return;
    SEL speakerSelector = NSSelectorFromString(@"SetSpeakerPhone:");
    if (![self respondsToSelector:speakerSelector]) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, speakerSelector, YES);
    WCAtlasCompatibilityMarkTriggered(@"auto-speakerphone");
}

static void WCAtlasInstallAutoSpeakerphoneHook(void) {
    Class managerClass = NSClassFromString(@"VoipUIManager");
    SEL selector = NSSelectorFromString(@"audioDeviceStartedSuccess:");
    Method method = managerClass ? class_getInstanceMethod(managerClass, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 3 || !WCAtlasMethodReturnsVoid(method) ||
        (!WCAtlasMethodArgumentIsObject(method, 2) && !WCAtlasMethodArgumentIsInteger(method, 2))) return;
    IMP original = NULL;
    MSHookMessageEx(managerClass, selector, (IMP)WCAtlasAudioDeviceStartedSuccess, &original);
    WCAtlasOriginalAudioDeviceStartedSuccess = (WCAtlasAudioDeviceStartedSuccessIMP)original;
}

static void WCAtlasInstallExclusiveRedEnvelopeHooks(void) {
    Class logicClass = NSClassFromString(@"WCRedEnvelopesSendControlLogic");
    if (logicClass) {
        SEL selector = NSSelectorFromString(@"initWithData:");
        Method method = class_getInstanceMethod(logicClass, selector);
        if (method && method_getNumberOfArguments(method) == 3 &&
            WCAtlasMethodReturnsObject(method) && WCAtlasMethodArgumentIsObject(method, 2)) {
            IMP original = NULL;
            MSHookMessageEx(logicClass, selector, (IMP)WCAtlasRedEnvelopeInitWithData, &original);
            WCAtlasOriginalRedEnvelopeInitWithData =
                (id (*)(id, SEL, id))original;
        }

        selector = NSSelectorFromString(@"initWithData:Scene:RedEnvelopesType:");
        method = class_getInstanceMethod(logicClass, selector);
        if (method && method_getNumberOfArguments(method) == 5 &&
            WCAtlasMethodReturnsObject(method) && WCAtlasMethodArgumentIsObject(method, 2) &&
            WCAtlasMethodArgumentIsInteger(method, 3) && WCAtlasMethodArgumentIsInteger(method, 4)) {
            IMP original = NULL;
            MSHookMessageEx(logicClass, selector,
                            (IMP)WCAtlasRedEnvelopeInitWithDataSceneType, &original);
            WCAtlasOriginalRedEnvelopeInitWithDataSceneType =
                (id (*)(id, SEL, id, NSUInteger, NSUInteger))original;
        }
    }

    Class controllerClass = NSClassFromString(@"WCRedEnvelopesMakeRedEnvelopesViewController");
    if (!controllerClass) return;

    SEL selector = NSSelectorFromString(@"setupWithData:");
    Method method = class_getInstanceMethod(controllerClass, selector);
    if (method && method_getNumberOfArguments(method) == 3 &&
        WCAtlasMethodReturnsVoid(method) && WCAtlasMethodArgumentIsObject(method, 2)) {
        IMP original = NULL;
        MSHookMessageEx(controllerClass, selector, (IMP)WCAtlasRedEnvelopeSetupWithData, &original);
        WCAtlasOriginalRedEnvelopeSetupWithData = (void (*)(id, SEL, id))original;
    }

    selector = NSSelectorFromString(@"refreshViewWithData:");
    method = class_getInstanceMethod(controllerClass, selector);
    if (method && method_getNumberOfArguments(method) == 3 &&
        WCAtlasMethodReturnsVoid(method) && WCAtlasMethodArgumentIsObject(method, 2)) {
        IMP original = NULL;
        MSHookMessageEx(controllerClass, selector, (IMP)WCAtlasRedEnvelopeRefreshWithData, &original);
        WCAtlasOriginalRedEnvelopeRefreshWithData = (void (*)(id, SEL, id))original;
    }

    selector = NSSelectorFromString(@"setupCurrentMode");
    method = class_getInstanceMethod(controllerClass, selector);
    if (method && method_getNumberOfArguments(method) == 2 && WCAtlasMethodReturnsInteger(method)) {
        IMP original = NULL;
        MSHookMessageEx(controllerClass, selector, (IMP)WCAtlasRedEnvelopeSetupCurrentMode, &original);
        WCAtlasOriginalRedEnvelopeSetupCurrentMode = (NSInteger (*)(id, SEL))original;
    }

    selector = NSSelectorFromString(@"viewDidLoad");
    method = class_getInstanceMethod(controllerClass, selector);
    if (method && method_getNumberOfArguments(method) == 2 && WCAtlasMethodReturnsVoid(method)) {
        IMP original = NULL;
        MSHookMessageEx(controllerClass, selector, (IMP)WCAtlasRedEnvelopeViewDidLoad, &original);
        WCAtlasOriginalRedEnvelopeViewDidLoad = (void (*)(id, SEL))original;
    }
}

%hook MMAuthorizeUserInfoViewController

- (void)viewDidLayoutSubviews {
    %orig;
    WCAtlasTryAuthorizeGame(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCAtlasCompatibilityMarkTriggered(@"game-login");
    if (WCAtlasTryAuthorizeGame(self)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasTryAuthorizeGame(self);
    });
}

%end

%ctor {
    WCAtlasInstallPluginRegistry();
    %init;
    WCAtlasAutomationStart();
    WCAtlasMomentsCommentAntiDeleteInstallHooks();
    WCAtlasMomentsTailInstallHooks();
    WCAtlasCallAudioInstallHooks();
    WCAtlasMentionHighlightInstallHooks();
    WCAtlasInstallChatTTSSendEntryHooks();
    WCAtlasInstallAutoSpeakerphoneHook();
    WCAtlasInstallExclusiveRedEnvelopeHooks();
    if ([CADisplayLink instancesRespondToSelector:@selector(setPreferredFrameRateRange:)]) {
        %init(WCAtlasHighRefreshRateRange);
    }
}
