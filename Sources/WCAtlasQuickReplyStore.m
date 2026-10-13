#import "WCAtlasQuickReplyStore.h"
#import "WCAtlasAccount.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <string.h>

static NSString *const WCAtlasQuickReplyErrorDomain = @"com.qiu7c.wcatlas.quick-reply";

typedef NS_ENUM(NSInteger, WCAtlasQuickReplyErrorCode) {
    WCAtlasQuickReplyErrorInvalidValue = 1,
    WCAtlasQuickReplyErrorStorageUnavailable,
    WCAtlasQuickReplyErrorMediaCopyFailed,
};

static NSString *const WCAtlasQuickReplyItemsIndexName = @"index.json";
static NSString *const WCAtlasQuickReplyItemsBackupName = @"index.backup.json";
static NSString *const WCAtlasQuickReplyFoldersIndexName = @"folders.json";
static NSString *const WCAtlasQuickReplyFoldersBackupName = @"folders.backup.json";
static NSString *const WCAtlasQuickReplyRecoveryDirectoryName = @"QuickReplyRecovery";
static NSString *const WCAtlasQuickReplyRecordsDirectoryName = @"records";
static NSString *const WCAtlasQuickReplyLibraryDirectoryName = @"Library";
static NSString *const WCAtlasQuickReplyRootDirectoryName = @"_root";
static NSString *const WCAtlasQuickReplyFolderMetadataName = @".folder.json";
static NSString *const WCAtlasQuickReplySearchIndexName = @"search-index.json";
static NSString *const WCAtlasQuickReplyItemsMigrationMarkerName = @".items-v2";
static NSString *const WCAtlasQuickReplyFoldersMigrationMarkerName = @".folders-v2";
static NSString *const WCAtlasQuickReplyItemsStableRecoveryMarkerName = @".items-v3-stable";
static NSString *const WCAtlasQuickReplyFoldersStableRecoveryMarkerName = @".folders-v3-stable";
static NSString *const WCAtlasQuickReplyItemsDefaultsKey = @"com.qiu7c.wcatlas.quick-reply.message-list.v3";
static NSString *const WCAtlasQuickReplyFoldersDefaultsKey = @"com.qiu7c.wcatlas.quick-reply.folder-list.v3";
static NSString *const WCAtlasQuickReplyDeletedFoldersDefaultsKey = @"com.qiu7c.wcatlas.quick-reply.deleted-folder-identifiers.v1";

static NSError *WCAtlasQuickReplyError(WCAtlasQuickReplyErrorCode code, NSString *description) {
    return [NSError errorWithDomain:WCAtlasQuickReplyErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"快捷回复处理失败"}];
}

static void WCAtlasQuickReplySetIndexReadError(NSError **error) {
    if (error) {
        *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable,
                                      @"消息库索引暂时无法读取，已停止操作以保护现有消息");
    }
}

static NSString *WCAtlasQuickReplyTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static BOOL WCAtlasQuickReplyIsSafePathComponent(NSString *value) {
    return value.length > 0 && [value isEqualToString:value.lastPathComponent] &&
           ![value isEqualToString:@"."] && ![value isEqualToString:@".."] &&
           [value rangeOfString:@"/"].location == NSNotFound &&
           [value rangeOfString:@"\\"].location == NSNotFound;
}

static NSSet<NSString *> *WCAtlasQuickReplyDeletedFolderIdentifiers(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasQuickReplyDeletedFoldersDefaultsKey];
    if (![value isKindOfClass:NSArray.class]) return [NSSet set];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (id candidate in (NSArray *)value) {
        NSString *identifier = WCAtlasQuickReplyTrimmedString(candidate);
        if (WCAtlasQuickReplyIsSafePathComponent(identifier)) [identifiers addObject:identifier];
    }
    return identifiers;
}

static void WCAtlasQuickReplySetDeletedFolderIdentifiers(NSSet<NSString *> *identifiers) {
    NSArray<NSString *> *values = [[identifiers allObjects] sortedArrayUsingSelector:@selector(compare:)];
    [NSUserDefaults.standardUserDefaults setObject:values forKey:WCAtlasQuickReplyDeletedFoldersDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

static void WCAtlasQuickReplyTarWriteOctal(char *field, size_t length, unsigned long long value) {
    memset(field, '0', length);
    if (length == 0) return;
    field[length - 1] = '\0';
    char buffer[32] = {0};
    snprintf(buffer, sizeof(buffer), "%llo", value);
    size_t valueLength = strlen(buffer);
    size_t available = length - 1;
    size_t copyLength = MIN(valueLength, available);
    memcpy(field + available - copyLength, buffer + valueLength - copyLength, copyLength);
}

static NSData *WCAtlasQuickReplyTarHeader(NSString *relativePath, unsigned long long size, NSDate *modificationDate) {
    NSData *nameData = [relativePath dataUsingEncoding:NSUTF8StringEncoding];
    if (nameData.length == 0 || nameData.length >= 100) return nil;
    unsigned char header[512] = {0};
    memcpy(header, nameData.bytes, nameData.length);
    WCAtlasQuickReplyTarWriteOctal((char *)header + 100, 8, 0644);
    WCAtlasQuickReplyTarWriteOctal((char *)header + 108, 8, 0);
    WCAtlasQuickReplyTarWriteOctal((char *)header + 116, 8, 0);
    WCAtlasQuickReplyTarWriteOctal((char *)header + 124, 12, size);
    WCAtlasQuickReplyTarWriteOctal((char *)header + 136, 12, (unsigned long long)MAX(0.0, modificationDate.timeIntervalSince1970));
    memset(header + 148, ' ', 8);
    header[156] = '0';
    memcpy(header + 257, "ustar", 5);
    header[262] = '\0';
    header[263] = '0';
    header[264] = '0';
    unsigned int checksum = 0;
    for (NSUInteger index = 0; index < sizeof(header); index++) checksum += header[index];
    snprintf((char *)header + 148, 7, "%06o", checksum);
    header[154] = '\0';
    header[155] = ' ';
    return [NSData dataWithBytes:header length:sizeof(header)];
}

@implementation WCAtlasQuickReplyItem

- (id)copyWithZone:(NSZone *)zone {
    WCAtlasQuickReplyItem *copy = [[[self class] allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.type = self.type;
    copy.title = self.title;
    copy.text = self.text;
    copy.folderIdentifier = self.folderIdentifier;
    copy.mediaRelativePath = self.mediaRelativePath;
    copy.thumbnailRelativePath = self.thumbnailRelativePath;
    copy.sortIndex = self.sortIndex;
    copy.pinned = self.pinned;
    copy.createdAt = self.createdAt;
    copy.lastUsedAt = self.lastUsedAt;
    copy.useCount = self.useCount;
    copy.sourceConversation = self.sourceConversation;
    copy.sourceMessageID = self.sourceMessageID;
    copy.sourceAccountIdentifier = self.sourceAccountIdentifier;
    copy.metadata = self.metadata;
    return copy;
}

@end

@implementation WCAtlasQuickReplyFolder

- (id)copyWithZone:(NSZone *)zone {
    WCAtlasQuickReplyFolder *copy = [[[self class] allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.name = self.name;
    copy.sortIndex = self.sortIndex;
    return copy;
}

@end

@interface WCAtlasQuickReplyStore ()
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyItem *> *lastKnownItems;
@property (nonatomic, copy) NSArray<WCAtlasQuickReplyFolder *> *lastKnownFolders;
- (nullable NSURL *)sharedDirectoryCreatingIfNeeded:(BOOL)create error:(NSError **)error;
- (nullable NSURL *)recoveryDirectoryCreatingIfNeeded:(BOOL)create error:(NSError **)error;
@end

@implementation WCAtlasQuickReplyStore

+ (instancetype)sharedStore {
    static WCAtlasQuickReplyStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [WCAtlasQuickReplyStore new]; });
    return store;
}

- (BOOL)isAvailable {
    return [self sharedDirectoryCreatingIfNeeded:YES error:nil] != nil;
}

- (NSURL *)quickRepliesRootURL {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                            inDomains:NSUserDomainMask].firstObject;
    return documents ? [[documents URLByAppendingPathComponent:@"WCAtlas" isDirectory:YES]
                        URLByAppendingPathComponent:@"QuickReplies" isDirectory:YES] : nil;
}

- (NSURL *)recoveryDirectoryCreatingIfNeeded:(BOOL)create error:(NSError **)error {
    NSURL *root = [self quickRepliesRootURL];
    if (!root) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable, @"无法访问快捷回复恢复目录");
        return nil;
    }
    NSURL *directory = [root URLByAppendingPathComponent:@"Recovery" isDirectory:YES];
    if (!create) return directory;
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&directoryError]) {
        if (error) *error = directoryError ?: WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable,
                                                                    @"无法创建快捷回复恢复目录");
        return nil;
    }
    for (NSString *component in @[@"media", @"thumbnails", WCAtlasQuickReplyRecordsDirectoryName]) {
        NSURL *child = [directory URLByAppendingPathComponent:component isDirectory:YES];
        if (![NSFileManager.defaultManager createDirectoryAtURL:child
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:&directoryError]) {
            if (error) *error = directoryError;
            return nil;
        }
    }
    return directory;
}

- (NSURL *)legacyQuickRepliesRootURL {
    NSURL *applicationSupport = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                                     inDomains:NSUserDomainMask].firstObject;
    return applicationSupport ? [[applicationSupport URLByAppendingPathComponent:@"WCAtlas" isDirectory:YES]
                                 URLByAppendingPathComponent:@"QuickReplies" isDirectory:YES] : nil;
}

