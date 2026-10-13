#import "WCAtlasAntiRevokeTemplateEditor.h"

#import "WCAtlasAntiRevoke.h"
#import "WCAtlasEnhancements.h"

@interface WCAtlasAntiRevokeTemplateEditorViewController () <UIColorPickerViewControllerDelegate, UITextViewDelegate>
@property (nonatomic, copy) NSString *editorTitle;
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) NSString *defaultValue;
@property (nonatomic, copy) NSString *colorKey;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *colorButton;
@property (nonatomic, strong) UIColor *selectedColor;
@end

@implementation WCAtlasAntiRevokeTemplateEditorViewController

- (instancetype)initWithTitle:(NSString *)title defaultsKey:(NSString *)defaultsKey defaultValue:(NSString *)defaultValue colorKey:(NSString *)colorKey {
    self = [super init];
    if (self) {
        _editorTitle = [title copy];
        _defaultsKey = [defaultsKey copy];
        _defaultValue = [defaultValue copy];
        _colorKey = [colorKey copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.editorTitle;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(saveTapped)];

    UILabel *help = [UILabel new];
    help.translatesAutoresizingMaskIntoConstraints = NO;
    help.numberOfLines = 0;
    help.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    help.textColor = UIColor.secondaryLabelColor;
    help.text = @"可使用 {用户名}、{内容}、{yyyy}、{MM}、{dd}、{HH}、{mm}、{ss}。支持换行，编辑区域会随键盘保持可见。";
    [self.view addSubview:help];

    UITextView *textView = [UITextView new];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    textView.layer.cornerRadius = 12.0;
    textView.layer.cornerCurve = kCACornerCurveContinuous;
    textView.textContainerInset = UIEdgeInsetsMake(14.0, 14.0, 14.0, 14.0);
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.alwaysBounceVertical = YES;
    NSString *savedValue = [NSUserDefaults.standardUserDefaults stringForKey:self.defaultsKey];
    textView.text = savedValue.length > 0 ? savedValue : self.defaultValue;
    textView.delegate = self;
    UIToolbar *keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 44.0)];
    keyboardToolbar.items = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithTitle:@"收起键盘" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)],
    ];
    textView.inputAccessoryView = keyboardToolbar;
    [self.view addSubview:textView];
    self.textView = textView;

    UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    colorButton.translatesAutoresizingMaskIntoConstraints = NO;
    colorButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    colorButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [colorButton addTarget:self action:@selector(colorTapped) forControlEvents:UIControlEventTouchUpInside];
    colorButton.hidden = self.colorKey.length == 0;
    [self.view addSubview:colorButton];
    self.colorButton = colorButton;
    self.selectedColor = self.colorKey.length > 0 ? WCAtlasColorForDefaultsKey(self.colorKey, UIColor.secondaryLabelColor) : nil;
    [self updateColorButton];

    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [reset setTitle:@"恢复默认模板" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:reset];

    [NSLayoutConstraint activateConstraints:@[
        [help.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:22.0],
        [help.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-22.0],
        [help.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
        [textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [textView.topAnchor constraintEqualToAnchor:help.bottomAnchor constant:14.0],
        [textView.heightAnchor constraintGreaterThanOrEqualToConstant:260.0],
        [colorButton.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:6.0],
        [colorButton.topAnchor constraintEqualToAnchor:textView.bottomAnchor constant:16.0],
        [colorButton.heightAnchor constraintEqualToConstant:44.0],
        [reset.trailingAnchor constraintEqualToAnchor:textView.trailingAnchor constant:-6.0],
        [reset.centerYAnchor constraintEqualToAnchor:colorButton.centerYAnchor],
        [reset.topAnchor constraintGreaterThanOrEqualToAnchor:textView.bottomAnchor constant:16.0],
        [reset.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
    ]];
}

- (void)updateColorButton {
    if (self.colorKey.length == 0) return;
    UIImage *dot = [[UIImage systemImageNamed:@"circle.fill"] imageWithTintColor:self.selectedColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    [self.colorButton setImage:dot forState:UIControlStateNormal];
    [self.colorButton setTitle:@"  提示文字颜色" forState:UIControlStateNormal];
}

- (void)colorTapped {
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.title = @"提示文字颜色";
    picker.selectedColor = self.selectedColor ?: UIColor.secondaryLabelColor;
    picker.supportsAlpha = YES;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    self.selectedColor = viewController.selectedColor;
    [self updateColorButton];
}

- (void)colorPickerViewController:(__unused UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(__unused BOOL)continuously API_AVAILABLE(ios(15.0)) {
    self.selectedColor = color;
    [self updateColorButton];
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (void)resetTapped {
    self.textView.text = self.defaultValue;
    if (self.colorKey.length > 0) {
        self.selectedColor = UIColor.secondaryLabelColor;
        [self updateColorButton];
    }
}

- (void)saveTapped {
    NSString *value = [self.textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length > 0) [NSUserDefaults.standardUserDefaults setObject:value forKey:self.defaultsKey];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:self.defaultsKey];
    if (self.colorKey.length > 0 && self.selectedColor) {
        [NSUserDefaults.standardUserDefaults setObject:WCAtlasHexStringFromColor(self.selectedColor) forKey:self.colorKey];
        [NSNotificationCenter.defaultCenter postNotificationName:WCAtlasAntiRevokePromptDidChangeNotification object:nil];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
