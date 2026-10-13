#import "WCAtlasQuickReplyViewController.h"
#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasSilkDecoder.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasRuntimeFeatures.h"
#import "WCAtlasInterfaceTweaks.h"
#import "WCAtlasSendConfirmation.h"
#import "WCAtlasSendConfirmationViewController.h"
#import "WCAtlasPrivateAPI.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <objc/message.h>
#import <math.h>

typedef NS_ENUM(NSInteger, WCAtlasQuickReplySortMode) {
    WCAtlasQuickReplySortModeCustom = 0,
    WCAtlasQuickReplySortModeRecent,
    WCAtlasQuickReplySortModeFrequency,
};

static NSString *const WCAtlasQuickReplySortModeKey = @"com.qiu7c.wcatlas.quick-reply.sort-mode";

static UIImage *WCAtlasQuickReplyGroupAvatar(NSString *groupUserName) {
    if (![groupUserName hasSuffix:@"@chatroom"]) return nil;
    static NSCache<NSString *, UIImage *> *avatarCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ avatarCache = [NSCache new]; avatarCache.countLimit = 80; });
    UIImage *cached = [avatarCache objectForKey:groupUserName];
    if (cached) return cached;
    UIImage *image = WCAtlasPrivateContactAvatarImage(WCAtlasPrivateContact(groupUserName));
    if (!image) return nil;
    @try {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
            initWithSize:CGSizeMake(36.0, 36.0)];
        UIImage *rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            (void)context;
            [image drawInRect:CGRectMake(0.0, 0.0, 36.0, 36.0)];
        }];
        if (rendered) [avatarCache setObject:rendered forKey:groupUserName];
        return rendered;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *WCAtlasQuickReplyReferenceSymbol(WCAtlasQuickReplyItem *item) {
    NSInteger messageType = [item.metadata[@"messageType"] integerValue];
    NSInteger innerType = [item.metadata[@"innerType"] integerValue];
    if (messageType == 1) return @"text.bubble";
    if (messageType == 3) return @"photo";
    if (messageType == 34) return @"waveform";
    if (messageType == 43 || messageType == 62) return @"video";
    if (messageType == 47) return @"face.smiling";
    if (messageType == 48) return @"map";
    if (messageType == 49) {
        if (innerType == 6) return @"doc.fill";
        if (innerType == 33 || innerType == 36 || innerType == 44) return @"square.grid.2x2.fill";
        if (innerType == 19) return @"bubble.left.and.bubble.right.fill";
        if (innerType == 5) return @"link";
        if (innerType == 3) return @"music.note";
        return @"app.badge";
    }
    return @"doc.text";
}

static NSString *WCAtlasQuickReplyReferenceTypeName(WCAtlasQuickReplyItem *item) {
    NSInteger messageType = [item.metadata[@"messageType"] integerValue];
    NSInteger innerType = [item.metadata[@"innerType"] integerValue];
    if (messageType == 49 && innerType == 6) return @"文件";
    if (messageType == 49 && (innerType == 33 || innerType == 36 || innerType == 44)) return @"小程序";
    if (messageType == 49 && innerType == 19) return @"聊天记录";
    if (messageType == 48) return @"位置";
    return @"原消息";
}

@interface WCAtlasQuickReplyTextEditorViewController : UIViewController
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, copy) void (^saveHandler)(NSString *title, NSString *text);
@property (nonatomic, assign) BOOL scriptMode;
- (instancetype)initWithItem:(nullable WCAtlasQuickReplyItem *)item scriptMode:(BOOL)scriptMode;
@end

@implementation WCAtlasQuickReplyTextEditorViewController