- (void)copyMissingContentsFromDirectory:(NSURL *)sourceDirectory toDirectory:(NSURL *)destinationDirectory {
    NSFileManager *manager = NSFileManager.defaultManager;
    BOOL sourceIsDirectory = NO;
    if (![manager fileExistsAtPath:sourceDirectory.path isDirectory:&sourceIsDirectory] || !sourceIsDirectory) return;
    [manager createDirectoryAtURL:destinationDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    NSDirectoryEnumerator<NSURL *> *enumerator = [manager enumeratorAtURL:sourceDirectory
                                                includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                   options:0
                                                              errorHandler:nil];
    for (NSURL *sourceURL in enumerator) {
        NSString *relativePath = [sourceURL.path substringFromIndex:sourceDirectory.path.length];
        while ([relativePath hasPrefix:@"/"]) relativePath = [relativePath substringFromIndex:1];
        if (!relativePath.length) continue;
        NSURL *destinationURL = [destinationDirectory URLByAppendingPathComponent:relativePath];
        NSNumber *isDirectory = nil;
        [sourceURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) {
            [manager createDirectoryAtURL:destinationURL withIntermediateDirectories:YES attributes:nil error:nil];
        } else if (![manager fileExistsAtPath:destinationURL.path]) {
            [manager createDirectoryAtURL:[destinationURL URLByDeletingLastPathComponent]
              withIntermediateDirectories:YES attributes:nil error:nil];
            [manager copyItemAtURL:sourceURL toURL:destinationURL error:nil];
        }
    }
}

- (void)migratePreviousPersistentLibrariesIntoDirectory:(NSURL *)sharedDirectory recoveryDirectory:(NSURL *)recoveryDirectory {
    NSURL *legacyRoot = [self legacyQuickRepliesRootURL];
    if (legacyRoot) [self copyMissingContentsFromDirectory:[legacyRoot URLByAppendingPathComponent:@"Shared" isDirectory:YES]
                                               toDirectory:sharedDirectory];
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *legacyRecovery = documents ? [[documents URLByAppendingPathComponent:@"WCAtlas" isDirectory:YES]
                                         URLByAppendingPathComponent:WCAtlasQuickReplyRecoveryDirectoryName isDirectory:YES] : nil;
    if (legacyRecovery) {
        [self copyMissingContentsFromDirectory:legacyRecovery toDirectory:sharedDirectory];
        [self copyMissingContentsFromDirectory:legacyRecovery toDirectory:recoveryDirectory];
    }
}

- (NSURL *)sharedDirectoryCreatingIfNeeded:(BOOL)create error:(NSError **)error {
    NSURL *root = [self quickRepliesRootURL];
    if (!root) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable, @"无法访问微信沙盒 Documents 目录");
        return nil;
    }
    NSURL *directory = [root URLByAppendingPathComponent:@"Shared" isDirectory:YES];
    if (!create) return directory;
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *component in @[@"media", @"thumbnails", WCAtlasQuickReplyLibraryDirectoryName,
                                  [WCAtlasQuickReplyLibraryDirectoryName stringByAppendingPathComponent:WCAtlasQuickReplyRootDirectoryName]]) {
        NSURL *child = [directory URLByAppendingPathComponent:component isDirectory:YES];
        NSError *directoryError = nil;
        if (![manager createDirectoryAtURL:child withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
            if (error) *error = directoryError ?: WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable, @"无法创建快捷回复目录");
            return nil;
        }
    }
    NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:YES error:nil];
    if (recoveryDirectory) {
        [self migratePreviousPersistentLibrariesIntoDirectory:directory
                                            recoveryDirectory:recoveryDirectory];
    }
    NSURL *legacyRoot = [self legacyQuickRepliesRootURL];
    if (legacyRoot) [self migrateLegacyLibrariesIntoDirectory:directory root:legacyRoot];
    return directory;
}

- (void)migrateLegacyLibrariesIntoDirectory:(NSURL *)sharedDirectory root:(NSURL *)root {
    NSURL *marker = [sharedDirectory URLByAppendingPathComponent:@".shared-library-v1"];
    if ([NSFileManager.defaultManager fileExistsAtPath:marker.path]) return;
    NSFileManager *manager = NSFileManager.defaultManager;
    NSError *childrenError = nil;
    NSArray<NSURL *> *children = [manager contentsOfDirectoryAtURL:root
                                       includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:&childrenError];
    if (!children || childrenError) return;
    NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:YES error:nil];
    if (!recoveryDirectory) return;
    NSMutableArray<NSMutableDictionary *> *mergedItems = [NSMutableArray array];
    NSURL *sharedItemsURL = [sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName];
    BOOL sharedItemsExist = [manager fileExistsAtPath:sharedItemsURL.path];
    NSData *sharedData = [NSData dataWithContentsOfURL:sharedItemsURL];
    NSError *sharedItemsError = nil;
    id sharedObject = sharedData.length ? [NSJSONSerialization JSONObjectWithData:sharedData options:NSJSONReadingMutableContainers error:&sharedItemsError] : nil;
    if (sharedItemsExist && (![sharedObject isKindOfClass:NSArray.class] || sharedItemsError)) return;
    if (!sharedItemsExist) {
        NSData *recoveryItemsData = [NSData dataWithContentsOfURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]];
        id recoveryItemsObject = recoveryItemsData.length
            ? [NSJSONSerialization JSONObjectWithData:recoveryItemsData options:NSJSONReadingMutableContainers error:nil]
            : nil;
        if ([recoveryItemsObject isKindOfClass:NSArray.class]) {
            sharedData = recoveryItemsData;
            sharedObject = recoveryItemsObject;
        }
    }
    if ([sharedObject isKindOfClass:NSArray.class]) {
        for (id value in sharedObject) if ([value isKindOfClass:NSDictionary.class]) [mergedItems addObject:[value mutableCopy]];
    }
    NSMutableArray<NSMutableDictionary *> *folders = [NSMutableArray array];
    NSURL *sharedFoldersURL = [sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName];
    BOOL sharedFoldersExist = [manager fileExistsAtPath:sharedFoldersURL.path];
    NSData *folderData = [NSData dataWithContentsOfURL:sharedFoldersURL];
    NSError *sharedFoldersError = nil;
    id folderObject = folderData.length ? [NSJSONSerialization JSONObjectWithData:folderData options:NSJSONReadingMutableContainers error:&sharedFoldersError] : nil;
    if (sharedFoldersExist && (![folderObject isKindOfClass:NSArray.class] || sharedFoldersError)) return;
    if (!sharedFoldersExist) {
        NSData *recoveryFoldersData = [NSData dataWithContentsOfURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]];
        id recoveryFoldersObject = recoveryFoldersData.length
            ? [NSJSONSerialization JSONObjectWithData:recoveryFoldersData options:NSJSONReadingMutableContainers error:nil]
            : nil;
        if ([recoveryFoldersObject isKindOfClass:NSArray.class]) {
            folderData = recoveryFoldersData;
            folderObject = recoveryFoldersObject;
        }
    }
    if ([folderObject isKindOfClass:NSArray.class]) {
        for (id value in folderObject) if ([value isKindOfClass:NSDictionary.class]) [folders addObject:[value mutableCopy]];
    }
    NSMutableDictionary<NSString *, NSString *> *folderIDByName = [NSMutableDictionary dictionary];
    for (NSDictionary *folder in folders) {
        NSString *name = WCAtlasQuickReplyTrimmedString(folder[@"name"]);
        NSString *identifier = WCAtlasQuickReplyTrimmedString(folder[@"id"]);
        if (name.length && identifier.length) folderIDByName[name] = identifier;
    }
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    NSMutableSet<NSString *> *migrationOrigins = [NSMutableSet set];
    for (NSDictionary *item in mergedItems) {
        NSString *identifier = WCAtlasQuickReplyTrimmedString(item[@"id"]);
        if (identifier.length) [identifiers addObject:identifier];
        NSString *origin = WCAtlasQuickReplyTrimmedString(item[@"migrationOrigin"]);
        if (origin.length) [migrationOrigins addObject:origin];
    }
    NSInteger nextSort = mergedItems.count;
    for (NSURL *legacyDirectory in children) {
        NSNumber *isDirectory = nil;
        [legacyDirectory getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue || [legacyDirectory.lastPathComponent isEqualToString:@"Shared"]) continue;
        NSData *data = [NSData dataWithContentsOfURL:[legacyDirectory URLByAppendingPathComponent:@"index.json"]];
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
        if (![object isKindOfClass:NSArray.class]) continue;
        NSData *categoriesData = [NSData dataWithContentsOfURL:[legacyDirectory URLByAppendingPathComponent:@"categories.json"]];
        id categoriesObject = categoriesData.length ? [NSJSONSerialization JSONObjectWithData:categoriesData options:0 error:nil] : nil;
        if ([categoriesObject isKindOfClass:NSArray.class]) {
            for (id value in (NSArray *)categoriesObject) {
                NSString *categoryName = WCAtlasQuickReplyTrimmedString(value);
                if (!categoryName.length || folderIDByName[categoryName]) continue;
                NSString *folderID = NSUUID.UUID.UUIDString.lowercaseString;
                folderIDByName[categoryName] = folderID;
                [folders addObject:[@{@"id": folderID, @"name": categoryName, @"sort": @(folders.count)} mutableCopy]];
            }
        }
        for (NSDictionary *rawItem in (NSArray *)object) {
            if (![rawItem isKindOfClass:NSDictionary.class]) continue;
            NSMutableDictionary *item = [rawItem mutableCopy];
            NSString *oldIdentifier = WCAtlasQuickReplyTrimmedString(item[@"id"]);
            NSString *migrationOrigin = [legacyDirectory.lastPathComponent stringByAppendingFormat:@"/%@", oldIdentifier.length ? oldIdentifier : @"unknown"];
            if ([migrationOrigins containsObject:migrationOrigin]) continue;
            NSString *identifier = oldIdentifier;
            if (!identifier.length || [identifiers containsObject:identifier]) identifier = NSUUID.UUID.UUIDString.lowercaseString;
            item[@"id"] = identifier;
            item[@"migrationOrigin"] = migrationOrigin;
            item[@"sourceAccount"] = legacyDirectory.lastPathComponent;
            NSString *category = WCAtlasQuickReplyTrimmedString(item[@"category"]);
            if (category.length) {
                NSString *folderID = folderIDByName[category];
                if (!folderID) {
                    folderID = NSUUID.UUID.UUIDString.lowercaseString;
                    folderIDByName[category] = folderID;
                    [folders addObject:[@{@"id": folderID, @"name": category, @"sort": @(folders.count)} mutableCopy]];
                }
                item[@"folder"] = folderID;
            }
            [item removeObjectForKey:@"category"];
            for (NSString *key in @[@"media", @"thumbnail"]) {
                NSString *relativePath = WCAtlasQuickReplyTrimmedString(item[key]);
                if (!relativePath.length) continue;
                NSURL *source = [legacyDirectory URLByAppendingPathComponent:relativePath];
                NSString *child = [key isEqualToString:@"media"] ? @"media" : @"thumbnails";
                NSString *extension = source.pathExtension.length ? source.pathExtension : ([key isEqualToString:@"media"] ? @"dat" : @"jpg");
                NSString *newRelativePath = [child stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:extension]];
                NSURL *destination = [sharedDirectory URLByAppendingPathComponent:newRelativePath];
                if (![manager fileExistsAtPath:source.path]) { [item removeObjectForKey:key]; continue; }
                [manager removeItemAtURL:destination error:nil];
                NSError *copyError = nil;
                if (![manager copyItemAtURL:source toURL:destination error:&copyError]) {
                    [item removeObjectForKey:key];
                    continue;
                }
                item[key] = newRelativePath;
            }
            item[@"sort"] = @(nextSort++);
            [mergedItems addObject:item];
            [identifiers addObject:identifier];
            [migrationOrigins addObject:migrationOrigin];
        }
    }
    NSError *serializationError = nil;
    NSData *itemsData = [NSJSONSerialization dataWithJSONObject:mergedItems options:0 error:&serializationError];
    NSData *foldersData = [NSJSONSerialization dataWithJSONObject:folders options:0 error:&serializationError];
    if (!itemsData || !foldersData) return;
    if (sharedData.length) [sharedData writeToURL:[sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsBackupName] options:NSDataWritingAtomic error:nil];
    if (folderData.length) [folderData writeToURL:[sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersBackupName] options:NSDataWritingAtomic error:nil];
    if (![itemsData writeToURL:sharedItemsURL options:NSDataWritingAtomic error:nil]) return;
    if (![foldersData writeToURL:sharedFoldersURL options:NSDataWritingAtomic error:nil]) return;
    if (![itemsData writeToURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]
                        options:NSDataWritingAtomic error:nil]) return;
    if (![foldersData writeToURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                          options:NSDataWritingAtomic error:nil]) return;
    [[NSData data] writeToURL:marker options:NSDataWritingAtomic error:nil];
}

