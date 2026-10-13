#import "WCAtlasReleaseNotes.h"
#import "WCAtlasSettingsCatalog.h"

static NSString *const WCAtlasLastShownReleaseNotesVersionKey = @"com.qiu7c.wcatlas.ui.last-shown-release-notes-version";

@interface WCAtlasReleaseNoteItem ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *detail;
@end

@implementation WCAtlasReleaseNoteItem

+ (instancetype)itemWithTitle:(NSString *)title detail:(NSString *)detail {
    WCAtlasReleaseNoteItem *item = [self new];
    item.title = title;
    item.detail = detail;
    return item;
}

@end

@interface WCAtlasReleaseNote ()
@property (nonatomic, copy, readwrite) NSString *version;
@property (nonatomic, copy, readwrite) NSString *headline;
@property (nonatomic, copy, readwrite) NSArray<WCAtlasReleaseNoteItem *> *items;
@end

@implementation WCAtlasReleaseNote

+ (instancetype)noteWithVersion:(NSString *)version
                       headline:(NSString *)headline
                          items:(NSArray<WCAtlasReleaseNoteItem *> *)items {
    WCAtlasReleaseNote *note = [self new];
    note.version = version;
    note.headline = headline;
    note.items = items;
    return note;
}

@end

NSArray<WCAtlasReleaseNote *> *WCAtlasReleaseNotes(void) {
    static NSArray<WCAtlasReleaseNote *> *notes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notes = @[
            [WCAtlasReleaseNote noteWithVersion:@"1.0.0"
                                     headline:@"首个正式版本"
                                        items:@[
                [WCAtlasReleaseNoteItem itemWithTitle:@"WCAtlas"
                                               detail:@"作为首个版本发布，提供聊天、朋友圈、消息库、自动化与通话等实用增强。"],
            ]],
        ];
    });
    return notes;
}

BOOL WCAtlasShouldPresentCurrentReleaseNotes(void) {
    NSString *shownVersion = [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasLastShownReleaseNotesVersionKey];
    return ![shownVersion isEqualToString:WCAtlasDisplayVersion];
}

void WCAtlasMarkCurrentReleaseNotesPresented(void) {
    [NSUserDefaults.standardUserDefaults setObject:WCAtlasDisplayVersion forKey:WCAtlasLastShownReleaseNotesVersionKey];
}

@implementation WCAtlasReleaseNotesHistoryViewController

