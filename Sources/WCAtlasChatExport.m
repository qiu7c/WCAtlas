#import "WCAtlasChatExport.h"

#import <objc/message.h>

#import "WCAtlasEnhancements.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasQuickReplyStore.h"

static NSString *const WCAtlasExportTextAction = @"com.qiu7c.wcatlas.chat-export.text";
static NSString *const WCAtlasSaveImagesAction = @"com.qiu7c.wcatlas.chat-export.images";
static NSString *const WCAtlasShareCardAction = @"com.qiu7c.wcatlas.chat-export.card";
static NSString *const WCAtlasQuickReplyImportAction = @"com.qiu7c.wcatlas.quick-reply.import";
static void WCAtlasShowExportMessage(UIViewController *controller, NSString *title, NSString *message);
static NSString *WCAtlasMessageBody(id wrap);

typedef NS_ENUM(NSInteger, WCAtlasShareCardStyle) {
    WCAtlasShareCardStyleMinimal = 0,
    WCAtlasShareCardStyleConversation = 1,
    WCAtlasShareCardStyleDark = 2,
};

static id WCAtlasExportSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

static id WCAtlasExportCall(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSArray *WCAtlasSelectedMessages(UIViewController *controller) {
    id selected = WCAtlasExportCall(controller, @"getSelectedMsgs");
    return [selected isKindOfClass:[NSArray class]] ? selected : @[];
}

static NSString *WCAtlasExportConversationUsername(UIViewController *controller) {
    return WCAtlasPrivateChatUserName(controller);
}

static BOOL WCAtlasExportOptionEnabled(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:key];
    return value ? [value boolValue] : YES;
}

NSArray<NSDictionary *> *WCAtlasChatMultiSelectActions(UIViewController *controller) {
    NSMutableArray<NSDictionary *> *actions = [NSMutableArray array];
    if (WCAtlasEnhancementEnabled(WCAtlasMultiSelectExportEnabledKey)) {
        if (WCAtlasExportOptionEnabled(WCAtlasMultiSelectExportTextKey)) {
            [actions addObject:@{ @"id": WCAtlasExportTextAction, @"title": @"纯文本", @"symbol": @"doc.on.clipboard" }];
        }
        if (WCAtlasExportOptionEnabled(WCAtlasMultiSelectSaveImagesKey)) {
            [actions addObject:@{ @"id": WCAtlasSaveImagesAction, @"title": @"保存图片", @"symbol": @"square.and.arrow.down" }];
        }
        if (WCAtlasExportOptionEnabled(WCAtlasMultiSelectShareCardKey)) {
            [actions addObject:@{ @"id": WCAtlasShareCardAction, @"title": @"分享卡片", @"symbol": @"rectangle.on.rectangle" }];
        }
    }
    if (WCAtlasEnhancementEnabled(WCAtlasQuickReplyEnabledKey)) {
        [actions addObject:@{ @"id": WCAtlasQuickReplyImportAction, @"title": @"存入消息库", @"symbol": @"tray.and.arrow.down.fill" }];
    }
    return actions;
}