- (BOOL)isManagedRelativePath:(NSString *)relativePath {
    if (relativePath.length == 0 || relativePath.isAbsolutePath) return NO;
    NSArray<NSString *> *components = relativePath.pathComponents;
    if (components.count != 2 || [components containsObject:@".."]) return NO;
    return [components.firstObject isEqualToString:@"media"] ||
           [components.firstObject isEqualToString:@"thumbnails"];
}

- (void)synchronizeRecoveryFileForRelativePath:(NSString *)relativePath
                               sharedDirectory:(NSURL *)sharedDirectory
                             recoveryDirectory:(NSURL *)recoveryDirectory {
    if (![self isManagedRelativePath:relativePath] || !sharedDirectory || !recoveryDirectory) return;
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *primaryURL = [sharedDirectory URLByAppendingPathComponent:relativePath];
    NSURL *recoveryURL = [recoveryDirectory URLByAppendingPathComponent:relativePath];
    BOOL primaryExists = [manager fileExistsAtPath:primaryURL.path];
    BOOL recoveryExists = [manager fileExistsAtPath:recoveryURL.path];
    if (primaryExists == recoveryExists) return;
    NSURL *sourceURL = primaryExists ? primaryURL : recoveryURL;
    NSURL *destinationURL = primaryExists ? recoveryURL : primaryURL;
    NSError *linkError = nil;
    if (![manager linkItemAtURL:sourceURL toURL:destinationURL error:&linkError]) {
        [manager copyItemAtURL:sourceURL toURL:destinationURL error:nil];
    }
}

- (WCAtlasQuickReplyItem *)itemFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
    NSNumber *typeValue = dictionary[@"type"];
    if (identifier.length == 0 || ![typeValue respondsToSelector:@selector(integerValue)]) return nil;
    NSInteger type = typeValue.integerValue;
    if (type < WCAtlasQuickReplyTypeText || type > WCAtlasQuickReplyTypeJavaScript) return nil;
    WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
    item.identifier = identifier;
    item.type = (WCAtlasQuickReplyType)type;
    item.title = [dictionary[@"title"] isKindOfClass:NSString.class] ? dictionary[@"title"] : @"";
    item.text = [dictionary[@"text"] isKindOfClass:NSString.class] ? dictionary[@"text"] : @"";
    item.folderIdentifier = [dictionary[@"folder"] isKindOfClass:NSString.class] ? dictionary[@"folder"] : nil;
    item.mediaRelativePath = [dictionary[@"media"] isKindOfClass:NSString.class] ? dictionary[@"media"] : nil;
    item.thumbnailRelativePath = [dictionary[@"thumbnail"] isKindOfClass:NSString.class] ? dictionary[@"thumbnail"] : nil;
    item.sortIndex = [dictionary[@"sort"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"sort"] integerValue] : 0;
    item.pinned = [dictionary[@"pinned"] respondsToSelector:@selector(boolValue)] && [dictionary[@"pinned"] boolValue];
    NSTimeInterval timestamp = [dictionary[@"createdAt"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"createdAt"] doubleValue] : 0;
    item.createdAt = timestamp > 0 ? [NSDate dateWithTimeIntervalSince1970:timestamp] : NSDate.date;
    NSTimeInterval lastUsedTimestamp = [dictionary[@"lastUsedAt"] respondsToSelector:@selector(doubleValue)]
        ? [dictionary[@"lastUsedAt"] doubleValue] : 0;
    item.lastUsedAt = lastUsedTimestamp > 0 ? [NSDate dateWithTimeIntervalSince1970:lastUsedTimestamp] : nil;
    item.useCount = [dictionary[@"useCount"] respondsToSelector:@selector(unsignedIntegerValue)]
        ? [dictionary[@"useCount"] unsignedIntegerValue] : 0;
    item.sourceConversation = [dictionary[@"sourceConversation"] isKindOfClass:NSString.class] ? dictionary[@"sourceConversation"] : nil;
    item.sourceMessageID = [dictionary[@"sourceMessageID"] isKindOfClass:NSString.class] ? dictionary[@"sourceMessageID"] : nil;
    item.sourceAccountIdentifier = [dictionary[@"sourceAccount"] isKindOfClass:NSString.class] ? dictionary[@"sourceAccount"] : nil;
    item.metadata = [dictionary[@"metadata"] isKindOfClass:NSDictionary.class] ? dictionary[@"metadata"] : @{};
    return item;
}

- (NSDictionary *)dictionaryForItem:(WCAtlasQuickReplyItem *)item {
    NSMutableDictionary *dictionary = [@{
        @"id": item.identifier ?: @"",
        @"type": @(item.type),
        @"title": item.title ?: @"",
        @"text": item.text ?: @"",
        @"sort": @(item.sortIndex),
        @"pinned": @(item.isPinned),
        @"createdAt": @((item.createdAt ?: NSDate.date).timeIntervalSince1970),
        @"useCount": @(item.useCount),
    } mutableCopy];
    if (item.lastUsedAt) dictionary[@"lastUsedAt"] = @(item.lastUsedAt.timeIntervalSince1970);
    if (item.mediaRelativePath.length > 0) dictionary[@"media"] = item.mediaRelativePath;
    if (item.thumbnailRelativePath.length > 0) dictionary[@"thumbnail"] = item.thumbnailRelativePath;
    if (item.folderIdentifier.length > 0) dictionary[@"folder"] = item.folderIdentifier;
    if (item.sourceConversation.length > 0) dictionary[@"sourceConversation"] = item.sourceConversation;
    if (item.sourceMessageID.length > 0) dictionary[@"sourceMessageID"] = item.sourceMessageID;
    if (item.sourceAccountIdentifier.length > 0) dictionary[@"sourceAccount"] = item.sourceAccountIdentifier;
    if (item.metadata.count > 0) dictionary[@"metadata"] = item.metadata;
    return dictionary;
}

- (NSURL *)libraryDirectoryInSharedDirectory:(NSURL *)sharedDirectory {
    return [sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplyLibraryDirectoryName isDirectory:YES];
}

- (NSURL *)canonicalDirectoryForFolderIdentifier:(NSString *)folderIdentifier
                                  sharedDirectory:(NSURL *)sharedDirectory {
    NSString *component = WCAtlasQuickReplyTrimmedString(folderIdentifier);
    if (!WCAtlasQuickReplyIsSafePathComponent(component)) component = WCAtlasQuickReplyRootDirectoryName;
    return [[self libraryDirectoryInSharedDirectory:sharedDirectory]
            URLByAppendingPathComponent:component isDirectory:YES];
}

