#import "WCAtlasContactInfoCard.h"
#import <QuartzCore/QuartzCore.h>

@interface WCAtlasContactInfoCardViewController ()
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, strong, nullable) UIImage *avatar;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *rows;
@property (nonatomic, copy) NSDictionary<NSString *, id> *rowSelectionHandlers;
@property (nonatomic, copy, nullable) NSString *messageBlockSwitchTitle;
@property (nonatomic, assign) BOOL messageBlockSwitchEnabled;
@property (nonatomic, copy, nullable) WCAtlasContactInfoCardSwitchHandler messageBlockSwitchHandler;
@property (nonatomic, copy, nullable) NSString *sendConfirmationSwitchTitle;
@property (nonatomic, assign) BOOL sendConfirmationSwitchEnabled;
@property (nonatomic, copy, nullable) WCAtlasContactInfoCardSwitchHandler sendConfirmationSwitchHandler;
- (NSInteger)numberOfConfiguredSwitches;
- (void)infoCardSwitchValueChanged:(UISwitch *)sender;
@end

@implementation WCAtlasContactInfoCardViewController

- (instancetype)initWithTitle:(NSString *)title
                       avatar:(UIImage *)avatar
                         name:(NSString *)name
                     userName:(NSString *)userName
                         rows:(NSArray<NSDictionary<NSString *,NSString *> *> *)rows {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _cardTitle = [title copy] ?: @"信息卡片";
        _avatar = avatar;
        _displayName = [name copy] ?: @"";
        _userName = [userName copy] ?: @"";
        _rows = [rows copy] ?: @[];
        _rowSelectionHandlers = @{};
    }
    return self;
}

- (void)configureRowActionWithTitle:(NSString *)title
                            handler:(WCAtlasContactInfoCardRowSelectionHandler)handler {
    if (title.length == 0) return;
    NSMutableDictionary *handlers = [self.rowSelectionHandlers mutableCopy] ?: [NSMutableDictionary dictionary];
    if (handler) handlers[title] = [handler copy];
    else [handlers removeObjectForKey:title];
    self.rowSelectionHandlers = handlers;
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.cardTitle;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.bounds), 124.0)];
    header.backgroundColor = UIColor.clearColor;
    UIImageView *avatarView = [[UIImageView alloc] initWithImage:self.avatar ?: [UIImage systemImageNamed:@"person.crop.circle.fill"]];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.tintColor = UIColor.tertiaryLabelColor;
    avatarView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.layer.cornerRadius = 28.0;
    avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    avatarView.clipsToBounds = YES;
    UILabel *nameLabel = [UILabel new];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = self.displayName.length ? self.displayName : self.userName;
    nameLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    UILabel *idLabel = [UILabel new];
    idLabel.translatesAutoresizingMaskIntoConstraints = NO;
    idLabel.text = self.userName;
    idLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    idLabel.textColor = UIColor.secondaryLabelColor;
    idLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [header addSubview:avatarView];
    [header addSubview:nameLabel];
    [header addSubview:idLabel];
    [NSLayoutConstraint activateConstraints:@[
        [avatarView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20.0],
        [avatarView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:56.0],
        [avatarView.heightAnchor constraintEqualToConstant:56.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:14.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20.0],
        [nameLabel.bottomAnchor constraintEqualToAnchor:header.centerYAnchor constant:-2.0],
        [idLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [idLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
        [idLabel.topAnchor constraintEqualToAnchor:header.centerYAnchor constant:5.0],
    ]];
    self.tableView.tableHeaderView = header;
}

- (void)updateRows:(NSArray<NSDictionary<NSString *,NSString *> *> *)rows {
    self.rows = [rows copy] ?: @[];
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)configureMessageBlockSwitchWithTitle:(NSString *)title
                                      enabled:(BOOL)enabled
                                      handler:(WCAtlasContactInfoCardSwitchHandler)handler {
    self.messageBlockSwitchTitle = title.length > 0 ? [title copy] : nil;
    self.messageBlockSwitchEnabled = enabled;
    self.messageBlockSwitchHandler = [handler copy];
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)configureSendConfirmationSwitchWithTitle:(NSString *)title
                                          enabled:(BOOL)enabled
                                          handler:(WCAtlasContactInfoCardSwitchHandler)handler {
    self.sendConfirmationSwitchTitle = title.length > 0 ? [title copy] : nil;
    self.sendConfirmationSwitchEnabled = enabled;
    self.sendConfirmationSwitchHandler = [handler copy];
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (NSInteger)numberOfConfiguredSwitches {
    return (self.messageBlockSwitchTitle.length > 0 ? 1 : 0) +
           (self.sendConfirmationSwitchTitle.length > 0 ? 1 : 0);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return [self numberOfConfiguredSwitches] > 0 ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? self.rows.count : [self numberOfConfiguredSwitches];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        NSInteger switchIndex = indexPath.row;
        static NSString *switchIdentifier = @"WCAtlasContactInfoCardSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchIdentifier];
        UISwitch *toggle = [cell.accessoryView isKindOfClass:UISwitch.class]
            ? (UISwitch *)cell.accessoryView : [UISwitch new];
        [toggle removeTarget:self action:@selector(infoCardSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
        [toggle addTarget:self action:@selector(infoCardSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        BOOL messageBlock = self.messageBlockSwitchTitle.length > 0 &&
                            (switchIndex == 0 || self.sendConfirmationSwitchTitle.length == 0);
        toggle.tag = messageBlock ? 1 : 2;
        toggle.on = messageBlock ? self.messageBlockSwitchEnabled : self.sendConfirmationSwitchEnabled;
        cell.textLabel.text = messageBlock ? self.messageBlockSwitchTitle : self.sendConfirmationSwitchTitle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    static NSString *identifier = @"WCAtlasContactInfoCardCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    NSDictionary *row = self.rows[indexPath.row];
    cell.textLabel.text = row[@"title"] ?: @"";
    cell.detailTextLabel.text = row[@"value"] ?: @"";
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    BOOL actionable = self.rowSelectionHandlers[row[@"title"]] != nil;
    cell.accessoryType = actionable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)infoCardSwitchValueChanged:(UISwitch *)sender {
    if (sender.tag == 1) {
        self.messageBlockSwitchEnabled = sender.isOn;
        if (self.messageBlockSwitchHandler) self.messageBlockSwitchHandler(sender.isOn);
    } else if (sender.tag == 2) {
        self.sendConfirmationSwitchEnabled = sender.isOn;
        if (self.sendConfirmationSwitchHandler) self.sendConfirmationSwitchHandler(sender.isOn);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0 || indexPath.row >= self.rows.count) return;
    NSString *title = self.rows[indexPath.row][@"title"];
    WCAtlasContactInfoCardRowSelectionHandler handler = self.rowSelectionHandlers[title];
    if (handler) {
        handler(self);
        return;
    }
    NSString *value = self.rows[indexPath.row][@"value"];
    if (value.length == 0 || [value isEqualToString:@"暂无"]) return;
    UIPasteboard.generalPasteboard.string = value;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return nil;
}

@end