- (instancetype)initWithItem:(WCAtlasQuickReplyItem *)item scriptMode:(BOOL)scriptMode {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _titleField = [UITextField new];
        _titleField.text = item.title;
        _textView = [UITextView new];
        _textView.text = item.text;
        _scriptMode = scriptMode;
        self.title = scriptMode ? (item ? @"编辑 JS 脚本" : @"新建 JS 脚本")
                                : (item ? @"编辑文字素材" : @"新建文字素材");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(save)];
    self.titleField.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleField.placeholder = @"备注（可选）";
    self.titleField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.titleField.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.titleField.layer.cornerRadius = 10.0;
    self.titleField.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.titleField.leftView = padding;
    self.titleField.leftViewMode = UITextFieldViewModeAlways;

    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.font = self.scriptMode ? [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular]
                                         : [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.textView.layer.cornerRadius = 10.0;
    self.textView.textContainerInset = UIEdgeInsetsMake(14, 10, 14, 10);
    self.textView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    UILabel *hint = [UILabel new];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = self.scriptMode ? @"JavaScript（实现 main(input)）" : @"文字内容";
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;

    [self.view addSubview:self.titleField];
    [self.view addSubview:hint];
    [self.view addSubview:self.textView];
    [NSLayoutConstraint activateConstraints:@[
        [self.titleField.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.titleField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.titleField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.titleField.heightAnchor constraintEqualToConstant:48],
        [hint.topAnchor constraintEqualToAnchor:self.titleField.bottomAnchor constant:18],
        [hint.leadingAnchor constraintEqualToAnchor:self.titleField.leadingAnchor constant:2],
        [self.textView.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:7],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.titleField.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.titleField.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
    if (self.textView.text.length == 0) [self.textView becomeFirstResponder];
}

- (void)save {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法保存"
                                                                       message:self.scriptMode ? @"JS 脚本不能为空。" : @"文字内容不能为空。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (self.saveHandler) self.saveHandler(self.titleField.text ?: @"", text);
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@interface WCAtlasQuickReplyPlayerView : UIView
@property (nonatomic, strong, nullable) AVPlayer *player;
@end

@implementation WCAtlasQuickReplyPlayerView

+ (Class)layerClass {
    return AVPlayerLayer.class;
}

- (AVPlayer *)player {
    return ((AVPlayerLayer *)self.layer).player;
}

- (void)setPlayer:(AVPlayer *)player {
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
    playerLayer.player = player;
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
}

@end

@interface WCAtlasQuickReplyMediaPreviewViewController : UIViewController <AVAudioPlayerDelegate>
@property (nonatomic, strong) WCAtlasQuickReplyItem *item;
@property (nonatomic, copy) dispatch_block_t sendHandler;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) UIButton *voicePlayButton;
@property (nonatomic, strong) UILabel *voiceStatusLabel;
@property (nonatomic, strong) UISlider *voiceProgressSlider;
@property (nonatomic, strong) UILabel *voiceTimeLabel;
@property (nonatomic, strong) NSTimer *voiceProgressTimer;
@property (nonatomic, assign) BOOL showsSendButton;
@property (nonatomic, copy) NSString *voiceSourcePath;
@property (nonatomic, copy) NSString *voiceTemporaryWAVPath;
@property (nonatomic, assign) BOOL voiceDecodeInProgress;
@property (nonatomic, assign) NSUInteger voiceDecodeGeneration;
- (instancetype)initWithItem:(WCAtlasQuickReplyItem *)item;
@end

@implementation WCAtlasQuickReplyMediaPreviewViewController

static NSString *WCAtlasVoicePreviewTimeText(NSTimeInterval currentTime, NSTimeInterval duration) {
    NSInteger currentSeconds = MAX(0, (NSInteger)floor(currentTime));
    NSInteger durationSeconds = MAX(0, (NSInteger)ceil(duration));
    return [NSString stringWithFormat:@"%ld:%02ld / %ld:%02ld",
            (long)(currentSeconds / 60), (long)(currentSeconds % 60),
            (long)(durationSeconds / 60), (long)(durationSeconds % 60)];
}

- (instancetype)initWithItem:(WCAtlasQuickReplyItem *)item {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _item = item;
        _showsSendButton = YES;
        self.title = item.type == WCAtlasQuickReplyTypeImage ? @"确认图片素材" :
                     (item.type == WCAtlasQuickReplyTypeVideo ? @"确认视频素材" : @"确认语音素材");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    if (self.showsSendButton) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发送"
                                                                                  style:UIBarButtonItemStyleDone
                                                                                 target:self
                                                                                 action:@selector(sendTapped)];
    }
    NSString *path = [WCAtlasQuickReplyStore.sharedStore absoluteMediaPathForItem:self.item];
    if (self.item.type == WCAtlasQuickReplyTypeVoice) {
        self.voiceSourcePath = path;
        NSUInteger voiceTime = [self.item.metadata[@"voiceTime"] unsignedIntegerValue];
        NSUInteger voiceFormat = [self.item.metadata[@"voiceFormat"] unsignedIntegerValue];
        NSError *audioError = nil;
        if (voiceFormat != 4) {
            self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path ?: @""] error:&audioError];
        }
        UIImageView *waveform = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.circle.fill"]];
        waveform.translatesAutoresizingMaskIntoConstraints = NO;
        waveform.tintColor = UIColor.whiteColor;
        waveform.contentMode = UIViewContentModeScaleAspectFit;
        UIButton *playButton = [UIButton buttonWithType:UIButtonTypeSystem];
        playButton.translatesAutoresizingMaskIntoConstraints = NO;
        playButton.tintColor = UIColor.whiteColor;
        playButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        BOOL canDecodeSilk = voiceFormat == 4 && path.length > 0;
        [playButton setTitle:(self.audioPlayer || canDecodeSilk) ? @"播放" : @"暂不可预览" forState:UIControlStateNormal];
        playButton.enabled = self.audioPlayer != nil || canDecodeSilk;
        [playButton addTarget:self action:@selector(voicePlayTapped) forControlEvents:UIControlEventTouchUpInside];
        UILabel *statusLabel = [UILabel new];
        statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        statusLabel.textAlignment = NSTextAlignmentCenter;
        statusLabel.numberOfLines = 0;
        statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        statusLabel.textColor = UIColor.lightGrayColor;
        if (self.audioPlayer) {
            statusLabel.text = @"轻点播放预览";
        } else if (voiceFormat == 4) {
            statusLabel.text = @"首次播放将快速解码";
        } else {
            statusLabel.text = audioError.localizedDescription ?: @"无法读取该语音文件。";
        }
        UISlider *progressSlider = [UISlider new];
        progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
        progressSlider.minimumValue = 0.0f;
        NSTimeInterval metadataDuration = voiceTime / 1000.0;
        NSTimeInterval initialDuration = self.audioPlayer.duration > 0.0 ? self.audioPlayer.duration : metadataDuration;
        progressSlider.maximumValue = MAX(0.01, initialDuration);
        progressSlider.value = 0.0f;
        progressSlider.minimumTrackTintColor = UIColor.whiteColor;
        progressSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.28];
        progressSlider.enabled = self.audioPlayer != nil;
        [progressSlider addTarget:self action:@selector(voiceProgressChanged:) forControlEvents:UIControlEventValueChanged];
        UILabel *timeLabel = [UILabel new];
        timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightRegular];
        timeLabel.textColor = UIColor.lightGrayColor;
        timeLabel.textAlignment = NSTextAlignmentCenter;
        timeLabel.text = WCAtlasVoicePreviewTimeText(0.0, initialDuration);
        [self.view addSubview:waveform];
        [self.view addSubview:playButton];
        [self.view addSubview:progressSlider];
        [self.view addSubview:timeLabel];
        [self.view addSubview:statusLabel];
        self.voicePlayButton = playButton;
        self.voiceStatusLabel = statusLabel;
        self.voiceProgressSlider = progressSlider;
        self.voiceTimeLabel = timeLabel;
        self.audioPlayer.delegate = self;
        [NSLayoutConstraint activateConstraints:@[
            [waveform.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [waveform.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-88.0],
            [waveform.widthAnchor constraintEqualToConstant:112.0],
            [waveform.heightAnchor constraintEqualToConstant:112.0],
            [playButton.topAnchor constraintEqualToAnchor:waveform.bottomAnchor constant:18.0],
            [playButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [progressSlider.topAnchor constraintEqualToAnchor:playButton.bottomAnchor constant:16.0],
            [progressSlider.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
            [progressSlider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],
            [timeLabel.topAnchor constraintEqualToAnchor:progressSlider.bottomAnchor constant:2.0],
            [timeLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [statusLabel.topAnchor constraintEqualToAnchor:timeLabel.bottomAnchor constant:10.0],
            [statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
            [statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],
        ]];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationDidEnterBackground:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    } else if (self.item.type == WCAtlasQuickReplyTypeVideo) {
        self.player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path ?: @""]];
        WCAtlasQuickReplyPlayerView *playerView = [WCAtlasQuickReplyPlayerView new];
        playerView.translatesAutoresizingMaskIntoConstraints = NO;
        playerView.player = self.player;
        [self.view addSubview:playerView];
        [NSLayoutConstraint activateConstraints:@[
            [playerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [playerView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
            [playerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [playerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
        [self.player play];
    } else {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:path]];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.view addSubview:imageView];
        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [imageView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
            [imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
    }
}

- (NSTimeInterval)voicePreviewDuration {
    NSTimeInterval playerDuration = self.audioPlayer.duration;
    if (isfinite(playerDuration) && playerDuration > 0.0) return playerDuration;
    return [self.item.metadata[@"voiceTime"] unsignedIntegerValue] / 1000.0;
}

- (void)updateVoiceProgress {
    NSTimeInterval duration = [self voicePreviewDuration];
    NSTimeInterval currentTime = self.audioPlayer ? self.audioPlayer.currentTime : 0.0;
    self.voiceProgressSlider.maximumValue = MAX(0.01, duration);
    if (!self.voiceProgressSlider.tracking) self.voiceProgressSlider.value = MIN(duration, MAX(0.0, currentTime));
    self.voiceTimeLabel.text = WCAtlasVoicePreviewTimeText(currentTime, duration);
}

- (void)startVoiceProgressTimer {
    [self.voiceProgressTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.voiceProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(__unused NSTimer *timer) {
        [weakSelf updateVoiceProgress];
    }];
}

- (void)stopVoiceProgressTimer {
    [self.voiceProgressTimer invalidate];
    self.voiceProgressTimer = nil;
}

- (void)voiceProgressChanged:(UISlider *)slider {
    if (!self.audioPlayer) return;
    self.audioPlayer.currentTime = MIN(self.audioPlayer.duration, MAX(0.0, slider.value));
    [self updateVoiceProgress];
}

- (void)voicePlayTapped {
    if (!self.audioPlayer) {
        if ([self.item.metadata[@"voiceFormat"] unsignedIntegerValue] == 4) [self decodeSilkVoiceAndPlay];
        return;
    }
    if (self.audioPlayer.isPlaying) {
        [self.audioPlayer pause];
        [self stopVoiceProgressTimer];
        [self updateVoiceProgress];
        [self.voicePlayButton setTitle:@"继续播放" forState:UIControlStateNormal];
        self.voiceStatusLabel.text = @"已暂停";
    } else {
        if (self.audioPlayer.currentTime >= self.audioPlayer.duration) self.audioPlayer.currentTime = 0;
        if ([self.audioPlayer play]) {
            [self startVoiceProgressTimer];
            [self updateVoiceProgress];
            [self.voicePlayButton setTitle:@"暂停" forState:UIControlStateNormal];
            self.voiceStatusLabel.text = @"正在播放";
        } else {
            self.voicePlayButton.enabled = NO;
            self.voiceProgressSlider.enabled = NO;
            [self.voicePlayButton setTitle:@"暂不可预览" forState:UIControlStateNormal];
            self.voiceStatusLabel.text = @"系统播放器无法播放该语音文件。";
        }
    }
}

- (void)decodeSilkVoiceAndPlay {
    if (self.voiceDecodeInProgress || self.voiceSourcePath.length == 0) return;
    self.voiceDecodeInProgress = YES;
    NSUInteger generation = ++self.voiceDecodeGeneration;
    self.voicePlayButton.enabled = NO;
    self.voiceProgressSlider.enabled = NO;
    [self.voicePlayButton setTitle:@"正在准备…" forState:UIControlStateNormal];
    self.voiceStatusLabel.text = @"正在解码 Silk 语音";
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WCAtlasVoicePreviews"];
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&directoryError]) {
        self.voiceDecodeInProgress = NO;
        self.voicePlayButton.enabled = YES;
        [self.voicePlayButton setTitle:@"重试" forState:UIControlStateNormal];
        self.voiceStatusLabel.text = directoryError.localizedDescription ?: @"无法创建语音预览缓存";
        return;
    }
    NSString *destination = [directory stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"wav"]];
    NSString *source = self.voiceSourcePath;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *decodeError = nil;
        BOOL decoded = WCAtlasSilkDecodeFileToWAV(source, destination, &decodeError);
        dispatch_async(dispatch_get_main_queue(), ^{
            WCAtlasQuickReplyMediaPreviewViewController *strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.voiceDecodeGeneration || !strongSelf.viewIfLoaded.window) {
                [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
                return;
            }
            strongSelf.voiceDecodeInProgress = NO;
            if (!decoded) {
                strongSelf.voicePlayButton.enabled = YES;
                strongSelf.voiceProgressSlider.enabled = NO;
                [strongSelf.voicePlayButton setTitle:@"重试" forState:UIControlStateNormal];
                strongSelf.voiceStatusLabel.text = decodeError.localizedDescription ?: @"Silk 语音解码失败";
                return;
            }
            NSError *audioError = nil;
            AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:destination]
                                                                           error:&audioError];
            if (!player) {
                [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
                strongSelf.voicePlayButton.enabled = YES;
                strongSelf.voiceProgressSlider.enabled = NO;
                [strongSelf.voicePlayButton setTitle:@"重试" forState:UIControlStateNormal];
                strongSelf.voiceStatusLabel.text = audioError.localizedDescription ?: @"无法播放解码后的语音";
                return;
            }
            strongSelf.voiceTemporaryWAVPath = destination;
            strongSelf.audioPlayer = player;
            player.delegate = strongSelf;
            [player prepareToPlay];
            strongSelf.voicePlayButton.enabled = YES;
            strongSelf.voiceProgressSlider.enabled = YES;
            [strongSelf.voicePlayButton setTitle:@"播放" forState:UIControlStateNormal];
            strongSelf.voiceStatusLabel.text = @"准备完成";
            [strongSelf updateVoiceProgress];
            [strongSelf voicePlayTapped];
        });
    });
}

