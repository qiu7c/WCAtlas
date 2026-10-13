#import "WCAtlasAntiRevoke.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "WCAtlasLogging.h"
#import "WCAtlasAccount.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasInterfaceTweaks.h"

static NSUInteger WCAtlasUIntegerValue(id object, NSString *key);

NSString *const WCAtlasAntiRevokePromptDidChangeNotification = @"WCAtlasAntiRevokePromptDidChangeNotification";
static NSString *const WCAtlasAntiRevokeSidePromptRecordsKey = @"com.qiu7c.wcatlas.message.anti-revoke.side-records";
static NSString *const WCAtlasAntiRevokeArchiveKey = @"com.qiu7c.wcatlas.message.anti-revoke.archive";
static NSString *const WCAtlasAntiRevokeLocalPromptContentsKey = @"com.qiu7c.wcatlas.message.anti-revoke.local-prompt-contents";

static NSMutableArray<NSDictionary *> *WCAtlasAntiRevokeMemoryRecords(void) {
    static NSMutableArray<NSDictionary *> *records;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasAntiRevokeArchiveKey];
        records = [([saved isKindOfClass:[NSArray class]] ? saved : @[]) mutableCopy];
    });
    return records;
}

void WCAtlasAntiRevokeSetPersistenceEnabled(BOOL enabled) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:enabled forKey:WCAtlasAntiRevokePersistRecordsKey];
    if (enabled) {
        @synchronized (WCAtlasAntiRevokeMemoryRecords()) { [defaults setObject:WCAtlasAntiRevokeMemoryRecords() forKey:WCAtlasAntiRevokeArchiveKey]; }
    } else {
        [defaults removeObjectForKey:WCAtlasAntiRevokeArchiveKey];
    }
}

static void WCAtlasAntiRevokeAppendRecord(NSString *session, NSString *operatorName, id message, NSString *summary, NSDate *date) {
    NSUInteger type = WCAtlasUIntegerValue(message, @"m_uiMessageType");
    NSDictionary *record = @{
        @"session": session ?: @"",
        @"contact": operatorName ?: @"用户",
        @"summary": summary ?: @"",
        @"type": @(type),
        @"time": @((date ?: [NSDate date]).timeIntervalSince1970),
    };
    @synchronized (WCAtlasAntiRevokeMemoryRecords()) {
        [WCAtlasAntiRevokeMemoryRecords() insertObject:record atIndex:0];
        if (WCAtlasAntiRevokeMemoryRecords().count > 500) {
            [WCAtlasAntiRevokeMemoryRecords() removeObjectsInRange:NSMakeRange(500, WCAtlasAntiRevokeMemoryRecords().count - 500)];
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:WCAtlasAntiRevokePersistRecordsKey]) {
            [[NSUserDefaults standardUserDefaults] setObject:WCAtlasAntiRevokeMemoryRecords() forKey:WCAtlasAntiRevokeArchiveKey];
        }
    }
}

static NSString *const WCAtlasDefaultLocalRevokeTemplate =
    @"拦截到一条{用户名}撤回的消息\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n内容：{内容}";

static NSString *const WCAtlasDefaultRevokeReplyTemplate =
    @"【捕捉到一条撤回消息】\n操作用户：{用户名}\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n"
    @"撤回内容：{内容}\n\n撤回无效，消息已保存";

static id WCAtlasSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void WCAtlasSafeSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {}
}