- (NSArray<NSDictionary *> *)canonicalItemDictionariesInSharedDirectory:(NSURL *)sharedDirectory {
    NSURL *libraryDirectory = [self libraryDirectoryInSharedDirectory:sharedDirectory];
    NSDirectoryEnumerator<NSURL *> *enumerator = [NSFileManager.defaultManager
        enumeratorAtURL:libraryDirectory includingPropertiesForKeys:@[NSURLIsDirectoryKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    if (!enumerator) return nil;
    NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
    for (NSURL *URL in enumerator) {
        NSNumber *isDirectory = nil;
        [URL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue || ![URL.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:nil];
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![object isKindOfClass:NSDictionary.class]) return nil;
        NSMutableDictionary *dictionary = [object mutableCopy];
        NSString *directoryName = URL.URLByDeletingLastPathComponent.lastPathComponent;
        if ([directoryName isEqualToString:WCAtlasQuickReplyRootDirectoryName]) [dictionary removeObjectForKey:@"folder"];
        else if (directoryName.length > 0) dictionary[@"folder"] = directoryName;
        [records addObject:dictionary];
    }
    return records;
}

- (BOOL)writeCanonicalItemRecordsLocked:(NSArray<WCAtlasQuickReplyItem *> *)items
                         sharedDirectory:(NSURL *)sharedDirectory
                                   error:(NSError **)error {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSMutableSet<NSString *> *desiredPaths = [NSMutableSet setWithCapacity:items.count];
    NSMutableArray *searchValues = [NSMutableArray arrayWithCapacity:items.count];
    for (WCAtlasQuickReplyItem *item in items) {
        if (!WCAtlasQuickReplyIsSafePathComponent(item.identifier)) {
            if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"消息标识无效，已停止写入");
            return NO;
        }
        NSURL *folderDirectory = [self canonicalDirectoryForFolderIdentifier:item.folderIdentifier sharedDirectory:sharedDirectory];
        if (![manager createDirectoryAtURL:folderDirectory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSURL *recordURL = [folderDirectory URLByAppendingPathComponent:[item.identifier stringByAppendingPathExtension:@"json"]];
        NSDictionary *dictionary = [self dictionaryForItem:item];
        NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:error];
        if (!data || ![data writeToURL:recordURL options:NSDataWritingAtomic error:error]) return NO;
        [desiredPaths addObject:recordURL.URLByStandardizingPath.path];
        [searchValues addObject:@{@"id": item.identifier, @"folder": item.folderIdentifier ?: @"",
                                  @"title": item.title ?: @"", @"text": item.text ?: @"", @"type": @(item.type)}];
    }
    NSURL *libraryDirectory = [self libraryDirectoryInSharedDirectory:sharedDirectory];
    NSDirectoryEnumerator<NSURL *> *enumerator = [manager enumeratorAtURL:libraryDirectory
                                                includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                              errorHandler:nil];
    for (NSURL *URL in enumerator) {
        NSNumber *isDirectory = nil;
        [URL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue || ![URL.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        if ([URL.lastPathComponent isEqualToString:WCAtlasQuickReplyFolderMetadataName]) continue;
        if (![desiredPaths containsObject:URL.URLByStandardizingPath.path]) [manager removeItemAtURL:URL error:nil];
    }
    NSData *searchData = [NSJSONSerialization dataWithJSONObject:searchValues options:0 error:nil];
    if (searchData) [searchData writeToURL:[sharedDirectory URLByAppendingPathComponent:WCAtlasQuickReplySearchIndexName]
                                  options:NSDataWritingAtomic error:nil];
    return YES;
}

- (NSArray<NSDictionary *> *)recordDictionariesInDirectory:(NSURL *)directory {
    NSURL *recordsDirectory = [directory URLByAppendingPathComponent:WCAtlasQuickReplyRecordsDirectoryName isDirectory:YES];
    NSArray<NSURL *> *URLs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:recordsDirectory
                                                        includingPropertiesForKeys:nil
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:nil];
    NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
    for (NSURL *URL in URLs) {
        if (![URL.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:nil];
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([object isKindOfClass:NSDictionary.class]) [records addObject:object];
    }
    return records;
}

- (BOOL)writeItemRecordsLocked:(NSArray<WCAtlasQuickReplyItem *> *)items
               sharedDirectory:(NSURL *)sharedDirectory
             recoveryDirectory:(NSURL *)recoveryDirectory
                         error:(NSError **)error {
    for (WCAtlasQuickReplyItem *item in items) {
        NSString *fileName = [item.identifier stringByAppendingPathExtension:@"json"];
        if (!fileName.length) continue;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[self dictionaryForItem:item] options:0 error:error];
        if (!data) return NO;
        for (NSURL *baseDirectory in @[sharedDirectory, recoveryDirectory]) {
            NSURL *URL = [[baseDirectory URLByAppendingPathComponent:WCAtlasQuickReplyRecordsDirectoryName isDirectory:YES]
                          URLByAppendingPathComponent:fileName];
            if (![data writeToURL:URL options:NSDataWritingAtomic error:error]) return NO;
        }
    }
    return YES;
}

- (WCAtlasQuickReplyType)recoveredTypeForMediaURL:(NSURL *)URL {
    NSString *extension = URL.pathExtension.lowercaseString;
    if ([@[@"jpg", @"jpeg", @"png", @"gif", @"webp", @"heic", @"heif", @"bmp"] containsObject:extension]) {
        return WCAtlasQuickReplyTypeImage;
    }
    if ([@[@"mp4", @"mov", @"m4v", @"3gp"] containsObject:extension]) return WCAtlasQuickReplyTypeVideo;
    return WCAtlasQuickReplyTypeVoice;
}

- (void)appendOrphanedMediaFromDirectory:(NSURL *)sourceDirectory
                         sharedDirectory:(NSURL *)sharedDirectory
                       recoveryDirectory:(NSURL *)recoveryDirectory
                         knownIdentifiers:(NSMutableSet<NSString *> *)knownIdentifiers
                                   items:(NSMutableArray<WCAtlasQuickReplyItem *> *)items {
    NSURL *mediaDirectory = [sourceDirectory URLByAppendingPathComponent:@"media" isDirectory:YES];
    NSArray<NSURL *> *URLs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:mediaDirectory
                                                        includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:nil];
    for (NSURL *URL in URLs) {
        NSNumber *isDirectory = nil;
        [URL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) continue;
        NSString *identifier = URL.URLByDeletingPathExtension.lastPathComponent.lowercaseString;
        if (!identifier.length || [knownIdentifiers containsObject:identifier]) continue;
        NSString *relativePath = [@"media" stringByAppendingPathComponent:URL.lastPathComponent];
        [self synchronizeRecoveryFileForRelativePath:relativePath sharedDirectory:sharedDirectory recoveryDirectory:recoveryDirectory];
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        item.identifier = identifier;
        item.type = [self recoveredTypeForMediaURL:URL];
        item.title = [NSString stringWithFormat:@"恢复的文件 · %@", URL.lastPathComponent];
        item.text = @"";
        item.mediaRelativePath = relativePath;
        item.sortIndex = items.count;
        NSDate *date = nil;
        [URL getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        item.createdAt = date ?: NSDate.date;
        item.metadata = @{ @"recoveredFromSandbox": @YES };
        [items addObject:item];
        [knownIdentifiers addObject:identifier];
    }
}

- (NSArray<NSDictionary *> *)loadJSONArrayAtURL:(NSURL *)primaryURL
                                       backupURL:(NSURL *)backupURL
                                     recoveryURL:(NSURL *)recoveryURL
                                           error:(NSError **)error {
    NSFileManager *manager = NSFileManager.defaultManager;
    BOOL primaryExists = [manager fileExistsAtPath:primaryURL.path];
    NSData *primaryData = [NSData dataWithContentsOfURL:primaryURL options:0 error:nil];
    NSError *primaryParseError = nil;
    id primaryObject = primaryData.length
        ? [NSJSONSerialization JSONObjectWithData:primaryData options:0 error:&primaryParseError]
        : nil;
    NSData *recoveryData = [NSData dataWithContentsOfURL:recoveryURL options:0 error:nil];
    NSError *recoveryParseError = nil;
    id recoveryObject = recoveryData.length
        ? [NSJSONSerialization JSONObjectWithData:recoveryData options:0 error:&recoveryParseError]
        : nil;
    BOOL recoveryValid = [recoveryObject isKindOfClass:NSArray.class] && !recoveryParseError;
    if ([primaryObject isKindOfClass:NSArray.class] && !primaryParseError) {
        if ([(NSArray *)primaryObject count] == 0 && recoveryValid && [(NSArray *)recoveryObject count] > 0) {
            [recoveryData writeToURL:primaryURL options:NSDataWritingAtomic error:nil];
            return recoveryObject;
        }
        [primaryData writeToURL:recoveryURL options:NSDataWritingAtomic error:nil];
        return primaryObject;
    }

    if (recoveryValid) {
        [recoveryData writeToURL:primaryURL options:NSDataWritingAtomic error:nil];
        return recoveryObject;
    }

    BOOL backupExists = [manager fileExistsAtPath:backupURL.path];
    NSData *backupData = [NSData dataWithContentsOfURL:backupURL options:0 error:nil];
    NSError *backupParseError = nil;
    id backupObject = backupData.length
        ? [NSJSONSerialization JSONObjectWithData:backupData options:0 error:&backupParseError]
        : nil;
    if ([backupObject isKindOfClass:NSArray.class] && !backupParseError) {
        [backupData writeToURL:primaryURL options:NSDataWritingAtomic error:nil];
        [backupData writeToURL:recoveryURL options:NSDataWritingAtomic error:nil];
        return backupObject;
    }
    BOOL recoveryExists = [manager fileExistsAtPath:recoveryURL.path];
    if (!primaryExists && !backupExists && !recoveryExists) return @[];
    if (error) {
        *error = primaryParseError ?: recoveryParseError ?: backupParseError ?:
            WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable,
                                 @"消息库索引暂时无法读取，已停止写入以避免清空");
    }
    return nil;
}

- (BOOL)writeJSONArrayData:(NSData *)data
                primaryURL:(NSURL *)primaryURL
                 backupURL:(NSURL *)backupURL
               recoveryURL:(NSURL *)recoveryURL
                     error:(NSError **)error {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSData *previousRecoveryData = [NSData dataWithContentsOfURL:recoveryURL options:0 error:nil];
    BOOL recoveryPreviouslyExisted = [manager fileExistsAtPath:recoveryURL.path];
    NSData *currentData = nil;
    if ([manager fileExistsAtPath:primaryURL.path]) {
        currentData = [NSData dataWithContentsOfURL:primaryURL options:0 error:nil];
        id currentObject = currentData.length ? [NSJSONSerialization JSONObjectWithData:currentData options:0 error:nil] : nil;
        if (![currentObject isKindOfClass:NSArray.class]) {
            if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable,
                                                      @"消息库索引异常，已拒绝覆盖原数据");
            return NO;
        }
        if (![currentData writeToURL:backupURL options:NSDataWritingAtomic error:error]) return NO;
    }
    if (![data writeToURL:recoveryURL options:NSDataWritingAtomic error:error]) return NO;
    BOOL written = [data writeToURL:primaryURL options:NSDataWritingAtomic error:error];
    if (!written) {
        if (recoveryPreviouslyExisted && previousRecoveryData.length) {
            [previousRecoveryData writeToURL:recoveryURL options:NSDataWritingAtomic error:nil];
        } else {
            [manager removeItemAtURL:recoveryURL error:nil];
        }
        return NO;
    }
    if (written && ![manager fileExistsAtPath:backupURL.path]) {
        [data writeToURL:backupURL options:NSDataWritingAtomic error:nil];
    }
    return written;
}

- (NSMutableArray<WCAtlasQuickReplyItem *> *)loadItemsLocked {
    NSURL *directory = [self sharedDirectoryCreatingIfNeeded:YES error:nil];
    if (!directory) return nil;
    NSURL *migrationMarker = [[self libraryDirectoryInSharedDirectory:directory]
                              URLByAppendingPathComponent:WCAtlasQuickReplyItemsMigrationMarkerName];
    BOOL migrated = [NSFileManager.defaultManager fileExistsAtPath:migrationMarker.path];
    NSArray *canonicalRecords = [self canonicalItemDictionariesInSharedDirectory:directory];
    if (migrated) {
        NSURL *stableRecoveryMarker = [[self libraryDirectoryInSharedDirectory:directory]
            URLByAppendingPathComponent:WCAtlasQuickReplyItemsStableRecoveryMarkerName];
        BOOL stableRecoveryFinished = [NSFileManager.defaultManager fileExistsAtPath:stableRecoveryMarker.path];
        id defaultsValue = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasQuickReplyItemsDefaultsKey];
        NSArray *defaultsRecords = [defaultsValue isKindOfClass:NSArray.class] ? defaultsValue : @[];
        if (!canonicalRecords && defaultsRecords.count == 0) return nil;
        NSMutableDictionary<NSString *, NSDictionary *> *recordsByIdentifier = [NSMutableDictionary dictionary];
        for (NSDictionary *dictionary in defaultsRecords) {
            if (![dictionary isKindOfClass:NSDictionary.class]) continue;
            NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
            if (identifier.length > 0) recordsByIdentifier[identifier.lowercaseString] = dictionary;
        }
        NSURL *recoveryDirectory = nil;
        if (!stableRecoveryFinished) {
            recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:NO error:nil];
            NSArray *legacyIndex = [self loadJSONArrayAtURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]
                                                  backupURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyItemsBackupName]
                                                recoveryURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]
                                                      error:nil];
            for (NSDictionary *dictionary in legacyIndex ?: @[]) {
                if (![dictionary isKindOfClass:NSDictionary.class]) continue;
                NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
                if (identifier.length > 0) recordsByIdentifier[identifier.lowercaseString] = dictionary;
            }
            for (NSURL *recordDirectory in recoveryDirectory ? @[directory, recoveryDirectory] : @[directory]) {
                for (NSDictionary *dictionary in [self recordDictionariesInDirectory:recordDirectory]) {
                    NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
                    if (identifier.length > 0) recordsByIdentifier[identifier.lowercaseString] = dictionary;
                }
            }
        }
        for (NSDictionary *dictionary in canonicalRecords ?: @[]) {
            if (![dictionary isKindOfClass:NSDictionary.class]) continue;
            NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
            if (identifier.length > 0) recordsByIdentifier[identifier.lowercaseString] = dictionary;
        }
        NSMutableArray *canonicalItems = [NSMutableArray arrayWithCapacity:recordsByIdentifier.count];
        for (NSDictionary *dictionary in recordsByIdentifier.allValues) {
            WCAtlasQuickReplyItem *item = [self itemFromDictionary:dictionary];
            if (!item) return nil;
            [canonicalItems addObject:item];
        }
        if (!stableRecoveryFinished) {
            NSMutableSet<NSString *> *knownIdentifiers = [NSMutableSet setWithCapacity:canonicalItems.count];
            for (WCAtlasQuickReplyItem *item in canonicalItems) [knownIdentifiers addObject:item.identifier.lowercaseString];
            [self appendOrphanedMediaFromDirectory:directory sharedDirectory:directory recoveryDirectory:recoveryDirectory
                                  knownIdentifiers:knownIdentifiers items:canonicalItems];
            if (recoveryDirectory) {
                [self appendOrphanedMediaFromDirectory:recoveryDirectory sharedDirectory:directory recoveryDirectory:recoveryDirectory
                                      knownIdentifiers:knownIdentifiers items:canonicalItems];
            }
        }
        if (!stableRecoveryFinished || canonicalRecords.count != canonicalItems.count) {
            if ([self writeCanonicalItemRecordsLocked:canonicalItems sharedDirectory:directory error:nil]) {
                [[NSData data] writeToURL:stableRecoveryMarker options:NSDataWritingAtomic error:nil];
            }
        }
        NSMutableArray *mirroredRecords = [NSMutableArray arrayWithCapacity:canonicalItems.count];
        for (WCAtlasQuickReplyItem *item in canonicalItems) [mirroredRecords addObject:[self dictionaryForItem:item]];
        [NSUserDefaults.standardUserDefaults setObject:mirroredRecords forKey:WCAtlasQuickReplyItemsDefaultsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        return canonicalItems;
    }

    // One-time, copy-only compatibility import. The old locations are never
    // deleted and are not consulted again after the canonical marker exists.
    NSURL *legacyRoot = [self legacyQuickRepliesRootURL];
    if (legacyRoot) {
        [self copyMissingContentsFromDirectory:[legacyRoot URLByAppendingPathComponent:@"Shared" isDirectory:YES]
                                    toDirectory:directory];
    }

    NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:NO error:nil];
    NSArray *object = recoveryDirectory ? [self loadJSONArrayAtURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]
                                       backupURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyItemsBackupName]
                                     recoveryURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyItemsIndexName]
                                           error:nil] : @[];
    if (!recoveryDirectory) {
        for (NSString *name in @[WCAtlasQuickReplyItemsIndexName, WCAtlasQuickReplyItemsBackupName]) {
            NSData *legacyData = [NSData dataWithContentsOfURL:[directory URLByAppendingPathComponent:name] options:0 error:nil];
            id legacyObject = legacyData.length ? [NSJSONSerialization JSONObjectWithData:legacyData options:0 error:nil] : nil;
            if ([legacyObject isKindOfClass:NSArray.class]) { object = legacyObject; break; }
        }
    }
    if (!object) object = @[];
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet<NSString *> *knownIdentifiers = [NSMutableSet set];
    for (NSDictionary *dictionary in object) {
        WCAtlasQuickReplyItem *item = [self itemFromDictionary:dictionary];
        if (!item) return nil;
        [items addObject:item];
        [knownIdentifiers addObject:item.identifier.lowercaseString];
    }
    for (NSURL *recordDirectory in recoveryDirectory ? @[directory, recoveryDirectory] : @[directory]) {
        for (NSDictionary *dictionary in [self recordDictionariesInDirectory:recordDirectory]) {
            WCAtlasQuickReplyItem *item = [self itemFromDictionary:dictionary];
            if (!item || [knownIdentifiers containsObject:item.identifier.lowercaseString]) continue;
            [items addObject:item];
            [knownIdentifiers addObject:item.identifier.lowercaseString];
        }
    }
    [self appendOrphanedMediaFromDirectory:directory sharedDirectory:directory recoveryDirectory:recoveryDirectory
                          knownIdentifiers:knownIdentifiers items:items];
    if (recoveryDirectory) {
        [self appendOrphanedMediaFromDirectory:recoveryDirectory sharedDirectory:directory recoveryDirectory:recoveryDirectory
                              knownIdentifiers:knownIdentifiers items:items];
    }
    if ([self writeCanonicalItemRecordsLocked:items sharedDirectory:directory error:nil]) {
        [[NSData data] writeToURL:migrationMarker options:NSDataWritingAtomic error:nil];
    }
    return items;
}

