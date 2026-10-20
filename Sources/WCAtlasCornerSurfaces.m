#import "WCAtlasCornerSurfaces.h"

#import "WCAtlasCornerStyler.h"

#import <objc/runtime.h>
#import <string.h>

typedef struct {
    const char *identifier;
    const char *title;
    const char *subtitle;
    const char *icon;
    /// NULL means no class name has been confirmed on a device yet. Such a surface is not
    /// installed, not offered in the settings page, and cannot affect WeChat.
    const char *className;
    CGFloat defaultRadius;
} WCAtlasCornerSurface;

// Class names are only filled in once a device run confirms them; a wrong name is harmless
// because installation checks that the class and its layout method exist before touching it.
static WCAtlasCornerSurface WCAtlasCornerSurfaceTable[] = {
    { "avatar", "头像", "聊天页、资料页与列表里的头像", "person.crop.circle", "MMHeadImageView", 6 },
    { "chatBubble", "聊天气泡", "自己与对方的文本气泡", "bubble.left", "WCListTextCellView", 12 },
    { "chatImage", "聊天图片", "消息里的图片与视频封面", "photo", "WCImageView", 10 },
    { "topbar", "顶栏", "聊天与页面的导航栏", "rectangle.topthird.inset.filled", "MMUINavigationBar", 14 },
    { "input", "输入栏", "聊天底部的文字输入区域", "text.cursor", "MMGrowTextView", 10 },
    { "toolbar", "工具栏", "聊天底部工具栏", "rectangle.bottomhalf.filled", "MMInputToolView", 10 },
    { "menu", "菜单", "长按菜单与快捷菜单", "list.bullet", "MMMenuContentView", 12 },
    { "plusMenu", "加号菜单", "聊天加号面板", "plus.circle", NULL, 14 },
    { "moment", "朋友圈", "朋友圈正文卡片", "photo.on.rectangle", "WCTimeLineCellView", 12 },
    { "momentMenu", "朋友圈操作菜单", "朋友圈点赞回复面板", "hand.thumbsup", "WCCommentView", 12 },
    { "discoverPage", "发现页", "发现页的分组卡片", "safari", NULL, 12 },
    { "search", "搜一搜", "搜索结果卡片", "magnifyingglass", NULL, 12 },
    { "service", "服务号", "服务号消息卡片", "envelope", NULL, 12 },
    { "emoji", "表情面板", "表情面板的格子", "face.smiling", "MMEmoticonView", 8 },
    { "chatTime", "聊天时间", "居中的时间戳", "clock", "ChatTimeCellView", 8 },
    { "systemMessage", "系统消息", "灰色系统提示", "info.circle", "BaseMessageCellView", 8 },
    { "systemNotice", "系统通知", "顶部横幅通知", "bell", "MMToastView", 12 },
    { "systemPopup", "系统弹窗", "确认与提示弹窗", "exclamationmark.circle", "WCUIAlertView", 16 },
    { "msgRefer", "引用消息", "引用的消息条", "text.quote", "MMInputMsgReferView", 6 },
    { "quickReplyMsg", "快捷回复", "快捷回复面板", "arrowshape.turn.up.left", "QuickReplyMsgView", 12 },
    { "imeKeyboard", "输入法键盘", "键盘区域的圆角", "keyboard", NULL, 8 },
    { "voiceTranslate", "语音翻译", "语音转文字的卡片", "waveform", NULL, 12 },
    { "sendPublish", "发布按钮", "发送与发布按钮", "paperplane", NULL, 8 },
    { "profile", "资料页", "好友与自己的资料页", "person.text.rectangle", NULL, 16 },
    { "myPage", "我的页", "我的页面卡片", "person.crop.square", NULL, 16 },
    { "homepage", "首页", "会话列表的分组", "house", "MMMainTableView", 12 },
    { "finder", "视频号", "视频号卡片", "play.rectangle", NULL, 12 },
    { "chatFile", "聊天文件", "文件消息卡片", "doc", NULL, 8 },
    { "chatLocation", "位置消息", "位置卡片", "map", NULL, 10 },
    { "mainFrame", "主框架", "底部分栏容器", "square.grid.2x2", "MMTabBar", 16 },
    { "swipeMenu", "侧滑菜单", "主框架侧滑面板", "sidebar.left", NULL, 16 },
    { "floatingTab", "浮窗", "浮窗与悬浮球", "rectangle.on.rectangle", "FloatingTabBar", 12 },
    { "tpMode", "大字模式", "大字模式的卡片", "textformat.size.larger", NULL, 12 },
};

static const NSUInteger WCAtlasCornerSurfaceCount = sizeof(WCAtlasCornerSurfaceTable) / sizeof(WCAtlasCornerSurfaceTable[0]);

/// Original layout implementation per surface, so the hooked method still lays out normally.
static IMP WCAtlasCornerSurfaceOriginal[sizeof(WCAtlasCornerSurfaceTable) / sizeof(WCAtlasCornerSurfaceTable[0])];
static BOOL WCAtlasCornerSurfaceSwizzled[sizeof(WCAtlasCornerSurfaceTable) / sizeof(WCAtlasCornerSurfaceTable[0])];

