#import "WCAtlasCallAudio.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasLogging.h"
#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasSilkDecoder.h"
#import "WCAtlasTTSGenerator.h"
#import "WCAtlasVoiceEffectProcessor.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <stdbool.h>
#import <stdatomic.h>

extern void MSHookFunction(void *symbol, void *replacement, void **original);
extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

static NSString *const WCAtlasCallRecordDirectoryName = @"WCAtlas/CallRecordings";

typedef struct {
    AudioFileID file;
    SInt64 packet;
    AudioStreamBasicDescription format;
} WCAtlasPCMWriter;

typedef struct {
    AudioUnit unit;
    AURenderCallback callback;
    void *refCon;
} WCAtlasRenderSlot;

static _Atomic(bool) WCAtlasCallActive;
static _Atomic(bool) WCAtlasCallRecording;
static _Atomic(bool) WCAtlasVoiceActive;
static _Atomic(int) WCAtlasVoiceMode; // 0 replace, 1 mix
static _Atomic(uintptr_t) WCAtlasVoiceBytes;
static _Atomic(size_t) WCAtlasVoiceByteCount;
static _Atomic(uint64_t) WCAtlasVoiceFramePosition;
static _Atomic(uint64_t) WCAtlasAudioActivityGeneration;
static void *WCAtlasRetiredVoiceBuffers[32];
static NSUInteger WCAtlasRetiredVoiceBufferCount;
static WCAtlasPCMWriter WCAtlasMicWriter;
static WCAtlasPCMWriter WCAtlasPeerWriter;
static os_unfair_lock WCAtlasMicWriterLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock WCAtlasPeerWriterLock = OS_UNFAIR_LOCK_INIT;
static NSString *WCAtlasCallSessionPrefix;
static NSString *WCAtlasCallSessionDisplayName;
static NSString *WCAtlasMicRecordingPath;
static NSString *WCAtlasPeerRecordingPath;
static WCAtlasRenderSlot WCAtlasRenderSlots[16];
static dispatch_queue_t WCAtlasCallFileQueue;
static void WCAtlasCallDidStop(void);
static void WCAtlasFinalizeCurrentRecording(void);
static void WCAtlasCallVoiceDidFinish(void);

static OSStatus (*WCAtlasOriginalAudioUnitRender)(AudioUnit, AudioUnitRenderActionFlags *,
                                                const AudioTimeStamp *, UInt32, UInt32,
                                                AudioBufferList *);
static OSStatus (*WCAtlasOriginalAudioUnitSetProperty)(AudioUnit, AudioUnitPropertyID,
                                                     AudioUnitScope, AudioUnitElement,
                                                     const void *, UInt32);
static OSStatus (*WCAtlasOriginalAudioComponentInstanceDispose)(AudioComponentInstance);

static NSURL *WCAtlasCallRecordDirectory(void) {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                             inDomains:NSUserDomainMask].firstObject;
    NSURL *directory = [documents URLByAppendingPathComponent:WCAtlasCallRecordDirectoryName
                                                   isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

static BOOL WCAtlasFormatIsSupportedPCM(AudioStreamBasicDescription format) {
    if (format.mFormatID != kAudioFormatLinearPCM || format.mChannelsPerFrame == 0) return NO;
    BOOL float32 = (format.mFormatFlags & kAudioFormatFlagIsFloat) && format.mBitsPerChannel == 32;
    BOOL int16 = !(format.mFormatFlags & kAudioFormatFlagIsFloat) && format.mBitsPerChannel == 16;
    return float32 || int16;
}

static AudioStreamBasicDescription WCAtlasFormatForUnit(AudioUnit unit, AudioUnitScope scope,
                                                       AudioUnitElement element) {
    AudioStreamBasicDescription format = {0};
    UInt32 size = sizeof(format);
    if (!unit || AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, scope, element,
                                      &format, &size) != noErr) return format;
    return format;
}

static void WCAtlasCloseWriter(WCAtlasPCMWriter *writer) {
    if (!writer || !writer->file) return;
    AudioFileClose(writer->file);
    memset(writer, 0, sizeof(*writer));
}

static void WCAtlasOpenWriter(WCAtlasPCMWriter *writer, NSString *suffix,
                            AudioStreamBasicDescription sourceFormat) {
    if (!writer || writer->file || !WCAtlasFormatIsSupportedPCM(sourceFormat)) return;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *prefix = WCAtlasCallSessionPrefix ?: [formatter stringFromDate:NSDate.date];
    NSString *name = [NSString stringWithFormat:@"%@-%@.caf", prefix, suffix];
    NSURL *url = [WCAtlasCallRecordDirectory() URLByAppendingPathComponent:name];
    AudioStreamBasicDescription fileFormat = sourceFormat;
    OSStatus status = AudioFileCreateWithURL((__bridge CFURLRef)url, kAudioFileCAFType,
                                             &fileFormat, kAudioFileFlags_EraseFile,
                                             &writer->file);
    if (status == noErr) {
        writer->format = sourceFormat;
        writer->packet = 0;
        if ([suffix isEqualToString:@"mic"]) WCAtlasMicRecordingPath = url.path;
        if ([suffix isEqualToString:@"peer"]) WCAtlasPeerRecordingPath = url.path;
    } else {
        WCAtlasLog(@"通话录音文件创建失败：%@ status=%d", suffix, (int)status);
    }
}

static void WCAtlasExportMixedRecording(NSString *micPath, NSString *peerPath, NSString *prefix) {
    if (micPath.length == 0 || peerPath.length == 0 || prefix.length == 0) return;
    AVURLAsset *micAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:micPath] options:nil];
    AVURLAsset *peerAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:peerPath] options:nil];
    AVAssetTrack *micSource = [micAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetTrack *peerSource = [peerAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    if (!micSource || !peerSource) return;
    AVMutableComposition *composition = [AVMutableComposition composition];
    NSError *error = nil;
    AVMutableCompositionTrack *micTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                    preferredTrackID:kCMPersistentTrackID_Invalid];
    [micTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, micAsset.duration)
                      ofTrack:micSource atTime:kCMTimeZero error:&error];
    AVMutableCompositionTrack *peerTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                     preferredTrackID:kCMPersistentTrackID_Invalid];
    [peerTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, peerAsset.duration)
                       ofTrack:peerSource atTime:kCMTimeZero error:&error];
    if (error) {
        WCAtlasLog(@"通话录音混音轨构造失败：%@", error.localizedDescription);
        return;
    }
    NSURL *outputURL = [WCAtlasCallRecordDirectory()
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-mixed.m4a", prefix]];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc]
        initWithAsset:composition presetName:AVAssetExportPresetAppleM4A];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeAppleM4A;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        if (exporter.status == AVAssetExportSessionStatusCompleted) {
            WCAtlasLog(@"通话录音混合文件已生成：%@", outputURL.path);
        } else {
            WCAtlasLog(@"通话录音混合导出失败：%@", exporter.error.localizedDescription);
        }
    }];
}

static void WCAtlasWriteBuffers(WCAtlasPCMWriter *writer, NSString *suffix,
                              os_unfair_lock *writerLock,
                              AudioStreamBasicDescription format, UInt32 frames,
                              AudioBufferList *buffers) {
    if (!atomic_load(&WCAtlasCallRecording) || !buffers || frames == 0 ||
        !WCAtlasFormatIsSupportedPCM(format)) return;
    os_unfair_lock_lock(writerLock);
    WCAtlasOpenWriter(writer, suffix, format);
    if (!writer->file) {
        os_unfair_lock_unlock(writerLock);
        return;
    }
    UInt32 packets = frames;
    OSStatus status = AudioFileWritePackets(writer->file, false, buffers->mBuffers[0].mDataByteSize,
                                             NULL, writer->packet, &packets,
                                             buffers->mBuffers[0].mData);
    if (status == noErr) writer->packet += packets;
    os_unfair_lock_unlock(writerLock);
}