- (BOOL)saveItemsLocked:(NSArray<WCAtlasQuickReplyItem *> *)items error:(NSError **)error {
    NSURL *directory = [self sharedDirectoryCreatingIfNeeded:YES error:error];
    if (!directory) return NO;
    if (![self writeCanonicalItemRecordsLocked:items sharedDirectory:directory error:error]) return NO;
    NSMutableArray *defaultsRecords = [NSMutableArray arrayWithCapacity:items.count];
    for (WCAtlasQuickReplyItem *item in items) [defaultsRecords addObject:[self dictionaryForItem:item]];
    [NSUserDefaults.standardUserDefaults setObject:defaultsRecords forKey:WCAtlasQuickReplyItemsDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSURL *migrationMarker = [[self libraryDirectoryInSharedDirectory:directory]
                              URLByAppendingPathComponent:WCAtlasQuickReplyItemsMigrationMarkerName];
    [[NSData data] writeToURL:migrationMarker options:NSDataWritingAtomic error:nil];
    NSURL *stableRecoveryMarker = [[self libraryDirectoryInSharedDirectory:directory]
        URLByAppendingPathComponent:WCAtlasQuickReplyItemsStableRecoveryMarkerName];
    [[NSData data] writeToURL:stableRecoveryMarker options:NSDataWritingAtomic error:nil];
    return YES;
}

- (NSArray<WCAtlasQuickReplyItem *> *)items {
    @synchronized (self) {
        NSArray *loadedItems = [self loadItemsLocked];
        if (!loadedItems) {
            NSMutableArray *cachedCopies = [NSMutableArray arrayWithCapacity:self.lastKnownItems.count];
            for (WCAtlasQuickReplyItem *item in self.lastKnownItems) [cachedCopies addObject:item.copy];
            return cachedCopies;
        }
        NSArray *items = [loadedItems sortedArrayUsingComparator:^NSComparisonResult(WCAtlasQuickReplyItem *left, WCAtlasQuickReplyItem *right) {
            if (left.isPinned != right.isPinned) return left.isPinned ? NSOrderedAscending : NSOrderedDescending;
            if (left.sortIndex != right.sortIndex) return left.sortIndex < right.sortIndex ? NSOrderedAscending : NSOrderedDescending;
            return [right.createdAt compare:left.createdAt];
        }];
        NSMutableArray *copies = [NSMutableArray arrayWithCapacity:items.count];
        for (WCAtlasQuickReplyItem *item in items) [copies addObject:item.copy];
        self.lastKnownItems = copies;
        return copies;
    }
}

- (NSMutableArray<WCAtlasQuickReplyFolder *> *)loadFoldersLocked {
    NSURL *directory = [self sharedDirectoryCreatingIfNeeded:YES error:nil];
    if (!directory) return nil;
    NSURL *libraryDirectory = [self libraryDirectoryInSharedDirectory:directory];
    NSURL *migrationMarker = [libraryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersMigrationMarkerName];
    BOOL migrated = [NSFileManager.defaultManager fileExistsAtPath:migrationMarker.path];
    NSURL *stableRecoveryMarker = [libraryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersStableRecoveryMarkerName];
    BOOL stableRecoveryFinished = [NSFileManager.defaultManager fileExistsAtPath:stableRecoveryMarker.path];
    NSSet<NSString *> *deletedIdentifiers = WCAtlasQuickReplyDeletedFolderIdentifiers();
    NSMutableArray<WCAtlasQuickReplyFolder *> *folders = [NSMutableArray array];
    id defaultsValue = [NSUserDefaults.standardUserDefaults objectForKey:WCAtlasQuickReplyFoldersDefaultsKey];
    NSMutableArray<NSDictionary *> *rememberedFolders = [NSMutableArray array];
    if ([defaultsValue isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)defaultsValue) {
            if ([value isKindOfClass:NSDictionary.class]) [rememberedFolders addObject:value];
        }
    }
    NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:NO error:nil];
    NSMutableArray<NSURL *> *folderIndexURLs = [NSMutableArray arrayWithObjects:
        [directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName],
        [directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersBackupName], nil];
    if (recoveryDirectory) {
        [folderIndexURLs addObject:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]];
        [folderIndexURLs addObject:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersBackupName]];
    }
    for (NSURL *URL in folderIndexURLs) {
        NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:nil];
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![object isKindOfClass:NSArray.class]) continue;
        for (id value in (NSArray *)object) {
            if ([value isKindOfClass:NSDictionary.class]) [rememberedFolders addObject:value];
        }
    }
    NSString *(^rememberedName)(NSString *) = ^NSString *(NSString *identifier) {
        NSString *bestName = @"";
        for (NSDictionary *dictionary in rememberedFolders) {
            if (![WCAtlasQuickReplyTrimmedString(dictionary[@"id"]) isEqualToString:identifier]) continue;
            NSString *candidate = WCAtlasQuickReplyTrimmedString(dictionary[@"name"]);
            if (!candidate.length) continue;
            if (!bestName.length || ([bestName hasPrefix:@"恢复的分类 "] &&
                ![candidate hasPrefix:@"恢复的分类 "])) bestName = candidate;
        }
        return bestName;
    };
    NSArray<NSURL *> *children = [NSFileManager.defaultManager contentsOfDirectoryAtURL:libraryDirectory
                                                              includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   error:nil];
    if (!children) return nil;
    for (NSURL *child in children) {
        NSNumber *isDirectory = nil;
        [child getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue || [child.lastPathComponent isEqualToString:WCAtlasQuickReplyRootDirectoryName] ||
            [deletedIdentifiers containsObject:child.lastPathComponent]) continue;
        NSData *data = [NSData dataWithContentsOfURL:[child URLByAppendingPathComponent:WCAtlasQuickReplyFolderMetadataName]
                                             options:0 error:nil];
        id dictionary = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *name = [dictionary isKindOfClass:NSDictionary.class]
            ? WCAtlasQuickReplyTrimmedString(dictionary[@"name"]) : @"";
        if (name.length == 0) name = rememberedName(child.lastPathComponent);
        if (name.length == 0) name = [NSString stringWithFormat:@"恢复的分类 %@", [child.lastPathComponent substringToIndex:MIN((NSUInteger)8, child.lastPathComponent.length)]];
        WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyFolder new];
        folder.identifier = child.lastPathComponent;
        folder.name = name;
        folder.sortIndex = [dictionary[@"sort"] respondsToSelector:@selector(integerValue)]
            ? [dictionary[@"sort"] integerValue] : folders.count;
        [folders addObject:folder];
    }
    NSArray *defaultsFolders = rememberedFolders;
    if (migrated && !stableRecoveryFinished) {
        NSData *legacyData = [NSData dataWithContentsOfURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                                                   options:0 error:nil];
        id legacyObject = legacyData.length ? [NSJSONSerialization JSONObjectWithData:legacyData options:0 error:nil] : nil;
        if ([legacyObject isKindOfClass:NSArray.class]) {
            defaultsFolders = [defaultsFolders arrayByAddingObjectsFromArray:legacyObject];
        }
    }
    for (NSDictionary *dictionary in defaultsFolders) {
        if (![dictionary isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
        NSString *name = WCAtlasQuickReplyTrimmedString(dictionary[@"name"]);
        if (!WCAtlasQuickReplyIsSafePathComponent(identifier) || name.length == 0 ||
            [deletedIdentifiers containsObject:identifier]) continue;
        NSUInteger existingIndex = [folders indexOfObjectPassingTest:^BOOL(WCAtlasQuickReplyFolder *candidate,
                                                                            NSUInteger idx,
                                                                            BOOL *stop) {
            (void)idx; (void)stop;
            return [candidate.identifier isEqualToString:identifier];
        }];
        if (existingIndex != NSNotFound) {
            WCAtlasQuickReplyFolder *existing = folders[existingIndex];
            if ([existing.name hasPrefix:@"恢复的分类 "] &&
                ![name hasPrefix:@"恢复的分类 "]) {
                existing.name = name;
                existing.sortIndex = [dictionary[@"sort"] respondsToSelector:@selector(integerValue)]
                    ? [dictionary[@"sort"] integerValue] : existing.sortIndex;
            }
            continue;
        }
        WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyFolder new];
        folder.identifier = identifier;
        folder.name = name;
        folder.sortIndex = [dictionary[@"sort"] respondsToSelector:@selector(integerValue)]
            ? [dictionary[@"sort"] integerValue] : folders.count;
        [folders addObject:folder];
    }
    if (migrated) {
        if ([self saveFoldersLocked:folders error:nil]) {
            [[NSData data] writeToURL:stableRecoveryMarker options:NSDataWritingAtomic error:nil];
        }
        return folders;
    }

    NSArray *object = recoveryDirectory ? [self loadJSONArrayAtURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                                      backupURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersBackupName]
                                    recoveryURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                                          error:nil] : @[];
    if (!object) object = @[];
    for (NSDictionary *dictionary in object) {
        if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
        NSString *identifier = WCAtlasQuickReplyTrimmedString(dictionary[@"id"]);
        NSString *name = WCAtlasQuickReplyTrimmedString(dictionary[@"name"]);
        if (!identifier.length || !name.length) return nil;
        if ([deletedIdentifiers containsObject:identifier]) continue;
        WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyFolder new];
        folder.identifier = identifier;
        folder.name = name;
        folder.sortIndex = [dictionary[@"sort"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"sort"] integerValue] : folders.count;
        NSUInteger duplicateIndex = [folders indexOfObjectPassingTest:^BOOL(WCAtlasQuickReplyFolder *candidate, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop; return [candidate.identifier isEqualToString:folder.identifier];
        }];
        if (duplicateIndex == NSNotFound) [folders addObject:folder];
        else {
            WCAtlasQuickReplyFolder *existing = folders[duplicateIndex];
            existing.name = folder.name;
            existing.sortIndex = folder.sortIndex;
        }
    }
    [self saveFoldersLocked:folders error:nil];
    return folders;
}