static NSString *WCAtlasStringValue(id object, NSString *key) {
    id value = WCAtlasSafeValue(object, key);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSUInteger WCAtlasUIntegerValue(id object, NSString *key) {
    id value = WCAtlasSafeValue(object, key);
    return [value respondsToSelector:@selector(unsignedIntegerValue)] ? [value unsignedIntegerValue] : 0;
}

static unsigned long long WCAtlasUInt64Value(id object, NSString *key) {
    id value = WCAtlasSafeValue(object, key);
    if (![value respondsToSelector:@selector(unsignedLongLongValue)]) return 0;
    return [value unsignedLongLongValue];
}

static NSArray<NSString *> *WCAtlasSidePromptRecordKeys(id message) {
    unsigned long long serverID = WCAtlasUInt64Value(message, @"m_n64MesSvrID");
    unsigned long long localID = WCAtlasUInt64Value(message, @"m_uiMesLocalID");
    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:1];
    if (serverID > 0) {
        [keys addObject:[NSString stringWithFormat:@"server:%llu", serverID]];
        return keys;
    }
    if (localID > 0) {
        NSString *account = WCAtlasCurrentUserWXID() ?: @"";
        NSString *fromUser = WCAtlasStringValue(message, @"m_nsFromUsr") ?: @"";
        NSString *toUser = WCAtlasStringValue(message, @"m_nsToUsr") ?: @"";
        NSUInteger createTime = WCAtlasUIntegerValue(message, @"m_uiCreateTime");
        [keys addObject:[NSString stringWithFormat:@"local:%@:%@:%@:%llu:%lu",
                         account, fromUser, toUser, localID, (unsigned long)createTime]];
    }
    return keys;
}

NSString *WCAtlasAntiRevokeSidePromptForMessage(id message) {
    NSArray<NSString *> *recordKeys = WCAtlasSidePromptRecordKeys(message);
    if (recordKeys.count == 0) return nil;
    NSDictionary *records = [[NSUserDefaults standardUserDefaults] dictionaryForKey:WCAtlasAntiRevokeSidePromptRecordsKey];
    BOOL matched = NO;
    for (NSString *recordKey in recordKeys) {
        if (records[recordKey]) { matched = YES; break; }
    }
    if (!matched) return nil;
    NSString *customText = [[NSUserDefaults standardUserDefaults] stringForKey:WCAtlasAntiRevokeSideTextKey];
    return customText.length > 0 ? customText : @"已拦截撤回";
}

BOOL WCAtlasAntiRevokeIsLocalPromptMessage(id message) {
    if (WCAtlasUIntegerValue(message, @"m_uiMessageType") != 10000) return NO;
    NSString *content = WCAtlasStringValue(message, @"m_nsContent");
    if (content.length == 0) return NO;
    NSArray<NSString *> *knownContents = [[NSUserDefaults standardUserDefaults] arrayForKey:WCAtlasAntiRevokeLocalPromptContentsKey];
    return [knownContents containsObject:content];
}

static void WCAtlasRememberLocalPromptContent(NSString *content) {
    if (content.length == 0) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *knownContents = [[defaults arrayForKey:WCAtlasAntiRevokeLocalPromptContentsKey] mutableCopy] ?: [NSMutableArray array];
    [knownContents removeObject:content];
    [knownContents insertObject:content atIndex:0];
    if (knownContents.count > 200) [knownContents removeObjectsInRange:NSMakeRange(200, knownContents.count - 200)];
    [defaults setObject:knownContents forKey:WCAtlasAntiRevokeLocalPromptContentsKey];
}

