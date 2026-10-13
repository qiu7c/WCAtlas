#import "WCAtlasHomeCategories.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasPrivateAPI.h"
#import "WCAtlasSendConfirmation.h"
#import "WCAtlasSendConfirmationViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>

NSString *const WCAtlasHomeCategoriesEnabledKey = @"com.qiu7c.wcatlas.home.categories.enabled";
NSString *const WCAtlasHomeCategoriesDataKey = @"com.qiu7c.wcatlas.home.categories.data";

static NSString *const WCAtlasHomeCategorySessionPrefix = @"wcatlas_home_category_";
static NSString *const WCAtlasHomeCategoryAvatarFileKey = @"avatarFile";
static NSString *const WCAtlasHomeCategoryAvatarDirectoryName = @"WCAtlas/HomeCategoryAvatars";
static const CGFloat WCAtlasHomeCategoryRowHeight = 64.0;

#pragma mark - Persistent Model

static NSString *WCAtlasHomeCategoryIdentifier(void) {
    return NSUUID.UUID.UUIDString.lowercaseString;
}

static NSArray<NSString *> *WCAtlasHomeStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableOrderedSet<NSString *> *items = [NSMutableOrderedSet orderedSet];
    for (id item in value) if ([item isKindOfClass:NSString.class] && [item length] > 0) [items addObject:item];
    return items.array;
}

static NSDictionary *WCAtlasHomeFolder(id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    NSString *identifier = [raw[@"id"] isKindOfClass:NSString.class] ? raw[@"id"] : WCAtlasHomeCategoryIdentifier();
    NSString *title = [raw[@"title"] isKindOfClass:NSString.class] ? raw[@"title"] : @"文件夹";
    return @{@"id": identifier, @"title": title, @"sessions": WCAtlasHomeStringArray(raw[@"sessions"])};
}

static NSDictionary *WCAtlasHomeCategory(id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    NSString *identifier = [raw[@"id"] isKindOfClass:NSString.class] ? raw[@"id"] : WCAtlasHomeCategoryIdentifier();
    NSString *title = [raw[@"title"] isKindOfClass:NSString.class] ? raw[@"title"] : @"分类";
    NSMutableArray *folders = [NSMutableArray array];
    for (id value in [raw[@"folders"] isKindOfClass:NSArray.class] ? raw[@"folders"] : @[]) {
        NSDictionary *folder = WCAtlasHomeFolder(value);
        if (folder) [folders addObject:folder];
    }
    NSMutableDictionary *category = [@{@"id": identifier, @"title": title,
        @"sessions": WCAtlasHomeStringArray(raw[@"sessions"]), @"folders": folders} mutableCopy];
    NSString *avatarFile = [raw[WCAtlasHomeCategoryAvatarFileKey] isKindOfClass:NSString.class]
        ? [raw[WCAtlasHomeCategoryAvatarFileKey] lastPathComponent] : nil;
    if (avatarFile.length > 0) category[WCAtlasHomeCategoryAvatarFileKey] = avatarFile;
    return category;
}

static NSArray<NSDictionary *> *WCAtlasHomeCategories(void) {
    NSArray *raw = [NSUserDefaults.standardUserDefaults arrayForKey:WCAtlasHomeCategoriesDataKey];
    NSMutableArray *categories = [NSMutableArray array];
    for (id value in raw ?: @[]) {
        NSDictionary *category = WCAtlasHomeCategory(value);
        if (category) [categories addObject:category];
    }
    return categories;
}

static NSCache<NSString *, UIImage *> *WCAtlasHomeCategoryAvatarCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSCache new]; });
    return cache;
}

static NSHashTable<UITableView *> *WCAtlasHomeCategoryHomepageTables(void) {
    static NSHashTable<UITableView *> *tables;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ tables = [NSHashTable weakObjectsHashTable]; });
    return tables;
}

static void WCAtlasHomeTrackHomepageTable(UITableView *tableView) {
    if (tableView) [WCAtlasHomeCategoryHomepageTables() addObject:tableView];
}

static void WCAtlasHomeReloadTrackedHomepageTables(void) {
    for (UITableView *tableView in [WCAtlasHomeCategoryHomepageTables() allObjects]) {
        [tableView reloadData];
        [tableView setNeedsLayout];
    }
}

static NSURL *WCAtlasHomeCategoryAvatarDirectory(void) {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
    NSURL *directory = [support URLByAppendingPathComponent:WCAtlasHomeCategoryAvatarDirectoryName
                                                isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

static NSURL *WCAtlasHomeCategoryAvatarURL(NSString *fileName) {
    NSString *safeName = [fileName isKindOfClass:NSString.class] ? fileName.lastPathComponent : nil;
    return safeName.length > 0
        ? [WCAtlasHomeCategoryAvatarDirectory() URLByAppendingPathComponent:safeName isDirectory:NO] : nil;
}

static void WCAtlasSetHomeCategories(NSArray<NSDictionary *> *categories) {
    [NSUserDefaults.standardUserDefaults setObject:categories ?: @[] forKey:WCAtlasHomeCategoriesDataKey];
    [WCAtlasHomeCategoryAvatarCache() removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        WCAtlasPrivateRefreshHomeSessionList();
        WCAtlasHomeReloadTrackedHomepageTables();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WCAtlasHomeReloadTrackedHomepageTables(); });
    });
}

static NSArray<NSString *> *WCAtlasOrderedSessionsInCategory(NSDictionary *category) {
    NSMutableOrderedSet<NSString *> *sessions = [NSMutableOrderedSet orderedSetWithArray:
        WCAtlasHomeStringArray(category[@"sessions"])];
    for (NSDictionary *folder in [category[@"folders"] isKindOfClass:NSArray.class] ? category[@"folders"] : @[]) {
        [sessions addObjectsFromArray:WCAtlasHomeStringArray(folder[@"sessions"])];
    }
    return sessions.array;
}

