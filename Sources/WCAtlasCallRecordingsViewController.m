#import "WCAtlasCallRecordingsViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface WCAtlasCallRecordingPlayerViewController : UIViewController <AVAudioPlayerDelegate>
@property (nonatomic, strong) NSURL *recordingURL;
@property (nonatomic, copy) NSString *recordingTitle;
@property (nonatomic, copy) NSString *trackTitle;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) NSTimer *progressTimer;
- (instancetype)initWithURL:(NSURL *)URL title:(NSString *)title trackTitle:(NSString *)trackTitle;
- (void)close;
- (void)togglePlayback;
- (void)seekToSliderValue:(UISlider *)slider;
- (void)updateProgress;
- (void)exportRecording;
@end

@interface WCAtlasCallRecordingsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *sessions;
@end

@implementation WCAtlasCallRecordingPlayerViewController

- (instancetype)initWithURL:(NSURL *)URL title:(NSString *)title trackTitle:(NSString *)trackTitle {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _recordingURL = URL;
        _recordingTitle = [title copy];
        _trackTitle = [trackTitle copy];
    }
    return self;
}

- (NSString *)timeText:(NSTimeInterval)time {
    NSInteger seconds = MAX((NSInteger)time, 0);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.recordingTitle.length ? self.recordingTitle : @"通话录音";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"导出" style:UIBarButtonItemStylePlain target:self action:@selector(exportRecording)];

    UILabel *trackLabel = [UILabel new];
    trackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    trackLabel.text = self.trackTitle;
    trackLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    trackLabel.textAlignment = NSTextAlignmentCenter;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.circle.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = UIColor.systemGreenColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    self.progressSlider = [UISlider new];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressSlider.minimumValue = 0;
    [self.progressSlider addTarget:self action:@selector(seekToSliderValue:)
                  forControlEvents:UIControlEventValueChanged];

    self.elapsedLabel = [UILabel new];
    self.elapsedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.elapsedLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.elapsedLabel.textColor = UIColor.secondaryLabelColor;
    self.elapsedLabel.text = @"00:00";

    self.durationLabel = [UILabel new];
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.durationLabel.textColor = UIColor.secondaryLabelColor;
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.text = @"00:00";

    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.playPauseButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [self.playPauseButton setTitle:@"播放" forState:UIControlStateNormal];
    [self.playPauseButton addTarget:self action:@selector(togglePlayback)
                   forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:trackLabel];
    [self.view addSubview:iconView];
    [self.view addSubview:self.progressSlider];
    [self.view addSubview:self.elapsedLabel];
    [self.view addSubview:self.durationLabel];
    [self.view addSubview:self.playPauseButton];
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:guide.topAnchor constant:56],
        [iconView.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:88],
        [iconView.heightAnchor constraintEqualToConstant:88],
        [trackLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:20],
        [trackLabel.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:24],
        [trackLabel.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-24],
        [self.progressSlider.topAnchor constraintEqualToAnchor:trackLabel.bottomAnchor constant:48],
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:28],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-28],
        [self.elapsedLabel.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:8],
        [self.elapsedLabel.leadingAnchor constraintEqualToAnchor:self.progressSlider.leadingAnchor],
        [self.durationLabel.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:8],
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.progressSlider.trailingAnchor],
        [self.playPauseButton.topAnchor constraintEqualToAnchor:self.elapsedLabel.bottomAnchor constant:36],
        [self.playPauseButton.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
        [self.playPauseButton.widthAnchor constraintGreaterThanOrEqualToConstant:120],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:48]
    ]];

    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:self.recordingURL error:&error];
    if (!self.player) {
        self.playPauseButton.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开录音"
            message:error.localizedDescription ?: @"录音文件不可用" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    self.player.delegate = self;
    [self.player prepareToPlay];
    self.progressSlider.maximumValue = (float)self.player.duration;
    self.durationLabel.text = [self timeText:self.player.duration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.isMovingFromParentViewController && !self.isBeingDismissed &&
        !self.navigationController.isBeingDismissed) return;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [self.player stop];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)togglePlayback {
    if (self.player.isPlaying) {
        [self.player pause];
        [self.playPauseButton setTitle:@"继续播放" forState:UIControlStateNormal];
        return;
    }
    if (self.player.currentTime >= self.player.duration) self.player.currentTime = 0;
    [self.player play];
    [self.playPauseButton setTitle:@"暂停" forState:UIControlStateNormal];
    if (!self.progressTimer) {
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self
            selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
}

- (void)seekToSliderValue:(UISlider *)slider {
    self.player.currentTime = slider.value;
    self.elapsedLabel.text = [self timeText:self.player.currentTime];
}

- (void)updateProgress {
    if (!self.progressSlider.isTracking) self.progressSlider.value = (float)self.player.currentTime;
    self.elapsedLabel.text = [self timeText:self.player.currentTime];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    (void)player; (void)flag;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    self.progressSlider.value = (float)self.player.duration;
    self.elapsedLabel.text = [self timeText:self.player.duration];
    [self.playPauseButton setTitle:@"重新播放" forState:UIControlStateNormal];
}

- (void)exportRecording {
    if (!self.recordingURL) return;
    UIActivityViewController *controller = [[UIActivityViewController alloc]
        initWithActivityItems:@[self.recordingURL] applicationActivities:nil];
    controller.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:controller animated:YES completion:nil];
}

@end

@implementation WCAtlasCallRecordingsViewController

