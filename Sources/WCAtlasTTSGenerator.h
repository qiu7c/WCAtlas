#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Fish Audio API-key registration and management page.
FOUNDATION_EXPORT NSURL *WCAtlasFishAudioAPIKeysURL(void);

/// Returns the Fish Audio API key stored in the current WeChat Keychain.
/// The value is never written to NSUserDefaults or included in WCAtlas configuration exports.
FOUNDATION_EXPORT NSString * _Nullable WCAtlasFishAudioAPIKey(void);

/// Saves or removes the Fish Audio API key in the current WeChat Keychain.
/// @param APIKey Nonempty key to save, or an empty string to remove it.
/// @param error Receives a Security.framework error when the Keychain operation fails.
FOUNDATION_EXPORT BOOL WCAtlasSetFishAudioAPIKey(NSString * _Nullable APIKey,
                                                NSError * _Nullable * _Nullable error);

/// Returns the selected Fish Audio engine identifier. Defaults to `s2.1-pro-free`.
FOUNDATION_EXPORT NSString *WCAtlasFishAudioModel(void);

/// Saves one of the supported engine identifiers: `s2.1-pro-free`, `s2.1-pro`, or `s2-pro`.
/// Unsupported values fall back to `s2.1-pro-free`.
FOUNDATION_EXPORT void WCAtlasSetFishAudioModel(NSString * _Nullable model);

/// Returns the optional Fish Audio voice `reference_id`. An empty value uses Fish Audio's default voice.
FOUNDATION_EXPORT NSString *WCAtlasFishAudioReferenceID(void);

/// Saves the optional Fish Audio voice `reference_id` in WCAtlas preferences.
FOUNDATION_EXPORT void WCAtlasSetFishAudioReferenceID(NSString * _Nullable referenceID);

/// Returns the shared Fish Audio speech-speed multiplier. The supported range is 0.5 through 2.0
/// and the default is 1.0.
FOUNDATION_EXPORT double WCAtlasFishAudioSpeechSpeed(void);

/// Saves the shared Fish Audio speech-speed multiplier after clamping it to 0.5 through 2.0.
FOUNDATION_EXPORT void WCAtlasSetFishAudioSpeechSpeed(double speed);

/// Returns the selectable S2 tone presets. Each dictionary contains `identifier`, `name`, and the
/// optional Fish Audio natural-language `instruction` prepended to generated text.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasFishAudioTonePresets(void);

/// Returns the selected tone-preset identifier. Defaults to `natural`.
FOUNDATION_EXPORT NSString *WCAtlasFishAudioToneIdentifier(void);

/// Returns the localized display name of the selected tone preset.
FOUNDATION_EXPORT NSString *WCAtlasFishAudioToneName(void);

/// Saves a supported tone-preset identifier; unsupported values fall back to `natural`.
FOUNDATION_EXPORT void WCAtlasSetFishAudioToneIdentifier(NSString * _Nullable identifier);

/// Returns the editable Fish Audio voice presets as dictionaries containing `name` and
/// `referenceID`. On first use, WCAtlas seeds its bundled presets; subsequent user deletions persist.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasFishAudioVoicePresets(void);

/// Adds or replaces a voice preset after trimming its display name and `reference_id`.
/// @return NO when either value is empty; otherwise YES after persisting the normalized preset.
FOUNDATION_EXPORT BOOL WCAtlasAddFishAudioVoicePreset(NSString *name, NSString *referenceID);

/// Removes every saved voice preset matching the exact `reference_id`.
FOUNDATION_EXPORT void WCAtlasRemoveFishAudioVoicePreset(NSString *referenceID);

/// Generates speech through Fish Audio and writes the returned MP3 to a temporary file.
/// The completion block always runs on the main thread. The caller owns removal of a successful
/// output URL after copying or consuming it. Authentication, HTTP, API, malformed-response, and
/// local-file failures are returned as NSError values; no system speech synthesizer fallback runs.
FOUNDATION_EXPORT void WCAtlasGenerateFishAudioSpeech(
    NSString *text,
    void (^completion)(NSURL * _Nullable outputURL, NSError * _Nullable error));

NS_ASSUME_NONNULL_END
