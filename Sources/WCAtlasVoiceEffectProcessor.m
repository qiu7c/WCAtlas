#import "WCAtlasVoiceEffectProcessor.h"
#import <math.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <string.h>

#define WCATLAS_EFFECT_MAX_CHANNELS 8
#define WCATLAS_EFFECT_DELAY_SIZE 8192
#define WCATLAS_EFFECT_TWO_PI 6.28318530717958647692

typedef struct {
    float delay[WCATLAS_EFFECT_DELAY_SIZE];
    uint32_t writeIndex;
    float grainPhase;
    float robotPhase;
} WCAtlasVoiceEffectChannelState;

static _Atomic(int) WCAtlasVoiceEffectCurrentPreset;
static _Atomic(unsigned int) WCAtlasVoiceEffectResetGeneration;
static WCAtlasVoiceEffectChannelState WCAtlasVoiceEffectStates[WCATLAS_EFFECT_MAX_CHANNELS];
static unsigned int WCAtlasVoiceEffectAppliedGeneration;
static int WCAtlasVoiceEffectAppliedPreset;
static double WCAtlasVoiceEffectAppliedSampleRate;

void WCAtlasVoiceEffectSetPreset(WCAtlasRealtimeVoiceEffect effect) {
    int resolved = MIN((int)WCAtlasRealtimeVoiceEffectElectronic,
                       MAX((int)WCAtlasRealtimeVoiceEffectOff, (int)effect));
    int previous = atomic_exchange(&WCAtlasVoiceEffectCurrentPreset, resolved);
    if (previous != resolved) atomic_fetch_add(&WCAtlasVoiceEffectResetGeneration, 1);
}

WCAtlasRealtimeVoiceEffect WCAtlasVoiceEffectPreset(void) {
    return (WCAtlasRealtimeVoiceEffect)atomic_load(&WCAtlasVoiceEffectCurrentPreset);
}

NSString *WCAtlasVoiceEffectName(WCAtlasRealtimeVoiceEffect effect) {
    switch (effect) {
        case WCAtlasRealtimeVoiceEffectBright: return @"明亮女声";
        case WCAtlasRealtimeVoiceEffectDeep: return @"低沉男声";
        case WCAtlasRealtimeVoiceEffectRobot: return @"机器人";
        case WCAtlasRealtimeVoiceEffectElectronic: return @"电音";
        default: return @"原声";
    }
}

void WCAtlasVoiceEffectReset(void) {
    atomic_fetch_add(&WCAtlasVoiceEffectResetGeneration, 1);
}

static inline float WCAtlasVoiceEffectClamp(float value) {
    return fmaxf(-1.0f, fminf(1.0f, value));
}

static inline float WCAtlasVoiceEffectReadDelay(WCAtlasVoiceEffectChannelState *state,
                                               float delaySamples) {
    float position = (float)state->writeIndex - delaySamples;
    while (position < 0.0f) position += WCATLAS_EFFECT_DELAY_SIZE;
    while (position >= WCATLAS_EFFECT_DELAY_SIZE) position -= WCATLAS_EFFECT_DELAY_SIZE;
    uint32_t first = (uint32_t)position;
    uint32_t second = (first + 1) % WCATLAS_EFFECT_DELAY_SIZE;
    float fraction = position - (float)first;
    return state->delay[first] + (state->delay[second] - state->delay[first]) * fraction;
}

static inline float WCAtlasVoiceEffectTriangle(float phase) {
    return phase < 0.5f ? phase * 2.0f : (1.0f - phase) * 2.0f;
}

static inline float WCAtlasVoiceEffectPitchSample(WCAtlasVoiceEffectChannelState *state,
                                                 float input,
                                                 float ratio,
                                                 float sampleRate) {
    state->delay[state->writeIndex] = input;
    float window = fminf(3000.0f, fmaxf(640.0f, sampleRate * 0.035f));
    float phase1 = state->grainPhase;
    float phase2 = phase1 + 0.5f;
    if (phase2 >= 1.0f) phase2 -= 1.0f;
    bool pitchUp = ratio > 1.0f;
    float delay1 = 48.0f + (pitchUp ? (1.0f - phase1) : phase1) * window;
    float delay2 = 48.0f + (pitchUp ? (1.0f - phase2) : phase2) * window;
    float weight1 = WCAtlasVoiceEffectTriangle(phase1);
    float weight2 = WCAtlasVoiceEffectTriangle(phase2);
    float shifted = WCAtlasVoiceEffectReadDelay(state, delay1) * weight1 +
                    WCAtlasVoiceEffectReadDelay(state, delay2) * weight2;
    state->writeIndex = (state->writeIndex + 1) % WCATLAS_EFFECT_DELAY_SIZE;
    state->grainPhase += fabsf(ratio - 1.0f) / window;
    if (state->grainPhase >= 1.0f) state->grainPhase -= floorf(state->grainPhase);
    return WCAtlasVoiceEffectClamp(shifted * 0.92f + input * 0.08f);
}

