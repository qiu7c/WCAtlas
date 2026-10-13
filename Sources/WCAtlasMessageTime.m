#import "WCAtlasMessageTime.h"
#import "WCAtlasCompatibility.h"
#import "WCAtlasEnhancements.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

static const void *WCAtlasMessageTimeAvatarLabelKey = &WCAtlasMessageTimeAvatarLabelKey;
static const void *WCAtlasMessageTimeBubbleLabelKey = &WCAtlasMessageTimeBubbleLabelKey;
static const void *WCAtlasMessageTimeRefreshPendingKey = &WCAtlasMessageTimeRefreshPendingKey;
static const void *WCAtlasMessageTimeRefreshGenerationKey = &WCAtlasMessageTimeRefreshGenerationKey;
static NSString *const WCAtlasMessageTimeAvatarLabelIdentifier = @"com.qiu7c.wcatlas.message-time.avatar";
static NSString *const WCAtlasMessageTimeBubbleLabelIdentifier = @"com.qiu7c.wcatlas.message-time.bubble";

static id WCAtlasMessageTimeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id WCAtlasMessageTimeFirstValue(id object, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = WCAtlasMessageTimeValue(object, key);
        if (value) return value;
    }
    return nil;
}

static id WCAtlasMessageTimeViewModel(UIView *cell) {
    return WCAtlasMessageTimeFirstValue(cell, @[@"viewModel", @"m_viewModel"]);
}