- (BOOL)saveFoldersLocked:(NSArray<WCAtlasQuickReplyFolder *> *)folders error:(NSError **)error {
    NSURL *directory = [self sharedDirectoryCreatingIfNeeded:YES error:error];
    if (!directory) return NO;
    NSURL *libraryDirectory = [self libraryDirectoryInSharedDirectory:directory];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSMutableSet<NSString *> *identifiers = [NSMutableSet setWithCapacity:folders.count];
    for (WCAtlasQuickReplyFolder *folder in folders) {
        if (!WCAtlasQuickReplyIsSafePathComponent(folder.identifier) || folder.name.length == 0) {
            if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文件夹标识无效，已停止写入");
            return NO;
        }
        [identifiers addObject:folder.identifier];
        NSURL *folderDirectory = [libraryDirectory URLByAppendingPathComponent:folder.identifier isDirectory:YES];
        if (![manager createDirectoryAtURL:folderDirectory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"id": folder.identifier,
                                                                  @"name": folder.name,
                                                                  @"sort": @(folder.sortIndex)}
                                                       options:0 error:error];
        if (!data || ![data writeToURL:[folderDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFolderMetadataName]
                               options:NSDataWritingAtomic error:error]) return NO;
    }
    NSMutableArray *defaultsFolders = [NSMutableArray arrayWithCapacity:folders.count];
    for (WCAtlasQuickReplyFolder *folder in folders) {
        [defaultsFolders addObject:@{ @"id": folder.identifier,
                                      @"name": folder.name,
                                      @"sort": @(folder.sortIndex) }];
    }
    NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:YES error:error];
    NSData *foldersData = [NSJSONSerialization dataWithJSONObject:defaultsFolders options:0 error:error];
    if (!recoveryDirectory || !foldersData ||
        ![self writeJSONArrayData:foldersData
                       primaryURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                        backupURL:[directory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersBackupName]
                      recoveryURL:[recoveryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersIndexName]
                            error:error]) return NO;
    [NSUserDefaults.standardUserDefaults setObject:defaultsFolders forKey:WCAtlasQuickReplyFoldersDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSMutableSet<NSString *> *deletedIdentifiers = [WCAtlasQuickReplyDeletedFolderIdentifiers() mutableCopy];
    NSUInteger deletedCount = deletedIdentifiers.count;
    [deletedIdentifiers minusSet:identifiers];
    if (deletedIdentifiers.count != deletedCount) {
        WCAtlasQuickReplySetDeletedFolderIdentifiers(deletedIdentifiers);
    }
    NSArray<NSURL *> *children = [manager contentsOfDirectoryAtURL:libraryDirectory
                                         includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                            options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *child in children) {
        NSNumber *isDirectory = nil;
        [child getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue || [child.lastPathComponent isEqualToString:WCAtlasQuickReplyRootDirectoryName] ||
            [identifiers containsObject:child.lastPathComponent]) continue;
        [manager removeItemAtURL:[child URLByAppendingPathComponent:WCAtlasQuickReplyFolderMetadataName] error:nil];
        NSArray *remaining = [manager contentsOfDirectoryAtPath:child.path error:nil];
        if (remaining.count == 0) [manager removeItemAtURL:child error:nil];
    }
    [[NSData data] writeToURL:[libraryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersMigrationMarkerName]
                     options:NSDataWritingAtomic error:nil];
    [[NSData data] writeToURL:[libraryDirectory URLByAppendingPathComponent:WCAtlasQuickReplyFoldersStableRecoveryMarkerName]
                     options:NSDataWritingAtomic error:nil];
    return YES;
}

- (NSArray<WCAtlasQuickReplyFolder *> *)folders {
    @synchronized (self) {
        NSArray *loadedFolders = [self loadFoldersLocked];
        if (!loadedFolders) {
            NSMutableArray *cachedCopies = [NSMutableArray arrayWithCapacity:self.lastKnownFolders.count];
            for (WCAtlasQuickReplyFolder *folder in self.lastKnownFolders) [cachedCopies addObject:folder.copy];
            return cachedCopies;
        }
        NSArray *folders = [loadedFolders sortedArrayUsingComparator:^NSComparisonResult(WCAtlasQuickReplyFolder *left, WCAtlasQuickReplyFolder *right) {
            if (left.sortIndex != right.sortIndex) return left.sortIndex < right.sortIndex ? NSOrderedAscending : NSOrderedDescending;
            return [left.name localizedCompare:right.name];
        }];
        NSMutableArray *copies = [NSMutableArray arrayWithCapacity:folders.count];
        for (WCAtlasQuickReplyFolder *folder in folders) [copies addObject:folder.copy];
        self.lastKnownFolders = copies;
        return copies;
    }
}

- (WCAtlasQuickReplyFolder *)createFolderWithName:(NSString *)name error:(NSError **)error {
    NSString *trimmed = WCAtlasQuickReplyTrimmedString(name);
    if (!trimmed.length) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文件夹名称不能为空");
        return nil;
    }
    @synchronized (self) {
        NSMutableArray *folders = [self loadFoldersLocked];
        if (!folders) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        for (WCAtlasQuickReplyFolder *candidate in folders) {
            if ([candidate.name caseInsensitiveCompare:trimmed] == NSOrderedSame) return candidate.copy;
        }
        WCAtlasQuickReplyFolder *folder = [WCAtlasQuickReplyFolder new];
        folder.identifier = NSUUID.UUID.UUIDString.lowercaseString;
        folder.name = trimmed;
        folder.sortIndex = folders.count;
        [folders addObject:folder];
        return [self saveFoldersLocked:folders error:error] ? folder.copy : nil;
    }
}

- (BOOL)renameFolderWithIdentifier:(NSString *)identifier toName:(NSString *)name error:(NSError **)error {
    NSString *trimmed = WCAtlasQuickReplyTrimmedString(name);
    if (!identifier.length || !trimmed.length) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文件夹名称不能为空");
        return NO;
    }
    @synchronized (self) {
        NSMutableArray *folders = [self loadFoldersLocked];
        if (!folders) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        for (WCAtlasQuickReplyFolder *folder in folders) {
            if ([folder.identifier isEqualToString:identifier]) { folder.name = trimmed; return [self saveFoldersLocked:folders error:error]; }
        }
        return NO;
    }
}

- (BOOL)deleteFolderWithIdentifier:(NSString *)identifier error:(NSError **)error {
    if (!identifier.length) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文件夹标识无效");
        return NO;
    }
    @synchronized (self) {
        NSMutableArray *folders = [self loadFoldersLocked];
        if (!folders) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        NSIndexSet *matches = [folders indexesOfObjectsPassingTest:^BOOL(WCAtlasQuickReplyFolder *folder, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop; return [folder.identifier isEqualToString:identifier];
        }];
        if (!matches.count) {
            if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文件夹不存在或已被删除");
            return NO;
        }
        [folders removeObjectsAtIndexes:matches];
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        for (WCAtlasQuickReplyItem *item in items) if ([item.folderIdentifier isEqualToString:identifier]) item.folderIdentifier = nil;
        NSMutableSet<NSString *> *deletedIdentifiers = [WCAtlasQuickReplyDeletedFolderIdentifiers() mutableCopy];
        [deletedIdentifiers addObject:identifier];
        WCAtlasQuickReplySetDeletedFolderIdentifiers(deletedIdentifiers);
        BOOL succeeded = [self saveItemsLocked:items error:error] &&
            [self saveFoldersLocked:folders error:error];
        if (!succeeded) {
            [deletedIdentifiers removeObject:identifier];
            WCAtlasQuickReplySetDeletedFolderIdentifiers(deletedIdentifiers);
        }
        return succeeded;
    }
}

- (NSInteger)nextSortIndexForItems:(NSArray<WCAtlasQuickReplyItem *> *)items {
    NSInteger maximum = -1;
    for (WCAtlasQuickReplyItem *item in items) maximum = MAX(maximum, item.sortIndex);
    return maximum + 1;
}

- (WCAtlasQuickReplyItem *)existingItemInItems:(NSArray<WCAtlasQuickReplyItem *> *)items
                     sourceAccountIdentifier:(NSString *)sourceAccountIdentifier
                           sourceConversation:(NSString *)sourceConversation
                              sourceMessageID:(NSString *)sourceMessageID {
    NSString *conversation = WCAtlasQuickReplyTrimmedString(sourceConversation);
    NSString *messageID = WCAtlasQuickReplyTrimmedString(sourceMessageID);
    NSString *account = WCAtlasQuickReplyTrimmedString(sourceAccountIdentifier);
    if (conversation.length == 0 || messageID.length == 0) return nil;
    for (WCAtlasQuickReplyItem *item in items) {
        if ([WCAtlasQuickReplyTrimmedString(item.sourceAccountIdentifier) isEqualToString:account] &&
            [item.sourceConversation isEqualToString:conversation] &&
            [item.sourceMessageID isEqualToString:messageID]) return item;
    }
    return nil;
}

