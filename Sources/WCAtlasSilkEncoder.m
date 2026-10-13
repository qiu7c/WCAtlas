#import "WCAtlasSilkEncoder.h"
#import <AVFoundation/AVFoundation.h>
#include "SKP_Silk_SDK_API.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static NSString *const WCAtlasSilkEncoderErrorDomain = @"com.qiu7c.wcatlas.silk-encoder";

enum {
    WCAtlasSilkInputSampleRate = 16000,
    WCAtlasSilkFrameSamples = 320,
    WCAtlasSilkMaximumPacketBytes = 4096,
};

typedef NS_ENUM(NSInteger, WCAtlasSilkEncoderErrorCode) {
    WCAtlasSilkEncoderErrorInvalidPath = 1,
    WCAtlasSilkEncoderErrorUnreadableMedia,
    WCAtlasSilkEncoderErrorNoAudioTrack,
    WCAtlasSilkEncoderErrorReaderFailure,
    WCAtlasSilkEncoderErrorSDKFailure,
    WCAtlasSilkEncoderErrorWriteFailure,
};

static void WCAtlasSilkEncoderSetError(NSError **error, WCAtlasSilkEncoderErrorCode code, NSString *message) {
    if (error) {
        *error = [NSError errorWithDomain:WCAtlasSilkEncoderErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message ?: @"Silk 编码失败"}];
    }
}

static BOOL WCAtlasSilkWritePacket(FILE *output, const uint8_t *bytes, int16_t length) {
    uint8_t size[2] = {(uint8_t)(length & 0xff), (uint8_t)((length >> 8) & 0xff)};
    return fwrite(size, 1, sizeof(size), output) == sizeof(size) &&
           fwrite(bytes, 1, (size_t)length, output) == (size_t)length;
}

static BOOL WCAtlasSilkEncodeFrame(void *encoder,
                                 const SKP_SILK_SDK_EncControlStruct *control,
                                 const int16_t *samples,
                                 FILE *output,
                                 NSError **error) {
    uint8_t packet[WCAtlasSilkMaximumPacketBytes] = {0};
    int16_t packetLength = (int16_t)sizeof(packet);
    int result = SKP_Silk_SDK_Encode(encoder, control, samples, WCAtlasSilkFrameSamples,
                                     packet, &packetLength);
    if (result != 0 || packetLength <= 0 || packetLength > WCAtlasSilkMaximumPacketBytes) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorSDKFailure, @"Silk 音频帧编码失败");
        return NO;
    }
    if (!WCAtlasSilkWritePacket(output, packet, packetLength)) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorWriteFailure, @"写入 Silk 音频失败");
        return NO;
    }
    return YES;
}

