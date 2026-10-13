#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCAtlasRealtimeVoiceEffect) {
    WCAtlasRealtimeVoiceEffectOff = 0,
    WCAtlasRealtimeVoiceEffectBright = 1,
    WCAtlasRealtimeVoiceEffectDeep = 2,
    WCAtlasRealtimeVoiceEffectRobot = 3,
    WCAtlasRealtimeVoiceEffectElectronic = 4,
};

/// Atomically selects the effect used by subsequent microphone callbacks.
FOUNDATION_EXPORT void WCAtlasVoiceEffectSetPreset(WCAtlasRealtimeVoiceEffect effect);

/// Returns the currently active real-time effect.
FOUNDATION_EXPORT WCAtlasRealtimeVoiceEffect WCAtlasVoiceEffectPreset(void);

/// Returns the localized display name for an effect.
FOUNDATION_EXPORT NSString *WCAtlasVoiceEffectName(WCAtlasRealtimeVoiceEffect effect);

/// Processes one writable microphone PCM buffer in place.
/// Supports interleaved/non-interleaved signed 16-bit and float32 linear PCM.
/// The audio callback may call this function directly: it performs no allocation,
/// locking, Objective-C messaging, file access, or settings reads while enabled.
FOUNDATION_EXPORT void WCAtlasVoiceEffectProcess(AudioStreamBasicDescription format,
                                               UInt32 frames,
                                               AudioBufferList * _Nullable buffers);

/// Clears delay lines and oscillator state at call boundaries.
FOUNDATION_EXPORT void WCAtlasVoiceEffectReset(void);

NS_ASSUME_NONNULL_END
