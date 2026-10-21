#import <AppKit/AppKit.h>
#import <MailKit/MailKit.h>
#import <NaturalLanguage/NaturalLanguage.h>
#import "MIMECore.h"

// The host uses this file marker to notice when Mail has restored a message
// before its MIME data is available. It contains no message content, and it is
// written only after the extension has seen a usable reading view. A distributed
// notification cannot be used here because the app extension is sandboxed.
static NSString * const MTDecodeMarkerName = @".last-handled";
static void (^MTDecodeEventHook)(NSString *, NSString *);
static void MTRecordDecodeEvent(NSString *result, NSString *reason) {
    if (MTDecodeEventHook) { MTDecodeEventHook(result, reason); return; }
    if (![result isEqual:@"handled"]) return;
    NSURL *root = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MailTranslation"] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    NSURL *marker = [root URLByAppendingPathComponent:MTDecodeMarkerName];
    NSData *stamp = [[NSString stringWithFormat:@"%f", NSDate.date.timeIntervalSince1970] dataUsingEncoding:NSUTF8StringEncoding];
    [stamp writeToURL:marker options:NSDataWritingAtomic error:nil];
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:marker.path error:nil];
}

// The extension only supplies reading data. It never edits or sends a mailbox message.
@interface MailTranslationProbeExtension : NSObject <MEExtension, MEMessageSecurityHandler>
@end
@implementation MailTranslationProbeExtension
- (NSURL *)cacheRoot {return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MailTranslation"] isDirectory:YES];}
- (id<MEMessageSecurityHandler>)handlerForMessageSecurity { return self; }
- (NSData *)originalViewForMessage:(MTMessage *)message {
    static NSCache<NSString *, NSData *> *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        views = [NSCache new];
        views.countLimit = 4;
        views.totalCostLimit = 32 * 1024 * 1024;
    });
    NSData *view = [views objectForKey:message.key];
    if (view) return view;
    view = [message renderTranslations:nil includeControls:YES];
    if (view) [views setObject:view forKey:message.key cost:view.length];
    return view;
}
- (MEDecodedMessage *)decodedMessageForMessageData:(NSData *)data {
    if (!data.length) { MTRecordDecodeEvent(@"incomplete", @"empty"); return nil; }
    // Switching to an already-active translation must not re-parse MIME or
    // run language detection again; that work made Mail's reload flash.
    NSURL *root = [self cacheRoot];
    MTCache *cache = [[MTCache alloc] initWithRoot:root];
    NSString *key = [MTMessage keyForData:data];
    NSData *activeDisplay = [cache displayForKey:key];
    if (activeDisplay && [cache hasTranslatableSourceForKey:key]) {
        MTRecordDecodeEvent(@"handled", @"active");
        return [self decodedMessageWithDisplay:activeDisplay];
    }
    MTMessage *message = [MTMessage messageWithData:data];
    if (!message) {
        BOOL oversized = data.length > 10 * 1024 * 1024;
        MTRecordDecodeEvent(oversized ? @"handled" : @"incomplete", oversized ? @"oversized" : @"unparseable");
        return nil;
    }
    if (message.malformed) { MTRecordDecodeEvent(@"incomplete", @"malformed"); return nil; }
    if (message.protectedContent) { MTRecordDecodeEvent(@"handled", @"protected"); return nil; }
    // Detect the original body, never the subject or a cached translated view.
    // Returning nil leaves Chinese MIME, layout and Mail privacy behavior untouched.
    NSString *body = [message bodyTextForLanguageRecognition];
    if (!message.eligible) {
        // An empty body usually means Mail restored the message before its MIME
        // data arrived; ask the host to retry after Mail has fetched it.
        MTRecordDecodeEvent(body.length ? @"handled" : @"incomplete", body.length ? @"ineligible" : @"empty-body");
        return nil;
    }
    NLLanguage language = [NLLanguageRecognizer dominantLanguageForString:body];
    if ([language isEqual:NLLanguageSimplifiedChinese] || [language isEqual:NLLanguageTraditionalChinese]) {
        MTRecordDecodeEvent(@"handled", @"chinese");
        return nil;
    }
    // A short Chinese reply can be outweighed by an English signature or quote.
    // Conservatively leave a message starting with a Chinese paragraph untouched.
    for (NSString *line in [body componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *paragraph = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!paragraph.length) continue;
        language = [NLLanguageRecognizer dominantLanguageForString:paragraph];
        if ([language isEqual:NLLanguageSimplifiedChinese] || [language isEqual:NLLanguageTraditionalChinese]) {
            MTRecordDecodeEvent(@"handled", @"chinese");
            return nil;
        }
        break;
    }
    BOOL changed = NO;
    if (![cache rememberMessage:message changed:&changed]) { MTRecordDecodeEvent(@"incomplete", @"cache"); return nil; }
    if (![cache hasTranslatableSourceForKey:message.key]) [cache markTranslatableSourceForKey:message.key];
    NSData *display = [cache displayForKey:message.key];
    if (!display) display = [self originalViewForMessage:message];
    if (changed) {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.codex.mailtranslationprobe.cacheChanged" object:nil userInfo:nil deliverImmediately:YES];
    }
    // Original mode adds an independent inline control part around unchanged source MIME.
    if (!display) { MTRecordDecodeEvent(@"incomplete", @"render"); return nil; }
    MTRecordDecodeEvent(@"handled", @"rendered");
    return [self decodedMessageWithDisplay:display];
}
- (MEDecodedMessage *)decodedMessageWithDisplay:(NSData *)display {
    MEMessageSecurityInformation *security = [[MEMessageSecurityInformation alloc]
        initWithSigners:@[] isEncrypted:NO signingError:nil encryptionError:nil
        shouldBlockRemoteContent:NO localizedRemoteContentBlockingReason:nil];
    return [[MEDecodedMessage alloc] initWithData:display securityInformation:security context:nil banner:nil];
}
- (void)primaryActionClickedForMessageContext:(NSData *)context completionHandler:(void (^)(MEExtensionViewController *))completionHandler { completionHandler(nil); }
- (MEExtensionViewController *)extensionViewControllerForMessageContext:(NSData *)context { return nil; }
- (MEExtensionViewController *)extensionViewControllerForMessageSigners:(NSArray<MEMessageSigner *> *)signers { return nil; }
- (void)getEncodingStatusForMessage:(MEMessage *)message composeContext:(MEComposeContext *)context completionHandler:(void (^)(MEOutgoingMessageEncodingStatus *))completionHandler {
    completionHandler([[MEOutgoingMessageEncodingStatus alloc] initWithCanSign:NO canEncrypt:NO securityError:nil addressesFailingEncryption:@[]]);
}
- (void)encodeMessage:(MEMessage *)message composeContext:(MEComposeContext *)context completionHandler:(void (^)(MEMessageEncodingResult *))completionHandler {
    completionHandler([[MEMessageEncodingResult alloc] initWithEncodedMessage:nil signingError:nil encryptionError:nil]);
}
@end