static inline BOOL WCAtlasVoiceSample(uint64_t sourceFrame, UInt32 targetChannel,
                                    float *sample) {
    const SInt16 *samples = (const SInt16 *)atomic_load(&WCAtlasVoiceBytes);
    size_t bytes = atomic_load(&WCAtlasVoiceByteCount);
    size_t frameCount = bytes / sizeof(SInt16);
    if (!samples || frameCount == 0 || !sample) return NO;
    if (sourceFrame >= frameCount) {
        if (atomic_exchange(&WCAtlasVoiceActive, false)) {
            dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasCallVoiceDidFinish(); });
        }
        return NO;
    }
    (void)targetChannel;
    *sample = (float)samples[sourceFrame] / 32768.0f;
    return YES;
}

static void WCAtlasApplyVoice(AudioStreamBasicDescription format, UInt32 frames,
                            AudioBufferList *buffers) {
    if (!atomic_load(&WCAtlasVoiceActive) || !buffers || !WCAtlasFormatIsSupportedPCM(format)) return;
    uint64_t start = atomic_fetch_add(&WCAtlasVoiceFramePosition, frames);
    double ratio = 48000.0 / MAX(1.0, format.mSampleRate);
    BOOL mix = atomic_load(&WCAtlasVoiceMode) == 1;
    BOOL nonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 channelCount = MAX(1, format.mChannelsPerFrame);
    for (UInt32 bufferIndex = 0; bufferIndex < buffers->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &buffers->mBuffers[bufferIndex];
        UInt32 reportedChannels = buffer->mNumberChannels > 0 ? buffer->mNumberChannels : channelCount;
        UInt32 channels = nonInterleaved ? 1 : MAX(1, reportedChannels);
        if (format.mBitsPerChannel == 16) {
            SInt16 *values = buffer->mData;
            if (!values) continue;
            UInt32 availableFrames = buffer->mDataByteSize / (sizeof(SInt16) * channels);
            for (UInt32 frame = 0; frame < MIN(frames, availableFrames); frame++) {
                float voice = 0;
                if (!WCAtlasVoiceSample((uint64_t)((start + frame) * ratio), bufferIndex, &voice)) break;
                for (UInt32 channel = 0; channel < channels; channel++) {
                    UInt32 index = frame * channels + channel;
                    float original = (float)values[index] / 32768.0f;
                    float result = mix ? original * 0.45f + voice * 0.75f : voice;
                    result = fmaxf(-1.0f, fminf(1.0f, result));
                    values[index] = (SInt16)lrintf(result * 32767.0f);
                }
            }
        } else if (format.mBitsPerChannel == 32 && (format.mFormatFlags & kAudioFormatFlagIsFloat)) {
            float *values = buffer->mData;
            if (!values) continue;
            UInt32 availableFrames = buffer->mDataByteSize / (sizeof(float) * channels);
            for (UInt32 frame = 0; frame < MIN(frames, availableFrames); frame++) {
                float voice = 0;
                if (!WCAtlasVoiceSample((uint64_t)((start + frame) * ratio), bufferIndex, &voice)) break;
                for (UInt32 channel = 0; channel < channels; channel++) {
                    UInt32 index = frame * channels + channel;
                    float result = mix ? values[index] * 0.45f + voice * 0.75f : voice;
                    values[index] = fmaxf(-1.0f, fminf(1.0f, result));
                }
            }
        }
    }
}

static OSStatus WCAtlasAudioUnitRender(AudioUnit unit, AudioUnitRenderActionFlags *flags,
                                     const AudioTimeStamp *timestamp, UInt32 bus,
                                     UInt32 frames, AudioBufferList *buffers) {
    OSStatus status = WCAtlasOriginalAudioUnitRender
        ? WCAtlasOriginalAudioUnitRender(unit, flags, timestamp, bus, frames, buffers) : -1;
    if (status != noErr || !atomic_load(&WCAtlasCallActive)) return status;
    atomic_fetch_add(&WCAtlasAudioActivityGeneration, 1);
    AudioStreamBasicDescription format = WCAtlasFormatForUnit(unit, kAudioUnitScope_Output, bus);
    WCAtlasVoiceEffectProcess(format, frames, buffers);
    WCAtlasApplyVoice(format, frames, buffers);
    WCAtlasWriteBuffers(&WCAtlasMicWriter, @"mic", &WCAtlasMicWriterLock, format, frames, buffers);
    return status;
}

static WCAtlasRenderSlot *WCAtlasSlotForUnit(AudioUnit unit, BOOL create) {
    for (NSUInteger index = 0; index < 16; index++) {
        if (WCAtlasRenderSlots[index].unit == unit) return &WCAtlasRenderSlots[index];
    }
    if (!create) return NULL;
    for (NSUInteger index = 0; index < 16; index++) {
        if (!WCAtlasRenderSlots[index].unit) {
            WCAtlasRenderSlots[index].unit = unit;
            return &WCAtlasRenderSlots[index];
        }
    }
    return NULL;
}

static OSStatus WCAtlasRenderCallback(void *refCon, AudioUnitRenderActionFlags *flags,
                                    const AudioTimeStamp *timestamp, UInt32 bus,
                                    UInt32 frames, AudioBufferList *buffers) {
    WCAtlasRenderSlot *slot = refCon;
    if (!slot || !slot->callback) return noErr;
    OSStatus status = slot->callback(slot->refCon, flags, timestamp, bus, frames, buffers);
    if (status == noErr && atomic_load(&WCAtlasCallActive)) {
        atomic_fetch_add(&WCAtlasAudioActivityGeneration, 1);
        AudioStreamBasicDescription format = WCAtlasFormatForUnit(slot->unit, kAudioUnitScope_Input, bus);
        WCAtlasWriteBuffers(&WCAtlasPeerWriter, @"peer", &WCAtlasPeerWriterLock,
                          format, frames, buffers);
    }
    return status;
}

static OSStatus WCAtlasAudioUnitSetProperty(AudioUnit unit, AudioUnitPropertyID property,
                                          AudioUnitScope scope, AudioUnitElement element,
                                          const void *data, UInt32 size) {
    if (!WCAtlasOriginalAudioUnitSetProperty) return kAudio_ParamError;
    if (property == kAudioUnitProperty_SetRenderCallback && data &&
        size == sizeof(AURenderCallbackStruct)) {
        const AURenderCallbackStruct *original = data;
        WCAtlasRenderSlot *slot = WCAtlasSlotForUnit(unit, YES);
        if (slot && original->inputProc != WCAtlasRenderCallback) {
            slot->callback = original->inputProc;
            slot->refCon = original->inputProcRefCon;
            AURenderCallbackStruct wrapped = { WCAtlasRenderCallback, slot };
            return WCAtlasOriginalAudioUnitSetProperty(unit, property, scope, element,
                                                     &wrapped, sizeof(wrapped));
        }
    }
    return WCAtlasOriginalAudioUnitSetProperty(unit, property, scope, element, data, size);
}

static OSStatus WCAtlasAudioComponentInstanceDispose(AudioComponentInstance instance) {
    OSStatus status = WCAtlasOriginalAudioComponentInstanceDispose
        ? WCAtlasOriginalAudioComponentInstanceDispose(instance) : kAudio_ParamError;
    if (status == noErr) {
        WCAtlasRenderSlot *slot = WCAtlasSlotForUnit((AudioUnit)instance, NO);
        if (slot) {
            memset(slot, 0, sizeof(*slot));
            uint64_t generation = atomic_load(&WCAtlasAudioActivityGeneration);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (atomic_load(&WCAtlasCallActive) &&
                    atomic_load(&WCAtlasAudioActivityGeneration) == generation) {
                    WCAtlasCallDidStop();
                }
            });
        }
    }
    return status;
}

@class WCAtlasCallAudioPanel;

@interface WCAtlasCallVoiceLibraryViewController : UITableViewController
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyItem *> *voiceItems;
@property (nonatomic, weak) WCAtlasCallAudioPanel *audioPanel;
@end