static NSString *WCAtlasHomeConversationTitle(NSString *userName) {
    id contact = WCAtlasPrivateContact(userName);
    return WCAtlasPrivateContactDisplayName(contact, userName) ?: userName;
}

#pragma mark - Native Homepage Sessions

@interface WCAtlasHomeCategoryBrowserController : UITableViewController
@property (nonatomic, copy) NSString *categoryID;
@property (nonatomic, copy, nullable) NSString *folderID;
@property (nonatomic, strong, nullable) UIColor *navigationBackgroundColor;
- (void)applyBrowserNavigationAppearance;
- (void)closeCategoryBrowser;
- (void)leaveCategoryBrowser;
- (void)showCategorySettings;
@end

BOOL WCAtlasHomeCategoriesIsSyntheticUserName(NSString *userName) {
    return [userName hasPrefix:WCAtlasHomeCategorySessionPrefix];
}

BOOL WCAtlasHomeCategoriesShouldFilterSelectionObject(id object) {
    NSString *userName = [object isKindOfClass:NSString.class]
        ? (NSString *)object : WCAtlasPrivateHomeSessionUserName(object);
    return WCAtlasHomeCategoriesIsSyntheticUserName(userName);
}

id WCAtlasHomeCategoriesFilterSelectionObjects(id objects) {
    if (![objects isKindOfClass:NSArray.class]) return objects;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:[objects count]];
    BOOL removed = NO;
    for (id object in (NSArray *)objects) {
        if (WCAtlasHomeCategoriesShouldFilterSelectionObject(object)) {
            removed = YES;
            continue;
        }
        [filtered addObject:object];
    }
    return removed ? filtered : objects;
}

static NSDictionary *WCAtlasHomeCategoryForSyntheticUserName(NSString *userName) {
    if (!WCAtlasHomeCategoriesIsSyntheticUserName(userName)) return nil;
    NSString *identifier = [userName substringFromIndex:WCAtlasHomeCategorySessionPrefix.length];
    for (NSDictionary *category in WCAtlasHomeCategories()) {
        if ([category[@"id"] isEqualToString:identifier]) return category;
    }
    return nil;
}

static UIColor *WCAtlasHomeOpaqueBackgroundColor(UIViewController *controller,
                                                 UITableView *tableView) {
    UIColor *color = controller.view.backgroundColor;
    CGFloat alpha = color ? CGColorGetAlpha(color.CGColor) : 0.0;
    if (alpha < 0.5) {
        color = tableView.backgroundColor;
        alpha = color ? CGColorGetAlpha(color.CGColor) : 0.0;
    }
    if (!color || alpha < 0.5) color = UIColor.systemBackgroundColor;
    return color;
}

void WCAtlasHomeCategoriesApplyToSessionManager(id sessionManager) {
    NSCAssert(NSThread.isMainThread, @"Homepage categories must be applied on the main thread");
    NSArray<NSDictionary *> *categories = WCAtlasHomeCategories();
    BOOL enabled = WCAtlasEnhancementEnabled(WCAtlasHomeCategoriesEnabledKey) && categories.count > 0;
    NSMutableSet<NSString *> *hidden = [NSMutableSet set];
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    if (enabled) {
        for (NSDictionary *category in categories) {
            NSArray<NSString *> *orderedSessions = WCAtlasOrderedSessionsInCategory(category);
            NSSet<NSString *> *sessions = [NSSet setWithArray:orderedSessions];
            for (NSString *userName in sessions) {
                if (userName.length > 0 && !WCAtlasHomeCategoriesIsSyntheticUserName(userName)) {
                    [hidden addObject:userName];
                }
            }
            NSString *identifier = category[@"id"];
            NSString *title = category[@"title"];
            if (identifier.length == 0 || title.length == 0) continue;
            [entries addObject:@{
                @"userName": [WCAtlasHomeCategorySessionPrefix stringByAppendingString:identifier],
                @"title": title,
                @"subtitle": @"",
                @"sessionUserNames": orderedSessions
            }];
        }
    }
    WCAtlasPrivateReplaceHomeCategorySessions(sessionManager, hidden, entries);
}

BOOL WCAtlasHomeCategoriesHandleSelection(id controller, UITableView *tableView, NSIndexPath *indexPath) {
    if (![controller isKindOfClass:UIViewController.class] || !indexPath) return NO;
    WCAtlasHomeTrackHomepageTable(tableView);
    id session = WCAtlasPrivateHomeSessionData(controller, tableView, indexPath);
    NSString *userName = WCAtlasPrivateHomeSessionUserName(session);
    NSDictionary *category = WCAtlasHomeCategoryForSyntheticUserName(userName);
    if (!category) return NO;
    WCAtlasHomeCategoryBrowserController *browser = [WCAtlasHomeCategoryBrowserController new];
    browser.categoryID = category[@"id"];
    browser.hidesBottomBarWhenPushed = YES;
    browser.navigationBackgroundColor = WCAtlasHomeOpaqueBackgroundColor((UIViewController *)controller, tableView);
    [browser applyBrowserNavigationAppearance];
    browser.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:browser
        action:@selector(closeCategoryBrowser)];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:browser];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [(UIViewController *)controller presentViewController:navigation animated:YES completion:nil];
    return YES;
}

void WCAtlasHomeCategoriesConfigureCellData(id cellData) {
    NSString *userName = WCAtlasPrivateHomeSessionUserName(cellData);
    NSDictionary *category = WCAtlasHomeCategoryForSyntheticUserName(userName);
    if (!category) return;
    NSString *avatarUserName = [WCAtlasHomeCategorySessionPrefix stringByAppendingString:category[@"id"] ?: @""];
    WCAtlasPrivateConfigureHomeCategoryCellData(cellData, category[@"title"], @"", avatarUserName);
}

static const NSInteger WCAtlasHomeUnreadBadgeTag = 0x57434247;
static char WCAtlasHomeNativeBadgeHiddenKey;