- (WCAtlasQuickReplyItem *)addText:(NSString *)text
                            title:(NSString *)title
                folderIdentifier:(NSString *)folderIdentifier
               sourceConversation:(NSString *)sourceConversation
                  sourceMessageID:(NSString *)sourceMessageID
                            error:(NSError **)error {
    NSString *trimmed = WCAtlasQuickReplyTrimmedString(text);
    if (trimmed.length == 0) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"文字内容不能为空");
        return nil;
    }
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        WCAtlasQuickReplyItem *existing = [self existingItemInItems:items
                                          sourceAccountIdentifier:WCAtlasCurrentUserWXID()
                                               sourceConversation:sourceConversation
                                                  sourceMessageID:sourceMessageID];
        if (existing) return existing.copy;
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        item.identifier = NSUUID.UUID.UUIDString.lowercaseString;
        item.type = WCAtlasQuickReplyTypeText;
        item.title = WCAtlasQuickReplyTrimmedString(title);
        item.text = trimmed;
        item.folderIdentifier = WCAtlasQuickReplyTrimmedString(folderIdentifier).length ? folderIdentifier : nil;
        item.sortIndex = [self nextSortIndexForItems:items];
        item.pinned = NO;
        item.createdAt = NSDate.date;
        item.sourceConversation = WCAtlasQuickReplyTrimmedString(sourceConversation).length > 0 ? sourceConversation : nil;
        item.sourceMessageID = WCAtlasQuickReplyTrimmedString(sourceMessageID).length > 0 ? sourceMessageID : nil;
        item.sourceAccountIdentifier = WCAtlasQuickReplyTrimmedString(WCAtlasCurrentUserWXID()).length ? WCAtlasCurrentUserWXID() : nil;
        item.metadata = @{};
        [items addObject:item];
        return [self saveItemsLocked:items error:error] ? item.copy : nil;
    }
}

- (WCAtlasQuickReplyItem *)addJavaScript:(NSString *)script
                                  title:(NSString *)title
                       folderIdentifier:(NSString *)folderIdentifier
                                  error:(NSError **)error {
    NSString *trimmed = WCAtlasQuickReplyTrimmedString(script);
    if (trimmed.length == 0) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"JS 脚本不能为空");
        return nil;
    }
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        item.identifier = NSUUID.UUID.UUIDString.lowercaseString;
        item.type = WCAtlasQuickReplyTypeJavaScript;
        item.title = WCAtlasQuickReplyTrimmedString(title);
        item.text = trimmed;
        item.folderIdentifier = WCAtlasQuickReplyTrimmedString(folderIdentifier).length ? folderIdentifier : nil;
        item.sortIndex = [self nextSortIndexForItems:items];
        item.createdAt = NSDate.date;
        item.sourceAccountIdentifier = WCAtlasQuickReplyTrimmedString(WCAtlasCurrentUserWXID()).length ? WCAtlasCurrentUserWXID() : nil;
        item.metadata = @{};
        [items addObject:item];
        return [self saveItemsLocked:items error:error] ? item.copy : nil;
    }
}

- (WCAtlasQuickReplyItem *)addMessageReferenceForConversation:(NSString *)conversation
                                                     localID:(unsigned long long)localID
                                                    serverID:(long long)serverID
                                                 messageType:(NSInteger)messageType
                                                   innerType:(NSInteger)innerType
                                                     preview:(NSString *)preview
                                                       title:(NSString *)title
                                           folderIdentifier:(NSString *)folderIdentifier
                                                       error:(NSError **)error {
    NSString *session = WCAtlasQuickReplyTrimmedString(conversation);
    if (session.length == 0 || (localID == 0 && serverID == 0)) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue,
                                                 @"消息会话或消息标识无效");
        return nil;
    }
    NSString *sourceMessageID = serverID != 0
        ? [NSString stringWithFormat:@"svr:%lld", serverID]
        : [NSString stringWithFormat:@"local:%llu", localID];
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        WCAtlasQuickReplyItem *existing = [self existingItemInItems:items
                                          sourceAccountIdentifier:WCAtlasCurrentUserWXID()
                                               sourceConversation:session
                                                  sourceMessageID:sourceMessageID];
        if (existing) return existing.copy;
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        item.identifier = NSUUID.UUID.UUIDString.lowercaseString;
        item.type = WCAtlasQuickReplyTypeMessageReference;
        item.title = WCAtlasQuickReplyTrimmedString(title);
        item.text = WCAtlasQuickReplyTrimmedString(preview);
        item.folderIdentifier = WCAtlasQuickReplyTrimmedString(folderIdentifier).length ? folderIdentifier : nil;
        item.sortIndex = [self nextSortIndexForItems:items];
        item.pinned = NO;
        item.createdAt = NSDate.date;
        item.sourceConversation = session;
        item.sourceMessageID = sourceMessageID;
        item.sourceAccountIdentifier = WCAtlasQuickReplyTrimmedString(WCAtlasCurrentUserWXID()).length
            ? WCAtlasCurrentUserWXID() : nil;
        item.metadata = @{ @"localID": @(localID),
                           @"serverID": @(serverID),
                           @"messageType": @(messageType),
                           @"innerType": @(innerType) };
        [items addObject:item];
        return [self saveItemsLocked:items error:error] ? item.copy : nil;
    }
}

- (WCAtlasQuickReplyItem *)addGroupInvitationForGroupUserName:(NSString *)groupUserName
                                                  groupName:(NSString *)groupName
                                          folderIdentifier:(NSString *)folderIdentifier
                                                      error:(NSError **)error {
    NSString *group = WCAtlasQuickReplyTrimmedString(groupUserName);
    if (![group hasSuffix:@"@chatroom"]) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"群聊标识无效");
        return nil;
    }
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        NSString *name = WCAtlasQuickReplyTrimmedString(groupName);
        if (name.length == 0) name = group;
        item.identifier = NSUUID.UUID.UUIDString.lowercaseString;
        item.type = WCAtlasQuickReplyTypeGroupInvitation;
        item.title = [NSString stringWithFormat:@"群邀请 · %@", name];
        item.text = group;
        item.folderIdentifier = WCAtlasQuickReplyTrimmedString(folderIdentifier).length ? folderIdentifier : nil;
        item.sortIndex = [self nextSortIndexForItems:items];
        item.pinned = NO;
        item.createdAt = NSDate.date;
        item.sourceAccountIdentifier = WCAtlasQuickReplyTrimmedString(WCAtlasCurrentUserWXID()).length
            ? WCAtlasCurrentUserWXID() : nil;
        item.metadata = @{ @"groupUserName": group, @"groupName": name };
        [items addObject:item];
        return [self saveItemsLocked:items error:error] ? item.copy : nil;
    }
}

- (UIImage *)thumbnailForMediaURL:(NSURL *)URL type:(WCAtlasQuickReplyType)type {
    UIImage *image = nil;
    if (type == WCAtlasQuickReplyTypeImage) {
        image = [UIImage imageWithContentsOfFile:URL.path];
    } else if (type == WCAtlasQuickReplyTypeVideo) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:URL options:nil];
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(480.0, 480.0);
        CGImageRef frame = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 600) actualTime:NULL error:nil];
        if (frame) {
            image = [UIImage imageWithCGImage:frame];
            CGImageRelease(frame);
        }
    }
    if (!image) return nil;
    CGFloat longest = MAX(image.size.width, image.size.height);
    if (longest <= 480.0) return image;
    CGFloat scale = 480.0 / longest;
    CGSize size = CGSizeMake(MAX(1.0, floor(image.size.width * scale)), MAX(1.0, floor(image.size.height * scale)));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context;
        [image drawInRect:(CGRect){CGPointZero, size}];
    }];
}

- (WCAtlasQuickReplyItem *)addMediaAtURL:(NSURL *)sourceURL
                                   type:(WCAtlasQuickReplyType)type
                                  title:(NSString *)title
                      folderIdentifier:(NSString *)folderIdentifier
                     sourceConversation:(NSString *)sourceConversation
                        sourceMessageID:(NSString *)sourceMessageID
                                  error:(NSError **)error {
    if (type != WCAtlasQuickReplyTypeImage && type != WCAtlasQuickReplyTypeVideo && type != WCAtlasQuickReplyTypeVoice) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"只支持图片、视频和语音素材");
        return nil;
    }
    NSString *sourcePath = sourceURL.path;
    BOOL isDirectory = NO;
    if (sourcePath.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:sourcePath isDirectory:&isDirectory] || isDirectory) {
        if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue, @"所选媒体文件不存在");
        return nil;
    }
    @synchronized (self) {
        NSURL *directory = [self sharedDirectoryCreatingIfNeeded:YES error:error];
        if (!directory) return nil;
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return nil; }
        WCAtlasQuickReplyItem *existing = [self existingItemInItems:items
                                          sourceAccountIdentifier:WCAtlasCurrentUserWXID()
                                               sourceConversation:sourceConversation
                                                  sourceMessageID:sourceMessageID];
        if (existing) return existing.copy;
        NSString *identifier = NSUUID.UUID.UUIDString.lowercaseString;
        NSString *extension = sourceURL.pathExtension.lowercaseString;
        if (extension.length == 0) extension = type == WCAtlasQuickReplyTypeImage ? @"jpg" : (type == WCAtlasQuickReplyTypeVideo ? @"mp4" : @"aud");
        NSString *mediaRelativePath = [@"media" stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:extension]];
        NSURL *destinationURL = [directory URLByAppendingPathComponent:mediaRelativePath];
        NSError *copyError = nil;
        if (![NSFileManager.defaultManager copyItemAtURL:sourceURL toURL:destinationURL error:&copyError]) {
            if (error) *error = copyError ?: WCAtlasQuickReplyError(WCAtlasQuickReplyErrorMediaCopyFailed, @"复制媒体文件失败");
            return nil;
        }
        NSString *thumbnailRelativePath = nil;
        UIImage *thumbnail = [self thumbnailForMediaURL:destinationURL type:type];
        NSData *thumbnailData = thumbnail ? UIImageJPEGRepresentation(thumbnail, 0.82) : nil;
        if (thumbnailData.length > 0) {
            thumbnailRelativePath = [@"thumbnails" stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"jpg"]];
            [thumbnailData writeToURL:[directory URLByAppendingPathComponent:thumbnailRelativePath]
                              options:NSDataWritingAtomic
                                error:nil];
        }
        WCAtlasQuickReplyItem *item = [WCAtlasQuickReplyItem new];
        item.identifier = identifier;
        item.type = type;
        item.title = WCAtlasQuickReplyTrimmedString(title);
        item.text = @"";
        item.folderIdentifier = WCAtlasQuickReplyTrimmedString(folderIdentifier).length ? folderIdentifier : nil;
        item.mediaRelativePath = mediaRelativePath;
        item.thumbnailRelativePath = thumbnailRelativePath;
        item.sortIndex = [self nextSortIndexForItems:items];
        item.createdAt = NSDate.date;
        item.sourceConversation = WCAtlasQuickReplyTrimmedString(sourceConversation).length > 0 ? sourceConversation : nil;
        item.sourceMessageID = WCAtlasQuickReplyTrimmedString(sourceMessageID).length > 0 ? sourceMessageID : nil;
        item.sourceAccountIdentifier = WCAtlasQuickReplyTrimmedString(WCAtlasCurrentUserWXID()).length ? WCAtlasCurrentUserWXID() : nil;
        item.metadata = @{};
        [items addObject:item];
        if ([self saveItemsLocked:items error:error]) return item.copy;
        [NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil];
        if (thumbnailRelativePath) [NSFileManager.defaultManager removeItemAtURL:[directory URLByAppendingPathComponent:thumbnailRelativePath] error:nil];
        return nil;
    }
}