static void WCAtlasRememberSidePrompt(id message, NSString *text, unsigned long long explicitServerID) {
    NSMutableArray<NSString *> *recordKeys = [WCAtlasSidePromptRecordKeys(message) mutableCopy];
    if (explicitServerID > 0) {
        NSString *serverKey = [NSString stringWithFormat:@"server:%llu", explicitServerID];
        if (![recordKeys containsObject:serverKey]) [recordKeys addObject:serverKey];
    }
    if (recordKeys.count == 0 || text.length == 0) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    @synchronized (defaults) {
        NSMutableDictionary *records = [[defaults dictionaryForKey:WCAtlasAntiRevokeSidePromptRecordsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
        while (records.count >= 800) [records removeObjectForKey:records.allKeys.firstObject];
        for (NSString *recordKey in recordKeys) records[recordKey] = text;
        [defaults setObject:records forKey:WCAtlasAntiRevokeSidePromptRecordsKey];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
    });
}

static NSString *WCAtlasTextBetween(NSString *text, NSString *opening, NSString *closing) {
    if (text.length == 0 || opening.length == 0 || closing.length == 0) return nil;
    NSRange first = [text rangeOfString:opening];
    if (first.location == NSNotFound) return nil;
    NSUInteger contentStart = NSMaxRange(first);
    if (contentStart > text.length) return nil;
    NSRange searchRange = NSMakeRange(contentStart, text.length - contentStart);
    NSRange last = [text rangeOfString:closing options:0 range:searchRange];
    if (last.location == NSNotFound) return nil;
    return [text substringWithRange:NSMakeRange(contentStart, last.location - contentStart)];
}

static NSDictionary<NSString *, NSString *> *WCAtlasDateFields(NSDate *date) {
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                           NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *parts = [[NSCalendar currentCalendar] components:units fromDate:date];
    return @{
        @"yyyy": [NSString stringWithFormat:@"%ld", (long)parts.year],
        @"MM": [NSString stringWithFormat:@"%02ld", (long)parts.month],
        @"dd": [NSString stringWithFormat:@"%02ld", (long)parts.day],
        @"HH": [NSString stringWithFormat:@"%02ld", (long)parts.hour],
        @"mm": [NSString stringWithFormat:@"%02ld", (long)parts.minute],
        @"ss": [NSString stringWithFormat:@"%02ld", (long)parts.second],
    };
}

static NSString *WCAtlasMessageTypeName(NSUInteger type) {
    switch (type) {
        case 1:  return @"文本";
        case 3:  return @"图片";
        case 34: return @"语音";
        case 42: return @"名片";
        case 43: return @"视频";
        case 47: return @"表情";
        case 48: return @"位置";
        case 49: return @"分享";
        default: return [NSString stringWithFormat:@"类型(%lu)", (unsigned long)type];
    }
}

static NSString *WCAtlasContentSummary(id message) {
    NSUInteger type = WCAtlasUIntegerValue(message, @"m_uiMessageType");
    NSString *content = WCAtlasStringValue(message, @"m_nsContent");
    if (type == 1 && content.length > 0) return content;
    return [NSString stringWithFormat:@"[%@]", WCAtlasMessageTypeName(type)];
}

static NSString *WCAtlasApplyRevokeTemplate(NSString *templateText,
                                          NSString *operatorName,
                                          NSString *contentSummary,
                                          NSDate *messageDate) {
    NSString *result = [templateText stringByReplacingOccurrencesOfString:@"{用户名}"
                                                                withString:operatorName ?: @"用户"];
    result = [result stringByReplacingOccurrencesOfString:@"{内容}"
                                                withString:contentSummary ?: @""];
    NSDictionary<NSString *, NSString *> *fields = WCAtlasDateFields(messageDate ?: [NSDate date]);
    for (NSString *key in fields) {
        result = [result stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key]
                                                    withString:fields[key]];
    }
    return result;
}

static NSString *WCAtlasRevokeOperatorName(NSString *replaceMessage) {
    NSRange phrase = [replaceMessage rangeOfString:@"撤回了一条消息"];
    NSString *name = phrase.location == NSNotFound ? @"用户" : [replaceMessage substringToIndex:phrase.location];
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length >= 2 && [name hasPrefix:@"\""] && [name hasSuffix:@"\""]) {
        name = [name substringWithRange:NSMakeRange(1, name.length - 2)];
    }
    return name.length > 0 ? name : @"用户";
}

static id WCAtlasNewMessageWrap(NSUInteger type) {
    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector]) return nil;
    id allocated = [wrapClass alloc];
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(allocated, initSelector, type);
}