- (instancetype)init {
    return [self initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"版本介绍";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 84.0;
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return WCAtlasReleaseNotes().count;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return WCAtlasReleaseNotes()[section].items.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    WCAtlasReleaseNote *note = WCAtlasReleaseNotes()[section];
    return [NSString stringWithFormat:@"V %@ · %@", note.version, note.headline];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCAtlasReleaseHistoryCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WCAtlasReleaseHistoryCell"];
    WCAtlasReleaseNoteItem *item = WCAtlasReleaseNotes()[indexPath.section].items[indexPath.row];
    cell.textLabel.text = item.title;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.text = item.detail;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

@interface WCAtlasReleaseNotesViewController ()
@property (nonatomic, strong) UIControl *backdropView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, assign) BOOL appeared;
@property (nonatomic, assign) BOOL closing;
@end

@implementation WCAtlasReleaseNotesViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    return self;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UIView *)releaseRowForItem:(WCAtlasReleaseNoteItem *)item {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self labelWithFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                       color:UIColor.labelColor
                                       lines:0];
    titleLabel.text = item.title;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold]];
    UILabel *detailLabel = [self labelWithFont:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]
                                        color:UIColor.secondaryLabelColor
                                        lines:0];
    detailLabel.text = item.detail;
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, detailLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 3.0;

    [row addSubview:textStack];
    [NSLayoutConstraint activateConstraints:@[
        [textStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [textStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [textStack.topAnchor constraintEqualToAnchor:row.topAnchor],
        [textStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
    ]];
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    self.backdropView = [UIControl new];
    self.backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.16];
    [self.backdropView addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backdropView];

    self.cardView = [UIView new];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = UIColor.clearColor;
    self.cardView.layer.cornerRadius = 26.0;
    self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.12;
    self.cardView.layer.shadowRadius = 20.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, -4.0);
    [self.view addSubview:self.cardView];

    UIVisualEffectView *materialView = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    materialView.translatesAutoresizingMaskIntoConstraints = NO;
    materialView.userInteractionEnabled = NO;
    materialView.clipsToBounds = YES;
    materialView.layer.cornerRadius = 26.0;
    materialView.layer.cornerCurve = kCACornerCurveContinuous;
    materialView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self.cardView addSubview:materialView];

    UIView *grabberView = [UIView new];
    grabberView.translatesAutoresizingMaskIntoConstraints = NO;
    grabberView.backgroundColor = UIColor.tertiaryLabelColor;
    grabberView.layer.cornerRadius = 2.5;
    grabberView.userInteractionEnabled = NO;
    grabberView.accessibilityElementsHidden = YES;
    [self.cardView addSubview:grabberView];

    WCAtlasReleaseNote *note = WCAtlasReleaseNotes().firstObject;

    UILabel *titleLabel = [self labelWithFont:[[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2]
                                                scaledFontForFont:[UIFont systemFontOfSize:22.0 weight:UIFontWeightBold]]
                                       color:UIColor.labelColor
                                       lines:1];
    titleLabel.text = @"WCAtlas 更新";
    UILabel *headlineLabel = [self labelWithFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
                                          color:UIColor.secondaryLabelColor
                                          lines:0];
    headlineLabel.text = note.headline;
    UIStackView *headingStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, headlineLabel]];
    headingStack.translatesAutoresizingMaskIntoConstraints = NO;
    headingStack.axis = UILayoutConstraintAxisVertical;
    headingStack.spacing = 2.0;

    UILabel *versionLabel = [self labelWithFont:[[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                                  scaledFontForFont:[UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]]
                                         color:UIColor.systemBlueColor
                                         lines:1];
    versionLabel.text = [NSString stringWithFormat:@"V %@", note.version];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.12];
    versionLabel.layer.cornerRadius = 9.0;
    versionLabel.layer.cornerCurve = kCACornerCurveContinuous;
    versionLabel.layer.masksToBounds = YES;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
        scaledFontForFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold]];
    closeButton.tintColor = UIColor.tertiaryLabelColor;
    closeButton.accessibilityLabel = @"关闭版本介绍";
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = NO;
    scrollView.showsVerticalScrollIndicator = YES;
    UIStackView *itemsStack = [UIStackView new];
    itemsStack.translatesAutoresizingMaskIntoConstraints = NO;
    itemsStack.axis = UILayoutConstraintAxisVertical;
    itemsStack.alignment = UIStackViewAlignmentFill;
    itemsStack.spacing = 14.0;
    for (WCAtlasReleaseNoteItem *item in note.items) [itemsStack addArrangedSubview:[self releaseRowForItem:item]];
    [scrollView addSubview:itemsStack];

    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    doneButton.backgroundColor = UIColor.systemBlueColor;
    doneButton.tintColor = UIColor.whiteColor;
    doneButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:[UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]];
    [doneButton setTitle:@"开始使用" forState:UIControlStateNormal];
    doneButton.layer.cornerRadius = 15.0;
    doneButton.layer.cornerCurve = kCACornerCurveContinuous;
    [doneButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.cardView addSubview:headingStack];
    [self.cardView addSubview:versionLabel];
    [self.cardView addSubview:closeButton];
    [self.cardView addSubview:scrollView];
    [self.cardView addSubview:doneButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [materialView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [materialView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [materialView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [materialView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.cardView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.58],
        [grabberView.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [grabberView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:10.0],
        [grabberView.widthAnchor constraintEqualToConstant:38.0],
        [grabberView.heightAnchor constraintEqualToConstant:5.0],
        [headingStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [headingStack.topAnchor constraintEqualToAnchor:grabberView.bottomAnchor constant:12.0],
        [headingStack.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-8.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:headingStack.topAnchor constant:17.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-17.0],
        [closeButton.widthAnchor constraintEqualToConstant:44.0],
        [closeButton.heightAnchor constraintEqualToConstant:34.0],
        [versionLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [versionLabel.topAnchor constraintEqualToAnchor:headingStack.bottomAnchor constant:14.0],
        [versionLabel.widthAnchor constraintGreaterThanOrEqualToConstant:62.0],
        [versionLabel.heightAnchor constraintEqualToConstant:26.0],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-22.0],
        [scrollView.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:14.0],
        [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:72.0],
        [itemsStack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [itemsStack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [itemsStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [itemsStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [itemsStack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
        [doneButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [doneButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-22.0],
        [doneButton.topAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:14.0],
        [doneButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [doneButton.heightAnchor constraintEqualToConstant:50.0],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.appeared) return;
    self.backdropView.alpha = 0.0;
    self.cardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(UIScreen.mainScreen.bounds));
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.appeared) return;
    self.appeared = YES;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.01 : 0.34;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.backdropView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)closeTapped {
    if (self.closing || self.isBeingDismissed) return;
    self.closing = YES;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.01 : 0.2;
    [UIView animateWithDuration:duration animations:^{
        self.backdropView.alpha = 0.0;
        self.cardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(UIScreen.mainScreen.bounds));
    } completion:^(__unused BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

@end