static id WCAtlasMessageTimeMessage(id viewModel) {
    id message = WCAtlasMessageTimeFirstValue(viewModel, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    id parent = WCAtlasMessageTimeValue(viewModel, @"parentModel");
    return WCAtlasMessageTimeFirstValue(parent, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
}

static NSString *WCAtlasMessageTimeObjectString(id object, NSArray<NSString *> *keys) {
    id value = WCAtlasMessageTimeFirstValue(object, keys);
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

/// Cell reuse can leave delayed layout work targeting a different message.
/// Use the same stable fields WeChatX validates (local/server ID, create time,
/// sender and recipient), with object identity only as a last-resort fallback.
static NSString *WCAtlasMessageTimeIdentity(UIView *cell) {
    id viewModel = WCAtlasMessageTimeViewModel(cell);
    id message = WCAtlasMessageTimeMessage(viewModel);
    if (!viewModel || !message) return nil;
    NSString *localID = WCAtlasMessageTimeObjectString(message, @[@"m_uiMesLocalID", @"localID"]);
    NSString *serverID = WCAtlasMessageTimeObjectString(message, @[@"m_n64MesSvrID", @"svrID"]);
    NSString *createTime = WCAtlasMessageTimeObjectString(message, @[@"m_uiCreateTime", @"createTime"]);
    NSString *fromUser = WCAtlasMessageTimeObjectString(message, @[@"m_nsFromUsr", @"fromUsr"]);
    NSString *toUser = WCAtlasMessageTimeObjectString(message, @[@"m_nsToUsr", @"toUsr"]);
    if (localID.length == 0 && serverID.length == 0 && createTime.length == 0) {
        return [NSString stringWithFormat:@"vm:%p|msg:%p",
                (__bridge void *)viewModel, (__bridge void *)message];
    }
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            localID ?: @"", serverID ?: @"", createTime ?: @"",
            fromUser ?: @"", toUser ?: @""];
}

static BOOL WCAtlasMessageTimeIdentityMatches(UIView *cell, NSString *expectedIdentity) {
    NSString *currentIdentity = WCAtlasMessageTimeIdentity(cell);
    return currentIdentity == expectedIdentity || [currentIdentity isEqualToString:expectedIdentity];
}

static NSTimeInterval WCAtlasMessageTimeCreateTime(id message, id viewModel) {
    for (id object in @[message ?: NSNull.null, viewModel ?: NSNull.null]) {
        if (object == NSNull.null) continue;
        id value = WCAtlasMessageTimeFirstValue(object, @[@"m_uiCreateTime", @"createTime"]);
        NSTimeInterval time = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
        if (isfinite(time) && time > 0) return time;
    }
    return 0;
}

static UIView *WCAtlasMessageTimeDescendant(UIView *root, BOOL (^matches)(UIView *view)) {
    if (!root || !matches) return nil;
    for (UIView *subview in root.subviews) {
        if (matches(subview)) return subview;
        UIView *nested = WCAtlasMessageTimeDescendant(subview, matches);
        if (nested) return nested;
    }
    return nil;
}

static UIView *WCAtlasMessageTimeAvatarView(UIView *cell) {
    SEL selector = NSSelectorFromString(@"getHeadImageView");
    if ([cell respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
        if ([value isKindOfClass:UIView.class] && ![value isHidden]) return value;
    }
    UIView *avatar = WCAtlasMessageTimeDescendant(cell, ^BOOL(UIView *candidate) {
        return [NSStringFromClass(candidate.class) containsString:@"MMHeadImageView"];
    });
    return avatar.hidden ? nil : avatar;
}

static BOOL WCAtlasMessageTimeAnchorIsUsable(id value) {
    if (![value isKindOfClass:UIView.class]) return NO;
    UIView *view = value;
    return !view.hidden && view.alpha > 0.01 && CGRectGetWidth(view.bounds) > 1.0 && CGRectGetHeight(view.bounds) > 1.0;
}

static BOOL WCAtlasMessageTimeFrameIsUsable(CGRect frame, CGRect cellBounds) {
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame) || CGRectIsEmpty(frame)) return NO;
    if (!isfinite(CGRectGetMinX(frame)) || !isfinite(CGRectGetMinY(frame)) ||
        !isfinite(CGRectGetWidth(frame)) || !isfinite(CGRectGetHeight(frame))) return NO;
    return CGRectIntersectsRect(frame, CGRectInset(cellBounds, -80.0, -80.0));
}

BOOL WCAtlasShouldShowSplitMessageMetadata(id viewModel, BOOL preferHeadPart) {
    if (!viewModel) return NO;
    Class splitClass = NSClassFromString(@"TextMessageSubViewModel");
    BOOL isSplitModel = splitClass ? [viewModel isKindOfClass:splitClass]
                                   : [NSStringFromClass([viewModel class]) isEqualToString:@"TextMessageSubViewModel"];
    if (!isSplitModel) return YES;

    id parentModel = WCAtlasMessageTimeValue(viewModel, @"parentModel");
    id value = WCAtlasMessageTimeValue(parentModel, @"subViewModels");
    if ([value isKindOfClass:NSArray.class]) {
        NSArray *subViewModels = value;
        if (subViewModels.count > 1) {
            NSUInteger index = [subViewModels indexOfObjectIdenticalTo:viewModel];
            if (index != NSNotFound) {
                return preferHeadPart ? index == 0 : index == subViewModels.count - 1;
            }
        }
    }

    // Version fallback used by WeChat's long-split models when the parent
    // collection is unavailable during an intermediate layout pass.
    NSString *partKey = preferHeadPart ? @"isHeadPart" : @"isTailPart";
    id partValue = WCAtlasMessageTimeValue(viewModel, partKey);
    return partValue ? [partValue boolValue] : YES;
}

static void WCAtlasMessageTimeRemoveDuplicateLabels(UIView *cell,
                                                     NSString *identifier,
                                                     UILabel *preferred) {
    if (!cell || identifier.length == 0) return;
    // WCAtlas owns these labels and always attaches them directly to the cell.
    // A direct scan keeps this safe to run from every layoutSubviews pass.
    for (UIView *subview in cell.subviews.copy) {
        if (subview != preferred && [subview isKindOfClass:UILabel.class] &&
            [subview.accessibilityIdentifier isEqualToString:identifier]) {
            [subview removeFromSuperview];
        }
    }
}

UIView *WCAtlasMessageSideAnchorView(UIView *cell) {
    if (!cell) return nil;
    SEL selector = NSSelectorFromString(@"getBgImageView");
    if ([cell respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
        if (WCAtlasMessageTimeAnchorIsUsable(value)) return value;
    }
    id content = WCAtlasMessageTimeFirstValue(cell, @[@"m_contentView", @"contentView", @"m_msgContentView",
                                                    @"msgContentView", @"m_messageView", @"messageView",
                                                    @"m_nodeView", @"nodeView"]);
    if ([content isKindOfClass:UIView.class]) {
        if ([content respondsToSelector:selector]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(content, selector);
            if (WCAtlasMessageTimeAnchorIsUsable(value)) return value;
        }
        id value = WCAtlasMessageTimeFirstValue(content, @[@"m_bgImageView", @"bgImageView"]);
        if (WCAtlasMessageTimeAnchorIsUsable(value)) return value;
        if (WCAtlasMessageTimeAnchorIsUsable(content)) return content;
    }
    for (NSString *selectorName in @[@"getContentView", @"getMessageContentView", @"getMsgContentView", @"getNodeView"]) {
        SEL contentSelector = NSSelectorFromString(selectorName);
        if (![cell respondsToSelector:contentSelector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, contentSelector);
        if (![value isKindOfClass:UIView.class]) continue;
        if (WCAtlasMessageTimeAnchorIsUsable(value)) return value;
    }
    return nil;
}

static UILabel *WCAtlasMessageTimeLabel(UIView *cell, const void *key, NSString *identifier) {
    UILabel *label = objc_getAssociatedObject(cell, key);
    if (label) {
        if (label.superview != cell) [cell addSubview:label];
        label.accessibilityIdentifier = identifier;
        WCAtlasMessageTimeRemoveDuplicateLabels(cell, identifier, label);
        return label;
    }
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.numberOfLines = 1;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.userInteractionEnabled = NO;
    label.layer.zPosition = 900.0;
    label.accessibilityIdentifier = identifier;
    [cell addSubview:label];
    objc_setAssociatedObject(cell, key, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCAtlasMessageTimeRemoveDuplicateLabels(cell, identifier, label);
    return label;
}

static void WCAtlasSetMessageTimeLabelsHidden(UIView *cell) {
    UILabel *avatar = objc_getAssociatedObject(cell, WCAtlasMessageTimeAvatarLabelKey);
    UILabel *bubble = objc_getAssociatedObject(cell, WCAtlasMessageTimeBubbleLabelKey);
    WCAtlasMessageTimeRemoveDuplicateLabels(cell, WCAtlasMessageTimeAvatarLabelIdentifier, avatar);
    WCAtlasMessageTimeRemoveDuplicateLabels(cell, WCAtlasMessageTimeBubbleLabelIdentifier, bubble);
    avatar.hidden = YES;
    bubble.hidden = YES;
}

UILabel *WCAtlasVisibleMessageTimeSideLabel(UIView *cell) {
    UILabel *label = objc_getAssociatedObject(cell, WCAtlasMessageTimeBubbleLabelKey);
    if (!label || label.hidden || label.alpha <= 0.01 || label.superview == nil) return nil;
    return label;
}

void WCAtlasHideMessageTimeLabels(UIView *cell) {
    WCAtlasSetMessageTimeLabelsHidden(cell);
    NSUInteger generation = [objc_getAssociatedObject(cell, WCAtlasMessageTimeRefreshGenerationKey) unsignedIntegerValue];
    objc_setAssociatedObject(cell, WCAtlasMessageTimeRefreshGenerationKey,
                             @(generation + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, WCAtlasMessageTimeRefreshPendingKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *WCAtlasMessageTimeText(NSTimeInterval time, NSString *format) {
    static NSCache<NSString *, NSDateFormatter *> *formatters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ formatters = [NSCache new]; });
    NSDateFormatter *formatter = [formatters objectForKey:format];
    if (!formatter) {
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = format;
        [formatters setObject:formatter forKey:format];
    }
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
}

static void WCAtlasRefreshMessageTimeLabels(UIView *cell) {
    UILabel *existingAvatar = objc_getAssociatedObject(cell, WCAtlasMessageTimeAvatarLabelKey);
    UILabel *existingBubble = objc_getAssociatedObject(cell, WCAtlasMessageTimeBubbleLabelKey);
    WCAtlasMessageTimeRemoveDuplicateLabels(cell, WCAtlasMessageTimeAvatarLabelIdentifier, existingAvatar);
    WCAtlasMessageTimeRemoveDuplicateLabels(cell, WCAtlasMessageTimeBubbleLabelIdentifier, existingBubble);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasChatMessageTimeEnabledKey);
    BOOL bubbleSide = [defaults boolForKey:WCAtlasChatMessageTimeBubbleSideKey];
    // Bubble mode wins if legacy settings ever contain both booleans. When
    // neither is set, fall back to the default below-avatar mode.
    BOOL belowAvatar = !bubbleSide;
    if (!enabled || !cell.window) {
        WCAtlasHideMessageTimeLabels(cell);
        return;
    }

    id viewModel = WCAtlasMessageTimeViewModel(cell);
    if (!viewModel) {
        WCAtlasHideMessageTimeLabels(cell);
        return;
    }
    if (!WCAtlasShouldShowSplitMessageMetadata(viewModel, belowAvatar)) {
        WCAtlasSetMessageTimeLabelsHidden(cell);
        return;
    }
    id message = WCAtlasMessageTimeMessage(viewModel);
    NSTimeInterval time = WCAtlasMessageTimeCreateTime(message, viewModel);
    if (time <= 0) {
        WCAtlasHideMessageTimeLabels(cell);
        return;
    }

    NSString *format = [defaults stringForKey:WCAtlasChatMessageTimeFormatKey];
    if (format.length == 0) format = @"MM-dd HH:mm:ss";
    NSString *text = WCAtlasMessageTimeText(time, format);
    CGFloat configuredSize = [defaults doubleForKey:WCAtlasChatMessageTimeFontSizeKey];
    CGFloat fontSize = MIN(18.0, MAX(8.0, configuredSize > 0 ? configuredSize : 10.0));
    UIFontWeight fontWeight = [defaults boolForKey:WCAtlasChatMessageTimeBoldKey] ? UIFontWeightSemibold : UIFontWeightRegular;
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:fontWeight];
    UIColor *color = WCAtlasDynamicColorForDefaultsKeys(WCAtlasChatMessageTimeLightColorKey,
                                                       WCAtlasChatMessageTimeDarkColorKey,
                                                       WCAtlasChatMessageTimeColorKey,
                                                       [UIColor colorWithRed:0.56 green:0.56 blue:0.58 alpha:1.0],
                                                       [UIColor colorWithRed:0.60 green:0.60 blue:0.62 alpha:1.0]);
    CGFloat labelHeight = MAX(12.0, ceil(fontSize * 1.5));
    CGFloat measuredWidth = ceil([text sizeWithAttributes:@{NSFontAttributeName: font}].width) + 4.0;
    CGFloat labelWidth = MIN(118.0, MAX(50.0, measuredWidth));
    BOOL isSender = [WCAtlasMessageTimeValue(viewModel, @"isSender") boolValue];

    UILabel *avatarLabel = objc_getAssociatedObject(cell, WCAtlasMessageTimeAvatarLabelKey);
    if (belowAvatar) {
        UIView *avatar = WCAtlasMessageTimeAvatarView(cell);
        if (avatar) {
            avatarLabel = WCAtlasMessageTimeLabel(cell, WCAtlasMessageTimeAvatarLabelKey,
                                                  WCAtlasMessageTimeAvatarLabelIdentifier);
            CGRect frame = [avatar convertRect:avatar.bounds toView:cell];
            if (!WCAtlasMessageTimeFrameIsUsable(frame, cell.bounds)) {
                avatarLabel.hidden = YES;
                frame = CGRectNull;
            }
            if (!CGRectIsNull(frame)) {
                avatarLabel.text = text;
                avatarLabel.font = font;
                avatarLabel.textColor = color;
                CGFloat avatarSpacing = MIN(8.0, MAX(-6.0, [defaults doubleForKey:WCAtlasChatMessageTimeAvatarSpacingKey]));
                CGFloat fittedWidth = MIN(labelWidth, MAX(0.0, CGRectGetWidth(cell.bounds) - 4.0));
                CGFloat x = CGRectGetMidX(frame) - fittedWidth * 0.5;
                CGFloat y = CGRectGetMaxY(frame) + avatarSpacing;
                x = MIN(MAX(2.0, x), MAX(2.0, CGRectGetWidth(cell.bounds) - fittedWidth - 2.0));
                y = MIN(MAX(0.0, y), MAX(0.0, CGRectGetHeight(cell.bounds) - labelHeight));
                avatarLabel.frame = CGRectMake(x, y, fittedWidth, labelHeight);
                avatarLabel.hidden = NO;
            }
        } else {
            avatarLabel.hidden = YES;
        }
    } else {
        avatarLabel.hidden = YES;
    }

    UILabel *bubbleLabel = objc_getAssociatedObject(cell, WCAtlasMessageTimeBubbleLabelKey);
    if (bubbleSide) {
        UIView *bubble = WCAtlasMessageSideAnchorView(cell);
        if (bubble) {
            CGRect frame = [bubble convertRect:bubble.bounds toView:cell];
            if (!WCAtlasMessageTimeFrameIsUsable(frame, cell.bounds)) {
                bubbleLabel.hidden = YES;
                frame = CGRectNull;
            }
            if (!CGRectIsNull(frame)) {
                CGFloat gap = 5.0;
                CGFloat cellWidth = CGRectGetWidth(cell.bounds);
                CGFloat availableWidth = isSender ? CGRectGetMinX(frame) - gap - 2.0
                                                  : cellWidth - CGRectGetMaxX(frame) - gap - 2.0;
                if (availableWidth >= 40.0) {
                    CGFloat fittedWidth = MIN(labelWidth, availableWidth);
                    CGFloat x = isSender ? CGRectGetMinX(frame) - fittedWidth - gap : CGRectGetMaxX(frame) + gap;
                    bubbleLabel = WCAtlasMessageTimeLabel(cell, WCAtlasMessageTimeBubbleLabelKey,
                                                          WCAtlasMessageTimeBubbleLabelIdentifier);
                    bubbleLabel.text = text;
                    bubbleLabel.font = font;
                    bubbleLabel.textColor = color;
                    NSInteger verticalPosition = MIN(2, MAX(0, [defaults integerForKey:WCAtlasChatMessageTimeBubbleVerticalPositionKey]));
                    CGFloat y = CGRectGetMinY(frame);
                    if (verticalPosition == 1) y = CGRectGetMidY(frame) - labelHeight * 0.5;
                    else if (verticalPosition == 2) y = CGRectGetMaxY(frame) - labelHeight;
                    y = MIN(MAX(0.0, y), MAX(0.0, CGRectGetHeight(cell.bounds) - labelHeight));
                    bubbleLabel.frame = CGRectMake(x,
                                                   y,
                                                   fittedWidth,
                                                   labelHeight);
                    bubbleLabel.hidden = NO;
                } else {
                    bubbleLabel.hidden = YES;
                }
            }
        } else {
            bubbleLabel.hidden = YES;
        }
    } else {
        bubbleLabel.hidden = YES;
    }
    WCAtlasCompatibilityMarkTriggered(@"chat-message-time");
}

void WCAtlasLayoutMessageTimeLabels(UIView *cell) {
    if (!cell) return;
    if (!cell.window || !WCAtlasEnhancementEnabled(WCAtlasChatMessageTimeEnabledKey)) {
        WCAtlasSetMessageTimeLabelsHidden(cell);
        return;
    }
    [UIView performWithoutAnimation:^{
        WCAtlasRefreshMessageTimeLabels(cell);
    }];
}

void WCAtlasScheduleMessageTimeRefresh(UIView *cell) {
    if (!cell) return;
    if (!WCAtlasEnhancementEnabled(WCAtlasChatMessageTimeEnabledKey)) {
        WCAtlasHideMessageTimeLabels(cell);
        return;
    }
    if ([objc_getAssociatedObject(cell, WCAtlasMessageTimeRefreshPendingKey) boolValue]) return;
    objc_setAssociatedObject(cell, WCAtlasMessageTimeRefreshPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSUInteger generation = [objc_getAssociatedObject(cell, WCAtlasMessageTimeRefreshGenerationKey) unsignedIntegerValue];
    NSString *messageIdentity = WCAtlasMessageTimeIdentity(cell);
    __weak UIView *weakCell = cell;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongCell = weakCell;
        if (!strongCell ||
            [objc_getAssociatedObject(strongCell, WCAtlasMessageTimeRefreshGenerationKey) unsignedIntegerValue] != generation) return;
        if (WCAtlasMessageTimeIdentityMatches(strongCell, messageIdentity)) {
            WCAtlasRefreshMessageTimeLabels(strongCell);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *delayedCell = weakCell;
            if (!delayedCell ||
                [objc_getAssociatedObject(delayedCell, WCAtlasMessageTimeRefreshGenerationKey) unsignedIntegerValue] != generation) return;
            objc_setAssociatedObject(delayedCell, WCAtlasMessageTimeRefreshPendingKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (WCAtlasMessageTimeIdentityMatches(delayedCell, messageIdentity)) {
                WCAtlasRefreshMessageTimeLabels(delayedCell);
            }
        });
    });
}
