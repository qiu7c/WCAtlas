#import "WCAtlasListEditorViewController.h"
#import "WCAtlasEnhancements.h"

@interface WCAtlasListEditorViewController () <UITextViewDelegate>
@property (nonatomic, copy) NSString *editorTitle;
@property (nonatomic, copy) NSString *editorSubtitle;
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, assign) WCAtlasListEditorMode mode;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation WCAtlasListEditorViewController

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                  defaultsKey:(NSString *)defaultsKey
                         mode:(WCAtlasListEditorMode)mode {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _editorTitle = [title copy];
        _editorSubtitle = [subtitle copy];
        _defaultsKey = [defaultsKey copy];
        _mode = mode;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.editorTitle;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(save)];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = self.editorSubtitle;
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.numberOfLines = 0;

    UITextView *textView = [UITextView new];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    textView.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightRegular];
    textView.textColor = UIColor.labelColor;
    textView.textContainerInset = UIEdgeInsetsMake(14.0, 12.0, 14.0, 12.0);
    textView.layer.cornerRadius = 8.0;
    textView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    textView.layer.borderColor = UIColor.separatorColor.CGColor;
    textView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textView.delegate = self;
    self.textView = textView;

    UILabel *emptyLabel = [UILabel new];
    emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    emptyLabel.text = self.mode == WCAtlasListEditorModeMapping ? @"原名称=新名称" : @"每行一项";
    emptyLabel.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightRegular];
    emptyLabel.textColor = UIColor.placeholderTextColor;
    emptyLabel.userInteractionEnabled = NO;
    self.emptyLabel = emptyLabel;

    [self.view addSubview:subtitle];
    [self.view addSubview:textView];
    [textView addSubview:emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [subtitle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [subtitle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [textView.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:12.0],
        [textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [emptyLabel.topAnchor constraintEqualToAnchor:textView.topAnchor constant:14.0],
        [emptyLabel.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:17.0],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardFrameChanged:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:self.defaultsKey];
    if (self.mode == WCAtlasListEditorModeMapping && [storedValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *mapping = storedValue;
        NSArray *keys = [mapping.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        NSMutableArray *lines = [NSMutableArray arrayWithCapacity:keys.count];
        for (NSString *key in keys) {
            id value = mapping[key];
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [lines addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
            }
        }
        textView.text = [lines componentsJoinedByString:@"\n"];
    } else if ([storedValue isKindOfClass:[NSArray class]]) {
        textView.text = [(NSArray *)storedValue componentsJoinedByString:@"\n"];
    }
    [self updateEmptyLabel];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardFrameChanged:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frameInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frameInView));
    if (overlap > 0.0) overlap = MAX(0.0, overlap - self.view.safeAreaInsets.bottom);
    UIEdgeInsets contentInset = self.textView.contentInset;
    contentInset.bottom = overlap;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options =
        (UIViewAnimationOptions)([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        self.textView.contentInset = contentInset;
        self.textView.scrollIndicatorInsets = contentInset;
    } completion:nil];
}

- (void)textViewDidChange:(__unused UITextView *)textView {
    [self updateEmptyLabel];
}

- (void)updateEmptyLabel {
    self.emptyLabel.hidden = self.textView.text.length > 0;
}

- (NSArray<NSString *> *)trimmedLines {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    [self.textView.text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *value = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length == 0 || [seen containsObject:value]) return;
        [seen addObject:value];
        [result addObject:value];
    }];
    return result;
}

- (void)save {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.mode == WCAtlasListEditorModeList) {
        [defaults setObject:[self trimmedLines] forKey:self.defaultsKey];
    } else {
        NSMutableDictionary<NSString *, NSString *> *mapping = [NSMutableDictionary dictionary];
        NSMutableArray<NSString *> *invalidLines = [NSMutableArray array];
        for (NSString *line in [self trimmedLines]) {
            NSRange separator = [line rangeOfString:@"="];
            if (separator.location == NSNotFound) {
                [invalidLines addObject:line];
                continue;
            }
            NSString *source = [[line substringToIndex:separator.location]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *target = [[line substringFromIndex:separator.location + 1]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (source.length == 0 || target.length == 0) {
                [invalidLines addObject:line];
                continue;
            }
            mapping[source] = target;
        }
        if (invalidLines.count > 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格式不正确"
                                                                           message:@"重命名规则必须写成“原名称=新名称”，请检查后再保存。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        [defaults setObject:mapping forKey:self.defaultsKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:WCAtlasEnhancementDidChangeNotification object:self.defaultsKey];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