- (void)cleanupVoicePreview {
    self.voiceDecodeGeneration++;
    self.voiceDecodeInProgress = NO;
    [self stopVoiceProgressTimer];
    [self.audioPlayer stop];
    self.audioPlayer.currentTime = 0.0;
    [self updateVoiceProgress];
    if (self.voiceTemporaryWAVPath.length > 0) {
        [NSFileManager.defaultManager removeItemAtPath:self.voiceTemporaryWAVPath error:nil];
        self.voiceTemporaryWAVPath = nil;
        self.audioPlayer = nil;
    }
    if ([self.item.metadata[@"voiceFormat"] unsignedIntegerValue] == 4 && self.voicePlayButton) {
        self.voicePlayButton.enabled = self.voiceSourcePath.length > 0;
        self.voiceProgressSlider.enabled = NO;
        [self.voicePlayButton setTitle:@"播放" forState:UIControlStateNormal];
        self.voiceStatusLabel.text = @"首次播放将快速解码";
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    (void)player;
    [self stopVoiceProgressTimer];
    self.audioPlayer.currentTime = 0.0;
    [self updateVoiceProgress];
    [self.voicePlayButton setTitle:@"播放" forState:UIControlStateNormal];
    self.voiceStatusLabel.text = flag ? @"播放完成" : @"播放已停止";
}

- (void)applicationDidEnterBackground:(__unused NSNotification *)notification {
    [self cleanupVoicePreview];
}

- (void)sendTapped {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    if (self.sendHandler) self.sendHandler();
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.player pause];
    [self cleanupVoicePreview];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end

@interface WCAtlasQuickReplyViewController () <UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic, copy, nullable) WCAtlasQuickReplySelectionHandler selectionHandler;
@property (nonatomic, copy, nullable) WCAtlasQuickReplyDirectSendHandler directSendHandler;
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyItem *> *allItems;
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyItem *> *visibleItems;
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyFolder *> *folders;
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyFolder *> *visibleFolders;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy, nullable) NSString *currentFolderIdentifier;
@property (nonatomic, copy, nullable) NSString *currentFolderName;
@property (nonatomic, strong, nullable) NSURL *pendingExportURL;
@property (nonatomic, assign) BOOL pendingAudioImport;
- (void)sortTapped;
- (void)exportAllTapped;
- (void)cleanupMediaTapped;
- (void)presentGroupInvitationPicker;
@end