NSString *WCAtlasCornerKey(NSString *identifier, NSString *name) {
    return [NSString stringWithFormat:@"com.qiu7c.wcatlas.corner.%@.%@", identifier, name];
}

static NSString *WCAtlasSurfaceKey(const WCAtlasCornerSurface *surface, NSString *name) {
    return WCAtlasCornerKey([NSString stringWithUTF8String:surface->identifier], name);
}

static const WCAtlasCornerSurface *WCAtlasSurfaceForClass(Class cls) {
    while (cls) {
        const char *name = class_getName(cls);
        for (NSUInteger index = 0; index < WCAtlasCornerSurfaceCount; index++) {
            const char *candidate = WCAtlasCornerSurfaceTable[index].className;
            if (candidate && strcmp(candidate, name) == 0) return &WCAtlasCornerSurfaceTable[index];
        }
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

static char WCAtlasCornerSurfaceStyledKey;

static void WCAtlasApplySurfaceStyle(UIView *view, const WCAtlasCornerSurface *surface) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = [defaults boolForKey:WCAtlasSurfaceKey(surface, @"enabled")];
    CGFloat radius = [defaults doubleForKey:WCAtlasSurfaceKey(surface, @"radius")];
    BOOL styled = objc_getAssociatedObject(view, &WCAtlasCornerSurfaceStyledKey) != nil;
    if (!enabled || radius <= 0) {
        // Only undo what this module set. WeChat rounds plenty of these views itself (avatars
        // are circles), and clearing unconditionally would flatten them.
        if (styled) {
            WCAtlasClearCornerStyle(view);
            objc_setAssociatedObject(view, &WCAtlasCornerSurfaceStyledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    WCAtlasApplyCornerRadius(view, radius, WCAtlasCornerAll);
    WCAtlasApplyCornerBorder(view, radius, WCAtlasCornerAll, 0, nil);
    objc_setAssociatedObject(view, &WCAtlasCornerSurfaceStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCAtlasSurfaceLayoutSubviews(id self, SEL command) {
    // The implementation is only installed on the classes in the table, so a lookup always
    // succeeds; subclasses resolve to the entry they inherit from.
    const WCAtlasCornerSurface *surface = WCAtlasSurfaceForClass(object_getClass(self));
    if (!surface) return;
    NSUInteger index = (NSUInteger)(surface - WCAtlasCornerSurfaceTable);
    IMP original = WCAtlasCornerSurfaceOriginal[index];
    if (original) ((void (*)(id, SEL))original)(self, command);
    if ([self isKindOfClass:UIView.class]) WCAtlasApplySurfaceStyle((UIView *)self, surface);
}

void WCAtlasInstallCornerSurfaceDefaults(void) {
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    for (NSUInteger index = 0; index < WCAtlasCornerSurfaceCount; index++) {
        const WCAtlasCornerSurface *surface = &WCAtlasCornerSurfaceTable[index];
        if (!surface->className) continue;
        defaults[WCAtlasSurfaceKey(surface, @"enabled")] = @NO;
        defaults[WCAtlasSurfaceKey(surface, @"radius")] = @(surface->defaultRadius);
    }
    [NSUserDefaults.standardUserDefaults registerDefaults:defaults];
}

NSInteger WCAtlasInstallCornerSurfaces(void) {
    NSInteger installed = 0;
    SEL selector = @selector(layoutSubviews);
    for (NSUInteger index = 0; index < WCAtlasCornerSurfaceCount; index++) {
        const WCAtlasCornerSurface *surface = &WCAtlasCornerSurfaceTable[index];
        if (!surface->className || WCAtlasCornerSurfaceSwizzled[index]) continue;
        Class cls = NSClassFromString([NSString stringWithUTF8String:surface->className]);
        if (!cls) continue;
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) continue;
        WCAtlasCornerSurfaceOriginal[index] = method_getImplementation(method);
        method_setImplementation(method, (IMP)WCAtlasSurfaceLayoutSubviews);
        WCAtlasCornerSurfaceSwizzled[index] = YES;
        installed++;
    }
    return installed;
}

NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasCornerSurfaceDescriptors(void) {
    // The constructor can run before WeChat's own classes are registered, in which case the first
    // pass installs nothing. Retrying here (the settings page is opened long after launch) gives
    // every surface a second chance without needing a separate timer.
    WCAtlasInstallCornerSurfaces();
    NSMutableArray *descriptors = [NSMutableArray array];
    for (NSUInteger index = 0; index < WCAtlasCornerSurfaceCount; index++) {
        const WCAtlasCornerSurface *surface = &WCAtlasCornerSurfaceTable[index];
        if (!surface->className || !WCAtlasCornerSurfaceSwizzled[index]) continue;
        [descriptors addObject:@{
            @"identifier": [NSString stringWithUTF8String:surface->identifier],
            @"title": [NSString stringWithUTF8String:surface->title],
            @"subtitle": [NSString stringWithUTF8String:surface->subtitle],
            @"icon": [NSString stringWithUTF8String:surface->icon],
        }];
    }
    return descriptors;
}