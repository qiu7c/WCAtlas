#import "WCAtlasInAppNotification.h"
#import "WCAtlasLogging.h"

#import <UIKit/UIKit.h>

static const NSTimeInterval WCAtlasInAppNotificationDuration = 4.0;
static const NSTimeInterval WCAtlasInAppNotificationDuplicateInterval = 5.0;
static const NSTimeInterval WCAtlasTransientHUDDuration = 1.6;

NSString *const WCAtlasInAppNotificationSymbolKey = @"com.qiu7c.wcatlas.in-app-notification.symbol";
NSString *const WCAtlasInAppNotificationHeightKey = @"com.qiu7c.wcatlas.in-app-notification.height";
NSString *const WCAtlasInAppNotificationBlurIntensityKey = @"com.qiu7c.wcatlas.in-app-notification.blur-intensity";
CGFloat const WCAtlasInAppNotificationMinimumHeight = 56.0;
CGFloat const WCAtlasInAppNotificationMaximumHeight = 90.0;

NSString *WCAtlasInAppNotificationResolvedSymbolName(NSString *requestedSymbolName) {
    NSString *stored = [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasInAppNotificationSymbolKey];
    if (stored.length == 0 || [stored isEqualToString:@"automatic"]) {
        return requestedSymbolName.length > 0 ? requestedSymbolName : @"bell.fill";
    }
    return stored;
}

CGFloat WCAtlasInAppNotificationPreferredHeight(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CGFloat value = [defaults objectForKey:WCAtlasInAppNotificationHeightKey]
        ? [defaults doubleForKey:WCAtlasInAppNotificationHeightKey] : 60.0;
    return MIN(WCAtlasInAppNotificationMaximumHeight,
               MAX(WCAtlasInAppNotificationMinimumHeight, value));
}

CGFloat WCAtlasInAppNotificationBlurIntensity(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CGFloat value = [defaults objectForKey:WCAtlasInAppNotificationBlurIntensityKey]
        ? [defaults doubleForKey:WCAtlasInAppNotificationBlurIntensityKey] : 0.85;
    return MIN(1.0, MAX(0.20, value));
}

static UIWindow *WCAtlasInAppActiveWindow(void) {
    UIWindow *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows.reverseObjectEnumerator) {
            if (window.hidden || window.alpha <= 0.0 || window.windowLevel != UIWindowLevelNormal) continue;
            if (window.isKeyWindow) return window;
            if (!fallback) fallback = window;
        }
    }
    return fallback;
}

@interface WCAtlasInAppNotificationRequest : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy, nullable) dispatch_block_t action;
@end

@implementation WCAtlasInAppNotificationRequest
@end

@interface WCAtlasInAppBannerView : UIControl
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
- (instancetype)initWithRequest:(WCAtlasInAppNotificationRequest *)request;
@end

@implementation WCAtlasInAppBannerView

