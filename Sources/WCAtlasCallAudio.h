#import <Foundation/Foundation.h>

@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

/// Installs the guarded WeChat VoIP lifecycle hooks and AudioUnit PCM adapters.
/// Safe to call repeatedly; unsupported WeChat methods or AudioUnit symbols are skipped.
FOUNDATION_EXPORT void WCAtlasCallAudioInstallHooks(void);

/// Marks the WeChat audio device as started after `VoipUIManager`
/// `audioDeviceStartedSuccess:` has invoked its original implementation.
/// Must be called on the main thread; repeated notifications are idempotent.
FOUNDATION_EXPORT void WCAtlasCallAudioNotifyAudioDeviceStarted(void);

/// Presents the real-time microphone effect selector and applies changes to an active call.
/// Must be called on the main thread. Selection is persisted for future calls.
FOUNDATION_EXPORT void WCAtlasPresentCallVoiceEffectPicker(UIViewController *presenter,
                                                         void (^ _Nullable completion)(void));

NS_ASSUME_NONNULL_END