static BOOL WCAtlasHomeLooksLikeNativeUnreadBadge(UIView *view) {
    if (!view || view.tag == WCAtlasHomeUnreadBadgeTag) return NO;
    NSString *semantic = [NSString stringWithFormat:@"%@ %@ %@",
        NSStringFromClass(view.class), view.accessibilityIdentifier ?: @"",
        view.accessibilityLabel ?: @""];
    if ([semantic rangeOfString:@"badge" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [semantic rangeOfString:@"unread" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [semantic rangeOfString:@"reddot" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    UIColor *color = view.backgroundColor;
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha] && alpha > 0.5 &&
        red > 0.75 && green < 0.5 && blue < 0.5 &&
        CGRectGetWidth(view.bounds) <= 60.0 && CGRectGetHeight(view.bounds) <= 30.0) return YES;
    return NO;
}

static void WCAtlasHomeSetNativeUnreadBadgesHidden(UIView *root, BOOL hidden) {
    for (UIView *view in root.subviews) {
        NSNumber *managed = objc_getAssociatedObject(view, &WCAtlasHomeNativeBadgeHiddenKey);
        if (hidden && WCAtlasHomeLooksLikeNativeUnreadBadge(view)) {
            if (!managed) objc_setAssociatedObject(view, &WCAtlasHomeNativeBadgeHiddenKey,
                @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            view.hidden = YES;
        } else if (!hidden && managed) {
            view.hidden = managed.boolValue;
            objc_setAssociatedObject(view, &WCAtlasHomeNativeBadgeHiddenKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        WCAtlasHomeSetNativeUnreadBadgesHidden(view, hidden);
    }
}

static UIView *WCAtlasHomeFindAvatarView(UIView *root, BOOL imageFallback) {
    for (UIView *view in root.subviews) {
        if (view.tag == WCAtlasHomeUnreadBadgeTag || view.hidden || view.alpha <= 0.01) continue;
        CGSize size = view.bounds.size;
        BOOL plausibleSize = size.width >= 30.0 && size.width <= 80.0 &&
                             size.height >= 30.0 && size.height <= 80.0;
        NSString *className = NSStringFromClass(view.class);
        if (plausibleSize && [className rangeOfString:@"Head" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return view;
        }
        UIView *nested = WCAtlasHomeFindAvatarView(view, imageFallback);
        if (nested) return nested;
        if (imageFallback && plausibleSize && [view isKindOfClass:UIImageView.class]) return view;
    }
    return nil;
}

void WCAtlasHomeCategoriesLayoutUnreadBadge(UIView *itemView) {
    if (![itemView isKindOfClass:UIView.class]) return;
    NSCAssert(NSThread.isMainThread, @"Homepage category unread badges must be laid out on the main thread");

    UILabel *badge = (UILabel *)[itemView viewWithTag:WCAtlasHomeUnreadBadgeTag];
    NSString *userName = WCAtlasPrivateHomeSessionUserName(itemView);
    NSDictionary *category = WCAtlasHomeCategoryForSyntheticUserName(userName);
    WCAtlasHomeSetNativeUnreadBadgesHidden(itemView, category != nil);
    if (category) {
        WCAtlasPrivateConfigureVisibleHomeCategoryItemView(
            itemView, category[@"title"] ?: @"分类", @"", userName);
    }
    NSUInteger unreadCount = WCAtlasHomeCategoriesIsSyntheticUserName(userName)
        ? WCAtlasPrivateHomeCategoryUnreadCountForUserName(userName) : 0;
    BOOL showDot = WCAtlasHomeCategoriesIsSyntheticUserName(userName) &&
                   WCAtlasPrivateHomeCategoryShowsUnreadDot(userName);
    if (unreadCount == 0 && !showDot) {
        badge.hidden = YES;
        return;
    }

    UIView *avatar = WCAtlasHomeFindAvatarView(itemView, NO) ?: WCAtlasHomeFindAvatarView(itemView, YES);
    if (!avatar) {
        badge.hidden = YES;
        return;
    }
    if (!badge) {
        badge = [[UILabel alloc] initWithFrame:CGRectZero];
        badge.tag = WCAtlasHomeUnreadBadgeTag;
        badge.userInteractionEnabled = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor colorWithRed:0.98 green:0.24 blue:0.24 alpha:1.0];
        badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
        badge.layer.cornerRadius = 9.0;
        badge.layer.masksToBounds = YES;
        badge.accessibilityIdentifier = @"WCAtlasHomeCategoryUnreadBadge";
        [itemView addSubview:badge];
    }

    badge.text = showDot ? @"" : (unreadCount > 99 ? @"99+" :
        [NSString stringWithFormat:@"%lu", (unsigned long)unreadCount]);
    CGFloat height = showDot ? 10.0 : 18.0;
    CGSize textSize = [badge sizeThatFits:CGSizeMake(CGFLOAT_MAX, height)];
    CGFloat width = showDot ? 10.0 : MAX(18.0, ceil(textSize.width) + 8.0);
    badge.layer.cornerRadius = height * 0.5;
    CGRect avatarRect = [avatar convertRect:avatar.bounds toView:itemView];
    CGFloat x = CGRectGetMaxX(avatarRect) - 5.0;
    CGFloat y = CGRectGetMinY(avatarRect) - 4.0;
    x = MIN(MAX(0.0, x), MAX(0.0, CGRectGetWidth(itemView.bounds) - width));
    y = MIN(MAX(0.0, y), MAX(0.0, CGRectGetHeight(itemView.bounds) - height));
    badge.frame = CGRectMake(x, y, width, height);
    badge.hidden = NO;
    [itemView bringSubviewToFront:badge];
}

static UIView *WCAtlasHomeBrowserAccessoryView(NSArray<NSString *> *userNames) {
    NSDictionary<NSString *, NSNumber *> *state = WCAtlasPrivateHomeUnreadStateForUserNames(userNames);
    NSUInteger count = [state[@"count"] unsignedIntegerValue];
    BOOL showDot = count == 0 && [state[@"dot"] boolValue];
    if (count == 0 && !showDot) return nil;

    UILabel *badge = [UILabel new];
    badge.text = showDot ? @"" : (count > 99 ? @"99+" :
        [NSString stringWithFormat:@"%lu", (unsigned long)count]);
    badge.textAlignment = NSTextAlignmentCenter;
    badge.textColor = UIColor.whiteColor;
    badge.backgroundColor = [UIColor colorWithRed:0.98 green:0.24 blue:0.24 alpha:1.0];
    badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    CGFloat height = showDot ? 10.0 : 18.0;
    CGFloat width = showDot ? 10.0 : MAX(18.0,
        ceil([badge sizeThatFits:CGSizeMake(CGFLOAT_MAX, height)].width) + 8.0);
    badge.layer.cornerRadius = height * 0.5;
    badge.layer.masksToBounds = YES;
    [badge.widthAnchor constraintEqualToConstant:width].active = YES;
    [badge.heightAnchor constraintEqualToConstant:height].active = YES;

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.tintColor = UIColor.tertiaryLabelColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [chevron.widthAnchor constraintEqualToConstant:8.0].active = YES;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[badge, chevron]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8.0;
    stack.frame = CGRectMake(0.0, 0.0, width + 16.0, MAX(18.0, height));
    return stack;
}

#pragma mark - Management UI

@interface WCAtlasHomeCategoryDetailController : UITableViewController
@property (nonatomic, copy) NSString *categoryID;
@property (nonatomic, copy, nullable) NSString *folderID;
@end

static NSUInteger WCAtlasCategoryIndex(NSString *identifier, NSArray *categories) {
    return [categories indexOfObjectPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        (void)idx; (void)stop; return [item[@"id"] isEqualToString:identifier];
    }];
}

static NSArray<NSDictionary *> *WCAtlasHomeCombinedItems(NSDictionary *category, NSDictionary *folder) {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    if (!folder) {
        for (NSDictionary *child in [category[@"folders"] isKindOfClass:NSArray.class] ? category[@"folders"] : @[]) {
            [items addObject:@{@"kind": @"folder", @"value": child}];
        }
    }
    for (NSString *userName in WCAtlasHomeStringArray((folder ?: category)[@"sessions"])) {
        [items addObject:@{@"kind": @"session", @"value": userName}];
    }
    return items;
}

static const NSInteger WCAtlasHomeAvatarViewTag = 0x57434156;

static UIImage *WCAtlasHomeAvatarPlaceholder(NSString *symbolName, UIColor *color) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                                  weight:UIImageSymbolWeightRegular];
    UIImage *symbol = [[UIImage systemImageNamed:symbolName withConfiguration:configuration]
        imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(40.0, 40.0), NO, UIScreen.mainScreen.scale);
    CGSize size = symbol.size;
    [symbol drawInRect:CGRectMake((40.0 - size.width) * 0.5, (40.0 - size.height) * 0.5,
                                  size.width, size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *WCAtlasHomeCategoryIconImage(void) {
    static UIImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = WCAtlasHomeAvatarPlaceholder(@"folder.fill",
            [UIColor colorWithRed:0.20 green:0.48 blue:0.92 alpha:1.0]);
    });
    return image;
}

UIImage *WCAtlasHomeCategoryIconImageForUserName(NSString *userName) {
    NSDictionary *category = WCAtlasHomeCategoryForSyntheticUserName(userName);
    NSString *identifier = category[@"id"];
    NSString *avatarFile = category[WCAtlasHomeCategoryAvatarFileKey];
    if (identifier.length == 0 || avatarFile.length == 0) return WCAtlasHomeCategoryIconImage();
    UIImage *cached = [WCAtlasHomeCategoryAvatarCache() objectForKey:identifier];
    if (cached) return cached;
    UIImage *image = [UIImage imageWithContentsOfFile:WCAtlasHomeCategoryAvatarURL(avatarFile).path];
    if (!image) return WCAtlasHomeCategoryIconImage();
    [WCAtlasHomeCategoryAvatarCache() setObject:image forKey:identifier];
    return image;
}

static void WCAtlasHomeConfigureFolderImage(UITableViewCell *cell) {
    [[cell.imageView viewWithTag:WCAtlasHomeAvatarViewTag] removeFromSuperview];
    cell.imageView.image = WCAtlasHomeCategoryIconImage();
    cell.imageView.layer.cornerRadius = 0.0;
}

static void WCAtlasHomeConfigureCategoryImage(UITableViewCell *cell, NSDictionary *category) {
    [[cell.imageView viewWithTag:WCAtlasHomeAvatarViewTag] removeFromSuperview];
    NSString *identifier = category[@"id"];
    NSString *userName = identifier.length > 0
        ? [WCAtlasHomeCategorySessionPrefix stringByAppendingString:identifier] : nil;
    NSString *avatarFile = category[WCAtlasHomeCategoryAvatarFileKey];
    BOOL custom = avatarFile.length > 0 &&
                  [NSFileManager.defaultManager fileExistsAtPath:WCAtlasHomeCategoryAvatarURL(avatarFile).path];
    cell.imageView.image = WCAtlasHomeCategoryIconImageForUserName(userName);
    cell.imageView.layer.cornerRadius = custom ? 8.0 : 0.0;
    cell.imageView.clipsToBounds = custom;
    cell.imageView.contentMode = custom ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleAspectFit;
}

static void WCAtlasHomeConfigureConversationImage(UITableViewCell *cell, NSString *userName) {
    [[cell.imageView viewWithTag:WCAtlasHomeAvatarViewTag] removeFromSuperview];
    id contact = WCAtlasPrivateContact(userName);
    UIImage *cached = WCAtlasPrivateContactAvatarImage(contact);
    if (cached) {
        cell.imageView.image = cached;
        cell.imageView.layer.cornerRadius = 6.0;
        cell.imageView.clipsToBounds = YES;
        return;
    }
    cell.imageView.image = WCAtlasHomeAvatarPlaceholder(@"person.2.fill", UIColor.secondaryLabelColor);
    UIView *avatar = WCAtlasPrivateContactAvatarView(contact, userName, YES);
    if (!avatar) return;
    avatar.tag = WCAtlasHomeAvatarViewTag;
    avatar.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    avatar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    avatar.userInteractionEnabled = NO;
    cell.imageView.clipsToBounds = YES;
    cell.imageView.layer.cornerRadius = 6.0;
    [cell.imageView addSubview:avatar];
}

#pragma mark - Homepage Category Actions

static char WCAtlasHomeCategoryAvatarPickerDelegateKey;

static BOOL WCAtlasHomeMutateCategory(NSString *identifier,
                                      void (^mutation)(NSMutableDictionary *category)) {
    if (identifier.length == 0 || !mutation) return NO;
    NSMutableArray<NSDictionary *> *categories = [WCAtlasHomeCategories() mutableCopy];
    NSUInteger index = WCAtlasCategoryIndex(identifier, categories);
    if (index == NSNotFound) return NO;
    NSMutableDictionary *category = [categories[index] mutableCopy];
    mutation(category);
    categories[index] = category;
    WCAtlasSetHomeCategories(categories);
    return YES;
}

static UIViewController *WCAtlasHomeCategoryPresenter(id controller, UITableView *tableView) {
    UIViewController *presenter = [controller isKindOfClass:UIViewController.class] ? controller : nil;
    for (UIResponder *responder = tableView; !presenter && responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:UIViewController.class]) presenter = (UIViewController *)responder;
    }
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    return presenter;
}

static void WCAtlasHomeRemoveCategoryAvatarFile(NSString *fileName) {
    NSURL *URL = WCAtlasHomeCategoryAvatarURL(fileName);
    if (URL) [NSFileManager.defaultManager removeItemAtURL:URL error:nil];
}

static NSString *WCAtlasHomeStoreOriginalCategoryAvatar(
    NSDictionary<UIImagePickerControllerInfoKey, id> *info) {
    NSURL *sourceURL = [info[UIImagePickerControllerImageURL] isKindOfClass:NSURL.class]
        ? info[UIImagePickerControllerImageURL] : nil;
    NSData *data = sourceURL ? [NSData dataWithContentsOfURL:sourceURL options:NSDataReadingMappedIfSafe error:nil] : nil;
    NSString *extension = sourceURL.pathExtension.lowercaseString;
    NSCharacterSet *invalid = [NSCharacterSet.alphanumericCharacterSet invertedSet];
    if (extension.length == 0 || extension.length > 8 ||
        [extension rangeOfCharacterFromSet:invalid].location != NSNotFound) extension = @"jpg";
    if (data.length == 0) {
        UIImage *image = [info[UIImagePickerControllerOriginalImage] isKindOfClass:UIImage.class]
            ? info[UIImagePickerControllerOriginalImage] : nil;
        data = image ? UIImageJPEGRepresentation(image, 1.0) : nil;
        extension = @"jpg";
    }
    if (data.length == 0) return nil;
    NSString *fileName = [NSUUID.UUID.UUIDString.lowercaseString stringByAppendingPathExtension:extension];
    NSURL *destination = WCAtlasHomeCategoryAvatarURL(fileName);
    return [data writeToURL:destination options:NSDataWritingAtomic error:nil] ? fileName : nil;
}

@interface WCAtlasHomeCategoryAvatarPickerDelegate : NSObject
    <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *categoryID;
@end

@implementation WCAtlasHomeCategoryAvatarPickerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSString *avatarFile = WCAtlasHomeStoreOriginalCategoryAvatar(info);
    if (avatarFile.length > 0) {
        __block NSString *oldAvatarFile = nil;
        BOOL updated = WCAtlasHomeMutateCategory(self.categoryID, ^(NSMutableDictionary *category) {
            oldAvatarFile = category[WCAtlasHomeCategoryAvatarFileKey];
            category[WCAtlasHomeCategoryAvatarFileKey] = avatarFile;
        });
        if (updated) WCAtlasHomeRemoveCategoryAvatarFile(oldAvatarFile);
        else WCAtlasHomeRemoveCategoryAvatarFile(avatarFile);
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end


static void WCAtlasHomePresentCategoryRename(UIViewController *presenter, NSDictionary *category) {
    if (!presenter || !category) return;
    NSString *identifier = category[@"id"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名分类"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = category[@"title"];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        NSString *title = [alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (title.length == 0) return;
        WCAtlasHomeMutateCategory(identifier, ^(NSMutableDictionary *mutableCategory) {
            mutableCategory[@"title"] = title;
        });
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void WCAtlasHomePresentCategoryAvatar(UIViewController *presenter, NSDictionary *category) {
    if (!presenter || !category) return;
    NSString *identifier = category[@"id"];
    NSString *currentAvatarFile = category[WCAtlasHomeCategoryAvatarFileKey];
    BOOL hasCustomAvatar = currentAvatarFile.length > 0 &&
        [NSFileManager.defaultManager fileExistsAtPath:WCAtlasHomeCategoryAvatarURL(currentAvatarFile).path];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"分类头像"
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"从相册选择" style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *action) {
            UIImagePickerController *picker = [UIImagePickerController new];
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            picker.allowsEditing = NO;
            WCAtlasHomeCategoryAvatarPickerDelegate *delegate = [WCAtlasHomeCategoryAvatarPickerDelegate new];
            delegate.categoryID = identifier;
            picker.delegate = delegate;
            objc_setAssociatedObject(picker, &WCAtlasHomeCategoryAvatarPickerDelegateKey, delegate,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [presenter presentViewController:picker animated:YES completion:nil];
        }]];
    }
    if (hasCustomAvatar) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"恢复默认头像" style:UIAlertActionStyleDestructive
                                               handler:^(__unused UIAlertAction *action) {
            WCAtlasHomeMutateCategory(identifier, ^(NSMutableDictionary *mutableCategory) {
                NSString *avatarFile = mutableCategory[WCAtlasHomeCategoryAvatarFileKey];
                [mutableCategory removeObjectForKey:WCAtlasHomeCategoryAvatarFileKey];
                WCAtlasHomeRemoveCategoryAvatarFile(avatarFile);
            });
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = presenter.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                        CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    }
    [presenter presentViewController:sheet animated:YES completion:nil];
}

UISwipeActionsConfiguration *WCAtlasHomeCategoriesLeadingSwipeActions(id controller,
                                                                       UITableView *tableView,
                                                                       NSIndexPath *indexPath) {
    NSCAssert(NSThread.isMainThread, @"Homepage category actions require the main thread");
    if (!tableView || !indexPath) return nil;
    WCAtlasHomeTrackHomepageTable(tableView);
    id session = WCAtlasPrivateHomeSessionData(controller, tableView, indexPath);
    NSDictionary *category = WCAtlasHomeCategoryForSyntheticUserName(WCAtlasPrivateHomeSessionUserName(session));
    UIViewController *presenter = WCAtlasHomeCategoryPresenter(controller, tableView);
    if (!category || !presenter) return nil;
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"重命名"
                                                                        handler:^(__unused UIContextualAction *action,
                                                                                  __unused UIView *sourceView,
                                                                                  void (^completionHandler)(BOOL)) {
        completionHandler(YES);
        dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasHomePresentCategoryRename(presenter, category); });
    }];
    rename.backgroundColor = UIColor.systemBlueColor;
    UIContextualAction *avatar = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"更换头像"
                                                                        handler:^(__unused UIContextualAction *action,
                                                                                  __unused UIView *sourceView,
                                                                                  void (^completionHandler)(BOOL)) {
        completionHandler(YES);
        dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasHomePresentCategoryAvatar(presenter, category); });
    }];
    avatar.backgroundColor = UIColor.systemPurpleColor;
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[rename, avatar]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