- (instancetype)initWithRequest:(WCAtlasInAppNotificationRequest *)request {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 14.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.16;
    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@，%@", request.title, request.body];

    UIVisualEffectView *background = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    background.userInteractionEnabled = NO;
    background.layer.cornerRadius = 14.0;
    background.layer.cornerCurve = kCACornerCurveContinuous;
    background.clipsToBounds = YES;
    [self addSubview:background];

    CGFloat blurIntensity = WCAtlasInAppNotificationBlurIntensity();
    background.contentView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.10 + (1.0 - blurIntensity) * 0.45];

    UIView *iconBackground = [UIView new];
    iconBackground.translatesAutoresizingMaskIntoConstraints = NO;
    iconBackground.backgroundColor = [UIColor colorWithRed:0.12 green:0.72 blue:0.32 alpha:1.0];
    iconBackground.layer.cornerRadius = 10.0;
    iconBackground.layer.cornerCurve = kCACornerCurveContinuous;
    [background.contentView addSubview:iconBackground];

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightSemibold];
    NSString *resolvedSymbolName = WCAtlasInAppNotificationResolvedSymbolName(request.symbolName);
    UIImage *symbol = [UIImage systemImageNamed:resolvedSymbolName withConfiguration:configuration] ?:
                      [UIImage systemImageNamed:@"bell.fill" withConfiguration:configuration];
    self.symbolView = [[UIImageView alloc] initWithImage:symbol];
    self.symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolView.contentMode = UIViewContentModeScaleAspectFit;
    self.symbolView.tintColor = UIColor.whiteColor;
    [iconBackground addSubview:self.symbolView];

    self.titleLabel = [UILabel new];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = request.title;
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [background.contentView addSubview:self.titleLabel];

    self.bodyLabel = [UILabel new];
    self.bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bodyLabel.text = request.body;
    self.bodyLabel.textColor = UIColor.secondaryLabelColor;
    self.bodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.bodyLabel.adjustsFontForContentSizeCategory = YES;
    self.bodyLabel.numberOfLines = 2;
    self.bodyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [background.contentView addSubview:self.bodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [iconBackground.leadingAnchor constraintEqualToAnchor:background.contentView.leadingAnchor constant:12.0],
        [iconBackground.centerYAnchor constraintEqualToAnchor:background.contentView.centerYAnchor],
        [iconBackground.widthAnchor constraintEqualToConstant:38.0],
        [iconBackground.heightAnchor constraintEqualToConstant:38.0],
        [self.symbolView.centerXAnchor constraintEqualToAnchor:iconBackground.centerXAnchor],
        [self.symbolView.centerYAnchor constraintEqualToAnchor:iconBackground.centerYAnchor],
        [self.symbolView.widthAnchor constraintEqualToConstant:21.0],
        [self.symbolView.heightAnchor constraintEqualToConstant:21.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconBackground.trailingAnchor constant:10.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:background.contentView.trailingAnchor constant:-12.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:background.contentView.topAnchor constant:9.0],
        [self.bodyLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.bodyLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.bodyLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:1.0],
        [self.bodyLabel.bottomAnchor constraintEqualToAnchor:background.contentView.bottomAnchor constant:-9.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:WCAtlasInAppNotificationPreferredHeight()],
    ]];
    return self;
}

@end

@interface WCAtlasProgressCapsuleCenter : NSObject
@property(nonatomic, strong, nullable) UIView *capsule;
@property(nonatomic, strong, nullable) UILabel *label;
@property(nonatomic, strong, nullable) UIImageView *symbolView;
@property(nonatomic, strong, nullable) UIProgressView *progressView;
@property(nonatomic, assign) NSUInteger dismissalToken;
+ (instancetype)sharedCenter;
- (void)showMessage:(NSString *)message progress:(float)progress symbolName:(NSString *)symbolName;
- (void)completeMessage:(NSString *)message success:(BOOL)success;
- (void)dismissAnimated:(BOOL)animated;
@end

@implementation WCAtlasProgressCapsuleCenter

+ (instancetype)sharedCenter {
    static WCAtlasProgressCapsuleCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [WCAtlasProgressCapsuleCenter new];
        [NSNotificationCenter.defaultCenter addObserver:center selector:@selector(applicationDidEnterBackground:)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
    });
    return center;
}

- (void)applicationDidEnterBackground:(__unused NSNotification *)notification {
    [self dismissAnimated:NO];
}