@interface WCAtlasCallAudioPanel : NSObject
@property (nonatomic, strong) UIView *controlView;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIView *recordingDot;
@property (nonatomic, weak) UIViewController *hostController;
@property (nonatomic, weak) UIViewController *voiceLibraryController;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL menuExpanded;
- (void)loadVoiceItem:(WCAtlasQuickReplyItem *)item;
- (void)voiceDidFinish;
- (void)stopCurrentRecording;
- (void)pickVoiceEffect;
- (void)pickTTS;
- (void)presentFishTTSSettings;
- (void)presentFishTTSModelPicker;
- (void)presentFishTTSSpeedPicker;
- (void)presentFishTTSTonePicker;
- (void)presentFishTTSVoicePicker;
- (void)presentFishTTSAddVoicePreset;
- (void)presentFishTTSDeleteVoicePresetPicker;
@end

static void WCAtlasCallCollectLabels(UIView *view, NSMutableArray<UILabel *> *labels) {
    if (!view || view.hidden || view.alpha <= 0.01) return;
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) [labels addObject:label];
    }
    for (UIView *subview in view.subviews) WCAtlasCallCollectLabels(subview, labels);
}

static UILabel *WCAtlasCallNameLabel(UIViewController *controller) {
    if (!controller.viewIfLoaded.window) return nil;
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    WCAtlasCallCollectLabels(controller.view, labels);
    UILabel *best = nil;
    CGFloat bestScore = -CGFLOAT_MAX;
    CGFloat width = CGRectGetWidth(controller.view.bounds);
    CGFloat height = CGRectGetHeight(controller.view.bounds);
    for (UILabel *label in labels) {
        CGRect rect = [label convertRect:label.bounds toView:controller.view];
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect);
        if (CGRectIsEmpty(rect) || centerY < height * 0.18 || centerY > height * 0.58 ||
            fabs(centerX - width * 0.5) > width * 0.3) continue;
        NSString *text = [label.text stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0 || [text containsString:@":"] || [text containsString:@"录音"] ||
            [text containsString:@"语音包"]) continue;
        CGFloat score = label.font.pointSize * 12.0 - fabs(centerX - width * 0.5) -
            fabs(centerY - height * 0.36) * 0.08;
        if (score > bestScore) {
            best = label;
            bestScore = score;
        }
    }
    return best;
}

static UIViewController *WCAtlasCallTopViewController(UIViewController *controller) {
    if (!controller) return nil;
    UIViewController *presented = controller.presentedViewController;
    if (presented && !presented.isBeingDismissed) return WCAtlasCallTopViewController(presented);
    if ([controller isKindOfClass:UINavigationController.class]) {
        return WCAtlasCallTopViewController(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return WCAtlasCallTopViewController(((UITabBarController *)controller).selectedViewController);
    }
    for (UIViewController *child in controller.childViewControllers.reverseObjectEnumerator) {
        if (child.viewIfLoaded.window) return WCAtlasCallTopViewController(child);
    }
    return controller;
}

static BOOL WCAtlasCallClassNameLooksLikeCallUI(id object) {
    if (!object) return NO;
    NSString *name = NSStringFromClass([object class]).lowercaseString;
    if ([name hasPrefix:@"wcatlas"] || [name hasPrefix:@"wcallrecorder"]) return NO;
    return [name containsString:@"voip"] || [name containsString:@"multitalk"] ||
           [name containsString:@"callview"] || [name containsString:@"calling"];
}

static BOOL WCAtlasCallTextIndicatesActiveVideo(NSString *text) {
    if (![text isKindOfClass:NSString.class] || text.length == 0) return NO;
    NSString *normalized = [text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [normalized containsString:@"切换到语音"] ||
           [normalized containsString:@"切换语音"] ||
           [normalized containsString:@"关闭摄像头"] ||
           [normalized containsString:@"打开摄像头"] ||
           [normalized containsString:@"翻转摄像头"];
}

static BOOL WCAtlasCallViewLooksLikeActiveVideo(UIView *view) {
    if (!view || view.hidden || view.alpha <= 0.01) return NO;
    NSString *className = NSStringFromClass(view.class).lowercaseString;
    BOOL videoNamed = [className containsString:@"video"] ||
                      [className containsString:@"camera"];
    BOOL callSurfaceNamed = [className containsString:@"voip"] ||
                            [className containsString:@"call"] ||
                            [className containsString:@"render"] ||
                            [className containsString:@"preview"] ||
                            [className containsString:@"capture"];
    if (videoNamed && callSurfaceNamed) return YES;

    NSString *visibleText = nil;
    if ([view isKindOfClass:UILabel.class]) {
        visibleText = ((UILabel *)view).text;
    } else if ([view isKindOfClass:UIButton.class]) {
        visibleText = ((UIButton *)view).currentTitle;
    }
    if (WCAtlasCallTextIndicatesActiveVideo(visibleText) ||
        WCAtlasCallTextIndicatesActiveVideo(view.accessibilityLabel)) return YES;
    for (UIView *subview in view.subviews) {
        if (WCAtlasCallViewLooksLikeActiveVideo(subview)) return YES;
    }
    return NO;
}

static BOOL WCAtlasCallControllerLooksLikeActiveVideo(UIViewController *controller) {
    for (UIViewController *candidate = controller; candidate; candidate = candidate.parentViewController) {
        NSString *className = NSStringFromClass(candidate.class).lowercaseString;
        if (([className containsString:@"video"] || [className containsString:@"camera"]) &&
            ([className containsString:@"voip"] || [className containsString:@"call"])) return YES;
        if (WCAtlasCallViewLooksLikeActiveVideo(candidate.viewIfLoaded)) return YES;
    }
    return NO;
}

static UIViewController *WCAtlasCallVisibleInterfaceController(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            (scene.activationState != UISceneActivationStateForegroundActive &&
             scene.activationState != UISceneActivationStateForegroundInactive)) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden && window.alpha > 0.01 && window.rootViewController) [windows addObject:window];
        }
    }
    [windows sortUsingComparator:^NSComparisonResult(UIWindow *first, UIWindow *second) {
        if (first.windowLevel > second.windowLevel) return NSOrderedAscending;
        if (first.windowLevel < second.windowLevel) return NSOrderedDescending;
        if (first.isKeyWindow != second.isKeyWindow) {
            return first.isKeyWindow ? NSOrderedAscending : NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    UIViewController *fallback = nil;
    for (UIWindow *window in windows) {
        UIViewController *candidate = WCAtlasCallTopViewController(window.rootViewController);
        if (!candidate.viewIfLoaded.window) continue;
        if (WCAtlasCallClassNameLooksLikeCallUI(window) || WCAtlasCallClassNameLooksLikeCallUI(candidate)) {
            return candidate;
        }
        for (UIViewController *parent = candidate.parentViewController; parent; parent = parent.parentViewController) {
            if (WCAtlasCallClassNameLooksLikeCallUI(parent)) return candidate;
        }
        if (!fallback && window.windowLevel < UIWindowLevelAlert) fallback = candidate;
    }
    return fallback;
}

static NSData *WCAtlasCallPCMDataAtPath(NSString *path, NSError **error) {
    if (path.length == 0) return nil;
    AVAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetReader *reader = track ? [[AVAssetReader alloc] initWithAsset:asset error:error] : nil;
    NSDictionary *settings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM),
                                AVSampleRateKey: @48000,
                                AVNumberOfChannelsKey: @1,
                                AVLinearPCMBitDepthKey: @16,
                                AVLinearPCMIsFloatKey: @NO,
                                AVLinearPCMIsBigEndianKey: @NO,
                                AVLinearPCMIsNonInterleaved: @NO };
    AVAssetReaderTrackOutput *output = track ? [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                                                                outputSettings:settings] : nil;
    if (!reader || !output || ![reader canAddOutput:output]) return nil;
    [reader addOutput:output];
    if (![reader startReading]) return nil;
    NSMutableData *pcm = [NSMutableData data];
    CMSampleBufferRef sample = NULL;
    while ((sample = [output copyNextSampleBuffer])) {
        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
        size_t length = block ? CMBlockBufferGetDataLength(block) : 0;
        if (length > 0) {
            NSUInteger oldLength = pcm.length;
            [pcm increaseLengthBy:length];
            CMBlockBufferCopyDataBytes(block, 0, length, (uint8_t *)pcm.mutableBytes + oldLength);
        }
        CFRelease(sample);
    }
    return reader.status == AVAssetReaderStatusCompleted && pcm.length > 0 ? pcm : nil;
}

@implementation WCAtlasCallVoiceLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择通话语音包";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close)];
    NSMutableArray<WCAtlasQuickReplyItem *> *items = [NSMutableArray array];
    WCAtlasQuickReplyStore *store = WCAtlasQuickReplyStore.sharedStore;
    for (WCAtlasQuickReplyItem *item in store.items) {
        if (item.type != WCAtlasQuickReplyTypeVoice) continue;
        NSString *path = [store absoluteMediaPathForItem:item];
        if (path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path]) [items addObject:item];
    }
    self.voiceItems = items;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return MAX((NSInteger)self.voiceItems.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.voiceItems.count ? @"只显示消息库中已有本地音频文件的语音素材。"
                                 : @"消息库中暂无可用语音素材。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"call-voice-item"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                             reuseIdentifier:@"call-voice-item"];
    if (indexPath.row >= self.voiceItems.count) {
        cell.textLabel.text = @"暂无语音包";
        cell.detailTextLabel.text = @"先将语音或音频保存到消息库";
        cell.imageView.image = [UIImage systemImageNamed:@"waveform.slash"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    WCAtlasQuickReplyItem *item = self.voiceItems[indexPath.row];
    cell.textLabel.text = item.title.length ? item.title : @"语音素材";
    cell.detailTextLabel.text = item.createdAt
        ? [NSDateFormatter localizedStringFromDate:item.createdAt
                                         dateStyle:NSDateFormatterShortStyle
                                         timeStyle:NSDateFormatterShortStyle] : nil;
    cell.imageView.image = [UIImage systemImageNamed:@"waveform"];
    cell.imageView.tintColor = UIColor.systemGreenColor;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.voiceItems.count) return;
    WCAtlasQuickReplyItem *item = self.voiceItems[indexPath.row];
    [self dismissViewControllerAnimated:YES completion:^{ [self.audioPanel loadVoiceItem:item]; }];
}

@end

@implementation WCAtlasCallAudioPanel

+ (instancetype)sharedPanel {
    static WCAtlasCallAudioPanel *panel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ panel = [[self alloc] init]; });
    return panel;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)installRecordingIndicatorInController:(UIViewController *)controller {
    [self.recordingDot removeFromSuperview];
    self.recordingDot = nil;
    if (!atomic_load(&WCAtlasCallRecording)) return;
    UILabel *nameLabel = WCAtlasCallNameLabel(controller);
    if (!nameLabel) return;
    NSString *displayName = [nameLabel.text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (displayName.length > 0) WCAtlasCallSessionDisplayName = displayName;
    UIButton *dotButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dotButton.backgroundColor = UIColor.clearColor;
    dotButton.layer.zPosition = 10000.0;
    dotButton.translatesAutoresizingMaskIntoConstraints = NO;
    dotButton.accessibilityLabel = @"结束本次通话录音";
    dotButton.accessibilityHint = @"只停止本次通话，下次通话仍会自动录音";
    [dotButton addTarget:self action:@selector(stopCurrentRecording)
        forControlEvents:UIControlEventTouchUpInside];
    UIView *dot = [UIView new];
    dot.userInteractionEnabled = NO;
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 4.0;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [dotButton addSubview:dot];
    [controller.view addSubview:dotButton];
    CGFloat textWidth = ceil([nameLabel.text sizeWithAttributes:
        @{ NSFontAttributeName: nameLabel.font }].width);
    textWidth = MIN(textWidth, CGRectGetWidth(nameLabel.bounds));
    [NSLayoutConstraint activateConstraints:@[
        [dotButton.centerXAnchor constraintEqualToAnchor:nameLabel.centerXAnchor
                                                constant:textWidth * 0.5 + 11.0],
        [dotButton.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],
        [dotButton.widthAnchor constraintEqualToConstant:28.0],
        [dotButton.heightAnchor constraintEqualToConstant:28.0],
        [dot.centerXAnchor constraintEqualToAnchor:dotButton.centerXAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:dotButton.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:8.0],
        [dot.heightAnchor constraintEqualToConstant:8.0],
    ]];
    self.recordingDot = dotButton;
}

- (void)stopCurrentRecording {
    if (!atomic_load(&WCAtlasCallActive) || !atomic_load(&WCAtlasCallRecording)) return;
    WCAtlasFinalizeCurrentRecording();
    [self.recordingDot removeFromSuperview];
    self.recordingDot = nil;
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)toggleMenu {
    self.menuExpanded = !self.menuExpanded;
    if (self.menuExpanded) self.menuView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.menuView.alpha = self.menuExpanded ? 1.0 : 0.0;
        self.menuView.transform = self.menuExpanded
            ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        (void)finished;
        if (!self.menuExpanded) self.menuView.hidden = YES;
    }];
}