@implementation WCAtlasHomeCategoryBrowserController

- (void)applyBrowserNavigationAppearance {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.navigationBackgroundColor ?: UIColor.systemBackgroundColor;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.labelColor};
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        self.navigationItem.compactScrollEdgeAppearance = appearance;
    }
}

- (void)closeCategoryBrowser {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)leaveCategoryBrowser {
    if (self.folderID.length > 0 && self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self closeCategoryBrowser];
    }
}

- (NSArray<NSString *> *)sendConfirmationSessions {
    NSArray<NSString *> *sessions = self.folder
        ? WCAtlasHomeStringArray(self.folder[@"sessions"])
        : WCAtlasOrderedSessionsInCategory(self.category);
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (NSString *userName in sessions) {
        if ([userName hasSuffix:@"@chatroom"]) [groups addObject:userName];
    }
    return groups;
}

- (void)showCategorySettings {
    NSArray<NSString *> *groups = [self sendConfirmationSessions];
    NSString *scopeTitle = (self.folder ?: self.category)[@"title"] ?: @"当前归纳";
    if (groups.count == 0) {
        UIAlertController *empty = [UIAlertController alertControllerWithTitle:@"归纳群设置"
            message:@"当前归纳中没有可设置的群聊。" preferredStyle:UIAlertControllerStyleAlert];
        [empty addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:empty animated:YES completion:nil];
        return;
    }
    NSUInteger protectedCount = 0;
    NSSet<NSString *> *protectedGroups = [NSSet setWithArray:WCAtlasSendConfirmationProtectedConversations()];
    for (NSString *userName in groups) if ([protectedGroups containsObject:userName]) protectedCount++;
    NSString *message = [NSString stringWithFormat:
        @"“%@”包含 %lu 个群聊，其中 %lu 个已开启。开启后，向这些群聊发送消息前都需要确认。",
        scopeTitle, (unsigned long)groups.count, (unsigned long)protectedCount];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"归纳群设置"
        message:message preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"开启发送确认"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSUInteger count = WCAtlasSendConfirmationSetProtectedConversations(groups, YES);
        NSString *result = count > 0
            ? [NSString stringWithFormat:@"已为 %lu 个群聊开启发送确认", (unsigned long)count]
            : @"当前账号暂不可用，请稍后重试";
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"归纳群设置"
            message:result preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:done animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"关闭发送确认"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSUInteger count = WCAtlasSendConfirmationSetProtectedConversations(groups, NO);
        NSString *result = count > 0
            ? [NSString stringWithFormat:@"已为 %lu 个群聊关闭发送确认", (unsigned long)count]
            : @"当前账号暂不可用，请稍后重试";
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"归纳群设置"
            message:result preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:done animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) popover.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (NSDictionary *)category {
    for (NSDictionary *category in WCAtlasHomeCategories()) if ([category[@"id"] isEqualToString:self.categoryID]) return category;
    return nil;
}
- (NSDictionary *)folder {
    for (NSDictionary *folder in [self.category[@"folders"] isKindOfClass:NSArray.class] ? self.category[@"folders"] : @[]) if ([folder[@"id"] isEqualToString:self.folderID]) return folder;
    return nil;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self applyBrowserNavigationAppearance];
    self.title = (self.folder ?: self.category)[@"title"] ?: @"分类";
    self.hidesBottomBarWhenPushed = YES;
    self.tableView.rowHeight = WCAtlasHomeCategoryRowHeight;
    self.tableView.estimatedRowHeight = WCAtlasHomeCategoryRowHeight;
    self.tableView.backgroundColor = self.navigationBackgroundColor ?: UIColor.systemBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    UIBarButtonItem *back = self.navigationItem.leftBarButtonItem ?: [[UIBarButtonItem alloc]
        initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(leaveCategoryBrowser)];
    UIImage *settingsImage = [UIImage systemImageNamed:@"gearshape"];
    UIBarButtonItem *settings = settingsImage
        ? [[UIBarButtonItem alloc] initWithImage:settingsImage style:UIBarButtonItemStylePlain
                                         target:self action:@selector(showCategorySettings)]
        : [[UIBarButtonItem alloc] initWithTitle:@"设置" style:UIBarButtonItemStylePlain
                                          target:self action:@selector(showCategorySettings)];
    self.navigationItem.leftBarButtonItem = back;
    self.navigationItem.rightBarButtonItem = settings;
}
- (void)viewWillAppear:(BOOL)animated {
    [self applyBrowserNavigationAppearance];
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return WCAtlasHomeCombinedItems(self.category, self.folder).count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"browser"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"browser"];
    NSDictionary *item = WCAtlasHomeCombinedItems(self.category, self.folder)[indexPath.row];
    cell.accessoryView = nil;
    if ([item[@"kind"] isEqualToString:@"folder"]) {
        NSDictionary *folder = item[@"value"];
        cell.textLabel.text = folder[@"title"];
        WCAtlasHomeConfigureFolderImage(cell);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = WCAtlasHomeBrowserAccessoryView(WCAtlasHomeStringArray(folder[@"sessions"]));
    } else {
        NSString *userName = item[@"value"];
        cell.textLabel.text = WCAtlasHomeConversationTitle(userName);
        WCAtlasHomeConfigureConversationImage(cell, userName);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = WCAtlasHomeBrowserAccessoryView(userName.length > 0 ? @[userName] : @[]);
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSArray<NSDictionary *> *items = WCAtlasHomeCombinedItems(self.category, self.folder);
    if (indexPath.row >= items.count) return;
    NSDictionary *item = items[indexPath.row];
    if ([item[@"kind"] isEqualToString:@"folder"]) {
        NSDictionary *folder = item[@"value"];
        WCAtlasHomeCategoryBrowserController *browser = [WCAtlasHomeCategoryBrowserController new];
        browser.categoryID = self.categoryID;
        browser.folderID = folder[@"id"];
        browser.hidesBottomBarWhenPushed = YES;
        browser.navigationBackgroundColor = self.navigationBackgroundColor;
        [browser applyBrowserNavigationAppearance];
        [self.navigationController pushViewController:browser animated:YES];
        return;
    }
    NSString *userName = item[@"value"];
    WCAtlasPushPrivateChat(self, userName, YES);
}