static void WCAtlasImportSelectedQuickRepliesWithMetadata(UIViewController *controller, NSArray *messages,
                                                        NSString *remark, NSString *folderIdentifier) {
    NSString *trimmedRemark = [remark stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *conversation = WCAtlasExportConversationUsername(controller);
    NSUInteger imported = 0, alreadyPresent = 0, unavailable = 0;
    for (id wrap in messages) {
        NSInteger type = [WCAtlasExportSafeValue(wrap, @"m_uiMessageType") integerValue];
        NSInteger innerType = [WCAtlasExportSafeValue(wrap, @"m_uiAppMsgInnerType") integerValue];
        if (innerType == 0) {
            innerType = [WCAtlasExportSafeValue(WCAtlasExportSafeValue(wrap, @"m_extendInfoWithMsgType"),
                                               @"m_uiAppMsgInnerType") integerValue];
        }
        unsigned long long localID = [WCAtlasExportSafeValue(wrap, @"m_uiMesLocalID") unsignedLongLongValue];
        long long serverID = [WCAtlasExportSafeValue(wrap, @"m_n64MesSvrID") longLongValue];
        if (conversation.length == 0 || (localID == 0 && serverID == 0)) { unavailable++; continue; }
        NSUInteger beforeCount = WCAtlasQuickReplyStore.sharedStore.items.count;
        NSError *error = nil;
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyStore.sharedStore
            addMessageReferenceForConversation:conversation
                                        localID:localID
                                       serverID:serverID
                                    messageType:type
                                      innerType:innerType
                                        preview:WCAtlasMessageBody(wrap)
                                          title:trimmedRemark
                              folderIdentifier:folderIdentifier
                                          error:&error];
        if (item) {
            BOOL isNew = WCAtlasQuickReplyStore.sharedStore.items.count > beforeCount;
            if (isNew) imported++;
            else alreadyPresent++;
        } else {
            unavailable++;
        }
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (imported) [parts addObject:[NSString stringWithFormat:@"新增 %lu 项", (unsigned long)imported]];
    if (alreadyPresent) [parts addObject:[NSString stringWithFormat:@"已存在 %lu 项", (unsigned long)alreadyPresent]];
    if (unavailable) [parts addObject:[NSString stringWithFormat:@"无法定位 %lu 项", (unsigned long)unavailable]];
    WCAtlasShowExportMessage(controller, imported > 0 ? @"已加入快捷回复" : @"没有新增消息",
                           parts.count > 0 ? [parts componentsJoinedByString:@"，"] : @"没有可导入的消息。");
}

static void WCAtlasPresentQuickReplyImportFolderPicker(UIViewController *controller, NSArray *messages, NSString *remark) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"存入文件夹" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    void (^importIntoFolder)(NSString *) = ^(NSString *folderIdentifier) {
        WCAtlasImportSelectedQuickRepliesWithMetadata(controller, messages, remark, folderIdentifier);
    };
    [sheet addAction:[UIAlertAction actionWithTitle:@"消息库根目录" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        importIntoFolder(nil);
    }]];
    for (WCAtlasQuickReplyFolder *folder in WCAtlasQuickReplyStore.sharedStore.folders) {
        [sheet addAction:[UIAlertAction actionWithTitle:folder.name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            importIntoFolder(folder.identifier);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"文件夹名称"; }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"创建并导入" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *saveAction) {
            NSError *error = nil;
            WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyStore.sharedStore createFolderWithName:alert.textFields.firstObject.text error:&error];
            if (folder) importIntoFolder(folder.identifier);
            else WCAtlasShowExportMessage(controller, @"无法创建文件夹", error.localizedDescription ?: @"文件夹名称无效。");
        }]];
        [controller presentViewController:alert animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.sourceView = controller.view; popover.sourceRect = controller.view.bounds; }
    [controller presentViewController:sheet animated:YES completion:nil];
}

static void WCAtlasPresentQuickReplyImportConfiguration(UIViewController *controller, NSArray *messages) {
    BOOL single = messages.count == 1;
    NSString *message = single ? @"可填写备注并选择保存文件夹。" :
        [NSString stringWithFormat:@"将导入 %lu 条消息并统一存入一个文件夹；每条备注可稍后在消息库右滑重命名。", (unsigned long)messages.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加入快捷回复"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if (single) [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"备注（可选）"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *remark = single ? alert.textFields.firstObject.text : @"";
        WCAtlasPresentQuickReplyImportFolderPicker(controller, messages, remark ?: @"");
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}

static NSString *WCAtlasMessageBody(id wrap) {
    NSUInteger type = [WCAtlasExportSafeValue(wrap, @"m_uiMessageType") unsignedIntegerValue];
    id contentValue = WCAtlasExportSafeValue(wrap, @"m_nsContent");
    NSString *content = [contentValue isKindOfClass:[NSString class]] ? contentValue : nil;
    if (type == 1 && content.length > 0) return content;
    id titleValue = WCAtlasExportSafeValue(wrap, @"m_nsTitle");
    NSString *title = [titleValue isKindOfClass:[NSString class]] ? titleValue : nil;
    if (title.length > 0) return title;
    switch (type) {
        case 3: return @"图片";
        case 34: return @"语音";
        case 43: return @"视频";
        case 47: return @"表情";
        case 48: return @"位置";
        case 49: return @"分享内容";
        default: return content.length > 0 && ![content hasPrefix:@"<"] ? content : @"消息";
    }
}

static id WCAtlasContactForUsername(NSString *username) {
    return WCAtlasPrivateContact(username);
}

static NSString *WCAtlasContactDisplayName(id contact) {
    return WCAtlasPrivateContactDisplayName(contact, nil);
}

static NSString *WCAtlasSenderName(id wrap) {
    id displayValue = WCAtlasExportSafeValue(wrap, @"m_nsDisplayName");
    if ([displayValue isKindOfClass:[NSString class]] && [displayValue length] > 0 && ![displayValue hasPrefix:@"wxid_"]) return displayValue;
    NSString *username = nil;
    for (NSString *key in @[@"m_nsRealChatUsr", @"m_nsFromUsr"]) {
        id value = WCAtlasExportSafeValue(wrap, key);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0 && ![value containsString:@"@chatroom"]) {
            username = value;
            break;
        }
    }
    NSString *displayName = WCAtlasContactDisplayName(WCAtlasContactForUsername(username));
    if (displayName.length > 0) return displayName;
    return username.length > 0 && ![username hasPrefix:@"wxid_"] ? username : @"好友";
}