- (instancetype)init { return [self initWithStyle:UITableViewStyleInsetGrouped]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"通话录音";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(reloadRecordings)];
    [self reloadRecordings];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadRecordings];
}

- (NSURL *)recordingDirectory {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                             inDomains:NSUserDomainMask].firstObject;
    return [documents URLByAppendingPathComponent:@"WCAtlas/CallRecordings" isDirectory:YES];
}

- (NSString *)prefixForURL:(NSURL *)URL {
    NSString *name = URL.lastPathComponent.stringByDeletingPathExtension;
    for (NSString *suffix in @[@"-mixed", @"-mic", @"-peer"]) {
        if ([name hasSuffix:suffix]) return [name substringToIndex:name.length - suffix.length];
    }
    return nil;
}

- (void)reloadRecordings {
    NSURL *directory = self.recordingDirectory;
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory
                                                          includingPropertiesForKeys:@[NSURLFileSizeKey]
                                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               error:nil] ?: @[];
    NSMutableDictionary<NSString *, NSMutableDictionary *> *groups = [NSMutableDictionary dictionary];
    for (NSURL *URL in files) {
        if (![@[@"m4a", @"caf"] containsObject:URL.pathExtension.lowercaseString]) continue;
        NSString *prefix = [self prefixForURL:URL];
        if (prefix.length == 0) continue;
        NSMutableDictionary *session = groups[prefix];
        if (!session) {
            session = [@{ @"prefix": prefix, @"tracks": [NSMutableDictionary dictionary] } mutableCopy];
            groups[prefix] = session;
        }
        NSString *track = [URL.lastPathComponent containsString:@"-mixed."] ? @"mixed" :
            ([URL.lastPathComponent containsString:@"-mic."] ? @"mic" : @"peer");
        ((NSMutableDictionary *)session[@"tracks"])[track] = URL;
    }
    NSMutableArray *sessions = [NSMutableArray array];
    for (NSMutableDictionary *session in groups.allValues) {
        NSString *prefix = session[@"prefix"];
        NSURL *metadataURL = [directory URLByAppendingPathComponent:[prefix stringByAppendingPathExtension:@"json"]];
        NSData *data = [NSData dataWithContentsOfURL:metadataURL];
        id metadataObject = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSDictionary *metadata = [metadataObject isKindOfClass:NSDictionary.class] ? metadataObject : nil;
        session[@"name"] = [metadata[@"name"] isKindOfClass:NSString.class] ? metadata[@"name"] : @"通话录音";
        NSDateFormatter *parser = [NSDateFormatter new];
        parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        parser.dateFormat = @"yyyyMMdd-HHmmss";
        session[@"date"] = [parser dateFromString:prefix] ?: NSDate.distantPast;
        [sessions addObject:session.copy];
    }
    self.sessions = [sessions sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"date"] compare:left[@"date"]];
    }];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return MAX((NSInteger)self.sessions.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.sessions.count ? @"每次通话只显示一条记录；点按后选择双方混合、本地麦克风或对端声音。"
                               : @"暂无通话录音。开启后会在通话期间自动录制。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"call-session"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"call-session"];
    if (self.sessions.count == 0) {
        cell.textLabel.text = @"暂无录音";
        cell.detailTextLabel.text = @"完成一次启用录音的通话后再查看";
        cell.imageView.image = [UIImage systemImageNamed:@"waveform.slash"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    NSDictionary *session = self.sessions[indexPath.row];
    NSDictionary *tracks = session[@"tracks"];
    cell.textLabel.text = session[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %lu 条音轨",
        [NSDateFormatter localizedStringFromDate:session[@"date"] dateStyle:NSDateFormatterMediumStyle
                                       timeStyle:NSDateFormatterShortStyle], (unsigned long)tracks.count];
    cell.imageView.image = [UIImage systemImageNamed:@"waveform.circle"];
    cell.imageView.tintColor = UIColor.systemGreenColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.sessions.count) return;
    NSDictionary *tracks = self.sessions[indexPath.row][@"tracks"];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择播放音轨" message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSArray *entry in @[@[@"mixed", @"双方混合"], @[@"mic", @"本地麦克风"], @[@"peer", @"对端声音"]]) {
        NSURL *URL = tracks[entry[0]];
        if (!URL) continue;
        [sheet addAction:[UIAlertAction actionWithTitle:entry[1] style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            WCAtlasCallRecordingPlayerViewController *player = [[WCAtlasCallRecordingPlayerViewController alloc]
                initWithURL:URL title:self.sessions[indexPath.row][@"name"] trackTitle:entry[1]];
            if (self.navigationController) {
                [self.navigationController pushViewController:player animated:YES];
            } else {
                UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:player];
                player.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:player
                    action:@selector(close)];
                [self presentViewController:navigation animated:YES completion:nil];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    return indexPath.row < self.sessions.count;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (style != UITableViewCellEditingStyleDelete || indexPath.row >= self.sessions.count) return;
    NSDictionary *session = self.sessions[indexPath.row];
    for (NSURL *URL in [session[@"tracks"] allValues]) {
        [NSFileManager.defaultManager removeItemAtURL:URL error:nil];
    }
    NSURL *metadataURL = [self.recordingDirectory URLByAppendingPathComponent:
        [session[@"prefix"] stringByAppendingPathExtension:@"json"]];
    [NSFileManager.defaultManager removeItemAtURL:metadataURL error:nil];
    [self reloadRecordings];
}

@end