@end

@implementation WCAtlasHomeCategoriesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"首页会话归类";
    self.tableView.rowHeight = WCAtlasHomeCategoryRowHeight;
    self.tableView.estimatedRowHeight = WCAtlasHomeCategoryRowHeight;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCategory)];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return MAX(1, (NSInteger)WCAtlasHomeCategories().count); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"category"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"category"];
    NSArray *categories = WCAtlasHomeCategories();
    if (categories.count == 0) { cell.textLabel.text = @"暂无分类，点击右上角 + 新建"; cell.imageView.image = nil; cell.accessoryType = UITableViewCellAccessoryNone; return cell; }
    NSDictionary *category = categories[indexPath.row];
    cell.textLabel.text = category[@"title"];
    WCAtlasHomeConfigureCategoryImage(cell, category);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *categories = WCAtlasHomeCategories(); if (indexPath.row >= categories.count) return;
    WCAtlasHomeCategoryDetailController *detail = [WCAtlasHomeCategoryDetailController new]; detail.categoryID = categories[indexPath.row][@"id"];
    [self.navigationController pushViewController:detail animated:YES];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *categories = [WCAtlasHomeCategories() mutableCopy]; if (indexPath.row >= categories.count) return;
    NSString *avatarFile = categories[indexPath.row][WCAtlasHomeCategoryAvatarFileKey];
    [categories removeObjectAtIndex:indexPath.row];
    WCAtlasSetHomeCategories(categories); WCAtlasHomeRemoveCategoryAvatarFile(avatarFile); [self.tableView reloadData];
}
- (void)addCategory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建首页分类" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"例如：工作或家人"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *title = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (!title.length) return;
        NSMutableArray *categories = [WCAtlasHomeCategories() mutableCopy];
        [categories addObject:@{@"id": WCAtlasHomeCategoryIdentifier(), @"title": title, @"sessions": @[], @"folders": @[]}];
        WCAtlasSetHomeCategories(categories); [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@implementation WCAtlasHomeCategoryDetailController

- (NSDictionary *)category {
    for (NSDictionary *category in WCAtlasHomeCategories()) if ([category[@"id"] isEqualToString:self.categoryID]) return category;
    return nil;
}
- (NSDictionary *)folder {
    for (NSDictionary *folder in [self.category[@"folders"] isKindOfClass:NSArray.class] ? self.category[@"folders"] : @[]) if ([folder[@"id"] isEqualToString:self.folderID]) return folder;
    return nil;
}
- (NSArray<NSString *> *)sessions { return WCAtlasHomeStringArray((self.folder ?: self.category)[@"sessions"]); }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = (self.folder ?: self.category)[@"title"] ?: @"归类";
    self.tableView.rowHeight = WCAtlasHomeCategoryRowHeight;
    self.tableView.estimatedRowHeight = WCAtlasHomeCategoryRowHeight;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem)];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return MAX(1, (NSInteger)WCAtlasHomeCombinedItems(self.category, self.folder).count); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"detail"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"detail"];
    NSArray *items = WCAtlasHomeCombinedItems(self.category, self.folder);
    if (items.count == 0) { cell.textLabel.text = @"暂无内容"; cell.imageView.image = nil; cell.accessoryType = UITableViewCellAccessoryNone; return cell; }
    NSDictionary *item = items[indexPath.row];
    if ([item[@"kind"] isEqualToString:@"session"]) {
        NSString *userName = item[@"value"]; cell.textLabel.text = WCAtlasHomeConversationTitle(userName); WCAtlasHomeConfigureConversationImage(cell, userName); cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSDictionary *folder = item[@"value"]; cell.textLabel.text = folder[@"title"]; WCAtlasHomeConfigureFolderImage(cell); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *items = WCAtlasHomeCombinedItems(self.category, self.folder); if (indexPath.row >= items.count) return;
    NSDictionary *item = items[indexPath.row]; if (![item[@"kind"] isEqualToString:@"folder"]) return;
    NSDictionary *folder = item[@"value"];
    WCAtlasHomeCategoryDetailController *detail = [WCAtlasHomeCategoryDetailController new]; detail.categoryID = self.categoryID; detail.folderID = folder[@"id"];
    [self.navigationController pushViewController:detail animated:YES];
}
- (void)addItem {
    if (self.folderID) { [self chooseSessions]; return; }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"添加内容" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"选择会话" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self chooseSessions]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self addFolder]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController; if (popover) { popover.barButtonItem = self.navigationItem.rightBarButtonItem; }
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)chooseSessions {
    NSMutableOrderedSet *selected = [NSMutableOrderedSet orderedSetWithArray:self.sessions]; __weak typeof(self) weakSelf = self;
    __block UIViewController *picker = WCAtlasCreateConversationPicker(@"选择归类会话", @"好友和群聊均可归类；每个会话只保留一个一级分类或文件夹位置。", ^BOOL(NSString *userName) { return [selected containsObject:userName]; }, ^(NSString *userName) { if ([selected containsObject:userName]) [selected removeObject:userName]; else if (userName.length) [selected addObject:userName]; });
    WCAtlasConfigureConversationPickerCompletion(picker, ^{ [weakSelf saveSessions:selected.array]; [picker.navigationController popViewControllerAnimated:YES]; });
    [self.navigationController pushViewController:picker animated:YES];
}
- (void)saveSessions:(NSArray *)sessions {
    NSArray<NSString *> *normalized = WCAtlasHomeStringArray(sessions);
    NSSet<NSString *> *assigned = [NSSet setWithArray:normalized];
    NSMutableArray *categories = [WCAtlasHomeCategories() mutableCopy];
    NSUInteger targetCategoryIndex = WCAtlasCategoryIndex(self.categoryID, categories);
    if (targetCategoryIndex == NSNotFound) return;
    for (NSUInteger categoryIndex = 0; categoryIndex < categories.count; categoryIndex++) {
        NSMutableDictionary *category = [categories[categoryIndex] mutableCopy];
        BOOL targetCategory = categoryIndex == targetCategoryIndex;
        NSArray *directSessions = WCAtlasHomeStringArray(category[@"sessions"]);
        if (targetCategory && self.folderID.length == 0) {
            category[@"sessions"] = normalized;
        } else {
            NSMutableArray *remaining = [NSMutableArray array];
            for (NSString *userName in directSessions) {
                if (![assigned containsObject:userName]) [remaining addObject:userName];
            }
            category[@"sessions"] = remaining;
        }
        NSMutableArray *folders = [NSMutableArray array];
        for (NSDictionary *rawFolder in category[@"folders"] ?: @[]) {
            NSMutableDictionary *folder = [rawFolder mutableCopy];
            BOOL targetFolder = targetCategory && [folder[@"id"] isEqualToString:self.folderID];
            if (targetFolder) {
                folder[@"sessions"] = normalized;
            } else {
                NSMutableArray *remaining = [NSMutableArray array];
                for (NSString *userName in WCAtlasHomeStringArray(folder[@"sessions"])) {
                    if (![assigned containsObject:userName]) [remaining addObject:userName];
                }
                folder[@"sessions"] = remaining;
            }
            [folders addObject:folder];
        }
        category[@"folders"] = folders;
        categories[categoryIndex] = category;
    }
    WCAtlasSetHomeCategories(categories);
    [self.tableView reloadData];
}
- (void)addFolder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"文件夹名称"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { NSString *title = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (!title.length) return; NSMutableArray *categories = [WCAtlasHomeCategories() mutableCopy]; NSUInteger index = WCAtlasCategoryIndex(self.categoryID, categories); if (index == NSNotFound) return; NSMutableDictionary *category = [categories[index] mutableCopy]; NSMutableArray *folders = [category[@"folders"] mutableCopy] ?: [NSMutableArray array]; [folders addObject:@{@"id": WCAtlasHomeCategoryIdentifier(), @"title": title, @"sessions": @[]}]; category[@"folders"] = folders; categories[index] = category; WCAtlasSetHomeCategories(categories); [self.tableView reloadData]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; if (style != UITableViewCellEditingStyleDelete) return;
    NSArray *items = WCAtlasHomeCombinedItems(self.category, self.folder); if (indexPath.row >= items.count) return;
    NSDictionary *item = items[indexPath.row];
    if ([item[@"kind"] isEqualToString:@"session"]) { NSMutableArray *sessions = [self.sessions mutableCopy]; [sessions removeObject:item[@"value"]]; [self saveSessions:sessions]; return; }
    NSDictionary *targetFolder = item[@"value"];
    NSMutableArray *categories = [WCAtlasHomeCategories() mutableCopy]; NSUInteger index = WCAtlasCategoryIndex(self.categoryID, categories); if (index == NSNotFound) return; NSMutableDictionary *category = [categories[index] mutableCopy]; NSMutableArray *folders = [category[@"folders"] mutableCopy]; NSUInteger folderIndex = [folders indexOfObjectPassingTest:^BOOL(NSDictionary *folder, NSUInteger idx, BOOL *stop) { (void)idx; (void)stop; return [folder[@"id"] isEqualToString:targetFolder[@"id"]]; }]; if (folderIndex != NSNotFound) { [folders removeObjectAtIndex:folderIndex]; category[@"folders"] = folders; categories[index] = category; WCAtlasSetHomeCategories(categories); [self.tableView reloadData]; }
}
@end