- (void)buildCapsuleInWindow:(UIWindow *)window {
    UIView *capsule = [UIView new];
    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    capsule.userInteractionEnabled = NO;
    capsule.layer.cornerRadius = 19.0;
    capsule.layer.cornerCurve = kCACornerCurveContinuous;
    capsule.layer.shadowColor = UIColor.blackColor.CGColor;
    capsule.layer.shadowOpacity = 0.14;
    capsule.layer.shadowRadius = 9.0;
    capsule.layer.shadowOffset = CGSizeMake(0.0, 3.0);

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.userInteractionEnabled = NO;
    blur.layer.cornerRadius = 19.0;
    blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.clipsToBounds = YES;
    blur.contentView.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.08];
    [capsule addSubview:blur];

    UIImageView *symbolView = [UIImageView new];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    symbolView.tintColor = [UIColor colorWithRed:0.10 green:0.70 blue:0.29 alpha:1.0];
    [blur.contentView addSubview:symbolView];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = UIColor.labelColor;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [blur.contentView addSubview:label];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.translatesAutoresizingMaskIntoConstraints = NO;
    progressView.progressTintColor = symbolView.tintColor;
    progressView.trackTintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.18];
    [blur.contentView addSubview:progressView];

    [window addSubview:capsule];
    [NSLayoutConstraint activateConstraints:@[
        [capsule.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [capsule.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:6.0],
        [capsule.heightAnchor constraintEqualToConstant:38.0],
        [capsule.widthAnchor constraintGreaterThanOrEqualToConstant:188.0],
        [capsule.widthAnchor constraintLessThanOrEqualToAnchor:window.widthAnchor constant:-40.0],
        [blur.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor],
        [blur.topAnchor constraintEqualToAnchor:capsule.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:capsule.bottomAnchor],
        [symbolView.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor constant:12.0],
        [symbolView.centerYAnchor constraintEqualToAnchor:blur.contentView.centerYAnchor constant:-1.5],
        [symbolView.widthAnchor constraintEqualToConstant:17.0],
        [symbolView.heightAnchor constraintEqualToConstant:17.0],
        [label.leadingAnchor constraintEqualToAnchor:symbolView.trailingAnchor constant:7.0],
        [label.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor constant:-12.0],
        [label.centerYAnchor constraintEqualToAnchor:blur.contentView.centerYAnchor constant:-2.0],
        [progressView.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
        [progressView.trailingAnchor constraintEqualToAnchor:label.trailingAnchor],
        [progressView.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor constant:-4.0],
    ]];
    self.capsule = capsule;
    self.label = label;
    self.symbolView = symbolView;
    self.progressView = progressView;
    [window layoutIfNeeded];
    capsule.alpha = 0.0;
    capsule.transform = CGAffineTransformMakeTranslation(0.0, -12.0);
    [UIView animateWithDuration:0.24 animations:^{
        capsule.alpha = 1.0;
        capsule.transform = CGAffineTransformIdentity;
    }];
}

- (void)showMessage:(NSString *)message progress:(float)progress symbolName:(NSString *)symbolName {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showMessage:message progress:progress symbolName:symbolName]; });
        return;
    }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    UIWindow *window = WCAtlasInAppActiveWindow();
    if (!window) return;
    self.dismissalToken++;
    if (!self.capsule || self.capsule.window != window) {
        [self.capsule removeFromSuperview];
        [self buildCapsuleInWindow:window];
    }
    self.label.text = message;
    self.symbolView.image = [UIImage systemImageNamed:symbolName.length > 0 ? symbolName : @"person.2.fill"];
    self.symbolView.tintColor = [UIColor colorWithRed:0.10 green:0.70 blue:0.29 alpha:1.0];
    self.progressView.hidden = NO;
    self.progressView.progressTintColor = self.symbolView.tintColor;
    [self.progressView setProgress:MIN(1.0f, MAX(0.0f, progress)) animated:YES];
}

- (void)completeMessage:(NSString *)message success:(BOOL)success {
    [self showMessage:message progress:1.0 symbolName:success ? @"checkmark.circle.fill" : @"exclamationmark.circle.fill"];
    self.symbolView.tintColor = success ? [UIColor colorWithRed:0.10 green:0.70 blue:0.29 alpha:1.0]
                                       : UIColor.systemOrangeColor;
    self.progressView.hidden = YES;
    NSUInteger token = ++self.dismissalToken;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self && self.dismissalToken == token) [self dismissAnimated:YES];
    });
}

