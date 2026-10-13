#import "WCAtlasMomentsPrewarmer.h"

#import "WCAtlasAccount.h"
#import "WCAtlasLogging.h"
#import "WCAtlasEnhancements.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

@interface WCAtlasMomentsPrewarmer : NSObject
@property (nonatomic, strong, nullable) UIWindow *window;
@property (nonatomic, copy, nullable) NSString *completedAccount;
@property (nonatomic, assign) BOOL scheduled;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) NSUInteger launchAttemptCount;
+ (instancetype)sharedPrewarmer;
- (void)scheduleIfNeeded;
- (void)cancel;
@end

static BOOL WCAtlasMomentsPrewarmMethodMatches(Class cls, SEL selector, const char *encoding) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    const char *actual = method ? method_getTypeEncoding(method) : NULL;
    return actual && encoding && strcmp(actual, encoding) == 0;
}

static UIWindowScene *WCAtlasMomentsPrewarmActiveScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:UIWindowScene.class]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

@implementation WCAtlasMomentsPrewarmer

+ (instancetype)sharedPrewarmer {
    static WCAtlasMomentsPrewarmer *prewarmer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ prewarmer = [WCAtlasMomentsPrewarmer new]; });
    return prewarmer;
}

- (void)scheduleIfNeeded {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self scheduleIfNeeded]; });
        return;
    }
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey) ||
        self.scheduled || self.running) return;
    NSString *account = WCAtlasCurrentUserWXID();
    if ([self.completedAccount isEqualToString:account] || self.launchAttemptCount >= 15) return;
    self.scheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        strongSelf.scheduled = NO;
        if (!strongSelf || UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
            !WCAtlasEnhancementEnabled(WCAtlasMomentsInteractionReminderEnabledKey)) return;
        strongSelf.launchAttemptCount += 1;
        NSString *currentAccount = WCAtlasCurrentUserWXID();
        if (currentAccount.length == 0) {
            [strongSelf scheduleIfNeeded];
            return;
        }
        if ([strongSelf.completedAccount isEqualToString:currentAccount]) return;

        Class entryClass = objc_getClass("FindFriendEntryViewController");
        SEL initSelector = sel_registerName("init");
        SEL openSelector = sel_registerName("openAlbum");
        if (!entryClass) {
            [strongSelf scheduleIfNeeded];
            return;
        }
        if (!WCAtlasMomentsPrewarmMethodMatches(entryClass, initSelector, "@16@0:8") ||
            !WCAtlasMomentsPrewarmMethodMatches(entryClass, openSelector, "v16@0:8")) {
            strongSelf.completedAccount = currentAccount;
            WCAtlasLog(@"隐式初始化朋友圈失败：发现页入口 ABI 不匹配");
            return;
        }
        UIWindowScene *scene = WCAtlasMomentsPrewarmActiveScene();
        if (!scene) {
            [strongSelf scheduleIfNeeded];
            return;
        }

        id entry = ((id (*)(id, SEL))objc_msgSend)([entryClass alloc], initSelector);
        if (![entry isKindOfClass:UIViewController.class]) {
            strongSelf.completedAccount = currentAccount;
            WCAtlasLog(@"隐式初始化朋友圈失败：无法创建发现页");
            return;
        }

        UINavigationController *navigation = [[UINavigationController alloc]
            initWithRootViewController:(UIViewController *)entry];
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.frame = scene.coordinateSpace.bounds;
        window.windowLevel = UIWindowLevelNormal - 100.0;
        window.alpha = 0.001;
        window.userInteractionEnabled = NO;
        window.backgroundColor = UIColor.clearColor;
        window.accessibilityElementsHidden = YES;
        window.rootViewController = navigation;
        strongSelf.window = window;
        strongSelf.running = YES;
        window.hidden = NO;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) openSelf = weakSelf;
            if (!openSelf.running || openSelf.window != window ||
                UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
            @try {
                ((void (*)(id, SEL))objc_msgSend)(entry, openSelector);
                WCAtlasLog(@"已在隐式窗口调用朋友圈原生初始化入口");
            } @catch (NSException *exception) {
                WCAtlasLog(@"隐式初始化朋友圈失败：%@", exception.reason ?: @"未知异常");
            }
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) finishSelf = weakSelf;
            if (!finishSelf || finishSelf.window != window) return;
            Class timelineClass = objc_getClass("WCTimeLineViewController");
            BOOL initialized = timelineClass &&
                [navigation.topViewController isKindOfClass:timelineClass];
            finishSelf.completedAccount = currentAccount;
            finishSelf.launchAttemptCount = 0;
            [finishSelf cancel];
            WCAtlasLog(initialized ? @"朋友圈隐式初始化完成"
                                 : @"朋友圈隐式初始化未进入目标控制器");
        });
    });
}

- (void)cancel {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self cancel]; });
        return;
    }
    self.running = NO;
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.window = nil;
}

@end

void WCAtlasMomentsPrewarmIfNeeded(void) {
    [[WCAtlasMomentsPrewarmer sharedPrewarmer] scheduleIfNeeded];
}

void WCAtlasMomentsPrewarmCancel(void) {
    [[WCAtlasMomentsPrewarmer sharedPrewarmer] cancel];
}