static NSString *WCAtlasConversationTitle(UIViewController *controller) {
    id contact = WCAtlasPrivateChatContact(controller);
    NSString *displayName = WCAtlasContactDisplayName(contact);
    if (displayName.length > 0) return displayName;
    NSString *title = controller.navigationItem.title ?: controller.title;
    if (title.length > 0 && ![title hasPrefix:@"已选择"] && ![title containsString:@"条消息"]) return title;
    return @"聊天摘录";
}

static void WCAtlasShowExportMessage(UIViewController *controller, NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

static UIImage *WCAtlasImageForMessage(id wrap) {
    for (NSString *selectorName in @[@"getRawHDThumbImagePath", @"getHDThumbImagePath", @"getThumbImagePath"]) {
        id path = WCAtlasExportCall(wrap, selectorName);
        if ([path isKindOfClass:[NSString class]] && [path length] > 0) {
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if (image) return image;
        }
    }
    id thumb = WCAtlasExportSafeValue(wrap, @"m_oImage");
    return [thumb isKindOfClass:[UIImage class]] ? thumb : nil;
}

static void WCAtlasSaveSelectedImages(UIViewController *controller, NSArray *messages) {
    NSUInteger count = 0;
    for (id wrap in messages) {
        if ([WCAtlasExportSafeValue(wrap, @"m_uiMessageType") unsignedIntegerValue] != 3) continue;
        UIImage *image = WCAtlasImageForMessage(wrap);
        if (!image) continue;
        UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
        count++;
    }
    WCAtlasShowExportMessage(controller, count > 0 ? @"正在保存" : @"没有可保存的图片",
                           count > 0 ? [NSString stringWithFormat:@"已提交 %lu 张图片到系统相册。", (unsigned long)count]
                                     : @"所选消息没有已下载到本机的图片。");
}

static CGFloat WCAtlasTextHeight(NSString *text, UIFont *font, CGFloat width) {
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{ NSFontAttributeName: font }
                                     context:nil];
    return MAX(font.lineHeight, ceil(CGRectGetHeight(rect)));
}

static UIImage *WCAtlasRenderShareCard(NSArray *messages, NSString *chatName, WCAtlasShareCardStyle style) {
    CGFloat width = 390.0;
    CGFloat horizontal = 28.0;
    CGFloat textWidth = width - horizontal * 2.0;
    UIFont *senderFont = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    UIFont *bodyFont = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:messages.count];
    CGFloat contentHeight = 88.0;
    for (id wrap in messages) {
        NSString *sender = WCAtlasSenderName(wrap);
        NSString *body = WCAtlasMessageBody(wrap);
        CGFloat bodyHeight = WCAtlasTextHeight(body, bodyFont, textWidth - (style == WCAtlasShareCardStyleConversation ? 24.0 : 0.0));
        CGFloat itemHeight = 22.0 + bodyHeight + 22.0;
        [items addObject:@{ @"sender": sender, @"body": body, @"height": @(itemHeight) }];
        contentHeight += itemHeight;
    }
    CGFloat height = MAX(180.0, contentHeight + 24.0);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = MAX(2.0, UIScreen.mainScreen.scale);
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width, height) format:format];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        UIColor *canvas = style == WCAtlasShareCardStyleDark ? [UIColor colorWithWhite:0.08 alpha:1.0] : (style == WCAtlasShareCardStyleConversation ? [UIColor colorWithWhite:0.94 alpha:1.0] : UIColor.whiteColor);
        UIColor *primary = style == WCAtlasShareCardStyleDark ? UIColor.whiteColor : UIColor.blackColor;
        UIColor *secondary = style == WCAtlasShareCardStyleDark ? [UIColor colorWithWhite:0.68 alpha:1.0] : [UIColor colorWithWhite:0.42 alpha:1.0];
        [canvas setFill];
        UIRectFill(CGRectMake(0.0, 0.0, width, height));
        NSString *header = chatName.length > 0 ? chatName : @"聊天摘录";
        [header drawInRect:CGRectMake(horizontal, 28.0, textWidth, 34.0)
           withAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold], NSForegroundColorAttributeName: primary }];
        CGFloat y = 82.0;
        for (NSDictionary *item in items) {
            CGFloat itemHeight = [item[@"height"] doubleValue];
            CGRect contentRect = CGRectMake(horizontal, y, textWidth, itemHeight - 10.0);
            if (style == WCAtlasShareCardStyleConversation) {
                [[UIColor whiteColor] setFill];
                [[UIBezierPath bezierPathWithRoundedRect:contentRect cornerRadius:14.0] fill];
            } else if (style == WCAtlasShareCardStyleMinimal) {
                [[UIColor colorWithWhite:0.90 alpha:1.0] setStroke];
                UIBezierPath *line = [UIBezierPath bezierPath];
                [line moveToPoint:CGPointMake(horizontal, CGRectGetMaxY(contentRect))];
                [line addLineToPoint:CGPointMake(width - horizontal, CGRectGetMaxY(contentRect))];
                line.lineWidth = 0.5;
                [line stroke];
            }
            CGFloat inset = style == WCAtlasShareCardStyleConversation ? 12.0 : 0.0;
            [item[@"sender"] drawInRect:CGRectMake(horizontal + inset, y + 8.0, textWidth - inset * 2.0, 18.0)
                         withAttributes:@{ NSFontAttributeName: senderFont, NSForegroundColorAttributeName: secondary }];
            [item[@"body"] drawInRect:CGRectMake(horizontal + inset, y + 31.0, textWidth - inset * 2.0, itemHeight - 38.0)
                       withAttributes:@{ NSFontAttributeName: bodyFont, NSForegroundColorAttributeName: primary }];
            y += itemHeight;
        }
    }];
}

