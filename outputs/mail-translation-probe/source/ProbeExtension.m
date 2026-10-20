#import <AppKit/AppKit.h>
#import <MailKit/MailKit.h>
#import <NaturalLanguage/NaturalLanguage.h>
#import "MIMECore.h"

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
    // Switching to an already-active translation must not re-parse MIME or
    // run language detection again; that work made Mail's reload flash.
    NSURL *root = [self cacheRoot];
    MTCache *cache = [[MTCache alloc] initWithRoot:root];
    NSString *key = [MTMessage keyForData:data];
    NSData *activeDisplay = [cache displayForKey:key];
    if (activeDisplay && [cache hasTranslatableSourceForKey:key]) return [self decodedMessageWithDisplay:activeDisplay];
    MTMessage *message = [MTMessage messageWithData:data];
    if (!message.eligible) return nil;
    // Detect the original body, never the subject or a cached translated view.
    // Returning nil leaves Chinese MIME, layout and Mail privacy behavior untouched.
    NSString *body = [message bodyTextForLanguageRecognition];
    NLLanguage language = [NLLanguageRecognizer dominantLanguageForString:body];
    if ([language isEqual:NLLanguageSimplifiedChinese] || [language isEqual:NLLanguageTraditionalChinese]) return nil;
    // A short Chinese reply can be outweighed by an English signature or quote.
    // Conservatively leave a message starting with a Chinese paragraph untouched.
    for (NSString *line in [body componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *paragraph = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!paragraph.length) continue;
        language = [NLLanguageRecognizer dominantLanguageForString:paragraph];
        if ([language isEqual:NLLanguageSimplifiedChinese] || [language isEqual:NLLanguageTraditionalChinese]) return nil;
        break;
    }
    BOOL changed = NO;
    if (![cache rememberMessage:message changed:&changed]) return nil;
    if (![cache hasTranslatableSourceForKey:message.key]) [cache markTranslatableSourceForKey:message.key];
    NSData *display = [cache displayForKey:message.key];
    if (!display) display = [self originalViewForMessage:message];
    if (changed) {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.codex.mailtranslationprobe.cacheChanged" object:nil userInfo:nil deliverImmediately:YES];
    }
    // Original mode adds an independent inline control part around unchanged source MIME.
    if (!display) return nil;
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