- (void)dismissAnimated:(BOOL)animated {
    self.dismissalToken++;
    UIView *capsule = self.capsule;
    self.capsule = nil;
    self.label = nil;
    self.symbolView = nil;
    self.progressView = nil;
    if (!animated) {
        [capsule removeFromSuperview];
        return;
    }
    [UIView animateWithDuration:0.20 animations:^{
        capsule.alpha = 0.0;
        capsule.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
    } completion:^(__unused BOOL finished) { [capsule removeFromSuperview]; }];
}

@end

@interface WCAtlasTransientHUDCenter : NSObject
@property (nonatomic, strong, nullable) UIView *currentHUD;
@property (nonatomic, assign) NSUInteger presentationToken;
+ (instancetype)sharedCenter;
- (void)showMessage:(NSString *)message symbolName:(NSString *)symbolName;
@end

@implementation WCAtlasTransientHUDCenter

+ (instancetype)sharedCenter {
    static WCAtlasTransientHUDCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [WCAtlasTransientHUDCenter new];
        [NSNotificationCenter.defaultCenter addObserver:center
                                               selector:@selector(applicationDidEnterBackground:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    });
    return center;
}

- (void)applicationDidEnterBackground:(__unused NSNotification *)notification {
    self.presentationToken++;
    [self.currentHUD.layer removeAllAnimations];
    [self.currentHUD removeFromSuperview];
    self.currentHUD = nil;
}

- (void)showMessage:(NSString *)message symbolName:(NSString *)symbolName {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showMessage:message symbolName:symbolName]; });
        return;
    }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    UIWindow *window = WCAtlasInAppActiveWindow();
    if (!window) {
        WCAtlasLog(@"居中提示未显示：没有可用的前台窗口");
        return;
    }

    self.presentationToken++;
    [self.currentHUD.layer removeAllAnimations];
    [self.currentHUD removeFromSuperview];

    UIView *hud = [UIView new];
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    hud.userInteractionEnabled = NO;
    hud.layer.cornerRadius = 14.0;
    hud.layer.cornerCurve = kCACornerCurveContinuous;
    hud.layer.shadowColor = UIColor.blackColor.CGColor;
    hud.layer.shadowOpacity = 0.18;
    hud.layer.shadowRadius = 18.0;
    hud.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    UIVisualEffectView *background = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    background.userInteractionEnabled = NO;
    background.layer.cornerRadius = 14.0;
    background.layer.cornerCurve = kCACornerCurveContinuous;
    background.clipsToBounds = YES;
    background.contentView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.10];
    [hud addSubview:background];

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:31.0 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:configuration] ?:
                      [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:configuration];
    UIImageView *symbolView = [[UIImageView alloc] initWithImage:symbol];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    symbolView.tintColor = [UIColor colorWithRed:0.10 green:0.70 blue:0.29 alpha:1.0];
    [background.contentView addSubview:symbolView];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = UIColor.labelColor;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 2;
    [background.contentView addSubview:label];

    [window addSubview:hud];
    [NSLayoutConstraint activateConstraints:@[
        [hud.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [hud.centerYAnchor constraintEqualToAnchor:window.centerYAnchor constant:-12.0],
        [hud.widthAnchor constraintEqualToConstant:238.0],
        [hud.heightAnchor constraintGreaterThanOrEqualToConstant:112.0],
        [background.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:hud.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:hud.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:hud.bottomAnchor],
        [symbolView.centerXAnchor constraintEqualToAnchor:background.contentView.centerXAnchor],
        [symbolView.topAnchor constraintEqualToAnchor:background.contentView.topAnchor constant:19.0],
        [symbolView.widthAnchor constraintEqualToConstant:36.0],
        [symbolView.heightAnchor constraintEqualToConstant:36.0],
        [label.leadingAnchor constraintEqualToAnchor:background.contentView.leadingAnchor constant:16.0],
        [label.trailingAnchor constraintEqualToAnchor:background.contentView.trailingAnchor constant:-16.0],
        [label.topAnchor constraintEqualToAnchor:symbolView.bottomAnchor constant:10.0],
        [label.bottomAnchor constraintEqualToAnchor:background.contentView.bottomAnchor constant:-17.0],
    ]];
    self.currentHUD = hud;
    [window layoutIfNeeded];

    hud.alpha = 0.0;
    hud.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        hud.alpha = 1.0;
        hud.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSUInteger token = self.presentationToken;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(WCAtlasTransientHUDDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.presentationToken != token || strongSelf.currentHUD != hud) return;
        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:^{
            hud.alpha = 0.0;
            hud.transform = CGAffineTransformMakeScale(0.96, 0.96);
        } completion:^(__unused BOOL finished) {
            if (strongSelf.currentHUD != hud) return;
            [hud removeFromSuperview];
            strongSelf.currentHUD = nil;
        }];
    });
}