static id WCAtlasOriginalMessage(id manager, NSString *session, long long serverID) {
    SEL selector = sel_registerName("GetMsg:n64SvrID:");
    if (!manager || ![manager respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL, NSString *, long long))objc_msgSend)(manager, selector, session, serverID);
}

static BOOL WCAtlasInsertLocalMessage(id manager, NSString *session, id message) {
    SEL selector = sel_registerName("AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:");
    if (![manager respondsToSelector:selector]) return NO;
    ((void (*)(id, SEL, NSString *, id, BOOL, BOOL))objc_msgSend)(manager, selector, session, message, YES, NO);
    return YES;
}

static void WCAtlasSendMessage(id manager, NSString *session, id message) {
    SEL selector = sel_registerName("AddMsg:MsgWrap:");
    if (![manager respondsToSelector:selector]) return;
    ((void (*)(id, SEL, NSString *, id))objc_msgSend)(manager, selector, session, message);
}

BOOL WCAtlasHandleRevokeMessage(id messageManager, id incomingMessage) {
    if (!WCAtlasEnhancementEnabled(WCAtlasAntiRevokeKey) || !incomingMessage) return NO;

    NSString *xml = WCAtlasStringValue(incomingMessage, @"m_nsContent");
    BOOL isRevokeXML = [xml containsString:@"<sysmsg type=\"revokemsg\""] ||
                       [xml containsString:@"<sysmsg type='revokemsg'"] ||
                       [xml containsString:@"<revokemsg>"];
    if (!isRevokeXML) return NO;

    NSString *session = WCAtlasTextBetween(xml, @"<session>", @"</session>");
    NSString *serverIDText = WCAtlasTextBetween(xml, @"<newmsgid>", @"</newmsgid>");
    NSString *replaceMessage = WCAtlasTextBetween(xml, @"<replacemsg><![CDATA[", @"]]></replacemsg>");
    long long serverID = serverIDText.longLongValue;
    if (session.length == 0 || serverID == 0 || replaceMessage.length == 0) return NO;

    // Own-message revoke notifications must keep WeChat's original behavior.
    if ([replaceMessage hasPrefix:@"你"] || [replaceMessage containsString:@"你撤回了一条消息"]) return NO;

    NSString *selfUsername = WCAtlasCurrentUserWXID();
    if (selfUsername.length == 0) return NO;
    id original = WCAtlasOriginalMessage(messageManager, session, serverID);
    NSString *originalFrom = WCAtlasStringValue(original, @"m_nsFromUsr");
    if (!original || (selfUsername.length > 0 && [originalFrom isEqualToString:selfUsername])) return NO;

    NSString *operatorName = WCAtlasRevokeOperatorName(replaceMessage);
    if ([operatorName isEqualToString:selfUsername]) return NO;
    NSUInteger createTime = WCAtlasUIntegerValue(original, @"m_uiCreateTime");
    NSDate *messageDate = [NSDate dateWithTimeIntervalSince1970:createTime];
    NSString *summary = WCAtlasContentSummary(original);
    WCAtlasAntiRevokeAppendRecord(session, operatorName, original, summary, messageDate);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *localTemplate = [defaults stringForKey:WCAtlasAntiRevokeLocalTemplateKey];
    if (localTemplate.length == 0) localTemplate = WCAtlasDefaultLocalRevokeTemplate;

    NSInteger promptStyle = [defaults integerForKey:WCAtlasAntiRevokePromptStyleKey];
    if (promptStyle == 1) {
        WCAtlasRememberSidePrompt(original, @"已拦截撤回", (unsigned long long)serverID);
    } else {
        id localMessage = WCAtlasNewMessageWrap(10000);
        if (!localMessage) return NO;
        WCAtlasSafeSetValue(localMessage, @"m_nsFromUsr", originalFrom);
        WCAtlasSafeSetValue(localMessage, @"m_nsToUsr", WCAtlasStringValue(original, @"m_nsToUsr"));
        WCAtlasSafeSetValue(localMessage, @"m_uiStatus", @4);
        NSString *localPromptContent = WCAtlasApplyRevokeTemplate(localTemplate, operatorName, summary, messageDate);
        WCAtlasSafeSetValue(localMessage, @"m_nsContent", localPromptContent);
        WCAtlasSafeSetValue(localMessage, @"m_uiCreateTime", @(createTime + 1));
        if (!WCAtlasInsertLocalMessage(messageManager, session, localMessage)) return NO;
        WCAtlasRememberLocalPromptContent(localPromptContent);
    }
    WCAtlasLog(@"已拦截 %@ 的撤回消息：%@", operatorName, summary);

    if (![defaults boolForKey:WCAtlasAntiRevokeNotifySenderKey]) return YES;
    NSTimeInterval filter = [defaults doubleForKey:WCAtlasAntiRevokeTimeFilterKey];
    NSTimeInterval age = [NSDate date].timeIntervalSince1970 - createTime;
    if (filter > 0.0 && age > filter) return YES;

    NSString *replyTemplate = [defaults stringForKey:WCAtlasAntiRevokeReplyTemplateKey];
    if (replyTemplate.length == 0) replyTemplate = WCAtlasDefaultRevokeReplyTemplate;
    NSString *replyText = WCAtlasApplyRevokeTemplate(replyTemplate, operatorName, summary, messageDate);
    id reply = WCAtlasNewMessageWrap(1);
    if (!reply) return YES;
    NSString *target = [session containsString:@"@chatroom"] ? session : originalFrom;
    WCAtlasSafeSetValue(reply, @"m_nsContent", replyText);
    WCAtlasSafeSetValue(reply, @"m_nsFromUsr", selfUsername);
    WCAtlasSafeSetValue(reply, @"m_nsToUsr", target);
    WCAtlasSafeSetValue(reply, @"m_uiStatus", @4);
    WCAtlasSafeSetValue(reply, @"m_uiCreateTime", @((NSUInteger)[NSDate date].timeIntervalSince1970));
    WCAtlasSendMessage(messageManager, target, reply);
    WCAtlasLog(@"已向撤回者发送提示（会话：%@）", target);
    return YES;
}