static inline float WCAtlasVoiceEffectSample(WCAtlasVoiceEffectChannelState *state,
                                            float input,
                                            WCAtlasRealtimeVoiceEffect effect,
                                            float sampleRate) {
    switch (effect) {
        case WCAtlasRealtimeVoiceEffectBright:
            return WCAtlasVoiceEffectPitchSample(state, input, 1.259921f, sampleRate);
        case WCAtlasRealtimeVoiceEffectDeep:
            return WCAtlasVoiceEffectPitchSample(state, input, 0.793701f, sampleRate);
        case WCAtlasRealtimeVoiceEffectRobot: {
            float carrier = sinf(state->robotPhase);
            state->robotPhase += (float)(WCATLAS_EFFECT_TWO_PI * 72.0 / sampleRate);
            if (state->robotPhase >= (float)WCATLAS_EFFECT_TWO_PI) {
                state->robotPhase -= (float)WCATLAS_EFFECT_TWO_PI;
            }
            return WCAtlasVoiceEffectClamp(input * (0.18f + carrier * 0.82f));
        }
        case WCAtlasRealtimeVoiceEffectElectronic: {
            float carrier = sinf(state->robotPhase);
            state->robotPhase += (float)(WCATLAS_EFFECT_TWO_PI * 36.0 / sampleRate);
            if (state->robotPhase >= (float)WCATLAS_EFFECT_TWO_PI) {
                state->robotPhase -= (float)WCATLAS_EFFECT_TWO_PI;
            }
            float quantized = roundf(input * 28.0f) / 28.0f;
            return WCAtlasVoiceEffectClamp(quantized * (0.72f + carrier * 0.28f));
        }
        default:
            return input;
    }
}

void WCAtlasVoiceEffectProcess(AudioStreamBasicDescription format,
                             UInt32 frames,
                             AudioBufferList *buffers) {
    WCAtlasRealtimeVoiceEffect effect = WCAtlasVoiceEffectPreset();
    if (effect == WCAtlasRealtimeVoiceEffectOff || !buffers || frames == 0 ||
        format.mFormatID != kAudioFormatLinearPCM || format.mChannelsPerFrame == 0) return;
    bool float32 = (format.mFormatFlags & kAudioFormatFlagIsFloat) && format.mBitsPerChannel == 32;
    bool int16 = !(format.mFormatFlags & kAudioFormatFlagIsFloat) && format.mBitsPerChannel == 16;
    if (!float32 && !int16) return;

    double sampleRate = format.mSampleRate > 1000.0 ? format.mSampleRate : 48000.0;
    unsigned int generation = atomic_load(&WCAtlasVoiceEffectResetGeneration);
    if (generation != WCAtlasVoiceEffectAppliedGeneration ||
        WCAtlasVoiceEffectAppliedPreset != effect ||
        fabs(WCAtlasVoiceEffectAppliedSampleRate - sampleRate) > 1.0) {
        memset(WCAtlasVoiceEffectStates, 0, sizeof(WCAtlasVoiceEffectStates));
        WCAtlasVoiceEffectAppliedGeneration = generation;
        WCAtlasVoiceEffectAppliedPreset = effect;
        WCAtlasVoiceEffectAppliedSampleRate = sampleRate;
    }

    bool nonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 formatChannels = MAX((UInt32)1, format.mChannelsPerFrame);
    for (UInt32 bufferIndex = 0; bufferIndex < buffers->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &buffers->mBuffers[bufferIndex];
        UInt32 bufferChannels = buffer->mNumberChannels > 0 ? buffer->mNumberChannels : formatChannels;
        UInt32 channels = nonInterleaved ? 1 : MAX((UInt32)1, bufferChannels);
        UInt32 availableFrames = int16
            ? buffer->mDataByteSize / (sizeof(SInt16) * channels)
            : buffer->mDataByteSize / (sizeof(float) * channels);
        UInt32 processFrames = MIN(frames, availableFrames);
        if (!buffer->mData) continue;
        for (UInt32 frame = 0; frame < processFrames; frame++) {
            for (UInt32 channel = 0; channel < channels; channel++) {
                UInt32 stateIndex = nonInterleaved ? bufferIndex : channel;
                if (stateIndex >= WCATLAS_EFFECT_MAX_CHANNELS) continue;
                UInt32 index = frame * channels + channel;
                float input = int16 ? ((SInt16 *)buffer->mData)[index] / 32768.0f
                                    : ((float *)buffer->mData)[index];
                float output = WCAtlasVoiceEffectSample(&WCAtlasVoiceEffectStates[stateIndex], input,
                                                       effect, (float)sampleRate);
                if (int16) ((SInt16 *)buffer->mData)[index] = (SInt16)lrintf(output * 32767.0f);
                else ((float *)buffer->mData)[index] = output;
            }
        }
    }
}