@implementation WCAtlasQuickReplyViewController

- (instancetype)initWithSelectionHandler:(WCAtlasQuickReplySelectionHandler)selectionHandler {
    return [self initWithSelectionHandler:selectionHandler directSendHandler:nil];
}

- (instancetype)initWithSelectionHandler:(WCAtlasQuickReplySelectionHandler)selectionHandler
                        directSendHandler:(WCAtlasQuickReplyDirectSendHandler)directSendHandler {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _selectionHandler = [selectionHandler copy];
        _directSendHandler = [directSendHandler copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.currentFolderName.length ? self.currentFolderName :
        (self.selectionHandler ? @"快捷回复" : @"管理消息库");
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 56.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 56.0, 0.0, 16.0);
    self.tableView.sectionHeaderHeight = 0.01;
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                         target:self
                                                                         action:@selector(addTapped)];
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(moreTapped)];
    more.accessibilityLabel = @"更多";
    self.navigationItem.rightBarButtonItems = @[add, more];
    if (!self.selectionHandler) {
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
    }
    self.searchBar = [UISearchBar new];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索备注或文字";
    WCAtlasInstallSearchBarInTableView(self.searchBar, self.tableView);
    if (self.directSendHandler) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(itemLongPressed:)];
        longPress.minimumPressDuration = 0.55;
        [self.tableView addGestureRecognizer:longPress];
    }
    if (self.selectionHandler && self.navigationController.presentingViewController) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(close)];
    }
    [self reloadItems];
}

- (void)itemLongPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan || !self.directSendHandler) return;
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[recognizer locationInView:self.tableView]];
    if (!indexPath) return;
    NSInteger itemIndex = indexPath.row - (NSInteger)self.visibleFolders.count;
    if (itemIndex < 0 || itemIndex >= (NSInteger)self.visibleItems.count) return;
    WCAtlasQuickReplyItem *item = self.visibleItems[itemIndex];
    if (WCAtlasEnhancementEnabled(WCAtlasQuickReplyInstantSendEnabledKey)) [self useItemNormally:item];
    else [self sendItemDirectly:item];
}

- (nullable WCAtlasQuickReplyFolder *)folderAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row >= 0 && indexPath.row < (NSInteger)self.visibleFolders.count
        ? self.visibleFolders[indexPath.row] : nil;
}

- (nullable WCAtlasQuickReplyItem *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = indexPath.row - (NSInteger)self.visibleFolders.count;
    return index >= 0 && index < (NSInteger)self.visibleItems.count ? self.visibleItems[index] : nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.selectionHandler) return;
    NSString *key = @"com.qiu7c.wcatlas.quick-reply.import-tip.shared";
    if ([NSUserDefaults.standardUserDefaults boolForKey:key]) return;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:key];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"从聊天中选取消息"
                                                                   message:@"在任意聊天中进入微信多选，选择消息后点“存入消息库”。文字、图片、语音、文件、小程序等消息均会在发送时复用微信原生链路。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"打开文件传输助手" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        WCAtlasOpenChatForUserName(@"filehelper");
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)moreTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"排序" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf sortTapped];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"全部导出" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf exportAllTapped];
    }]];
    if (!self.selectionHandler && !self.currentFolderIdentifier.length) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"清理媒体" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            [weakSelf cleanupMediaTapped];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) popover.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)exportAllTapped {
    NSError *error = nil;
    NSURL *packageURL = [WCAtlasQuickReplyStore.sharedStore createExportPackageWithError:&error];
    if (!packageURL) {
        [self showError:error ?: [NSError errorWithDomain:@"WCAtlas" code:3 userInfo:@{NSLocalizedDescriptionKey: @"无法创建快捷回复导出包。"}]];
        return;
    }
    self.pendingExportURL = packageURL;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[packageURL] asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)finishPendingExport {
    NSURL *URL = self.pendingExportURL;
    self.pendingExportURL = nil;
    if (URL) [NSFileManager.defaultManager removeItemAtURL:URL error:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
    self.pendingAudioImport = NO;
    [self finishPendingExport];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)URLs {
    (void)controller;
    if (self.pendingAudioImport) {
        self.pendingAudioImport = NO;
        NSURL *URL = URLs.firstObject;
        BOOL accessed = [URL startAccessingSecurityScopedResource];
        NSError *error = nil;
        [WCAtlasQuickReplyStore.sharedStore addMediaAtURL:URL type:WCAtlasQuickReplyTypeVoice
            title:URL.lastPathComponent.stringByDeletingPathExtension
            folderIdentifier:self.currentFolderIdentifier sourceConversation:nil sourceMessageID:nil error:&error];
        if (accessed) [URL stopAccessingSecurityScopedResource];
        if (error) [self showError:error];
        [self reloadItems];
        return;
    }
    [self finishPendingExport];
}

- (void)reloadItems {
    self.allItems = WCAtlasQuickReplyStore.sharedStore.items;
    self.folders = WCAtlasQuickReplyStore.sharedStore.folders;
    [self applySearchText:self.searchBar.text];
}

- (WCAtlasQuickReplySortMode)sortMode {
    NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasQuickReplySortModeKey];
    return value >= WCAtlasQuickReplySortModeCustom && value <= WCAtlasQuickReplySortModeFrequency
        ? (WCAtlasQuickReplySortMode)value : WCAtlasQuickReplySortModeCustom;
}