@interface WCAtlasAntiRevokeRecordsViewController () <UISearchBarDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleRecords;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation WCAtlasAntiRevokeRecordsViewController

- (instancetype)init { return [self initWithStyle:UITableViewStyleInsetGrouped]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"防撤回记录";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UISearchBar *searchBar = [UISearchBar new];
    searchBar.delegate = self;
    searchBar.placeholder = @"搜索联系人或内容";
    WCAtlasInstallSearchBarInTableView(searchBar, self.tableView);
    self.searchBar = searchBar;
    [self reloadRecordsWithQuery:nil];
}

- (void)reloadRecordsWithQuery:(NSString *)query {
    NSArray *records;
    @synchronized (WCAtlasAntiRevokeMemoryRecords()) { records = [WCAtlasAntiRevokeMemoryRecords() copy]; }
    NSString *needle = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (needle.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *record, __unused NSDictionary *bindings) {
            return [record[@"contact"] localizedCaseInsensitiveContainsString:needle] ||
                   [record[@"summary"] localizedCaseInsensitiveContainsString:needle] ||
                   [record[@"session"] localizedCaseInsensitiveContainsString:needle];
        }];
        records = [records filteredArrayUsingPredicate:predicate];
    }
    self.visibleRecords = records;
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    (void)searchBar;
    [self reloadRecordsWithQuery:searchText];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section { return self.visibleRecords.count; }

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    if (self.visibleRecords.count == 0) return @"本次运行尚未拦截撤回消息。默认记录只保存在内存中。";
    return [[NSUserDefaults standardUserDefaults] boolForKey:WCAtlasAntiRevokePersistRecordsKey]
        ? @"已开启本地保存，仅保存消息摘要和类型，不复制媒体文件。"
        : @"记录仅在本次微信运行期间保存在内存中。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"revoke-record"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"revoke-record"];
    NSDictionary *record = self.visibleRecords[indexPath.row];
    NSUInteger type = [record[@"type"] unsignedIntegerValue];
    NSString *category = type == 1 ? @"文字" : (type == 3 ? @"图片" : (type == 49 ? @"文件/分享" : WCAtlasMessageTypeName(type)));
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[record[@"time"] doubleValue]];
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"MM-dd HH:mm:ss";
    });
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", record[@"contact"], category];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %@", [formatter stringFromDate:date], record[@"summary"]];
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [UIImage systemImageNamed:type == 3 ? @"photo" : (type == 1 ? @"text.bubble" : @"doc")];
    cell.imageView.tintColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