@end

@interface WCAtlasInAppNotificationCenter : NSObject
@property (nonatomic, strong) NSMutableArray<WCAtlasInAppNotificationRequest *> *queue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *recentIdentifiers;
@property (nonatomic, strong, nullable) WCAtlasInAppNotificationRequest *currentRequest;
@property (nonatomic, strong, nullable) WCAtlasInAppBannerView *currentBanner;
@property (nonatomic, assign) NSUInteger presentationToken;
@property (nonatomic, assign) BOOL dismissing;
+ (instancetype)sharedCenter;
- (void)enqueueRequest:(WCAtlasInAppNotificationRequest *)request;
- (void)showNextIfPossible;
- (void)dismissCurrentAnimated:(BOOL)animated completion:(dispatch_block_t _Nullable)completion;
- (void)dismissAll;
@end

@implementation WCAtlasInAppNotificationCenter

+ (instancetype)sharedCenter {
    static WCAtlasInAppNotificationCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [WCAtlasInAppNotificationCenter new];
        center.queue = [NSMutableArray array];
        center.recentIdentifiers = [NSMutableDictionary dictionary];
        [NSNotificationCenter.defaultCenter addObserver:center
                                               selector:@selector(applicationDidEnterBackground:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    });
    return center;
}

- (UIWindow *)activeWindow {
    return WCAtlasInAppActiveWindow();
}

- (void)enqueueRequest:(WCAtlasInAppNotificationRequest *)request {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self enqueueRequest:request]; });
        return;
    }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;

    NSDate *now = NSDate.date;
    for (NSString *identifier in self.recentIdentifiers.allKeys.copy) {
        if ([now timeIntervalSinceDate:self.recentIdentifiers[identifier]] >
            WCAtlasInAppNotificationDuplicateInterval) {
            [self.recentIdentifiers removeObjectForKey:identifier];
        }
    }
    NSDate *lastShown = self.recentIdentifiers[request.identifier];
    if (lastShown && [now timeIntervalSinceDate:lastShown] <= WCAtlasInAppNotificationDuplicateInterval) return;
    self.recentIdentifiers[request.identifier] = now;

    [self.queue addObject:request];
    if (self.queue.count > 8) [self.queue removeObjectAtIndex:0];
    [self showNextIfPossible];
}

- (void)showNextIfPossible {
    if (self.currentRequest || self.dismissing || self.queue.count == 0) return;
    UIWindow *window = [self activeWindow];
    if (!window) {
        WCAtlasLog(@"应用内提醒未显示：没有可用的前台窗口");
        [self.queue removeAllObjects];
        return;
    }

    WCAtlasInAppNotificationRequest *request = self.queue.firstObject;
    [self.queue removeObjectAtIndex:0];
    self.currentRequest = request;
    WCAtlasInAppBannerView *banner = [[WCAtlasInAppBannerView alloc] initWithRequest:request];
    self.currentBanner = banner;
    [banner addTarget:self action:@selector(bannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(bannerSwiped:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [banner addGestureRecognizer:swipe];
    [window addSubview:banner];
    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:window.leadingAnchor constant:12.0],
        [banner.trailingAnchor constraintEqualToAnchor:window.trailingAnchor constant:-12.0],
        [banner.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:8.0],
    ]];
    [window layoutIfNeeded];

    banner.transform = CGAffineTransformMakeTranslation(0.0, -CGRectGetMaxY(banner.frame) - 20.0);
    banner.alpha = 0.35;
    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        banner.transform = CGAffineTransformIdentity;
        banner.alpha = 1.0;
    } completion:nil];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    NSUInteger token = ++self.presentationToken;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(WCAtlasInAppNotificationDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.presentationToken != token || strongSelf.currentRequest != request) return;
        [strongSelf dismissCurrentAnimated:YES completion:nil];
    });
}

