#import "WCAtlasInterfaceTweaks.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "WCAtlasCompatibility.h"
#import "WCAtlasEnhancements.h"

NSString *const WCAtlasChatInputRoundingEnabledKey = @"com.qiu7c.wcatlas.interface.chat-input-rounding";
NSString *const WCAtlasChatInputInnerRoundingKey = @"com.qiu7c.wcatlas.interface.chat-input-rounding.inner";
NSString *const WCAtlasChatInputOuterRoundingKey = @"com.qiu7c.wcatlas.interface.chat-input-rounding.outer";
NSString *const WCAtlasChatInputInnerRadiusKey = @"com.qiu7c.wcatlas.interface.chat-input-rounding.inner-radius";
NSString *const WCAtlasChatInputOuterRadiusKey = @"com.qiu7c.wcatlas.interface.chat-input-rounding.outer-radius";
NSString *const WCAtlasHideChatMuteIconKey = @"com.qiu7c.wcatlas.interface.hide-chat-mute-icon";
NSString *const WCAtlasGlobalAvatarRoundingEnabledKey = @"com.qiu7c.wcatlas.interface.global-avatar-rounding";
NSString *const WCAtlasGlobalAvatarCornerPercentKey = @"com.qiu7c.wcatlas.interface.global-avatar-corner-percent";

static UIColor *WCAtlasEffectiveBackgroundColorForView(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        UIColor *color = candidate.backgroundColor;
        if (color && CGColorGetAlpha(color.CGColor) > 0.01) return color;
    }
    return UIColor.systemGroupedBackgroundColor;
}

static void WCAtlasMatchSearchBarChrome(UIView *view, UITextField *textField, UIColor *backgroundColor) {
    for (UIView *subview in view.subviews) {
        NSString *className = NSStringFromClass(subview.class);
        if ([className containsString:@"UISearchBarBackground"] ||
            [className isEqualToString:@"_UISearchBarBackground"]) {
            subview.hidden = NO;
            subview.alpha = 1.0;
            subview.backgroundColor = backgroundColor;
            subview.layer.backgroundColor = backgroundColor.CGColor;
            if ([subview isKindOfClass:UIImageView.class]) {
                ((UIImageView *)subview).image = nil;
            }
        }
        if (subview != textField && ![subview isDescendantOfView:textField]) {
            WCAtlasMatchSearchBarChrome(subview, textField, backgroundColor);
        }
    }
}

static UIImage *WCAtlasTransparentSearchBackgroundImage(void) {
    static UIImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0, 1.0), NO, 0.0);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@interface WCAtlasSearchTableHeaderView : UIView
@property (nonatomic, weak) UISearchBar *searchBar;
@end

@implementation WCAtlasSearchTableHeaderView

- (void)layoutSubviews {
    [super layoutSubviews];
    UISearchBar *searchBar = self.searchBar;
    if (!searchBar) return;
    searchBar.frame = CGRectMake(0.0, 4.0, CGRectGetWidth(self.bounds),
                                 MAX(0.0, CGRectGetHeight(self.bounds) - 8.0));
    UIColor *backgroundColor = WCAtlasEffectiveBackgroundColorForView(self);
    searchBar.backgroundColor = backgroundColor;
    searchBar.layer.backgroundColor = backgroundColor.CGColor;
    WCAtlasMatchSearchBarChrome(searchBar, searchBar.searchTextField, backgroundColor);
}

@end

void WCAtlasStyleSearchBar(UISearchBar *searchBar) {
    if (!searchBar) return;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    UIImage *transparentImage = WCAtlasTransparentSearchBackgroundImage();
    searchBar.backgroundImage = transparentImage;
    searchBar.scopeBarBackgroundImage = transparentImage;
    UIColor *backgroundColor = WCAtlasEffectiveBackgroundColorForView(searchBar.superview);
    searchBar.backgroundColor = backgroundColor;
    searchBar.barTintColor = backgroundColor;
    searchBar.translucent = NO;
    searchBar.opaque = NO;
    searchBar.layer.backgroundColor = backgroundColor.CGColor;
    UITextField *textField = searchBar.searchTextField;
    WCAtlasMatchSearchBarChrome(searchBar, textField, backgroundColor);
    textField.backgroundColor = UIColor.secondarySystemFillColor;
    textField.layer.backgroundColor = UIColor.secondarySystemFillColor.CGColor;
    textField.borderStyle = UITextBorderStyleNone;
    textField.layer.cornerRadius = 14.0;
    textField.layer.cornerCurve = kCACornerCurveContinuous;
    textField.layer.masksToBounds = YES;
}