- (NSArray<WCAtlasQuickReplyItem *> *)sortedItems:(NSArray<WCAtlasQuickReplyItem *> *)items {
    WCAtlasQuickReplySortMode mode = self.sortMode;
    if (mode == WCAtlasQuickReplySortModeCustom) return items;
    return [items sortedArrayUsingComparator:^NSComparisonResult(WCAtlasQuickReplyItem *left, WCAtlasQuickReplyItem *right) {
        if (left.isPinned != right.isPinned) return left.isPinned ? NSOrderedAscending : NSOrderedDescending;
        if (mode == WCAtlasQuickReplySortModeFrequency && left.useCount != right.useCount) {
            return left.useCount > right.useCount ? NSOrderedAscending : NSOrderedDescending;
        }
        NSTimeInterval leftTime = left.lastUsedAt.timeIntervalSince1970;
        NSTimeInterval rightTime = right.lastUsedAt.timeIntervalSince1970;
        if (leftTime != rightTime) return leftTime > rightTime ? NSOrderedAscending : NSOrderedDescending;
        if (left.sortIndex != right.sortIndex) return left.sortIndex < right.sortIndex ? NSOrderedAscending : NSOrderedDescending;
        return [right.createdAt compare:left.createdAt];
    }];
}

- (void)sortTapped {
    WCAtlasQuickReplySortMode selectedMode = self.sortMode;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"消息排序"
                                                                   message:@"置顶消息始终排在最前"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"自定义顺序", @"value": @(WCAtlasQuickReplySortModeCustom)},
        @{@"title": @"最近使用", @"value": @(WCAtlasQuickReplySortModeRecent)},
        @{@"title": @"使用频率", @"value": @(WCAtlasQuickReplySortModeFrequency)},
    ];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *option in options) {
        WCAtlasQuickReplySortMode mode = [option[@"value"] integerValue];
        NSString *suffix = mode == selectedMode ? @" ✓" : @"";
        NSString *title = [option[@"title"] stringByAppendingString:suffix];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:mode forKey:WCAtlasQuickReplySortModeKey];
            [weakSelf reloadItems];
            weakSelf.editing = NO;
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.barButtonItem = self.navigationItem.rightBarButtonItems.count > 1 ? self.navigationItem.rightBarButtonItems[1] : nil; }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)applySearchText:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL searching = trimmed.length > 0;
    self.visibleFolders = !self.currentFolderIdentifier.length && !searching ? self.folders : @[];
    NSArray *matchingItems = [self.allItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WCAtlasQuickReplyItem *item, NSDictionary *bindings) {
            (void)bindings;
            BOOL folderMatches = searching && !self.currentFolderIdentifier.length
                ? YES
                : (self.currentFolderIdentifier.length
                    ? [item.folderIdentifier isEqualToString:self.currentFolderIdentifier]
                    : item.folderIdentifier.length == 0);
            BOOL textMatches = trimmed.length == 0 || [item.title localizedCaseInsensitiveContainsString:trimmed] ||
                               [item.text localizedCaseInsensitiveContainsString:trimmed];
            return folderMatches && textMatches;
    }]];
    self.visibleItems = [self sortedItems:matchingItems];
    [self.tableView reloadData];
}