- (void)show {
    if (!WCAtlasEnhancementEnabled(WCAtlasCallRecordingEnabledKey) &&
        !WCAtlasEnhancementEnabled(WCAtlasCallVoiceDisguiseEnabledKey) &&
        !WCAtlasEnhancementEnabled(WCAtlasCallRealtimeVoiceEffectEnabledKey)) return;
    UIViewController *controller = WCAtlasCallVisibleInterfaceController();
    if (!controller.viewIfLoaded.window) return;
    if ([controller isKindOfClass:WCAtlasCallVoiceLibraryViewController.class] ||
        ([controller isKindOfClass:UINavigationController.class] &&
         [((UINavigationController *)controller).topViewController
             isKindOfClass:WCAtlasCallVoiceLibraryViewController.class])) return;
    // The recording pipeline may continue for a video call, but these controls are
    // designed for the voice-call layout. Never cover the remote video surface.
    if (WCAtlasCallControllerLooksLikeActiveVideo(controller)) {
        [self.controlView removeFromSuperview];
        [self.menuView removeFromSuperview];
        [self.recordingDot removeFromSuperview];
        self.controlView = nil;
        self.menuView = nil;
        self.recordingDot = nil;
        self.statusLabel = nil;
        self.hostController = nil;
        self.menuExpanded = NO;
        return;
    }
    BOOL voiceEnabled = WCAtlasEnhancementEnabled(WCAtlasCallVoiceDisguiseEnabledKey);
    BOOL effectEnabled = WCAtlasEnhancementEnabled(WCAtlasCallRealtimeVoiceEffectEnabledKey);
    BOOL hasAudioControls = voiceEnabled || effectEnabled;
    if (self.hostController == controller) {
        [self installRecordingIndicatorInController:controller];
        if (!hasAudioControls || self.controlView.superview == controller.view) return;
    }
    [self.controlView removeFromSuperview];
    [self.menuView removeFromSuperview];
    [self.recordingDot removeFromSuperview];
    self.hostController = controller;
    [self installRecordingIndicatorInController:controller];
    if (!hasAudioControls) return;

    UIButton *voiceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    voiceButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.82];
    voiceButton.tintColor = UIColor.whiteColor;
    voiceButton.layer.cornerRadius = 22.0;
    voiceButton.layer.cornerCurve = kCACornerCurveContinuous;
    voiceButton.layer.zPosition = 10000.0;
    voiceButton.translatesAutoresizingMaskIntoConstraints = NO;
    [voiceButton setImage:[UIImage systemImageNamed:@"waveform"] forState:UIControlStateNormal];
    [voiceButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:voiceButton];

    UIView *menu = [UIView new];
    menu.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
    menu.layer.cornerRadius = 14.0;
    menu.layer.cornerCurve = kCACornerCurveContinuous;
    menu.layer.zPosition = 9999.0;
    menu.translatesAutoresizingMaskIntoConstraints = NO;
    menu.alpha = 0.0;
    menu.hidden = YES;
    menu.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [controller.view insertSubview:menu belowSubview:voiceButton];

    UILabel *label = [[UILabel alloc] init];
    label.text = effectEnabled
        ? [NSString stringWithFormat:@"实时变声：%@", WCAtlasVoiceEffectName(WCAtlasVoiceEffectPreset())]
        : @"语音包未播放";
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentLeft;
    NSMutableArray<UIButton *> *audioButtons = [NSMutableArray array];
    if (voiceEnabled) {
        [audioButtons addObject:[self button:@"选择语音包" action:@selector(pickVoice)]];
        [audioButtons addObject:[self button:@"TTS" action:@selector(pickTTS)]];
        [audioButtons addObject:[self button:@"停止播放" action:@selector(stopVoice)]];
    }
    if (effectEnabled) {
        [audioButtons addObject:[self button:@"变声效果" action:@selector(pickVoiceEffect)]];
    }
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:audioButtons];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[label, buttons]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 5;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [menu addSubview:stack];
    CGFloat desiredMenuWidth = audioButtons.count >= 4 ? 304.0 :
                               (audioButtons.count == 3 ? 248.0 : 190.0);
    CGFloat availableMenuWidth = MAX(190.0, CGRectGetWidth(controller.view.bounds) - 76.0);
    [NSLayoutConstraint activateConstraints:@[
        [voiceButton.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [voiceButton.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [voiceButton.widthAnchor constraintEqualToConstant:44],
        [voiceButton.heightAnchor constraintEqualToConstant:44],
        [menu.leadingAnchor constraintEqualToAnchor:voiceButton.trailingAnchor constant:8],
        [menu.centerYAnchor constraintEqualToAnchor:voiceButton.centerYAnchor],
        [menu.widthAnchor constraintEqualToConstant:MIN(desiredMenuWidth, availableMenuWidth)],
        [menu.heightAnchor constraintEqualToConstant:78],
        [stack.leadingAnchor constraintEqualToAnchor:menu.leadingAnchor constant:10],
        [stack.trailingAnchor constraintEqualToAnchor:menu.trailingAnchor constant:-8],
        [stack.topAnchor constraintEqualToAnchor:menu.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:menu.bottomAnchor constant:-8],
    ]];
    self.controlView = voiceButton;
    self.menuView = menu;
    self.statusLabel = label;
    self.menuExpanded = NO;
}

- (void)hide {
    if (self.voiceLibraryController.viewIfLoaded.window) {
        [self.voiceLibraryController dismissViewControllerAnimated:NO completion:nil];
    }
    self.voiceLibraryController = nil;
    [self.controlView removeFromSuperview];
    [self.menuView removeFromSuperview];
    [self.recordingDot removeFromSuperview];
    self.controlView = nil;
    self.menuView = nil;
    self.recordingDot = nil;
    self.hostController = nil;
    self.statusLabel = nil;
    self.menuExpanded = NO;
}

- (void)pickVoice {
    if (!WCAtlasEnhancementEnabled(WCAtlasCallVoiceDisguiseEnabledKey)) return;
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    WCAtlasCallVoiceLibraryViewController *library = [[WCAtlasCallVoiceLibraryViewController alloc]
        initWithStyle:UITableViewStyleInsetGrouped];
    library.audioPanel = self;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:library];
    self.voiceLibraryController = navigation;
    [presenter presentViewController:navigation animated:YES completion:nil];
}

- (void)stopVoice {
    atomic_store(&WCAtlasVoiceActive, false);
    atomic_store(&WCAtlasVoiceFramePosition, 0);
    self.statusLabel.text = WCAtlasEnhancementEnabled(WCAtlasCallRealtimeVoiceEffectEnabledKey)
        ? [NSString stringWithFormat:@"实时变声：%@", WCAtlasVoiceEffectName(WCAtlasVoiceEffectPreset())]
        : @"语音包已停止";
}

- (void)voiceDidFinish {
    if (atomic_load(&WCAtlasVoiceActive)) return;
    self.statusLabel.text = WCAtlasEnhancementEnabled(WCAtlasCallRealtimeVoiceEffectEnabledKey)
        ? [NSString stringWithFormat:@"实时变声：%@", WCAtlasVoiceEffectName(WCAtlasVoiceEffectPreset())]
        : @"语音包已播完";
}

- (void)pickVoiceEffect {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    __weak typeof(self) weakSelf = self;
    WCAtlasPresentCallVoiceEffectPicker(presenter, ^{
        weakSelf.statusLabel.text = [NSString stringWithFormat:@"实时变声：%@",
            WCAtlasVoiceEffectName(WCAtlasVoiceEffectPreset())];
    });
}

- (void)presentFishTTSModelPicker {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    NSArray<NSDictionary<NSString *, NSString *> *> *models = @[
        @{@"id": @"s2.1-pro-free", @"name": @"S2.1 Pro 免费版"},
        @{@"id": @"s2.1-pro", @"name": @"S2.1 Pro 正式版"},
        @{@"id": @"s2-pro", @"name": @"S2 Pro 兼容版"}
    ];
    NSString *selected = WCAtlasFishAudioModel();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 Fish Audio 模型"
        message:@"免费版默认启用；正式版和兼容版会消耗账户额度。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *model in models) {
        NSString *identifier = model[@"id"];
        NSString *title = [identifier isEqualToString:selected]
            ? [@"✓  " stringByAppendingString:model[@"name"]] : model[@"name"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioModel(identifier);
                weakSelf.statusLabel.text = [NSString stringWithFormat:@"Fish TTS：%@", model[@"name"]];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)presentFishTTSSpeedPicker {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 Fish TTS 语速"
        message:@"支持 0.5x–2.0x；设置同时用于聊天和通话 TTS。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    double selected = WCAtlasFishAudioSpeechSpeed();
    __weak typeof(self) weakSelf = self;
    for (NSNumber *value in @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0]) {
        double speed = value.doubleValue;
        NSString *name = speed == 1.0 ? @"正常（1.0x）" : [NSString stringWithFormat:@"%.2gx", speed];
        NSString *title = fabs(selected - speed) < 0.001 ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioSpeechSpeed(speed);
                weakSelf.statusLabel.text = [NSString stringWithFormat:@"Fish TTS 语速：%.2gx", speed];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)presentFishTTSTonePicker {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 Fish TTS 语调"
        message:@"使用 Fish Audio S2 自然语言风格指令；实际效果会随音色变化。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *selected = WCAtlasFishAudioToneIdentifier();
    __weak typeof(self) weakSelf = self;
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioTonePresets()) {
        NSString *identifier = preset[@"identifier"];
        NSString *name = preset[@"name"];
        NSString *title = [identifier isEqualToString:selected] ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioToneIdentifier(identifier);
                weakSelf.statusLabel.text = [NSString stringWithFormat:@"Fish TTS 语调：%@", name];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static NSString *WCAtlasFishTTSVoicePresetName(NSString *referenceID) {
    if (referenceID.length == 0) return nil;
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        if ([preset[@"referenceID"] isEqualToString:referenceID]) return preset[@"name"];
    }
    return nil;
}

static NSString *WCAtlasFishTTSReferenceIDFromInput(NSString *input) {
    NSString *value = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length == 0) return @"";
    NSURLComponents *components = [NSURLComponents componentsWithString:value];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if ([item.name isEqualToString:@"modelId"] && item.value.length > 0) return item.value;
    }
    NSArray<NSString *> *pathComponents = components.URL.pathComponents;
    NSUInteger marker = [pathComponents indexOfObject:@"m"];
    if (marker != NSNotFound && marker + 1 < pathComponents.count) return pathComponents[marker + 1];
    return value;
}

