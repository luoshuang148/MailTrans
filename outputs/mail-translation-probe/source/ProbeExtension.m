#import <AppKit/AppKit.h>
#import <MailKit/MailKit.h>
#import "MIMECore.h"

// The extension only supplies reading data. It never edits or sends a mailbox message.
@interface MailTranslationProbeExtension : NSObject <MEExtension, MEMessageSecurityHandler>
@end
@implementation MailTranslationProbeExtension
- (NSURL *)cacheRoot {return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MailTranslation"] isDirectory:YES];}
- (id<MEMessageSecurityHandler>)handlerForMessageSecurity { return self; }
- (MEDecodedMessage *)decodedMessageForMessageData:(NSData *)data {
    MTMessage *message = [MTMessage messageWithData:data];
    if (!message.eligible) return nil;
    NSData *display = nil;
    @synchronized(MailTranslationProbeExtension.class) {
        NSURL *root = [self cacheRoot];
        MTCache *cache = [[MTCache alloc] initWithRoot:root];
        if (![cache rememberMessage:message]) return nil;
        display = [cache displayForKey:message.key];
        if(!display)display=[message renderTranslations:nil includeControls:YES];
    }
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.codex.mailtranslationprobe.cacheChanged" object:nil userInfo:nil deliverImmediately:YES];
    // Original mode adds an independent inline control part around unchanged source MIME.
    if (!display) return nil;
    // Leave remote-content decisions to Mail and its existing privacy settings in both views.
    MEMessageSecurityInformation *security = [[MEMessageSecurityInformation alloc]
        initWithSigners:@[] isEncrypted:NO signingError:nil encryptionError:nil
        shouldBlockRemoteContent:NO localizedRemoteContentBlockingReason:nil];
    // The custom reading links use the containing app; no unstable MailKit banner UI.
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