@interface WCAtlasAntiRevokeAppearanceViewController () <UITextFieldDelegate, UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UITextField *xField;
@property (nonatomic, strong) UITextField *yField;
@property (nonatomic, strong) UIButton *colorButton;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, assign) CGPoint panStart;
@end

@implementation WCAtlasAntiRevokeAppearanceViewController

- (void)applyPreviewStageBackground {
    self.stage.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIColor.blackColor
        : [UIColor colorWithWhite:0.945 alpha:1.0];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"提示外观预览";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIView *stage = [UIView new];
    stage.translatesAutoresizingMaskIntoConstraints = NO;
    stage.layer.cornerRadius = 14.0;
    [self.view addSubview:stage];
    self.stage = stage;
    [self applyPreviewStageBackground];

    UIView *bubble = [UIView new];
    bubble.backgroundColor = [UIColor colorWithRed:0.58 green:0.91 blue:0.43 alpha:1.0];
    bubble.layer.cornerRadius = 7.0;
    [stage addSubview:bubble];
    self.bubble = bubble;
    UILabel *message = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 0.0, 150.0, 54.0)];
    message.text = @"这是一条消息";
    message.font = [UIFont systemFontOfSize:16.0];
    [bubble addSubview:message];

    UILabel *prompt = [UILabel new];
    prompt.font = [UIFont systemFontOfSize:10.0];
    prompt.textColor = WCAtlasDynamicColorForDefaultsKeys(WCAtlasAntiRevokeSideLightTextColorKey,
                                                        WCAtlasAntiRevokeSideDarkTextColorKey,
                                                        WCAtlasAntiRevokeSideTextColorKey,
                                                        UIColor.secondaryLabelColor,
                                                        UIColor.secondaryLabelColor);
    prompt.userInteractionEnabled = YES;
    prompt.text = [[NSUserDefaults standardUserDefaults] stringForKey:WCAtlasAntiRevokeSideTextKey] ?: @"已拦截撤回";
    [prompt addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(promptPanned:)]];
    [stage addSubview:prompt];
    self.promptLabel = prompt;

    UITextField *field = [UITextField new];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = @"提示文字";
    field.text = prompt.text;
    field.delegate = self;
    [field addTarget:self action:@selector(promptTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:field];
    self.textField = field;

    UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    colorButton.translatesAutoresizingMaskIntoConstraints = NO;
    colorButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [colorButton setTitle:@"  提示文字颜色" forState:UIControlStateNormal];
    [colorButton setImage:[[UIImage systemImageNamed:@"circle.fill"] imageWithTintColor:prompt.textColor renderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    [colorButton addTarget:self action:@selector(colorTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:colorButton];
    self.colorButton = colorButton;

    UILabel *coordinates = [UILabel new];
    coordinates.translatesAutoresizingMaskIntoConstraints = NO;
    coordinates.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    coordinates.textColor = UIColor.secondaryLabelColor;
    coordinates.text = @"拖动预览，或输入精确位置";
    [self.view addSubview:coordinates];
    self.coordinateLabel = coordinates;

    UITextField *(^coordinateField)(NSString *) = ^UITextField *(NSString *placeholder) {
        UITextField *input = [UITextField new];
        input.translatesAutoresizingMaskIntoConstraints = NO;
        input.borderStyle = UITextBorderStyleRoundedRect;
        input.placeholder = placeholder;
        input.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        input.textAlignment = NSTextAlignmentCenter;
        input.delegate = self;
        [input addTarget:self action:@selector(positionFieldChanged:) forControlEvents:UIControlEventEditingChanged];
        return input;
    };
    UITextField *xField = coordinateField(@"X");
    UITextField *yField = coordinateField(@"Y");
    [self.view addSubview:xField];
    [self.view addSubview:yField];
    self.xField = xField;
    self.yField = yField;

    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [reset setTitle:@"恢复推荐位置 X 0 / Y 10" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(resetPosition) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:reset];

    [NSLayoutConstraint activateConstraints:@[
        [stage.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [stage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [stage.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0],
        [stage.heightAnchor constraintEqualToConstant:220.0],
        [field.leadingAnchor constraintEqualToAnchor:stage.leadingAnchor],
        [field.trailingAnchor constraintEqualToAnchor:stage.trailingAnchor],
        [field.topAnchor constraintEqualToAnchor:stage.bottomAnchor constant:20.0],
        [field.heightAnchor constraintEqualToConstant:44.0],
        [colorButton.leadingAnchor constraintEqualToAnchor:field.leadingAnchor],
        [colorButton.trailingAnchor constraintEqualToAnchor:field.trailingAnchor],
        [colorButton.topAnchor constraintEqualToAnchor:field.bottomAnchor constant:8.0],
        [colorButton.heightAnchor constraintEqualToConstant:40.0],
        [coordinates.leadingAnchor constraintEqualToAnchor:field.leadingAnchor],
        [coordinates.topAnchor constraintEqualToAnchor:colorButton.bottomAnchor constant:8.0],
        [xField.leadingAnchor constraintEqualToAnchor:field.leadingAnchor],
        [xField.topAnchor constraintEqualToAnchor:coordinates.bottomAnchor constant:8.0],
        [xField.heightAnchor constraintEqualToConstant:42.0],
        [yField.leadingAnchor constraintEqualToAnchor:xField.trailingAnchor constant:10.0],
        [yField.trailingAnchor constraintEqualToAnchor:field.trailingAnchor],
        [yField.topAnchor constraintEqualToAnchor:xField.topAnchor],
        [yField.widthAnchor constraintEqualToAnchor:xField.widthAnchor],
        [yField.heightAnchor constraintEqualToAnchor:xField.heightAnchor],
        [reset.trailingAnchor constraintEqualToAnchor:field.trailingAnchor],
        [reset.topAnchor constraintEqualToAnchor:xField.bottomAnchor constant:10.0],
    ]];
    [self layoutPrompt];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (!previousTraitCollection ||
        previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self applyPreviewStageBackground];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bubble.frame = CGRectMake(CGRectGetWidth(self.stage.bounds) - 190.0, 72.0, 166.0, 54.0);
    [self layoutPrompt];
}

- (void)layoutPrompt {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CGFloat x = [defaults objectForKey:WCAtlasAntiRevokeSideOffsetXKey] ? [defaults doubleForKey:WCAtlasAntiRevokeSideOffsetXKey] : 0.0;
    CGFloat y = [defaults objectForKey:WCAtlasAntiRevokeSideOffsetYKey] ? [defaults doubleForKey:WCAtlasAntiRevokeSideOffsetYKey] : 10.0;
    [self.promptLabel sizeToFit];
    self.promptLabel.center = CGPointMake(CGRectGetMinX(self.bubble.frame) - CGRectGetWidth(self.promptLabel.bounds) * 0.5 - 8.0 + x,
                                          CGRectGetMidY(self.bubble.frame) + y);
    self.coordinateLabel.text = [NSString stringWithFormat:@"当前位置  X %.0f  /  Y %.0f", x, y];
    if (!self.xField.isFirstResponder) self.xField.text = [NSString stringWithFormat:@"X  %.0f", x];
    if (!self.yField.isFirstResponder) self.yField.text = [NSString stringWithFormat:@"Y  %.0f", y];
}

- (void)promptPanned:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        self.panStart = CGPointMake([defaults doubleForKey:WCAtlasAntiRevokeSideOffsetXKey], [defaults doubleForKey:WCAtlasAntiRevokeSideOffsetYKey]);
    }
    CGPoint translation = [gesture translationInView:self.stage];
    CGFloat x = MIN(80.0, MAX(-80.0, self.panStart.x + translation.x));
    CGFloat y = MIN(80.0, MAX(-80.0, self.panStart.y + translation.y));
    [NSUserDefaults.standardUserDefaults setDouble:x forKey:WCAtlasAntiRevokeSideOffsetXKey];
    [NSUserDefaults.standardUserDefaults setDouble:y forKey:WCAtlasAntiRevokeSideOffsetYKey];
    [self layoutPrompt];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
    }
}

- (void)promptTextChanged:(UITextField *)field {
    NSString *text = field.text.length > 0 ? field.text : @"已拦截撤回";
    self.promptLabel.text = text;
    [NSUserDefaults.standardUserDefaults setObject:text forKey:WCAtlasAntiRevokeSideTextKey];
    [self layoutPrompt];
}

- (void)positionFieldChanged:(UITextField *)field {
    NSString *numericText = [[field.text componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"-0123456789."] invertedSet]] componentsJoinedByString:@""];
    CGFloat value = MIN(80.0, MAX(-80.0, numericText.doubleValue));
    NSString *key = field == self.xField ? WCAtlasAntiRevokeSideOffsetXKey : WCAtlasAntiRevokeSideOffsetYKey;
    [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];
    [self layoutPrompt];
}

