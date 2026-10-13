#import "WCAtlasAvatarQuickPanel.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char WCAtlasAvatarQuickPanelActionKey;

@implementation WCAtlasAvatarQuickAction

+ (instancetype)actionWithTitle:(NSString *)title
                     symbolName:(NSString *)symbolName
                        handler:(void (^)(void))handler {
    WCAtlasAvatarQuickAction *action = [WCAtlasAvatarQuickAction new];
    action.title = title ?: @"";
    action.symbolName = symbolName ?: @"circle";
    action.handler = handler ?: ^{};
    return action;
}

@end

@interface WCAtlasAvatarQuickPanelController : UIViewController
@property (nonatomic, strong) UIImage *avatar;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *maskedRealName;
@property (nonatomic, copy) NSArray<WCAtlasAvatarQuickAction *> *actions;
@property (nonatomic, copy) void (^profileHandler)(void);
@end

@implementation WCAtlasAvatarQuickPanelController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.34];

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [dismissButton addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemBackgroundColor;
    card.layer.cornerRadius = 24.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    [self.view addSubview:card];

    UIButton *profileButton = [UIButton buttonWithType:UIButtonTypeCustom];
    profileButton.translatesAutoresizingMaskIntoConstraints = NO;
    profileButton.accessibilityLabel = @"查看资料";
    [profileButton addTarget:self action:@selector(openProfile) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:profileButton];

    UIImageView *avatarView = [[UIImageView alloc] initWithImage:self.avatar];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.backgroundColor = UIColor.tertiarySystemFillColor;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.layer.cornerRadius = 28.0;
    avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    avatarView.clipsToBounds = YES;
    [profileButton addSubview:avatarView];

    UILabel *nameLabel = [UILabel new];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = self.displayName.length ? self.displayName : self.userName;
    nameLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    nameLabel.textColor = UIColor.labelColor;
    [profileButton addSubview:nameLabel];

    UILabel *userLabel = [UILabel new];
    userLabel.translatesAutoresizingMaskIntoConstraints = NO;
    userLabel.text = self.maskedRealName.length > 0
        ? [NSString stringWithFormat:@"脱敏姓名 %@ · %@", self.maskedRealName, self.userName]
        : self.userName;
    userLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    userLabel.textColor = UIColor.secondaryLabelColor;
    userLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [profileButton addSubview:userLabel];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = UIColor.tertiaryLabelColor;
    [profileButton addSubview:chevron];

    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 10.0;
    rows.distribution = UIStackViewDistributionFillEqually;
    [card addSubview:rows];

    NSUInteger index = 0;
    while (index < self.actions.count) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 10.0;
        row.distribution = UIStackViewDistributionFillEqually;
        for (NSUInteger column = 0; column < 4; column++) {
            if (index < self.actions.count) {
                WCAtlasAvatarQuickAction *action = self.actions[index++];
                UIButton *button = [self actionButtonForAction:action];
                [row addArrangedSubview:button];
            } else {
                UIView *spacer = [UIView new];
                [row addArrangedSubview:spacer];
            }
        }
        [rows addArrangedSubview:row];
    }

    NSUInteger rowCount = MAX(1, (self.actions.count + 3) / 4);
    [NSLayoutConstraint activateConstraints:@[
        [dismissButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dismissButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dismissButton.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dismissButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [card.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
        [profileButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [profileButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [profileButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [profileButton.heightAnchor constraintEqualToConstant:64.0],
        [avatarView.leadingAnchor constraintEqualToAnchor:profileButton.leadingAnchor],
        [avatarView.centerYAnchor constraintEqualToAnchor:profileButton.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:56.0],
        [avatarView.heightAnchor constraintEqualToConstant:56.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:12.0],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10.0],
        [nameLabel.bottomAnchor constraintEqualToAnchor:profileButton.centerYAnchor constant:-1.0],
        [userLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [userLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10.0],
        [userLabel.topAnchor constraintEqualToAnchor:profileButton.centerYAnchor constant:3.0],
        [chevron.trailingAnchor constraintEqualToAnchor:profileButton.trailingAnchor],
        [chevron.centerYAnchor constraintEqualToAnchor:profileButton.centerYAnchor],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [rows.topAnchor constraintEqualToAnchor:profileButton.bottomAnchor constant:12.0],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
        [rows.heightAnchor constraintEqualToConstant:rowCount * 78.0 + (rowCount - 1) * 10.0],
    ]];
}

- (UIButton *)actionButtonForAction:(WCAtlasAvatarQuickAction *)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = UIColor.tertiarySystemBackgroundColor;
    button.layer.cornerRadius = 14.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = action.title;
    objc_setAssociatedObject(button, &WCAtlasAvatarQuickPanelActionKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [button addTarget:self action:@selector(runAction:) forControlEvents:UIControlEventTouchUpInside];

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:action.symbolName]];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.tintColor = UIColor.labelColor;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [button addSubview:imageView];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = action.title;
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    label.textColor = UIColor.labelColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    [button addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [imageView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [imageView.topAnchor constraintEqualToAnchor:button.topAnchor constant:12.0],
        [imageView.widthAnchor constraintEqualToConstant:25.0],
        [imageView.heightAnchor constraintEqualToConstant:25.0],
        [label.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:4.0],
        [label.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-4.0],
        [label.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:7.0],
    ]];
    return button;
}

- (void)closePanel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openProfile {
    void (^handler)(void) = self.profileHandler;
    [self dismissViewControllerAnimated:NO completion:handler];
}

- (void)runAction:(UIButton *)sender {
    WCAtlasAvatarQuickAction *action = objc_getAssociatedObject(sender, &WCAtlasAvatarQuickPanelActionKey);
    void (^handler)(void) = action.handler;
    [self dismissViewControllerAnimated:NO completion:handler];
}

@end

void WCAtlasPresentAvatarQuickPanel(UIViewController *presenter,
                                  UIImage *avatar,
                                  NSString *displayName,
                                  NSString *userName,
                                  NSString *maskedRealName,
                                  NSArray<WCAtlasAvatarQuickAction *> *actions,
                                  void (^profileHandler)(void)) {
    if (!presenter || presenter.presentedViewController || actions.count == 0) return;
    WCAtlasAvatarQuickPanelController *panel = [WCAtlasAvatarQuickPanelController new];
    panel.avatar = avatar;
    panel.displayName = displayName ?: @"";
    panel.userName = userName ?: @"";
    panel.maskedRealName = maskedRealName ?: @"";
    panel.actions = actions;
    panel.profileHandler = profileHandler ?: ^{};
    panel.modalPresentationStyle = UIModalPresentationOverFullScreen;
    panel.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:panel animated:NO completion:nil];
}