static void WCAtlasPresentShareCard(UIViewController *controller, NSArray *messages, WCAtlasShareCardStyle style) {
    UIImage *card = WCAtlasRenderShareCard(messages, WCAtlasConversationTitle(controller), style);
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[card] applicationActivities:nil];
    UIPopoverPresentationController *popover = activity.popoverPresentationController;
    if (popover) { popover.sourceView = controller.view; popover.sourceRect = controller.view.bounds; }
    [controller presentViewController:activity animated:YES completion:nil];
}

static void WCAtlasPresentShareCardStylePicker(UIViewController *controller, NSArray *messages) {
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"选择分享卡片样式" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *styles = @[
        @{ @"title": @"极简留白", @"value": @(WCAtlasShareCardStyleMinimal) },
        @{ @"title": @"对话卡片", @"value": @(WCAtlasShareCardStyleConversation) },
        @{ @"title": @"深色简报", @"value": @(WCAtlasShareCardStyleDark) },
    ];
    for (NSDictionary *style in styles) {
        [picker addAction:[UIAlertAction actionWithTitle:style[@"title"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WCAtlasPresentShareCard(controller, messages, [style[@"value"] integerValue]);
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    if (popover) { popover.sourceView = controller.view; popover.sourceRect = controller.view.bounds; }
    [controller presentViewController:picker animated:YES completion:nil];
}

BOOL WCAtlasHandleChatMultiSelectAction(UIViewController *controller, NSString *identifier) {
    if (!controller || identifier.length == 0) return NO;
    BOOL recognized = [identifier isEqualToString:WCAtlasExportTextAction] ||
                      [identifier isEqualToString:WCAtlasSaveImagesAction] ||
                      [identifier isEqualToString:WCAtlasShareCardAction] ||
                      [identifier isEqualToString:WCAtlasQuickReplyImportAction];
    if (!recognized) return NO;
    NSArray *messages = WCAtlasSelectedMessages(controller);
    if (messages.count == 0) {
        WCAtlasShowExportMessage(controller, @"没有选中消息", @"请先选择至少一条消息。");
        return YES;
    }
    if ([identifier isEqualToString:WCAtlasQuickReplyImportAction]) {
        WCAtlasPresentQuickReplyImportConfiguration(controller, messages);
    } else if ([identifier isEqualToString:WCAtlasExportTextAction]) {
        NSMutableArray<NSString *> *bodies = [NSMutableArray arrayWithCapacity:messages.count];
        for (id wrap in messages) {
            NSString *body = [WCAtlasMessageBody(wrap) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (body.length > 0) [bodies addObject:body];
        }
        UIPasteboard.generalPasteboard.string = [bodies componentsJoinedByString:@"\n"];
        WCAtlasShowExportMessage(controller, @"已复制", [NSString stringWithFormat:@"%lu 条消息正文已复制到剪贴板。", (unsigned long)bodies.count]);
    } else if ([identifier isEqualToString:WCAtlasSaveImagesAction]) {
        WCAtlasSaveSelectedImages(controller, messages);
    } else {
        WCAtlasPresentShareCardStylePicker(controller, messages);
    }
    return YES;
}