- (BOOL)updateItem:(WCAtlasQuickReplyItem *)item error:(NSError **)error {
    if (item.identifier.length == 0) return NO;
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        NSUInteger index = [items indexOfObjectPassingTest:^BOOL(WCAtlasQuickReplyItem *candidate, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop;
            return [candidate.identifier isEqualToString:item.identifier];
        }];
        if (index == NSNotFound) return NO;
        WCAtlasQuickReplyItem *stored = items[index];
        stored.title = WCAtlasQuickReplyTrimmedString(item.title);
        stored.folderIdentifier = WCAtlasQuickReplyTrimmedString(item.folderIdentifier).length ? item.folderIdentifier : nil;
        stored.metadata = [item.metadata isKindOfClass:NSDictionary.class] ? item.metadata : @{};
        if (stored.type == WCAtlasQuickReplyTypeText || stored.type == WCAtlasQuickReplyTypeJavaScript) {
            NSString *text = WCAtlasQuickReplyTrimmedString(item.text);
            if (text.length == 0) {
                if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorInvalidValue,
                    stored.type == WCAtlasQuickReplyTypeJavaScript ? @"JS 脚本不能为空" : @"文字内容不能为空");
                return NO;
            }
            stored.text = text;
        }
        stored.sortIndex = item.sortIndex;
        stored.pinned = item.isPinned;
        return [self saveItemsLocked:items error:error];
    }
}

- (BOOL)applyOrderedIdentifiers:(NSArray<NSString *> *)identifiers error:(NSError **)error {
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        NSMutableDictionary<NSString *, NSNumber *> *order = [NSMutableDictionary dictionary];
        [identifiers enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger index, BOOL *stop) {
            (void)stop;
            if ([identifier isKindOfClass:NSString.class] && identifier.length > 0 && !order[identifier]) {
                order[identifier] = @(index);
            }
        }];
        NSInteger trailingIndex = (NSInteger)order.count;
        for (WCAtlasQuickReplyItem *item in items) {
            NSNumber *index = order[item.identifier];
            item.sortIndex = index ? index.integerValue : trailingIndex++;
        }
        return [self saveItemsLocked:items error:error];
    }
}

- (BOOL)setPinned:(BOOL)pinned forIdentifier:(NSString *)identifier error:(NSError **)error {
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        WCAtlasQuickReplyItem *item = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WCAtlasQuickReplyItem *candidate, NSDictionary *bindings) {
            (void)bindings;
            return [candidate.identifier isEqualToString:identifier];
        }]].firstObject;
        if (!item) return NO;
        item.pinned = pinned;
        return [self saveItemsLocked:items error:error];
    }
}

- (BOOL)recordUsageForIdentifier:(NSString *)identifier error:(NSError **)error {
    if (!identifier.length) return NO;
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        for (WCAtlasQuickReplyItem *item in items) {
            if (![item.identifier isEqualToString:identifier]) continue;
            if (item.useCount < NSUIntegerMax) item.useCount++;
            item.lastUsedAt = NSDate.date;
            return [self saveItemsLocked:items error:error];
        }
        return NO;
    }
}

- (BOOL)moveItemWithIdentifier:(NSString *)identifier
            toFolderIdentifier:(NSString *)folderIdentifier
                         error:(NSError **)error {
    if (!identifier.length) return NO;
    NSString *destination = WCAtlasQuickReplyTrimmedString(folderIdentifier);
    @synchronized (self) {
        if (destination.length) {
            BOOL folderExists = NO;
            NSArray *folders = [self loadFoldersLocked];
            if (!folders) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
            for (WCAtlasQuickReplyFolder *folder in folders) {
                if ([folder.identifier isEqualToString:destination]) { folderExists = YES; break; }
            }
            if (!folderExists) return NO;
        }
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        for (WCAtlasQuickReplyItem *item in items) {
            if (![item.identifier isEqualToString:identifier]) continue;
            item.folderIdentifier = destination.length ? destination : nil;
            return [self saveItemsLocked:items error:error];
        }
        return NO;
    }
}

- (NSString *)safeAbsolutePathForRelativePath:(NSString *)relativePath {
    if (relativePath.length == 0 || relativePath.isAbsolutePath) return nil;
    NSURL *directory = [self sharedDirectoryCreatingIfNeeded:NO error:nil];
    NSString *root = directory.URLByStandardizingPath.path;
    NSString *candidate = [[directory URLByAppendingPathComponent:relativePath] URLByStandardizingPath].path;
    NSString *prefix = [root stringByAppendingString:@"/"];
    return [candidate hasPrefix:prefix] ? candidate : nil;
}

- (NSString *)absoluteMediaPathForItem:(WCAtlasQuickReplyItem *)item {
    return [self safeAbsolutePathForRelativePath:item.mediaRelativePath];
}

- (NSString *)absoluteThumbnailPathForItem:(WCAtlasQuickReplyItem *)item {
    return [self safeAbsolutePathForRelativePath:item.thumbnailRelativePath];
}

- (BOOL)deleteItemWithIdentifier:(NSString *)identifier error:(NSError **)error {
    if (identifier.length == 0) return NO;
    @synchronized (self) {
        NSMutableArray *items = [self loadItemsLocked];
        if (!items) { WCAtlasQuickReplySetIndexReadError(error); return NO; }
        NSUInteger index = [items indexOfObjectPassingTest:^BOOL(WCAtlasQuickReplyItem *candidate, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop;
            return [candidate.identifier isEqualToString:identifier];
        }];
        if (index == NSNotFound) return NO;
        WCAtlasQuickReplyItem *item = items[index];
        [items removeObjectAtIndex:index];
        if (![self saveItemsLocked:items error:error]) return NO;
        NSURL *recoveryDirectory = [self recoveryDirectoryCreatingIfNeeded:NO error:nil];
        NSURL *sharedDirectory = [self sharedDirectoryCreatingIfNeeded:NO error:nil];
        NSString *recordName = [identifier stringByAppendingPathExtension:@"json"];
        for (NSURL *baseDirectory in @[sharedDirectory, recoveryDirectory]) {
            NSURL *recordURL = [[baseDirectory URLByAppendingPathComponent:WCAtlasQuickReplyRecordsDirectoryName isDirectory:YES]
                                URLByAppendingPathComponent:recordName];
            [NSFileManager.defaultManager removeItemAtURL:recordURL error:nil];
        }
        for (NSString *relativePath in @[item.mediaRelativePath ?: @"", item.thumbnailRelativePath ?: @""]) {
            if (![self isManagedRelativePath:relativePath]) continue;
            NSString *primaryPath = [self safeAbsolutePathForRelativePath:relativePath];
            if (primaryPath.length) [NSFileManager.defaultManager removeItemAtPath:primaryPath error:nil];
            NSURL *recoveryURL = [recoveryDirectory URLByAppendingPathComponent:relativePath];
            if (recoveryURL.path.length) [NSFileManager.defaultManager removeItemAtURL:recoveryURL error:nil];
        }
        return YES;
    }
}

- (unsigned long long)managedMediaSize {
    @synchronized (self) {
        unsigned long long total = 0;
        for (WCAtlasQuickReplyItem *item in [self loadItemsLocked]) {
            for (NSString *path in @[[self absoluteMediaPathForItem:item] ?: @"", [self absoluteThumbnailPathForItem:item] ?: @""]) {
                if (path.length == 0) continue;
                NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
                total += [attributes[NSFileSize] unsignedLongLongValue];
            }
        }
        return total;
    }
}

- (NSURL *)createExportPackageWithError:(NSError **)error {
    @synchronized (self) {
        NSArray *items = [self loadItemsLocked];
        NSArray *folders = [self loadFoldersLocked];
        if (!items || !folders) {
            WCAtlasQuickReplySetIndexReadError(error);
            return nil;
        }
        if (![self saveItemsLocked:items error:error] || ![self saveFoldersLocked:folders error:error]) return nil;
        NSURL *sharedDirectory = [self sharedDirectoryCreatingIfNeeded:NO error:error];
        if (!sharedDirectory) return nil;
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyyMMdd-HHmmss";
        NSString *name = [NSString stringWithFormat:@"WCAtlas消息库-%@.tar", [formatter stringFromDate:NSDate.date]];
        NSURL *exportsDirectory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                                   URLByAppendingPathComponent:@"WCAtlasQuickReplyExports" isDirectory:YES];
        NSURL *packageURL = [exportsDirectory URLByAppendingPathComponent:name isDirectory:NO];
        NSFileManager *manager = NSFileManager.defaultManager;
        if (![manager createDirectoryAtURL:exportsDirectory withIntermediateDirectories:YES attributes:nil error:error]) return nil;
        if ([manager fileExistsAtPath:packageURL.path] && ![manager removeItemAtURL:packageURL error:error]) return nil;
        if (![manager createFileAtPath:packageURL.path contents:nil attributes:nil]) {
            if (error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable, @"无法创建快捷回复导出文件");
            return nil;
        }
        NSFileHandle *output = [NSFileHandle fileHandleForWritingToURL:packageURL error:error];
        if (!output) return nil;
        NSDirectoryEnumerator<NSURL *> *enumerator = [manager enumeratorAtURL:sharedDirectory
                                                   includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey, NSURLContentModificationDateKey]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:nil];
        BOOL succeeded = YES;
        for (NSURL *sourceURL in enumerator) {
            NSNumber *isDirectory = nil;
            [sourceURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            if (isDirectory.boolValue) continue;
            NSString *relativePath = [sourceURL.path substringFromIndex:sharedDirectory.path.length];
            while ([relativePath hasPrefix:@"/"]) relativePath = [relativePath substringFromIndex:1];
            NSDictionary *attributes = [manager attributesOfItemAtPath:sourceURL.path error:error];
            unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
            NSData *header = WCAtlasQuickReplyTarHeader(relativePath, fileSize, attributes[NSFileModificationDate] ?: NSDate.date);
            if (!attributes || !header) { succeeded = NO; break; }
            [output writeData:header];
            NSFileHandle *input = [NSFileHandle fileHandleForReadingFromURL:sourceURL error:error];
            if (!input) { succeeded = NO; break; }
            unsigned long long written = 0;
            while (written < fileSize) {
                @autoreleasepool {
                    NSData *chunk = [input readDataOfLength:(NSUInteger)MIN(1024ULL * 1024ULL, fileSize - written)];
                    if (!chunk.length) { succeeded = NO; break; }
                    [output writeData:chunk];
                    written += chunk.length;
                }
            }
            [input closeFile];
            if (!succeeded) break;
            NSUInteger paddingLength = (NSUInteger)((512ULL - (fileSize % 512ULL)) % 512ULL);
            if (paddingLength) [output writeData:[NSMutableData dataWithLength:paddingLength]];
        }
        if (succeeded) [output writeData:[NSMutableData dataWithLength:1024]];
        [output synchronizeFile];
        [output closeFile];
        if (!succeeded) {
            [manager removeItemAtURL:packageURL error:nil];
            if (error && !*error) *error = WCAtlasQuickReplyError(WCAtlasQuickReplyErrorStorageUnavailable, @"读取快捷回复文件时导出中断");
            return nil;
        }
        return packageURL;
    }
}

@end
