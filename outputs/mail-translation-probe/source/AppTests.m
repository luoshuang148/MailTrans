#define MT_APP_TEST 1
#import "ProbeApp.m"
#import <stdio.h>
@interface UIProbe:ProbeAppDelegate
@property NSDictionary *workerResult;
@end
@implementation UIProbe
-(void)activateMail{}
-(void)reloadMail{}
-(NSDictionary*)runWorker:(MTMessage*)message{return self.workerResult?:@{@"errorCode":@"launch_failed",@"message":@"Test worker unavailable"};}
@end
int main(void) {@autoreleasepool {
 [NSApplication sharedApplication];NSUInteger initialWindows=NSApp.windows.count;
 ProbeAppDelegate *delegate=[ProbeAppDelegate new];
 NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 delegate.cache=[[MTCache alloc]initWithRoot:root];
 NSMutableSet *keys=[NSMutableSet new];
 for(NSString *body in @[@"First body.",@"Second body.",@"Third body."]){
  NSString *raw=[NSString stringWithFormat:@"Subject: Same subject\r\nContent-Type: text/plain\r\n\r\n%@",body];
  MTMessage *mail=[MTMessage messageWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]];
  [delegate.cache rememberMessage:mail];[keys addObject:mail.key];
 }
 NSMenu *statusMenu=[delegate makeStatusMenu];BOOL clearFound=NO,panelFound=NO;
 for(NSMenuItem *item in statusMenu.itemArray){if(item.action==@selector(clearCache:))clearFound=YES;if([item.title containsString:@"面板"])panelFound=YES;}
 BOOL menuOkay=clearFound&&!panelFound;if(!menuOkay)fputs("FAIL: menu bar must offer clear cache without a translation panel\n",stderr);
 BOOL okay=menuOkay;
 NSString *english=@"Content-Type: text/plain; charset=utf-8\r\n\r\nThe workshop has moved to Thursday morning. Please bring the revised schedule for our meeting.";
 NSString *chinese=@"Content-Type: text/plain; charset=utf-8\r\n\r\n这封邮件本来就是中文，不应该自动调用英中翻译。";
 if(![delegate shouldAutoTranslateMessage:[MTMessage messageWithData:[english dataUsingEncoding:NSUTF8StringEncoding]]] || [delegate shouldAutoTranslateMessage:[MTMessage messageWithData:[chinese dataUsingEncoding:NSUTF8StringEncoding]]]){
  fputs("FAIL: automatic policy must select English and leave Chinese unchanged\n",stderr);okay=NO;
 }
 UIProbe *automatic=[UIProbe new];automatic.cache=delegate.cache;automatic.gate=[MTRequestGate new];automatic.automaticQueue=[MTTranslationQueue new];
 automatic.statusText=@"";
 NSString *existingKey=keys.anyObject;
 [automatic.automaticQueue enqueueKey:existingKey];
 [automatic translateKey:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0] automatic:YES];
 if(NSApp.windows.count!=initialWindows||!automatic.busy){fputs("FAIL: expired automatic request must drain queue without showing panel\n",stderr);okay=NO;}
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:2];
 while(automatic.busy&&[deadline timeIntervalSinceNow]>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 automatic.workerResult=@{@"provider":@"apple-local",@"errorCode":@"model_missing",@"source":@"fr",@"target":@"zh-Hans",@"message":@"需要本地语言包。"};
 [automatic translateKey:existingKey automatic:YES];deadline=[NSDate dateWithTimeIntervalSinceNow:2];
 while(automatic.busy&&[deadline timeIntervalSinceNow]>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 if(![automatic.statusText containsString:@"翻译为中文"]||[automatic.statusText containsString:@"英中语言包"]){fputs("FAIL: missing non-English quoted-language model must direct to correct manual setup action\n",stderr);okay=NO;}
 NSData *cachedChinese=[@"Cached Chinese MIME display" dataUsingEncoding:NSUTF8StringEncoding];
 [automatic.cache setDisplay:cachedChinese forKey:existingKey];[automatic.cache restoreKey:existingKey];
 [automatic translateKey:existingKey];
 if(automatic.busy||![[automatic.cache displayForKey:existingKey]isEqual:cachedChinese]){fputs("FAIL: switching back to Chinese must reuse existing translation immediately\n",stderr);okay=NO;}
 [automatic.cache restoreKey:existingKey];automatic.busy=YES;
 [automatic translateKey:existingKey];
 if(!automatic.busy||![[automatic.cache displayForKey:existingKey]isEqual:cachedChinese]){fputs("FAIL: cached switching must work while another translation is busy\n",stderr);okay=NO;}
 automatic.busy=NO;
 NSString *evictedKey=[@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0];
 NSUUID *late=[automatic.gate beginKey:evictedKey];automatic.workingKey=evictedKey;
 [automatic clearCache:nil];
 if([automatic.gate isCurrent:late forKey:evictedKey]||automatic.cache.recentMessages.count){fputs("FAIL: clear cache must cancel even an evicted in-flight message\n",stderr);okay=NO;}
 [delegate.cache clear];
 if(!okay)return 1;
 puts("PASS: menu-only UI, English automatic policy, language setup guidance, cached switching and safe cache clearing");return 0;
}}