BOOL WCAtlasEncodeAudioFileToSilk(NSString *sourcePath,
                                NSString *destinationPath,
                                NSUInteger *durationMilliseconds,
                                NSError **error) {
    if (durationMilliseconds) *durationMilliseconds = 0;
    if (sourcePath.length == 0 || destinationPath.length == 0) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorInvalidPath, @"音频文件路径无效");
        return NO;
    }

    NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count == 0) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorNoAudioTrack, @"媒体文件不包含可用音轨");
        return NO;
    }

    NSError *readerError = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&readerError];
    if (!reader) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorUnreadableMedia,
                                 readerError.localizedDescription ?: @"无法读取媒体文件");
        return NO;
    }
    NSDictionary *outputSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(WCAtlasSilkInputSampleRate),
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsNonInterleaved: @NO,
    };
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc]
                                               initWithTrack:audioTracks.firstObject
                                               outputSettings:outputSettings];
    readerOutput.alwaysCopiesSampleData = NO;
    if (![reader canAddOutput:readerOutput]) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorReaderFailure, @"无法创建音频转换通道");
        return NO;
    }
    [reader addOutput:readerOutput];

    FILE *output = fopen(destinationPath.fileSystemRepresentation, "wb");
    void *encoder = NULL;
    BOOL success = NO;
    int32_t encoderSize = 0;
    SKP_SILK_SDK_EncControlStruct control;
    NSMutableData *pendingPCM = nil;
    NSUInteger consumedBytes = 0;
    uint64_t totalSamples = 0;
    const NSUInteger frameBytes = WCAtlasSilkFrameSamples * sizeof(int16_t);
    memset(&control, 0, sizeof(control));
    if (!output) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorWriteFailure, @"无法创建临时语音文件");
        return NO;
    }
    static const uint8_t silkHeader[] = {0x02, '#', '!', 'S', 'I', 'L', 'K', '_', 'V', '3'};
    if (fwrite(silkHeader, 1, sizeof(silkHeader), output) != sizeof(silkHeader)) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorWriteFailure, @"无法写入 Silk 文件头");
        goto cleanup;
    }

    if (SKP_Silk_SDK_Get_Encoder_Size(&encoderSize) != 0 || encoderSize <= 0) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorSDKFailure, @"无法初始化 Silk 编码器");
        goto cleanup;
    }
    encoder = calloc(1, (size_t)encoderSize);
    if (!encoder || SKP_Silk_SDK_InitEncoder(encoder, &control) != 0) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorSDKFailure, @"无法初始化 Silk 编码器");
        goto cleanup;
    }
    control.API_sampleRate = WCAtlasSilkInputSampleRate;
    control.maxInternalSampleRate = WCAtlasSilkInputSampleRate;
    control.packetSize = WCAtlasSilkFrameSamples;
    control.bitRate = 20000;
    control.packetLossPercentage = 0;
    control.complexity = 2;
    control.useInBandFEC = 0;
    control.useDTX = 0;

    if (![reader startReading]) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorReaderFailure,
                                 reader.error.localizedDescription ?: @"无法开始读取音轨");
        goto cleanup;
    }

    pendingPCM = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBuffer = [readerOutput copyNextSampleBuffer];
        if (!sampleBuffer) break;
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t dataLength = blockBuffer ? CMBlockBufferGetDataLength(blockBuffer) : 0;
        if (dataLength > 0) {
            NSUInteger oldLength = pendingPCM.length;
            [pendingPCM increaseLengthBy:dataLength];
            OSStatus copyStatus = CMBlockBufferCopyDataBytes(blockBuffer, 0, dataLength,
                                                              (uint8_t *)pendingPCM.mutableBytes + oldLength);
            if (copyStatus != kCMBlockBufferNoErr) {
                CFRelease(sampleBuffer);
                WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorReaderFailure, @"读取音频采样失败");
                goto cleanup;
            }
        }
        CFRelease(sampleBuffer);

        while (pendingPCM.length - consumedBytes >= frameBytes) {
            const int16_t *samples = (const int16_t *)((const uint8_t *)pendingPCM.bytes + consumedBytes);
            if (!WCAtlasSilkEncodeFrame(encoder, &control, samples, output, error)) goto cleanup;
            consumedBytes += frameBytes;
            totalSamples += WCAtlasSilkFrameSamples;
        }
        if (consumedBytes >= 65536) {
            NSData *remainder = [pendingPCM subdataWithRange:NSMakeRange(consumedBytes,
                                                                         pendingPCM.length - consumedBytes)];
            pendingPCM = [remainder mutableCopy];
            consumedBytes = 0;
        }
    }
    if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusCancelled) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorReaderFailure,
                                 reader.error.localizedDescription ?: @"音轨读取失败");
        goto cleanup;
    }

    NSUInteger remainingBytes = pendingPCM.length - consumedBytes;
    if (remainingBytes > 0) {
        int16_t finalFrame[WCAtlasSilkFrameSamples] = {0};
        memcpy(finalFrame, (const uint8_t *)pendingPCM.bytes + consumedBytes, remainingBytes);
        if (!WCAtlasSilkEncodeFrame(encoder, &control, finalFrame, output, error)) goto cleanup;
        totalSamples += remainingBytes / sizeof(int16_t);
    }
    if (totalSamples == 0 || fflush(output) != 0) {
        WCAtlasSilkEncoderSetError(error, WCAtlasSilkEncoderErrorWriteFailure, @"媒体文件没有可编码的音频数据");
        goto cleanup;
    }
    if (durationMilliseconds) {
        *durationMilliseconds = MAX((NSUInteger)1,
                                    (NSUInteger)llround((double)totalSamples * 1000.0 /
                                                        WCAtlasSilkInputSampleRate));
    }
    success = YES;

cleanup:
    if (reader.status == AVAssetReaderStatusReading) [reader cancelReading];
    if (encoder) free(encoder);
    fclose(output);
    if (!success) [NSFileManager.defaultManager removeItemAtPath:destinationPath error:nil];
    return success;
}
