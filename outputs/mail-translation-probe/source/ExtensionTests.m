#import "ProbeExtension.m"
#import <stdio.h>
@interface FixtureExtension:MailTranslationProbeExtension
@property NSURL *fixtureRoot;
@end
@implementation FixtureExtension
-(NSURL*)cacheRoot{return self.fixtureRoot;}
@end
int main(void){@autoreleasepool {
 NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 FixtureExtension *extension=[FixtureExtension new];extension.fixtureRoot=root;
 MTCache *cache=[[MTCache alloc]initWithRoot:root];
 NSData *source=[@"Subject: Original layout\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<!doctype html><html><body style='margin:7px'><p>The workshop begins tomorrow morning.</p></body></html>" dataUsingEncoding:NSUTF8StringEncoding];
 MTMessage *message=[MTMessage messageWithData:source];int failures=0;
 MEDecodedMessage *original=[extension decodedMessageForMessageData:source];
 if(original==nil){fputs("FAIL: original view must keep translation controls available\n",stderr);failures++;}
 if(original.securityInformation.shouldBlockRemoteContent){fputs("FAIL: original view must defer remote images to Mail privacy settings\n",stderr);failures++;}
 NSData *display=[message renderTranslations:@[@"研讨会明天上午开始。"] includeControls:YES];[cache setDisplay:display forKey:message.key];
 MEDecodedMessage *chinese=[extension decodedMessageForMessageData:source];
 if(chinese==nil){fputs("FAIL: ready Chinese must use cached translated display\n",stderr);failures++;}
 if(chinese.securityInformation.shouldBlockRemoteContent){fputs("FAIL: Chinese view must defer remote images to Mail privacy settings\n",stderr);failures++;}
 [cache restoreKey:message.key];
 if([extension decodedMessageForMessageData:source]==nil){fputs("FAIL: restored original must retain controls for switching back\n",stderr);failures++;}
 if(![[cache sourceForKey:message.key]isEqual:source]){fputs("FAIL: original source bytes changed\n",stderr);failures++;}
 [cache clear];if(failures)return 1;puts("PASS: controls in original and Chinese views, unchanged original MIME");return 0;
}}