- (void)bannerTapped:(__unused WCAtlasInAppBannerView *)sender {
    dispatch_block_t action = self.currentRequest.action;
    [self dismissCurrentAnimated:YES completion:action];
}

- (void)bannerSwiped:(__unused UISwipeGestureRecognizer *)recognizer {
    [self dismissCurrentAnimated:YES completion:nil];
}

- (void)dismissCurrentAnimated:(BOOL)animated completion:(dispatch_block_t)completion {
    WCAtlasInAppBannerView *banner = self.currentBanner;
    if (!self.currentRequest || !banner) {
        if (completion) completion();
        return;
    }
    self.presentationToken++;
    self.dismissing = YES;
    self.currentRequest = nil;
    void (^finished)(void) = ^{
        [banner removeFromSuperview];
        self.currentBanner = nil;
        self.dismissing = NO;
        if (completion) completion();
        [self showNextIfPossible];
    };
    if (!animated) {
        finished();
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                     animations:^{
        banner.transform = CGAffineTransformMakeTranslation(0.0, -CGRectGetMaxY(banner.frame) - 20.0);
        banner.alpha = 0.0;
    } completion:^(__unused BOOL didFinish) { finished(); }];
}

- (void)applicationDidEnterBackground:(__unused NSNotification *)notification {
    [self dismissAll];
}

- (void)dismissAll {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self dismissAll]; });
        return;
    }
    [self.queue removeAllObjects];
    [self dismissCurrentAnimated:NO completion:nil];
}

@end

void WCAtlasShowInAppNotification(NSString *title,
                                NSString *body,
                                NSString *identifier,
                                NSString *symbolName,
                                dispatch_block_t action) {
    if (title.length == 0 || body.length == 0) return;
    WCAtlasInAppNotificationRequest *request = [WCAtlasInAppNotificationRequest new];
    request.title = title;
    request.body = body;
    request.identifier = identifier.length > 0 ? identifier : NSUUID.UUID.UUIDString;
    request.symbolName = symbolName.length > 0 ? symbolName : @"bell.fill";
    request.action = action;
    [[WCAtlasInAppNotificationCenter sharedCenter] enqueueRequest:request];
}

void WCAtlasShowTransientHUD(NSString *message, NSString *symbolName) {
    if (message.length == 0) return;
    [[WCAtlasTransientHUDCenter sharedCenter]
        showMessage:message
         symbolName:symbolName.length > 0 ? symbolName : @"checkmark.circle.fill"];
}

void WCAtlasShowProgressCapsule(NSString *message, float progress, NSString *symbolName) {
    if (message.length == 0) return;
    [[WCAtlasProgressCapsuleCenter sharedCenter] showMessage:message progress:progress symbolName:symbolName];
}

void WCAtlasCompleteProgressCapsule(NSString *message, BOOL success) {
    if (message.length == 0) return;
    [[WCAtlasProgressCapsuleCenter sharedCenter] completeMessage:message success:success];
}

void WCAtlasDismissProgressCapsule(void) {
    [[WCAtlasProgressCapsuleCenter sharedCenter] dismissAnimated:YES];
}

void WCAtlasDismissInAppNotifications(void) {
    [[WCAtlasInAppNotificationCenter sharedCenter] dismissAll];
}