- (void)colorTapped {
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.title = @"气泡旁提示颜色";
    picker.selectedColor = self.promptLabel.textColor ?: UIColor.secondaryLabelColor;
    picker.supportsAlpha = YES;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)applySelectedPromptColor:(UIColor *)color {
    self.promptLabel.textColor = color;
    [self.colorButton setImage:[[UIImage systemImageNamed:@"circle.fill"] imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    NSString *key = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? WCAtlasAntiRevokeSideDarkTextColorKey : WCAtlasAntiRevokeSideLightTextColorKey;
    [NSUserDefaults.standardUserDefaults setObject:WCAtlasHexStringFromColor(color) forKey:key];
}

- (void)colorPickerViewController:(__unused UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(__unused BOOL)continuously API_AVAILABLE(ios(15.0)) {
    [self applySelectedPromptColor:color];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    [self applySelectedPromptColor:viewController.selectedColor];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
}

- (void)resetPosition {
    [NSUserDefaults.standardUserDefaults setDouble:0.0 forKey:WCAtlasAntiRevokeSideOffsetXKey];
    [NSUserDefaults.standardUserDefaults setDouble:10.0 forKey:WCAtlasAntiRevokeSideOffsetYKey];
    [self layoutPrompt];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self layoutPrompt];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField != self.xField && textField != self.yField) return;
    NSString *key = textField == self.xField ? WCAtlasAntiRevokeSideOffsetXKey : WCAtlasAntiRevokeSideOffsetYKey;
    textField.text = [NSString stringWithFormat:@"%.0f", [NSUserDefaults.standardUserDefaults doubleForKey:key]];
    dispatch_async(dispatch_get_main_queue(), ^{ [textField selectAll:nil]; });
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField != self.xField && textField != self.yField) return;
    [self layoutPrompt];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
}

@end
