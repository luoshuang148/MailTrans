#import "ProbeExtension.m"
#import <stdio.h>
@interface FixtureExtension:MailTranslationProbeExtension
@property NSURL *fixtureRoot;
@end
@implementation FixtureExtension
-(NSURL*)cacheRoot{return self.fixtureRoot;}
@end
static NSMutableArray *MTEvents;
int main(void){@autoreleasepool {
 MTEvents=[NSMutableArray new];
 MTDecodeEventHook=^(NSString *result,NSString *reason){[MTEvents addObject:@[result,reason]];};
 NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 FixtureExtension *extension=[FixtureExtension new];extension.fixtureRoot=root;
 MTCache *cache=[[MTCache alloc]initWithRoot:root];
 NSData *source=[@"Subject: Original layout\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<!doctype html><html><body style='margin:7px'><p>The workshop begins tomorrow morning.</p></body></html>" dataUsingEncoding:NSUTF8StringEncoding];
 MTMessage *message=[MTMessage messageWithData:source];int failures=0;
 MEDecodedMessage *original=[extension decodedMessageForMessageData:source];
 if(original==nil){fputs("FAIL: original view must keep translation controls available\n",stderr);failures++;}
 if(![MTEvents.lastObject isEqual:@[@"handled",@"rendered"]]){fputs("FAIL: a usable original view must report a handled decode event\n",stderr);failures++;}
 [MTEvents removeAllObjects];
 if([extension decodedMessageForMessageData:[NSData data]]!=nil||![MTEvents.lastObject isEqual:@[@"incomplete",@"empty"]]){
  fputs("FAIL: missing MIME data must request a host retry instead of silently hiding controls\n",stderr);failures++;
 }
 if(original.securityInformation.shouldBlockRemoteContent){fputs("FAIL: original view must defer remote images to Mail privacy settings\n",stderr);failures++;}
 NSData *display=[message renderTranslations:@[@"研讨会明天上午开始。"] includeControls:YES];[cache setDisplay:display forKey:message.key activate:NO];
 MEDecodedMessage *defaultView=[extension decodedMessageForMessageData:source];
 NSRange english=[defaultView.rawData rangeOfData:[@"The workshop begins" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,defaultView.rawData.length)];
 if(defaultView==nil||[defaultView.rawData isEqual:display]||english.location==NSNotFound){fputs("FAIL: automatic translation must stay hidden until the user asks for Chinese\n",stderr);failures++;}
 [cache activateStoredDisplayForKey:message.key];
 MEDecodedMessage *chinese=[extension decodedMessageForMessageData:source];
 if(chinese==nil){fputs("FAIL: ready Chinese must use cached translated display\n",stderr);failures++;}
 if(chinese.securityInformation.shouldBlockRemoteContent){fputs("FAIL: Chinese view must defer remote images to Mail privacy settings\n",stderr);failures++;}
 [cache restoreKey:message.key];
 if([extension decodedMessageForMessageData:source]==nil){fputs("FAIL: restored original must retain controls for switching back\n",stderr);failures++;}
 if(![[cache sourceForKey:message.key]isEqual:source]){fputs("FAIL: original source bytes changed\n",stderr);failures++;}
 [cache clear];
 NSArray *chineseBodies=@[
  @"Content-Type: text/plain; charset=utf-8\r\n\r\n大家好，明天下午三点开会，请提前准备项目资料。会议结束后一起讨论下一步安排。",
  @"Content-Type: text/html; charset=utf-8\r\n\r\n<html><body><h1>Project update</h1><p>大家好，明天下午三点开会，请提前准备项目资料。会议结束后一起讨论下一步安排。</p><img src='https://example.invalid/image.png'></body></html>",
  @"Content-Type: text/plain; charset=utf-8\r\n\r\n各位同事，明天下午三點開會，請提前準備專案資料。會議結束後一起討論下一步安排。",
  @"Content-Type: text/plain; charset=utf-8\r\n\r\n你好",
  @"Content-Type: text/plain; charset=utf-8\r\n\r\n收到，谢谢。\r\n\r\nSent from my iPhone",
  @"Content-Type: text/html; charset=utf-8\r\n\r\n<html><body><p>收到，谢谢。</p><blockquote>The workshop begins tomorrow morning. Please bring the project documents.</blockquote></body></html>",
  @"Content-Type: text/html; charset=utf-8\r\n\r\n<html><body><pre>大家好，明天下午三点开会，请提前准备项目资料。会议结束后一起讨论下一步安排。</pre><p>This is an automated message.</p></body></html>",
  @"Content-Type: text/html; charset=utf-8\r\n\r\n<html><body><p><span>明</span><span>天</span><span>下</span><span>午</span><span>三</span><span>点</span><span>开</span><span>会</span><span>请</span><span>大</span><span>家</span><span>提</span><span>前</span><span>准</span><span>备</span><span>项</span><span>目</span><span>资</span><span>料</span><span>并</span><span>讨</span><span>论</span><span>下</span><span>一</span><span>步</span><span>安</span><span>排</span></p><p>Thanks.</p></body></html>"
 ];
 for(NSString *body in chineseBodies){
  NSData *input=[[@"Subject: English subject must not decide body language\r\n" stringByAppendingString:body]dataUsingEncoding:NSUTF8StringEncoding];
  if([extension decodedMessageForMessageData:input]!=nil){fputs("FAIL: Chinese source must be left to Mail without a replacement MIME or controls\n",stderr);failures++;}
  if(![MTEvents.lastObject isEqual:@[@"handled",@"chinese"]]){fputs("FAIL: intentionally skipped Chinese must stop host retries\n",stderr);failures++;}
  if([NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:0 error:nil].count){fputs("FAIL: Chinese source must not write translation cache\n",stderr);failures++;}
  [cache clear];
 }
 NSData *oldSource=[[chineseBodies.firstObject description]dataUsingEncoding:NSUTF8StringEncoding];
 MTMessage *oldChinese=[MTMessage messageWithData:oldSource];
 [cache rememberMessage:oldChinese];[cache setDisplay:[oldChinese renderTranslations:oldChinese.texts includeControls:YES] forKey:oldChinese.key];
 if([extension decodedMessageForMessageData:oldSource]!=nil){fputs("FAIL: previously cached Chinese source must still bypass the extension\n",stderr);failures++;}
 [cache clear];[NSFileManager.defaultManager removeItemAtURL:root error:nil];
 if(failures)return 1;puts("PASS: Chinese source untouched; English original/translated controls and remote-content policy preserved");return 0;
}}