- (void)presentFishTTSAddVoicePreset {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加 Fish Audio 音色"
        message:@"可粘贴音色 reference_id、包含 modelId 的完整链接，或 fish.audio/m/ 音色链接。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"预设名称";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"音色 ID 或完整链接";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加并使用" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            UIAlertController *inputAlert = weakAlert;
            NSString *name = inputAlert.textFields.firstObject.text ?: @"";
            NSString *input = inputAlert.textFields.count > 1 ? inputAlert.textFields[1].text : @"";
            NSString *referenceID = WCAtlasFishTTSReferenceIDFromInput(input);
            if (!WCAtlasAddFishAudioVoicePreset(name, referenceID)) {
                weakSelf.statusLabel.text = @"音色名称和 ID 不能为空";
                return;
            }
            WCAtlasSetFishAudioReferenceID(referenceID);
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"Fish TTS 音色：%@", name];
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)presentFishTTSDeleteVoicePresetPicker {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCAtlasFishAudioVoicePresets();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"删除音色预设"
        message:presets.count > 0 ? @"内置预设删除后也不会自动恢复。" : @"当前没有可删除的音色预设。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary<NSString *, NSString *> *preset in presets) {
        NSString *name = preset[@"name"];
        NSString *referenceID = preset[@"referenceID"];
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDestructive
            handler:^(__unused UIAlertAction *action) {
                WCAtlasRemoveFishAudioVoicePreset(referenceID);
                weakSelf.statusLabel.text = [NSString stringWithFormat:@"已删除音色预设：%@", name];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)presentFishTTSVoicePicker {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    NSString *selected = WCAtlasFishAudioReferenceID();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择 Fish Audio 音色"
        message:@"预设只保存音色 ID；生成时仍使用当前选择的基础模型。"
        preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    NSString *defaultTitle = selected.length == 0 ? @"✓  默认音色" : @"默认音色";
    [sheet addAction:[UIAlertAction actionWithTitle:defaultTitle style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            WCAtlasSetFishAudioReferenceID(nil);
            weakSelf.statusLabel.text = @"Fish TTS 音色：默认音色";
        }]];
    for (NSDictionary<NSString *, NSString *> *preset in WCAtlasFishAudioVoicePresets()) {
        NSString *name = preset[@"name"];
        NSString *referenceID = preset[@"referenceID"];
        NSString *title = [referenceID isEqualToString:selected]
            ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCAtlasSetFishAudioReferenceID(referenceID);
                weakSelf.statusLabel.text = [NSString stringWithFormat:@"Fish TTS 音色：%@", name];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"添加音色预设" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSAddVoicePreset]; });
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除音色预设" style:UIAlertActionStyleDestructive
        handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSDeleteVoicePresetPicker]; });
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"浏览官方音色库" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSURL *URL = [NSURL URLWithString:@"https://fish.audio/discovery/"];
            if (URL) [UIApplication.sharedApplication openURL:URL options:@{} completionHandler:nil];
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)presentFishTTSSettings {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window) return;
    BOOL hasKey = WCAtlasFishAudioAPIKey().length > 0;
    NSString *message = [NSString stringWithFormat:
        @"模型：%@\n语调：%@ · 语速：%.2gx\nAPI Key 只保存在本机 Keychain，不会进入配置导出。音色 ID 可从音色详情页网址 /m/ 后复制；留空使用默认音色。",
        WCAtlasFishAudioModel(), WCAtlasFishAudioToneName(), WCAtlasFishAudioSpeechSpeed()];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Fish Audio TTS 设置"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = hasKey ? @"API Key 已保存，留空保持不变" : @"粘贴 Fish Audio API Key";
        field.secureTextEntry = YES;
        field.textContentType = UITextContentTypePassword;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"音色 reference_id（可留空）";
        field.text = WCAtlasFishAudioReferenceID();
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    void (^saveValues)(BOOL) = ^(BOOL showResult) {
        UIAlertController *settingsAlert = weakAlert;
        NSString *key = settingsAlert.textFields.firstObject.text ?: @"";
        NSString *referenceID = settingsAlert.textFields.count > 1 ? settingsAlert.textFields[1].text : @"";
        NSError *keyError = nil;
        if (key.length > 0 && !WCAtlasSetFishAudioAPIKey(key, &keyError)) {
            weakSelf.statusLabel.text = keyError.localizedDescription ?: @"API Key 保存失败";
            return;
        }
        WCAtlasSetFishAudioReferenceID(referenceID);
        if (showResult) {
            weakSelf.statusLabel.text = WCAtlasFishAudioAPIKey().length > 0
                ? @"Fish Audio TTS 设置已保存" : @"请继续填写 Fish Audio API Key";
        }
    };
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"获取 Key" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSURL *URL = WCAtlasFishAudioAPIKeysURL();
            if (URL) [UIApplication.sharedApplication openURL:URL options:@{} completionHandler:nil];
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择音色" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            saveValues(NO);
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSVoicePicker]; });
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择模型" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            saveValues(NO);
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSModelPicker]; });
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择语调" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            saveValues(NO);
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSTonePicker]; });
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"选择语速" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            saveValues(NO);
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSSpeedPicker]; });
        }]];
    if (hasKey) {
        [alert addAction:[UIAlertAction actionWithTitle:@"删除 Key" style:UIAlertActionStyleDestructive
            handler:^(__unused UIAlertAction *action) {
                NSError *error = nil;
                WCAtlasSetFishAudioAPIKey(@"", &error);
                weakSelf.statusLabel.text = error.localizedDescription ?: @"Fish Audio API Key 已删除";
            }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { saveValues(YES); }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)pickTTS {
    UIViewController *presenter = self.hostController;
    if (!presenter.viewIfLoaded.window ||
        !WCAtlasEnhancementEnabled(WCAtlasCallVoiceDisguiseEnabledKey)) return;
    if (WCAtlasFishAudioAPIKey().length == 0) {
        [self presentFishTTSSettings];
        return;
    }
    NSString *referenceID = WCAtlasFishAudioReferenceID();
    NSString *voiceDescription = WCAtlasFishTTSVoicePresetName(referenceID) ?: (referenceID.length > 0 ? @"自定义音色" : @"默认音色");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"生成通话语音"
        message:[NSString stringWithFormat:@"Fish Audio · %@ · %@\n语调：%@ · 语速：%.2gx\n完成后自动保存到消息库并播放给对端。",
                 WCAtlasFishAudioModel(), voiceDescription, WCAtlasFishAudioToneName(),
                 WCAtlasFishAudioSpeechSpeed()]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"输入要说的话";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel
                                           handler:nil]];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakGenerationAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf presentFishTTSSettings]; });
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"生成并播放" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSString *text = weakGenerationAlert.textFields.firstObject.text ?: @"";
            weakSelf.statusLabel.text = @"正在请求 Fish Audio…";
            WCAtlasGenerateFishAudioSpeech(text, ^(NSURL *outputURL, NSError *generationError) {
                if (generationError || !outputURL) {
                    weakSelf.statusLabel.text = generationError.localizedDescription ?: @"TTS 生成失败";
                    return;
                }
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSError *storeError = nil;
                    NSString *titleText = [text stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    if (titleText.length > 24) {
                        NSRange range = [titleText rangeOfComposedCharacterSequencesForRange:
                            NSMakeRange(0, 24)];
                        titleText = [titleText substringWithRange:range];
                    }
                    NSString *displayText = titleText.length ? titleText : @"语音";
                    NSString *title = [@"TTS · " stringByAppendingString:displayText];
                    WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyStore.sharedStore
                        addMediaAtURL:outputURL type:WCAtlasQuickReplyTypeVoice title:title
                        folderIdentifier:nil sourceConversation:nil sourceMessageID:nil
                        error:&storeError];
                    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        WCAtlasCallAudioPanel *strongSelf = weakSelf;
                        if (!strongSelf) return;
                        if (!item) {
                            strongSelf.statusLabel.text = storeError.localizedDescription ?: @"TTS 保存失败";
                            return;
                        }
                        if (!atomic_load(&WCAtlasCallActive) || !strongSelf.controlView.window) {
                            strongSelf.statusLabel.text = @"TTS 已保存到消息库";
                            return;
                        }
                        [strongSelf loadVoiceItem:item];
                    });
                });
            });
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)loadVoiceItem:(WCAtlasQuickReplyItem *)item {
    NSString *sourcePath = [WCAtlasQuickReplyStore.sharedStore absoluteMediaPathForItem:item];
    if (sourcePath.length == 0) {
        self.statusLabel.text = @"语音包文件不存在";
        return;
    }
    self.statusLabel.text = @"正在准备语音包…";
    NSString *title = item.title.length ? item.title : @"语音素材";
    BOOL mightBeSilk = [item.metadata[@"voiceFormat"] unsignedIntegerValue] == 4 ||
        [@[@"aud", @"silk"] containsObject:sourcePath.pathExtension.lowercaseString];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSData *pcm = WCAtlasCallPCMDataAtPath(sourcePath, &error);
        NSString *temporaryPath = nil;
        if (!pcm.length && mightBeSilk) {
            NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WCAtlasCallVoice"];
            [NSFileManager.defaultManager createDirectoryAtPath:directory
                                    withIntermediateDirectories:YES attributes:nil error:nil];
            temporaryPath = [directory stringByAppendingPathComponent:
                [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"wav"]];
            if (WCAtlasSilkDecodeFileToWAV(sourcePath, temporaryPath, &error)) {
                pcm = WCAtlasCallPCMDataAtPath(temporaryPath, &error);
            }
        }
        if (temporaryPath.length) [NSFileManager.defaultManager removeItemAtPath:temporaryPath error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!atomic_load(&WCAtlasCallActive) || !self.controlView.window) return;
            if (!pcm.length) {
                self.statusLabel.text = error.localizedDescription ?: @"语音包解码失败";
                return;
            }
            void *copy = malloc(pcm.length);
            if (!copy) {
                self.statusLabel.text = @"语音包内存不足";
                return;
            }
            memcpy(copy, pcm.bytes, pcm.length);
            atomic_store(&WCAtlasVoiceByteCount, 0);
            void *old = (void *)atomic_exchange(&WCAtlasVoiceBytes, (uintptr_t)copy);
            atomic_store(&WCAtlasVoiceByteCount, pcm.length);
            atomic_store(&WCAtlasVoiceFramePosition, 0);
            atomic_store(&WCAtlasVoiceMode,
                [NSUserDefaults.standardUserDefaults integerForKey:WCAtlasCallVoiceModeKey] == 1 ? 1 : 0);
            atomic_store(&WCAtlasVoiceActive, true);
            if (old && WCAtlasRetiredVoiceBufferCount < 32) {
                WCAtlasRetiredVoiceBuffers[WCAtlasRetiredVoiceBufferCount++] = old;
            }
            [WCAtlasQuickReplyStore.sharedStore recordUsageForIdentifier:item.identifier error:nil];
            self.statusLabel.text = [NSString stringWithFormat:@"语音包：%@", title];
        });
    });
}

