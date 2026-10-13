#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCAtlasChatTTSStatusHandler)(NSString *message, BOOL success);

/// Presents the chat-scoped Fish Audio panel used by the long press on WeChat's
/// input-mode button. The panel can generate a voice message, choose voices and
/// models, manage the API key, and configure the optional text trigger.
/// @param presenter Visible chat controller. Main-thread only.
/// @param userName Exact friend or group username captured when the panel opens.
/// @param didSubmit Called after WeChat accepts the generated Silk voice for upload.
/// @param status Reports progress and terminal errors on the main thread.
FOUNDATION_EXPORT void WCAtlasPresentChatTTSPanel(
    UIViewController *presenter,
    NSString *userName,
    dispatch_block_t _Nullable didSubmit,
    WCAtlasChatTTSStatusHandler _Nullable status);

/// Consumes text matching the enabled custom TTS prefix and asynchronously sends
/// the suffix as a native WeChat voice message.
/// @return YES only when the text matched the enabled trigger and normal text
/// sending must be suppressed. Empty suffixes and failures are also consumed so
/// the trigger command is never leaked into the conversation.
/// @discussion Main-thread only. Unsupported chats, API failures, conversion
/// failures, and changed conversations are reported without clearing the input.
FOUNDATION_EXPORT BOOL WCAtlasChatTTSConsumeTriggeredText(
    UIViewController *presenter,
    NSString *userName,
    NSString *text,
    dispatch_block_t _Nullable didSubmit,
    WCAtlasChatTTSStatusHandler _Nullable status);

NS_ASSUME_NONNULL_END