void WCAtlasInstallSearchBarInTableView(UISearchBar *searchBar, UITableView *tableView) {
    if (!searchBar || !tableView) return;
    CGFloat width = CGRectGetWidth(tableView.bounds);
    WCAtlasSearchTableHeaderView *header = [[WCAtlasSearchTableHeaderView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, width, 60.0)];
    UIColor *backgroundColor = WCAtlasEffectiveBackgroundColorForView(tableView);
    header.backgroundColor = backgroundColor;
    header.layer.backgroundColor = backgroundColor.CGColor;
    header.opaque = YES;
    header.searchBar = searchBar;
    searchBar.frame = CGRectMake(0.0, 4.0, width, 52.0);
    searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:searchBar];
    WCAtlasStyleSearchBar(searchBar);
    tableView.tableHeaderView = header;
}

static char WCAtlasOriginalCornerRadiusKey;
static char WCAtlasOriginalMasksToBoundsKey;
static char WCAtlasOriginalCornerCurveKey;
static char WCAtlasRoundingStateSavedKey;
static char WCAtlasRoundingAppliedToToolViewKey;
static char WCAtlasRoundingConfigurationKey;
static char WCAtlasOriginalMuteIconHiddenKey;
static char WCAtlasOriginalMuteMemberLabelHiddenKey;
static char WCAtlasGlobalAvatarOriginalCornerRadiusKey;
static char WCAtlasGlobalAvatarOriginalMasksToBoundsKey;
static char WCAtlasGlobalAvatarOriginalCornerCurveKey;
static char WCAtlasGlobalAvatarStateSavedKey;
static char WCAtlasGlobalAvatarTargetViewKey;
static char WCAtlasGlobalAvatarExcludedKey;
static BOOL WCAtlasGlobalAvatarConfigurationEnabled = NO;
static CGFloat WCAtlasGlobalAvatarConfigurationRatio = 1.0;

static NSHashTable<UIView *> *WCAtlasTrackedGlobalAvatarViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}

static void WCAtlasRegisterGlobalAvatarDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSUserDefaults.standardUserDefaults registerDefaults:@{
            WCAtlasGlobalAvatarRoundingEnabledKey: @NO,
            WCAtlasGlobalAvatarCornerPercentKey: @100.0,
        }];
    });
}

static void WCAtlasReloadGlobalAvatarConfiguration(void) {
    WCAtlasRegisterGlobalAvatarDefaults();
    WCAtlasGlobalAvatarConfigurationEnabled = WCAtlasEnhancementEnabled(WCAtlasGlobalAvatarRoundingEnabledKey);
    CGFloat percent = [NSUserDefaults.standardUserDefaults doubleForKey:WCAtlasGlobalAvatarCornerPercentKey];
    WCAtlasGlobalAvatarConfigurationRatio = MIN(100.0, MAX(0.0, percent)) / 100.0;
}

static void WCAtlasEnsureGlobalAvatarConfiguration(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ WCAtlasReloadGlobalAvatarConfiguration(); });
}

static NSHashTable<UIImageView *> *WCAtlasHiddenMuteImageViews(void) {
    static NSHashTable<UIImageView *> *imageViews;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageViews = [NSHashTable weakObjectsHashTable];
    });
    return imageViews;
}

static NSHashTable<UILabel *> *WCAtlasHiddenMuteMemberLabels(void) {
    static NSHashTable<UILabel *> *labels;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        labels = [NSHashTable weakObjectsHashTable];
    });
    return labels;
}

static void WCAtlasRegisterChatInputRoundingDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            WCAtlasChatInputRoundingEnabledKey: @NO,
            WCAtlasChatInputInnerRoundingKey: @YES,
            WCAtlasChatInputOuterRoundingKey: @YES,
            WCAtlasChatInputInnerRadiusKey: @18.0,
            WCAtlasChatInputOuterRadiusKey: @22.0,
        }];
    });
}

static id WCAtlasInterfaceSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static UIView *WCAtlasInterfaceViewValue(id object, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = WCAtlasInterfaceSafeValue(object, key);
        if ([value isKindOfClass:[UIView class]]) return value;
    }
    return nil;
}

static CGFloat WCAtlasGlobalAvatarCornerRatio(void) {
    WCAtlasEnsureGlobalAvatarConfiguration();
    return WCAtlasGlobalAvatarConfigurationRatio;
}

static UIView *WCAtlasGlobalAvatarTargetView(UIView *headView) {
    SEL selector = NSSelectorFromString(@"headImageView");
    if ([headView respondsToSelector:selector]) {
        id target = ((id (*)(id, SEL))objc_msgSend)(headView, selector);
        if ([target isKindOfClass:UIView.class]) return target;
    }
    return headView;
}

static void WCAtlasRestoreGlobalAvatarRounding(UIView *headView) {
    UIView *target = objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarTargetViewKey);
    if (!target) target = headView;
    if (![objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarStateSavedKey) boolValue]) return;
    target.layer.cornerRadius = [objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerRadiusKey) doubleValue];
    target.layer.masksToBounds = [objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalMasksToBoundsKey) boolValue];
    NSString *curve = objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerCurveKey);
    if (curve.length > 0) target.layer.cornerCurve = curve;
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarStateSavedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarTargetViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerRadiusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalMasksToBoundsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerCurveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(UIView *headView) {
    return [objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarExcludedKey) boolValue];
}

void WCAtlasExcludeHeadViewFromGlobalAvatarRounding(UIView *headView) {
    if (!headView) return;
    objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarExcludedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasRestoreGlobalAvatarRounding(headView);
    [WCAtlasTrackedGlobalAvatarViews() removeObject:headView];
}