- (void)cleanupMediaTapped {
    NSUInteger mediaCount = 0;
    for (WCAtlasQuickReplyItem *item in self.allItems) {
        if (item.type == WCAtlasQuickReplyTypeImage || item.type == WCAtlasQuickReplyTypeVideo ||
            item.type == WCAtlasQuickReplyTypeVoice) mediaCount++;
    }
    if (mediaCount == 0) {
        [self showError:[NSError errorWithDomain:@"WCAtlas" code:3 userInfo:@{NSLocalizedDescriptionKey: @"消息库中没有媒体消息。"}]];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清理全部媒体素材？"
                                                                   message:[NSString stringWithFormat:@"将删除 WCAtlas 管理的 %lu 个图片、视频或语音副本；文字素材、聊天消息和系统相册不受影响。", (unsigned long)mediaCount]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"清理" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSError *lastError = nil;
        for (WCAtlasQuickReplyItem *item in weakSelf.allItems) {
            if (item.type == WCAtlasQuickReplyTypeImage || item.type == WCAtlasQuickReplyTypeVideo ||
                item.type == WCAtlasQuickReplyTypeVoice) {
                NSError *error = nil;
                [WCAtlasQuickReplyStore.sharedStore deleteItemWithIdentifier:item.identifier error:&error];
                if (error) lastError = error;
            }
        }
        [weakSelf reloadItems];
        if (lastError) [weakSelf showError:lastError];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editMediaItem:(WCAtlasQuickReplyItem *)item {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"编辑消息库记录" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重命名备注" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名备注" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"备注（可选）"; field.text = item.title; }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *saveAction) {
            item.title = alert.textFields.firstObject.text ?: @"";
            NSError *error = nil;
            [WCAtlasQuickReplyStore.sharedStore updateItem:item error:&error];
            if (error) [self showError:error];
            [self reloadItems];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"移动到文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self chooseFolderForItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.sourceView = self.view; popover.sourceRect = self.view.bounds; }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)renameItem:(WCAtlasQuickReplyItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名备注" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"备注（可选）";
        field.text = item.title;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        item.title = alert.textFields.firstObject.text ?: @"";
        NSError *error = nil;
        [WCAtlasQuickReplyStore.sharedStore updateItem:item error:&error];
        if (error) [self showError:error];
        [self reloadItems];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chooseFolderForItem:(WCAtlasQuickReplyItem *)item {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"移动到文件夹" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *rootTitle = item.folderIdentifier.length ? @"消息库根目录" : @"消息库根目录 ✓";
    [sheet addAction:[UIAlertAction actionWithTitle:rootTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        [WCAtlasQuickReplyStore.sharedStore moveItemWithIdentifier:item.identifier toFolderIdentifier:nil error:&error];
        if (error) [self showError:error];
        [self reloadItems];
    }]];
    for (WCAtlasQuickReplyFolder *folder in WCAtlasQuickReplyStore.sharedStore.folders) {
        NSString *title = [item.folderIdentifier isEqualToString:folder.identifier]
            ? [folder.name stringByAppendingString:@" ✓"] : folder.name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSError *error = nil;
            [WCAtlasQuickReplyStore.sharedStore moveItemWithIdentifier:item.identifier toFolderIdentifier:folder.identifier error:&error];
            if (error) [self showError:error];
            [self reloadItems];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.sourceView = self.view; popover.sourceRect = self.view.bounds; }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    (void)searchBar;
    [self applySearchText:searchText];
}

- (void)addTapped {
    if (!WCAtlasQuickReplyStore.sharedStore.isAvailable) {
        [self showError:[NSError errorWithDomain:@"WCAtlas" code:1 userInfo:@{NSLocalizedDescriptionKey: @"共享消息库暂时无法读写。"}]];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"添加消息库记录" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文字" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentTextEditorForItem:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建 JS 脚本" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentScriptEditorForItem:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"从相册选择图片或视频" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentMediaPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"从文件导入语音包" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentAudioDocumentPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"保存群聊邀请" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentGroupInvitationPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"从聊天中选取（打开文件传输助手）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        WCAtlasOpenChatForUserName(@"filehelper");
    }]];
    if (!self.currentFolderIdentifier.length) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self createFolder];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentGroupInvitationPicker {
    __block NSString *selectedGroup = nil;
    UIViewController *picker = WCAtlasCreateGroupPicker(
        @"选择邀请目标群",
        @"选择一次后会保存为消息库记录；以后在好友聊天中点击即可直接邀请。",
        ^BOOL(NSString *userName) {
            return selectedGroup.length > 0 && [selectedGroup isEqualToString:userName];
        },
        ^(NSString *userName) {
            selectedGroup = [selectedGroup isEqualToString:userName] ? nil : [userName copy];
        });
    __weak typeof(self) weakSelf = self;
    __weak UIViewController *weakPicker = picker;
    WCAtlasConfigureConversationPickerCompletion(picker, ^{
        if (selectedGroup.length == 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法保存"
                                                                           message:@"请先选择一个群聊。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [weakPicker presentViewController:alert animated:YES completion:nil];
            return;
        }
        NSError *error = nil;
        NSString *groupName = WCAtlasSendConfirmationDisplayName(selectedGroup);
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyStore.sharedStore
            addGroupInvitationForGroupUserName:selectedGroup
                                     groupName:groupName
                             folderIdentifier:weakSelf.currentFolderIdentifier
                                         error:&error];
        if (!item) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败"
                                                                           message:error.localizedDescription ?: @"保存群聊邀请失败。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [weakPicker presentViewController:alert animated:YES completion:nil];
            return;
        }
        [weakPicker.navigationController popViewControllerAnimated:YES];
        [weakSelf reloadItems];
    });
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)createFolder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"文件夹名称"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        [WCAtlasQuickReplyStore.sharedStore createFolderWithName:alert.textFields.firstObject.text error:&error];
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editFolder:(WCAtlasQuickReplyFolder *)folder {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:folder.name message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重命名" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = folder.name; }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *saveAction) {
            NSError *error = nil;
            [WCAtlasQuickReplyStore.sharedStore renameFolderWithIdentifier:folder.identifier toName:alert.textFields.firstObject.text error:&error];
            if (error) [self showError:error];
            [self reloadItems];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除文件夹" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        BOOL deleted = [WCAtlasQuickReplyStore.sharedStore deleteFolderWithIdentifier:folder.identifier error:&error];
        if (!deleted) [self showError:error ?: [NSError errorWithDomain:@"com.qiu7c.wcatlas.quick-reply"
                                                                    code:1
                                                                userInfo:@{NSLocalizedDescriptionKey: @"删除文件夹失败"}]];
        [self reloadItems];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) { popover.sourceView = self.view; popover.sourceRect = self.view.bounds; }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentTextEditorForItem:(WCAtlasQuickReplyItem *)item {
    WCAtlasQuickReplyTextEditorViewController *editor = [[WCAtlasQuickReplyTextEditorViewController alloc] initWithItem:item scriptMode:NO];
    __weak typeof(self) weakSelf = self;
    __weak WCAtlasQuickReplyItem *weakItem = item;
    editor.saveHandler = ^(NSString *title, NSString *text) {
        NSError *error = nil;
        WCAtlasQuickReplyItem *strongItem = weakItem;
        if (strongItem) {
            strongItem.title = title;
            strongItem.text = text;
            [WCAtlasQuickReplyStore.sharedStore updateItem:strongItem error:&error];
        } else {
            [WCAtlasQuickReplyStore.sharedStore addText:text title:title
                                     folderIdentifier:weakSelf.currentFolderIdentifier
                                    sourceConversation:nil sourceMessageID:nil error:&error];
        }
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
    };
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)presentScriptEditorForItem:(WCAtlasQuickReplyItem *)item {
    WCAtlasQuickReplyTextEditorViewController *editor = [[WCAtlasQuickReplyTextEditorViewController alloc] initWithItem:item scriptMode:YES];
    if (!item) editor.textView.text = @"function main(input) {\n  return { type: 'text', text: '自动回复' };\n}";
    __weak typeof(self) weakSelf = self;
    __weak WCAtlasQuickReplyItem *weakItem = item;
    editor.saveHandler = ^(NSString *title, NSString *script) {
        NSError *error = nil;
        WCAtlasQuickReplyItem *strongItem = weakItem;
        if (strongItem) {
            strongItem.title = title;
            strongItem.text = script;
            [WCAtlasQuickReplyStore.sharedStore updateItem:strongItem error:&error];
        } else {
            [WCAtlasQuickReplyStore.sharedStore addJavaScript:script title:title
                                          folderIdentifier:weakSelf.currentFolderIdentifier error:&error];
        }
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
    };
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)presentMediaPicker {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image", @"public.movie"];
    picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)presentAudioDocumentPicker {
    Class typeClass = NSClassFromString(@"UTType");
    SEL typeSelector = NSSelectorFromString(@"typeWithIdentifier:");
    SEL pickerSelector = NSSelectorFromString(@"initForOpeningContentTypes:asCopy:");
    if (![typeClass respondsToSelector:typeSelector] ||
        ![UIDocumentPickerViewController instancesRespondToSelector:pickerSelector]) return;
    id audioType = ((id (*)(id, SEL, id))objc_msgSend)(typeClass, typeSelector, @"public.audio");
    if (!audioType) return;
    UIDocumentPickerViewController *picker = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(
        [UIDocumentPickerViewController alloc], pickerSelector, @[audioType], YES);
    if (!picker) return;
    self.pendingAudioImport = YES;
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    NSURL *URL = info[UIImagePickerControllerMediaURL];
    WCAtlasQuickReplyType type = [mediaType isEqualToString:@"public.movie"] ? WCAtlasQuickReplyTypeVideo : WCAtlasQuickReplyTypeImage;
    NSString *temporaryImagePath = nil;
    if (type == WCAtlasQuickReplyTypeImage) {
        URL = info[UIImagePickerControllerImageURL];
        if (!URL) {
            UIImage *image = info[UIImagePickerControllerOriginalImage];
            NSData *data = image ? UIImageJPEGRepresentation(image, 0.96) : nil;
            temporaryImagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"jpg"]];
            if (data.length > 0 && [data writeToFile:temporaryImagePath options:NSDataWritingAtomic error:nil]) {
                URL = [NSURL fileURLWithPath:temporaryImagePath];
            }
        }
    }
    NSError *error = nil;
    if (URL) {
        [WCAtlasQuickReplyStore.sharedStore addMediaAtURL:URL type:type title:nil
                                      folderIdentifier:self.currentFolderIdentifier
                                     sourceConversation:nil sourceMessageID:nil error:&error];
    } else {
        error = [NSError errorWithDomain:@"WCAtlas" code:2 userInfo:@{NSLocalizedDescriptionKey: @"无法读取所选媒体文件。"}];
    }
    if (temporaryImagePath.length > 0) [NSFileManager.defaultManager removeItemAtPath:temporaryImagePath error:nil];
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
    }];
}

