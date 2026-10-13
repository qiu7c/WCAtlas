#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCAtlasQuickReplyType) {
    WCAtlasQuickReplyTypeText = 0,
    WCAtlasQuickReplyTypeImage = 1,
    WCAtlasQuickReplyTypeVideo = 2,
    WCAtlasQuickReplyTypeVoice = 3,
    WCAtlasQuickReplyTypeMessageReference = 4,
    WCAtlasQuickReplyTypeGroupInvitation = 5,
    WCAtlasQuickReplyTypeJavaScript = 6,
};

@interface WCAtlasQuickReplyItem : NSObject <NSCopying>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) WCAtlasQuickReplyType type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSString *folderIdentifier;
@property (nonatomic, copy, nullable) NSString *mediaRelativePath;
@property (nonatomic, copy, nullable) NSString *thumbnailRelativePath;
@property (nonatomic, assign) NSInteger sortIndex;
@property (nonatomic, assign, getter=isPinned) BOOL pinned;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *lastUsedAt;
@property (nonatomic, assign) NSUInteger useCount;
@property (nonatomic, copy, nullable) NSString *sourceConversation;
@property (nonatomic, copy, nullable) NSString *sourceMessageID;
@property (nonatomic, copy, nullable) NSString *sourceAccountIdentifier;
@property (nonatomic, copy) NSDictionary<NSString *, id> *metadata;
@end

@interface WCAtlasQuickReplyFolder : NSObject <NSCopying>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger sortIndex;
@end

@interface WCAtlasQuickReplyStore : NSObject

+ (instancetype)sharedStore;

@property (nonatomic, readonly, getter=isAvailable) BOOL available;

- (NSArray<WCAtlasQuickReplyItem *> *)items;
- (NSArray<WCAtlasQuickReplyFolder *> *)folders;
- (nullable WCAtlasQuickReplyItem *)addText:(NSString *)text
                                    title:(nullable NSString *)title
                        folderIdentifier:(nullable NSString *)folderIdentifier
                       sourceConversation:(nullable NSString *)sourceConversation
                          sourceMessageID:(nullable NSString *)sourceMessageID
                                    error:(NSError **)error;
- (nullable WCAtlasQuickReplyItem *)addJavaScript:(NSString *)script
                                          title:(nullable NSString *)title
                               folderIdentifier:(nullable NSString *)folderIdentifier
                                          error:(NSError **)error;
- (nullable WCAtlasQuickReplyItem *)addMediaAtURL:(NSURL *)sourceURL
                                           type:(WCAtlasQuickReplyType)type
                                          title:(nullable NSString *)title
                              folderIdentifier:(nullable NSString *)folderIdentifier
                             sourceConversation:(nullable NSString *)sourceConversation
                                sourceMessageID:(nullable NSString *)sourceMessageID
                                          error:(NSError **)error;
- (nullable WCAtlasQuickReplyItem *)addMessageReferenceForConversation:(NSString *)conversation
                                                              localID:(unsigned long long)localID
                                                             serverID:(long long)serverID
                                                          messageType:(NSInteger)messageType
                                                            innerType:(NSInteger)innerType
                                                              preview:(nullable NSString *)preview
                                                                title:(nullable NSString *)title
                                                    folderIdentifier:(nullable NSString *)folderIdentifier
                                                                error:(NSError **)error;
- (nullable WCAtlasQuickReplyItem *)addGroupInvitationForGroupUserName:(NSString *)groupUserName
                                                           groupName:(nullable NSString *)groupName
                                                   folderIdentifier:(nullable NSString *)folderIdentifier
                                                               error:(NSError **)error;
- (BOOL)updateItem:(WCAtlasQuickReplyItem *)item error:(NSError **)error;
- (BOOL)setPinned:(BOOL)pinned forIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)recordUsageForIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)applyOrderedIdentifiers:(NSArray<NSString *> *)identifiers error:(NSError **)error;
- (BOOL)deleteItemWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (nullable WCAtlasQuickReplyFolder *)createFolderWithName:(NSString *)name error:(NSError **)error;
- (BOOL)renameFolderWithIdentifier:(NSString *)identifier toName:(NSString *)name error:(NSError **)error;
- (BOOL)deleteFolderWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)moveItemWithIdentifier:(NSString *)identifier
            toFolderIdentifier:(nullable NSString *)folderIdentifier
                         error:(NSError **)error;
- (nullable NSString *)absoluteMediaPathForItem:(WCAtlasQuickReplyItem *)item;
- (nullable NSString *)absoluteThumbnailPathForItem:(WCAtlasQuickReplyItem *)item;
- (unsigned long long)managedMediaSize;
- (nullable NSURL *)createExportPackageWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