@end

void WCAtlasPresentCallVoiceEffectPicker(UIViewController *presenter,
                                       void (^completion)(void)) {
    if (!presenter) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            WCAtlasPresentCallVoiceEffectPicker(presenter, completion);
        });
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger selected = [defaults integerForKey:WCAtlasCallRealtimeVoiceEffectPresetKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"实时通话变声"
        message:@"效果直接处理本次通话的上行麦克风声音"
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger value = WCAtlasRealtimeVoiceEffectOff;
         value <= WCAtlasRealtimeVoiceEffectElectronic; value++) {
        WCAtlasRealtimeVoiceEffect effect = (WCAtlasRealtimeVoiceEffect)value;
        NSString *name = WCAtlasVoiceEffectName(effect);
        NSString *title = selected == value ? [@"✓  " stringByAppendingString:name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                [defaults setInteger:value forKey:WCAtlasCallRealtimeVoiceEffectPresetKey];
                BOOL enabled = [defaults boolForKey:WCAtlasCallRealtimeVoiceEffectEnabledKey];
                WCAtlasVoiceEffectSetPreset(enabled && atomic_load(&WCAtlasCallActive)
                    ? effect : WCAtlasRealtimeVoiceEffectOff);
                WCAtlasVoiceEffectReset();
                if (completion) completion();
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel
                                           handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = presenter.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void WCAtlasCallVoiceDidFinish(void) {
    [[WCAtlasCallAudioPanel sharedPanel] voiceDidFinish];
}

static void WCAtlasCallDidStart(void) {
    if (atomic_exchange(&WCAtlasCallActive, true)) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    WCAtlasRealtimeVoiceEffect effect = WCAtlasRealtimeVoiceEffectOff;
    if ([defaults boolForKey:WCAtlasCallRealtimeVoiceEffectEnabledKey]) {
        effect = (WCAtlasRealtimeVoiceEffect)[defaults integerForKey:WCAtlasCallRealtimeVoiceEffectPresetKey];
    }
    WCAtlasVoiceEffectSetPreset(effect);
    WCAtlasVoiceEffectReset();
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    WCAtlasCallSessionPrefix = [formatter stringFromDate:NSDate.date];
    WCAtlasCallSessionDisplayName = nil;
    WCAtlasMicRecordingPath = nil;
    WCAtlasPeerRecordingPath = nil;
    atomic_fetch_add(&WCAtlasAudioActivityGeneration, 1);
    atomic_store(&WCAtlasCallRecording, WCAtlasEnhancementEnabled(WCAtlasCallRecordingEnabledKey));
    for (NSNumber *delay in @[@0.0, @0.25, @0.75, @1.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (atomic_load(&WCAtlasCallActive)) [[WCAtlasCallAudioPanel sharedPanel] show];
        });
    }
    WCAtlasLog(@"通话音频会话开始");
}

void WCAtlasCallAudioNotifyAudioDeviceStarted(void) {
    if (NSThread.isMainThread) {
        WCAtlasCallDidStart();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ WCAtlasCallDidStart(); });
    }
}

static void WCAtlasFinalizeCurrentRecording(void) {
    BOOL wasRecording = atomic_exchange(&WCAtlasCallRecording, false);
    NSString *sessionPrefix = WCAtlasCallSessionPrefix;
    NSString *displayName = WCAtlasCallSessionDisplayName;
    NSString *micRecordingPath = WCAtlasMicRecordingPath;
    NSString *peerRecordingPath = WCAtlasPeerRecordingPath;
    WCAtlasCallSessionPrefix = nil;
    WCAtlasCallSessionDisplayName = nil;
    WCAtlasMicRecordingPath = nil;
    WCAtlasPeerRecordingPath = nil;
    if (!wasRecording && micRecordingPath.length == 0 && peerRecordingPath.length == 0) return;
    if (sessionPrefix.length > 0 && (micRecordingPath.length > 0 || peerRecordingPath.length > 0)) {
        NSDictionary *metadata = @{ @"name": displayName.length ? displayName : @"通话录音",
                                    @"timestamp": @((long long)NSDate.date.timeIntervalSince1970) };
        NSData *metadataData = [NSJSONSerialization dataWithJSONObject:metadata options:0 error:nil];
        NSURL *metadataURL = [WCAtlasCallRecordDirectory() URLByAppendingPathComponent:
            [sessionPrefix stringByAppendingPathExtension:@"json"]];
        [metadataData writeToURL:metadataURL atomically:YES];
    }
    dispatch_async(WCAtlasCallFileQueue, ^{
        os_unfair_lock_lock(&WCAtlasMicWriterLock);
        WCAtlasCloseWriter(&WCAtlasMicWriter);
        os_unfair_lock_unlock(&WCAtlasMicWriterLock);
        os_unfair_lock_lock(&WCAtlasPeerWriterLock);
        WCAtlasCloseWriter(&WCAtlasPeerWriter);
        os_unfair_lock_unlock(&WCAtlasPeerWriterLock);
        WCAtlasExportMixedRecording(micRecordingPath, peerRecordingPath, sessionPrefix);
    });
    WCAtlasLog(@"本次通话录音已结束，自动录音总开关保持不变");
}