void WCAtlasApplyGlobalAvatarRoundingToHeadView(UIView *headView) {
    if (!headView) return;
    WCAtlasEnsureGlobalAvatarConfiguration();
    if (WCAtlasHeadViewIsExcludedFromGlobalAvatarRounding(headView)) {
        WCAtlasRestoreGlobalAvatarRounding(headView);
        [WCAtlasTrackedGlobalAvatarViews() removeObject:headView];
        return;
    }
    [WCAtlasTrackedGlobalAvatarViews() addObject:headView];
    NSNumber *saved = objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarStateSavedKey);
    if (!WCAtlasGlobalAvatarConfigurationEnabled) {
        if (!saved.boolValue) return;
        WCAtlasRestoreGlobalAvatarRounding(headView);
        return;
    }
    UIView *target = WCAtlasGlobalAvatarTargetView(headView);
    UIView *savedTarget = objc_getAssociatedObject(headView, &WCAtlasGlobalAvatarTargetViewKey);
    if (saved.boolValue && savedTarget != target) {
        WCAtlasRestoreGlobalAvatarRounding(headView);
        saved = nil;
    }
    if (!saved.boolValue) {
        objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarTargetViewKey,
                                 target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerRadiusKey,
                                 @(target.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalMasksToBoundsKey,
                                 @(target.layer.masksToBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarOriginalCornerCurveKey,
                                 target.layer.cornerCurve ?: kCACornerCurveCircular,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(headView, &WCAtlasGlobalAvatarStateSavedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat width = CGRectGetWidth(target.bounds);
    CGFloat height = CGRectGetHeight(target.bounds);
    if (width <= 0.0 || height <= 0.0) return;
    CGFloat radius = MIN(width, height) * 0.5 * WCAtlasGlobalAvatarCornerRatio();
    if (fabs(target.layer.cornerRadius - radius) > 0.01) target.layer.cornerRadius = radius;
    if (![target.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) {
        target.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (!target.layer.masksToBounds) target.layer.masksToBounds = YES;
}

void WCAtlasRefreshTrackedGlobalAvatarViews(void) {
    WCAtlasReloadGlobalAvatarConfiguration();
    for (UIView *headView in WCAtlasTrackedGlobalAvatarViews().allObjects) {
        WCAtlasApplyGlobalAvatarRoundingToHeadView(headView);
    }
}

unsigned int WCAtlasGlobalAvatarScaledCornerSize(unsigned int originalSize) {
    WCAtlasEnsureGlobalAvatarConfiguration();
    if (!WCAtlasGlobalAvatarConfigurationEnabled) return originalSize;
    return (unsigned int)lrint((double)originalSize * WCAtlasGlobalAvatarCornerRatio());
}

static UIView *WCAtlasFindSubviewOfClassName(UIView *view, NSString *className) {
    if (!view) return nil;
    if ([NSStringFromClass(view.class) isEqualToString:className]) return view;
    for (UIView *subview in view.subviews) {
        UIView *match = WCAtlasFindSubviewOfClassName(subview, className);
        if (match) return match;
    }
    return nil;
}

static void WCAtlasSetRoundedState(UIView *view, BOOL enabled, CGFloat maximumRadius) {
    if (!view) return;
    if (enabled) {
        if (![objc_getAssociatedObject(view, &WCAtlasRoundingStateSavedKey) boolValue]) {
            objc_setAssociatedObject(view, &WCAtlasOriginalCornerRadiusKey, @(view.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &WCAtlasOriginalMasksToBoundsKey, @(view.layer.masksToBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &WCAtlasOriginalCornerCurveKey, view.layer.cornerCurve ?: kCACornerCurveCircular, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(view, &WCAtlasRoundingStateSavedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGFloat height = CGRectGetHeight(view.bounds);
        CGFloat radius = height > 0.0 ? MIN(maximumRadius, height * 0.5) : maximumRadius;
        if (ABS(view.layer.cornerRadius - radius) > 0.01) view.layer.cornerRadius = radius;
        if (![view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) view.layer.cornerCurve = kCACornerCurveContinuous;
        if (!view.layer.masksToBounds) view.layer.masksToBounds = YES;
        return;
    }
    if (![objc_getAssociatedObject(view, &WCAtlasRoundingStateSavedKey) boolValue]) return;
    view.layer.cornerRadius = [objc_getAssociatedObject(view, &WCAtlasOriginalCornerRadiusKey) doubleValue];
    view.layer.masksToBounds = [objc_getAssociatedObject(view, &WCAtlasOriginalMasksToBoundsKey) boolValue];
    NSString *cornerCurve = objc_getAssociatedObject(view, &WCAtlasOriginalCornerCurveKey);
    if (cornerCurve.length > 0) view.layer.cornerCurve = cornerCurve;
    objc_setAssociatedObject(view, &WCAtlasRoundingStateSavedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &WCAtlasOriginalCornerRadiusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &WCAtlasOriginalMasksToBoundsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &WCAtlasOriginalCornerCurveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void WCAtlasApplyChatInputRoundingToToolView(UIView *inputToolView) {
    if (!inputToolView) return;
    // Register fallback values on the chat path itself. The settings controller may
    // never have been opened in this process, especially immediately after launch.
    WCAtlasRegisterChatInputRoundingDefaults();
    static dispatch_once_t compatibilityOnce;
    dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"input-rounding"); });

    BOOL masterEnabled = WCAtlasEnhancementEnabled(WCAtlasChatInputRoundingEnabledKey);
    BOOL wasApplied = [objc_getAssociatedObject(inputToolView, &WCAtlasRoundingAppliedToToolViewKey) boolValue];
    // The common disabled path must not walk WeChat's input hierarchy during a
    // chat transition. Only revisit the hierarchy when there is state to restore.
    if (!masterEnabled && !wasApplied) return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL innerEnabled = masterEnabled && [defaults boolForKey:WCAtlasChatInputInnerRoundingKey];
    BOOL outerEnabled = masterEnabled && [defaults boolForKey:WCAtlasChatInputOuterRoundingKey];
    CGFloat innerRadius = [defaults objectForKey:WCAtlasChatInputInnerRadiusKey] ? [defaults doubleForKey:WCAtlasChatInputInnerRadiusKey] : 18.0;
    CGFloat outerRadius = [defaults objectForKey:WCAtlasChatInputOuterRadiusKey] ? [defaults doubleForKey:WCAtlasChatInputOuterRadiusKey] : 22.0;
    NSString *configuration = masterEnabled
        ? [NSString stringWithFormat:@"%d:%d:%.2f:%.2f", innerEnabled, outerEnabled, innerRadius, outerRadius]
        : nil;
    if (wasApplied && [configuration isEqualToString:objc_getAssociatedObject(inputToolView, &WCAtlasRoundingConfigurationKey)]) return;

    // Verified on the current WeChat build: the first UIView under MMInputToolView
    // is the visible outer toolbar background.
    UIView *outerBar = inputToolView.subviews.firstObject;
    UIView *growTextView = WCAtlasInterfaceViewValue(inputToolView, @[@"textView", @"_textView"]);
    if (![NSStringFromClass(growTextView.class) containsString:@"MMGrowTextView"]) {
        growTextView = WCAtlasFindSubviewOfClassName(inputToolView, @"MMGrowTextView");
    }

    WCAtlasSetRoundedState(growTextView, innerEnabled, MIN(40.0, MAX(0.0, innerRadius)));
    if (outerBar != growTextView) WCAtlasSetRoundedState(outerBar, outerEnabled, MIN(40.0, MAX(0.0, outerRadius)));
    objc_setAssociatedObject(inputToolView, &WCAtlasRoundingAppliedToToolViewKey,
                             masterEnabled ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(inputToolView, &WCAtlasRoundingConfigurationKey,
                             configuration, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void WCAtlasRestoreChatInputRoundingFromToolView(UIView *inputToolView) {
    if (!inputToolView) return;
    UIView *outerBar = inputToolView.subviews.firstObject;
    UIView *growTextView = WCAtlasInterfaceViewValue(inputToolView, @[@"textView", @"_textView"]);
    if (![NSStringFromClass(growTextView.class) containsString:@"MMGrowTextView"]) {
        growTextView = WCAtlasFindSubviewOfClassName(inputToolView, @"MMGrowTextView");
    }
    WCAtlasSetRoundedState(growTextView, NO, 0.0);
    if (outerBar != growTextView) WCAtlasSetRoundedState(outerBar, NO, 0.0);
}

BOOL WCAtlasShouldForceHideChatMuteImageView(UIImageView *imageView) {
    if (![imageView.accessibilityLabel isEqualToString:@"免打扰"]) return NO;
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ WCAtlasHideChatMuteIconKey: @NO }];
    return WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey);
}

BOOL WCAtlasShouldKeepManagedChatMuteImageViewHidden(UIImageView *imageView) {
    if (!objc_getAssociatedObject(imageView, &WCAtlasOriginalMuteIconHiddenKey)) return NO;
    return WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey);
}

static UIImageView *WCAtlasChatMuteImageViewBesideLabel(UILabel *label) {
    UIView *container = label.superview;
    if (!container || ![NSStringFromClass(label.class) isEqualToString:@"MMUILabel"]) return nil;
    NSString *text = label.text;
    if (text.length < 3 || ![text hasPrefix:@"("] || ![text hasSuffix:@")"]) return nil;
    NSString *memberCount = [text substringWithRange:NSMakeRange(1, text.length - 2)];
    NSCharacterSet *nonDigits = [NSCharacterSet decimalDigitCharacterSet].invertedSet;
    if (memberCount.length == 0 ||
        [memberCount rangeOfCharacterFromSet:nonDigits].location != NSNotFound) return nil;
    CGRect labelFrame = label.frame;
    for (UIView *subview in container.subviews) {
        if (![subview isKindOfClass:[UIImageView class]]) continue;
        UIImageView *imageView = (UIImageView *)subview;
        if (![imageView.accessibilityLabel isEqualToString:@"免打扰"]) continue;
        CGRect imageFrame = imageView.frame;
        BOOL immediatelyBeforeIcon = CGRectGetMaxX(labelFrame) <= CGRectGetMinX(imageFrame) + 2.0 &&
                                     CGRectGetMinX(imageFrame) - CGRectGetMaxX(labelFrame) <= 8.0;
        BOOL verticallyAligned = CGRectGetMaxY(labelFrame) > CGRectGetMinY(imageFrame) &&
                                 CGRectGetMinY(labelFrame) < CGRectGetMaxY(imageFrame);
        if (immediatelyBeforeIcon && verticallyAligned) return imageView;
    }
    return nil;
}

BOOL WCAtlasShouldKeepManagedChatMuteMemberLabelHidden(UILabel *label) {
    if (!objc_getAssociatedObject(label, &WCAtlasOriginalMuteMemberLabelHiddenKey)) return NO;
    return WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey);
}

void WCAtlasUpdateChatMuteMemberLabel(UILabel *label) {
    if (!label) return;
    NSNumber *savedHidden = objc_getAssociatedObject(label, &WCAtlasOriginalMuteMemberLabelHiddenKey);
    BOOL shouldHide = WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey) &&
                      WCAtlasChatMuteImageViewBesideLabel(label) != nil;
    if (shouldHide) {
        if (!savedHidden) {
            objc_setAssociatedObject(label, &WCAtlasOriginalMuteMemberLabelHiddenKey,
                                     @(label.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [WCAtlasHiddenMuteMemberLabels() addObject:label];
        label.hidden = YES;
    } else if (savedHidden) {
        label.hidden = savedHidden.boolValue;
        [WCAtlasHiddenMuteMemberLabels() removeObject:label];
        objc_setAssociatedObject(label, &WCAtlasOriginalMuteMemberLabelHiddenKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void WCAtlasUpdateChatMuteImageView(UIImageView *imageView) {
    if (!imageView) return;
    NSNumber *savedHidden = objc_getAssociatedObject(imageView, &WCAtlasOriginalMuteIconHiddenKey);
    if (WCAtlasShouldForceHideChatMuteImageView(imageView)) {
        static dispatch_once_t compatibilityOnce;
        dispatch_once(&compatibilityOnce, ^{ WCAtlasCompatibilityMarkTriggered(@"hide-chat-mute-icon"); });
        if (!savedHidden) {
            objc_setAssociatedObject(imageView, &WCAtlasOriginalMuteIconHiddenKey, @(imageView.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [WCAtlasHiddenMuteImageViews() addObject:imageView];
        imageView.hidden = YES;
    } else if (savedHidden) {
        imageView.hidden = savedHidden.boolValue;
        [WCAtlasHiddenMuteImageViews() removeObject:imageView];
        objc_setAssociatedObject(imageView, &WCAtlasOriginalMuteIconHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIView *subview in imageView.superview.subviews) {
        if ([NSStringFromClass(subview.class) isEqualToString:@"MMUILabel"]) {
            WCAtlasUpdateChatMuteMemberLabel((UILabel *)subview);
        }
    }
}

static void WCAtlasUpdateMuteIconInView(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:[UIImageView class]]) WCAtlasUpdateChatMuteImageView((UIImageView *)view);
    for (UIView *subview in view.subviews) WCAtlasUpdateMuteIconInView(subview);
}

void WCAtlasUpdateChatMuteIconVisibility(UIViewController *controller) {
    if (!controller.isViewLoaded) return;
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ WCAtlasHideChatMuteIconKey: @NO }];
    BOOL hideIcon = WCAtlasEnhancementEnabled(WCAtlasHideChatMuteIconKey);
    if (!hideIcon) {
        // Restore only views that WCAtlas actually changed. Do not recursively scan
        // the full chat hierarchy while the feature is disabled.
        for (UIImageView *imageView in WCAtlasHiddenMuteImageViews().allObjects) {
            WCAtlasUpdateChatMuteImageView(imageView);
        }
        for (UILabel *label in WCAtlasHiddenMuteMemberLabels().allObjects) {
            WCAtlasUpdateChatMuteMemberLabel(label);
        }
        return;
    }
    WCAtlasUpdateMuteIconInView(controller.view);
    WCAtlasUpdateMuteIconInView(controller.navigationController.navigationBar);
    if (hideIcon) WCAtlasCompatibilityMarkTriggered(@"hide-chat-mute-icon");
}