- (void)showError:(NSError *)error {
    if (!self.view.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"操作失败"
                                                                   message:error.localizedDescription ?: @"请稍后重试"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.visibleFolders.count + self.visibleItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"QuickReplyCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    WCAtlasQuickReplyFolder *folder = [self folderAtIndexPath:indexPath];
    if (folder) {
        NSUInteger count = 0;
        for (WCAtlasQuickReplyItem *candidate in self.allItems) if ([candidate.folderIdentifier isEqualToString:folder.identifier]) count++;
        cell.textLabel.text = folder.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu 项素材", (unsigned long)count];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightRegular];
        cell.imageView.image = [[UIImage systemImageNamed:@"folder" withConfiguration:configuration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = UIColor.labelColor;
        cell.imageView.contentMode = UIViewContentModeCenter;
        cell.imageView.clipsToBounds = NO;
        cell.imageView.layer.cornerRadius = 0.0;
        return cell;
    }
    WCAtlasQuickReplyItem *item = [self itemAtIndexPath:indexPath];
    if (!item) return cell;
    NSString *groupUserName = [item.metadata[@"groupUserName"] isKindOfClass:NSString.class]
        ? item.metadata[@"groupUserName"] : item.text;
    NSString *groupName = [item.metadata[@"groupName"] isKindOfClass:NSString.class]
        ? item.metadata[@"groupName"] : nil;
    if (item.type == WCAtlasQuickReplyTypeGroupInvitation && groupName.length == 0) {
        groupName = WCAtlasSendConfirmationDisplayName(groupUserName);
    }
    NSString *fallbackTitle = item.type == WCAtlasQuickReplyTypeJavaScript ? @"JS 脚本" :
        (item.type == WCAtlasQuickReplyTypeText ? item.text :
        (item.type == WCAtlasQuickReplyTypeImage ? @"图片素材" :
         (item.type == WCAtlasQuickReplyTypeVideo ? @"视频素材" :
          (item.type == WCAtlasQuickReplyTypeVoice ? @"语音素材" :
           (item.type == WCAtlasQuickReplyTypeGroupInvitation
                ? [NSString stringWithFormat:@"群邀请 · %@", groupName.length ? groupName : @"未知群聊"]
                 : (item.text.length ? item.text : @"原消息"))))));
    BOOL genericGroupTitle = item.type == WCAtlasQuickReplyTypeGroupInvitation &&
        ([item.title isEqualToString:@"群聊邀请"] || [item.title isEqualToString:@"群邀请"]);
    cell.textLabel.text = item.title.length > 0 && !genericGroupTitle ? item.title : fallbackTitle;
    cell.textLabel.numberOfLines = 1;
    NSString *typeName = item.type == WCAtlasQuickReplyTypeJavaScript ? @"JS 脚本" :
        (item.type == WCAtlasQuickReplyTypeText ? @"文字" :
        (item.type == WCAtlasQuickReplyTypeImage ? @"图片" :
         (item.type == WCAtlasQuickReplyTypeVideo ? @"视频" :
          (item.type == WCAtlasQuickReplyTypeVoice ? @"语音" :
           (item.type == WCAtlasQuickReplyTypeGroupInvitation ? @"群邀请" : WCAtlasQuickReplyReferenceTypeName(item))))));
    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:typeName];
    if (item.type == WCAtlasQuickReplyTypeGroupInvitation) {
        if (groupName.length > 0) [details addObject:groupName];
        if (groupUserName.length > 0 && ![groupUserName isEqualToString:groupName]) [details addObject:groupUserName];
    }
    if (item.isPinned) [details addObject:@"已置顶"];
    cell.detailTextLabel.text = [details componentsJoinedByString:@" · "];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSString *symbol = item.type == WCAtlasQuickReplyTypeJavaScript ? @"curlybraces" :
        (item.type == WCAtlasQuickReplyTypeText ? @"text.bubble" :
        (item.type == WCAtlasQuickReplyTypeImage ? @"photo" :
         (item.type == WCAtlasQuickReplyTypeVideo ? @"video" :
          (item.type == WCAtlasQuickReplyTypeVoice ? @"waveform" :
           (item.type == WCAtlasQuickReplyTypeGroupInvitation ? @"person.badge.plus" : WCAtlasQuickReplyReferenceSymbol(item))))));
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                                   weight:UIImageSymbolWeightRegular];
    UIImage *groupAvatar = item.type == WCAtlasQuickReplyTypeGroupInvitation
        ? WCAtlasQuickReplyGroupAvatar(groupUserName) : nil;
    UIImage *icon = groupAvatar ?: [UIImage systemImageNamed:symbol withConfiguration:configuration];
    if (!icon) icon = [UIImage systemImageNamed:@"doc.text" withConfiguration:configuration];
    cell.imageView.image = [icon imageWithRenderingMode:groupAvatar
        ? UIImageRenderingModeAlwaysOriginal : UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = UIColor.labelColor;
    cell.imageView.contentMode = groupAvatar ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
    cell.imageView.clipsToBounds = groupAvatar != nil;
    cell.imageView.layer.cornerRadius = groupAvatar ? 8.0 : 0.0;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; (void)indexPath;
    return !self.selectionHandler && self.sortMode == WCAtlasQuickReplySortModeCustom &&
           self.visibleFolders.count == 0 && self.searchBar.text.length == 0;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    (void)tableView;
    NSMutableArray *ordered = [self.visibleItems mutableCopy];
    WCAtlasQuickReplyItem *item = ordered[sourceIndexPath.row];
    [ordered removeObjectAtIndex:sourceIndexPath.row];
    [ordered insertObject:item atIndex:destinationIndexPath.row];
    NSMutableArray<NSString *> *identifiers = [NSMutableArray arrayWithCapacity:ordered.count];
    for (WCAtlasQuickReplyItem *candidate in ordered) [identifiers addObject:candidate.identifier];
    NSError *error = nil;
    [WCAtlasQuickReplyStore.sharedStore applyOrderedIdentifiers:identifiers error:&error];
    if (error) [self showError:error];
    [self reloadItems];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WCAtlasQuickReplyFolder *folder = [self folderAtIndexPath:indexPath];
    if (folder) {
        WCAtlasQuickReplyViewController *controller = [[WCAtlasQuickReplyViewController alloc]
            initWithSelectionHandler:self.selectionHandler directSendHandler:self.directSendHandler];
        controller.currentFolderIdentifier = folder.identifier;
        controller.currentFolderName = folder.name;
        [self.navigationController pushViewController:controller animated:YES];
        return;
    }
    WCAtlasQuickReplyItem *item = [self itemAtIndexPath:indexPath];
    if (!item) return;
    if (self.selectionHandler) {
        if (WCAtlasEnhancementEnabled(WCAtlasQuickReplyInstantSendEnabledKey)) [self sendItemDirectly:item];
        else [self useItemNormally:item];
        return;
    }
    if (item.type == WCAtlasQuickReplyTypeText) {
        [self presentTextEditorForItem:item];
        return;
    }
    if (item.type == WCAtlasQuickReplyTypeJavaScript) {
        [self presentScriptEditorForItem:item];
        return;
    }
    if (item.type == WCAtlasQuickReplyTypeMessageReference || item.type == WCAtlasQuickReplyTypeGroupInvitation) {
        [self editMediaItem:item];
        return;
    }
    NSString *path = [WCAtlasQuickReplyStore.sharedStore absoluteMediaPathForItem:item];
    if (item.type == WCAtlasQuickReplyTypeVoice && path.length > 0) {
        WCAtlasQuickReplyMediaPreviewViewController *preview = [[WCAtlasQuickReplyMediaPreviewViewController alloc] initWithItem:item];
        preview.showsSendButton = NO;
        [self.navigationController pushViewController:preview animated:YES];
        return;
    }
    [self editMediaItem:item];
}

- (void)useItemNormally:(WCAtlasQuickReplyItem *)item {
    if (!self.selectionHandler) return;
    if (item.type == WCAtlasQuickReplyTypeText || item.type == WCAtlasQuickReplyTypeJavaScript ||
        item.type == WCAtlasQuickReplyTypeMessageReference ||
        item.type == WCAtlasQuickReplyTypeGroupInvitation) {
        [WCAtlasQuickReplyStore.sharedStore recordUsageForIdentifier:item.identifier error:nil];
        WCAtlasQuickReplySelectionHandler handler = self.selectionHandler;
        [self dismissViewControllerAnimated:YES completion:^{ if (handler) handler(item); }];
        return;
    }
    WCAtlasQuickReplyMediaPreviewViewController *preview = [[WCAtlasQuickReplyMediaPreviewViewController alloc] initWithItem:item];
    __weak typeof(self) weakSelf = self;
    preview.sendHandler = ^{
        WCAtlasQuickReplyViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [WCAtlasQuickReplyStore.sharedStore recordUsageForIdentifier:item.identifier error:nil];
        WCAtlasQuickReplySelectionHandler handler = strongSelf.selectionHandler;
        [strongSelf dismissViewControllerAnimated:YES completion:^{ if (handler) handler(item); }];
    };
    [self.navigationController pushViewController:preview animated:YES];
}

- (void)sendItemDirectly:(WCAtlasQuickReplyItem *)item {
    if (!self.directSendHandler) return;
    [WCAtlasQuickReplyStore.sharedStore recordUsageForIdentifier:item.identifier error:nil];
    WCAtlasQuickReplyDirectSendHandler handler = self.directSendHandler;
    [self dismissViewControllerAnimated:YES completion:^{ handler(item); }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCAtlasQuickReplyFolder *folder = [self folderAtIndexPath:indexPath];
    if (folder) {
        __weak typeof(self) weakSelf = self;
        UIContextualAction *deleteFolder = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
            NSError *error = nil;
            BOOL deleted = [WCAtlasQuickReplyStore.sharedStore deleteFolderWithIdentifier:folder.identifier error:&error];
            if (!deleted) [weakSelf showError:error ?: [NSError errorWithDomain:@"com.qiu7c.wcatlas.quick-reply"
                                                                                 code:1
                                                                             userInfo:@{NSLocalizedDescriptionKey: @"删除文件夹失败"}]];
            [weakSelf reloadItems];
            completionHandler(deleted);
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[deleteFolder]];
    }
    WCAtlasQuickReplyItem *item = [self itemAtIndexPath:indexPath];
    if (!item) return nil;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:@"删除"
                                                                              handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSError *error = nil;
        BOOL deleted = [WCAtlasQuickReplyStore.sharedStore deleteItemWithIdentifier:item.identifier error:&error];
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
        completionHandler(deleted);
    }];
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:item.isPinned ? @"取消置顶" : @"置顶"
                                                                           handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSError *error = nil;
        BOOL changed = [WCAtlasQuickReplyStore.sharedStore setPinned:!item.isPinned forIdentifier:item.identifier error:&error];
        if (error) [weakSelf showError:error];
        [weakSelf reloadItems];
        completionHandler(changed);
    }];
    pinAction.backgroundColor = UIColor.systemOrangeColor;
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, pinAction]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    WCAtlasQuickReplyFolder *folder = [self folderAtIndexPath:indexPath];
    if (folder) {
        __weak typeof(self) weakSelf = self;
        UIContextualAction *renameFolder = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"重命名" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
            [weakSelf editFolder:folder];
            completionHandler(YES);
        }];
        renameFolder.backgroundColor = UIColor.systemBlueColor;
        return [UISwipeActionsConfiguration configurationWithActions:@[renameFolder]];
    }
    WCAtlasQuickReplyItem *item = [self itemAtIndexPath:indexPath];
    if (!item) return nil;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                        title:@"重命名"
                                                                      handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf renameItem:item];
        completionHandler(YES);
    }];
    rename.backgroundColor = UIColor.systemBlueColor;
    UIContextualAction *move = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"移动"
                                                                        handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf chooseFolderForItem:item];
        completionHandler(YES);
    }];
    move.backgroundColor = UIColor.systemTealColor;
    return [UISwipeActionsConfiguration configurationWithActions:@[rename, move]];
}

@end