static void WCAtlasCallDidStop(void) {
    if (!atomic_exchange(&WCAtlasCallActive, false)) return;
    WCAtlasVoiceEffectSetPreset(WCAtlasRealtimeVoiceEffectOff);
    WCAtlasVoiceEffectReset();
    atomic_store(&WCAtlasVoiceActive, false);
    atomic_store(&WCAtlasVoiceByteCount, 0);
    void *voiceBytes = (void *)atomic_exchange(&WCAtlasVoiceBytes, 0);
    WCAtlasFinalizeCurrentRecording();
    dispatch_async(dispatch_get_main_queue(), ^{ [[WCAtlasCallAudioPanel sharedPanel] hide]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (voiceBytes) free(voiceBytes);
        for (NSUInteger index = 0; index < WCAtlasRetiredVoiceBufferCount; index++) {
            free(WCAtlasRetiredVoiceBuffers[index]);
            WCAtlasRetiredVoiceBuffers[index] = NULL;
        }
        WCAtlasRetiredVoiceBufferCount = 0;
    });
    WCAtlasLog(@"通话音频会话结束，录音目录=%@", WCAtlasCallRecordDirectory().path);
}

typedef uintptr_t (*WCAtlasVoIPNoArgumentIMP)(id, SEL);
typedef uintptr_t (*WCAtlasVoIPOneArgumentIMP)(id, SEL, id);
typedef uintptr_t (*WCAtlasVoIPTwoArgumentIMP)(id, SEL, id, id);
static WCAtlasVoIPNoArgumentIMP WCAtlasOriginalStartNoArguments;
static WCAtlasVoIPNoArgumentIMP WCAtlasOriginalStartMuTalk;
static WCAtlasVoIPNoArgumentIMP WCAtlasOriginalStartRecovery;
static WCAtlasVoIPOneArgumentIMP WCAtlasOriginalStartOneArgument;
static WCAtlasVoIPTwoArgumentIMP WCAtlasOriginalStartTwoArguments;
static WCAtlasVoIPNoArgumentIMP WCAtlasOriginalStop;
static void (*WCAtlasOriginalStopVoid)(id, SEL);

static uintptr_t WCAtlasStartNoArguments(id self, SEL selector) {
    uintptr_t result = WCAtlasOriginalStartNoArguments ? WCAtlasOriginalStartNoArguments(self, selector) : 0;
    if (result != 0) WCAtlasCallDidStart();
    return result;
}

static uintptr_t WCAtlasStartMuTalk(id self, SEL selector) {
    uintptr_t result = WCAtlasOriginalStartMuTalk ? WCAtlasOriginalStartMuTalk(self, selector) : 0;
    if (result != 0) WCAtlasCallDidStart();
    return result;
}

static uintptr_t WCAtlasStartRecovery(id self, SEL selector) {
    uintptr_t result = WCAtlasOriginalStartRecovery ? WCAtlasOriginalStartRecovery(self, selector) : 0;
    if (result != 0) WCAtlasCallDidStart();
    return result;
}

static uintptr_t WCAtlasStartOneArgument(id self, SEL selector, id value) {
    uintptr_t result = WCAtlasOriginalStartOneArgument ? WCAtlasOriginalStartOneArgument(self, selector, value) : 0;
    if (result != 0) WCAtlasCallDidStart();
    return result;
}

static uintptr_t WCAtlasStartTwoArguments(id self, SEL selector, id first, id second) {
    uintptr_t result = WCAtlasOriginalStartTwoArguments ? WCAtlasOriginalStartTwoArguments(self, selector, first, second) : 0;
    if (result != 0) WCAtlasCallDidStart();
    return result;
}

static uintptr_t WCAtlasStop(id self, SEL selector) {
    uintptr_t result = WCAtlasOriginalStop ? WCAtlasOriginalStop(self, selector) : 0;
    WCAtlasCallDidStop();
    return result;
}

static void WCAtlasStopVoid(id self, SEL selector) {
    if (WCAtlasOriginalStopVoid) WCAtlasOriginalStopVoid(self, selector);
    WCAtlasCallDidStop();
}

static void WCAtlasInstallLifecycleHook(Class cls, NSString *name, IMP replacement, IMP *original,
                                      unsigned int argumentCount) {
    SEL selector = NSSelectorFromString(name);
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != argumentCount || *original) return;
    char *returnType = method_copyReturnType(method);
    const char *returnCursor = returnType ?: "";
    while (*returnCursor && strchr("rnNoORV", *returnCursor)) returnCursor++;
    BOOL stopMethod = [name isEqualToString:@"StopForVoIP"];
    BOOL supportedReturn = returnCursor[0] == '@' || strchr("cCsSiIlLqQB", returnCursor[0]) ||
        (stopMethod && returnCursor[0] == 'v');
    BOOL supportedArguments = YES;
    for (unsigned int index = 2; index < argumentCount; index++) {
        char *argumentType = method_copyArgumentType(method, index);
        const char *argumentCursor = argumentType ?: "";
        while (*argumentCursor && strchr("rnNoORV", *argumentCursor)) argumentCursor++;
        supportedArguments = supportedArguments && argumentCursor[0] == '@';
        if (argumentType) free(argumentType);
    }
    if (!supportedReturn || !supportedArguments) {
        WCAtlasLog(@"通话音频 Hook ABI 不匹配：%@ return=%s args=%u",
                 name, returnCursor, method_getNumberOfArguments(method));
        if (returnType) free(returnType);
        return;
    }
    if (stopMethod && returnCursor[0] == 'v') {
        IMP stopOriginal = NULL;
        MSHookMessageEx(cls, selector, (IMP)WCAtlasStopVoid, &stopOriginal);
        WCAtlasOriginalStopVoid = (void (*)(id, SEL))stopOriginal;
        if (returnType) free(returnType);
        WCAtlasLog(@"通话音频 Hook 已安装：%@ original=%p return=void", name, stopOriginal);
        return;
    }
    if (returnType) free(returnType);
    MSHookMessageEx(cls, selector, replacement, original);
    WCAtlasLog(@"通话音频 Hook 已安装：%@ original=%p", name, *original);
}

void WCAtlasCallAudioInstallHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WCAtlasCallFileQueue = dispatch_queue_create("com.qiu7c.wcatlas.call-audio-files", DISPATCH_QUEUE_SERIAL);
        MSHookFunction((void *)AudioUnitRender, (void *)WCAtlasAudioUnitRender,
                       (void **)&WCAtlasOriginalAudioUnitRender);
        MSHookFunction((void *)AudioUnitSetProperty, (void *)WCAtlasAudioUnitSetProperty,
                       (void **)&WCAtlasOriginalAudioUnitSetProperty);
        MSHookFunction((void *)AudioComponentInstanceDispose,
                       (void *)WCAtlasAudioComponentInstanceDispose,
                       (void **)&WCAtlasOriginalAudioComponentInstanceDispose);
        Class cls = NSClassFromString(@"AUAudioDevice");
        WCAtlasInstallLifecycleHook(cls, @"StartRecordAndPlayForVoIPWithRoomID:roomKey:",
                                 (IMP)WCAtlasStartTwoArguments, (IMP *)&WCAtlasOriginalStartTwoArguments, 4);
        WCAtlasInstallLifecycleHook(cls, @"StartRecordAndPlayForVoIP", (IMP)WCAtlasStartNoArguments,
                                 (IMP *)&WCAtlasOriginalStartNoArguments, 2);
        WCAtlasInstallLifecycleHook(cls, @"StartRecordAndPlayForIlink:", (IMP)WCAtlasStartOneArgument,
                                 (IMP *)&WCAtlasOriginalStartOneArgument, 3);
        WCAtlasInstallLifecycleHook(cls, @"StartRecordAndPlayForMuTalk", (IMP)WCAtlasStartMuTalk,
                                 (IMP *)&WCAtlasOriginalStartMuTalk, 2);
        WCAtlasInstallLifecycleHook(cls, @"StartRecordAndPlayForVoIPInterruptionRecovery",
                                 (IMP)WCAtlasStartRecovery,
                                 (IMP *)&WCAtlasOriginalStartRecovery, 2);
        WCAtlasInstallLifecycleHook(cls, @"StopForVoIP", (IMP)WCAtlasStop,
                                 (IMP *)&WCAtlasOriginalStop, 2);
        WCAtlasLog(@"通话音频 Hook 安装：AUAudioDevice=%@ render=%p setProperty=%p",
                 cls, WCAtlasOriginalAudioUnitRender, WCAtlasOriginalAudioUnitSetProperty);
    });
}
