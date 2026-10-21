#define MT_APP_TEST 1
#import "ProbeApp.m"
#import <stdio.h>
@interface TestApplication:NSApplication
@property BOOL terminationRequested;
@property(copy) void(^terminationObserver)(void);
@end
@implementation TestApplication
-(void)terminate:(id)sender {self.terminationRequested=YES;if(self.terminationObserver)self.terminationObserver();}
@end
@interface ProbeAppDelegate (PublicPreviewTests)
- (BOOL)automaticTranslationEnabled;
- (void)toggleAutomaticTranslation:(id)sender;
- (void)cancelCurrentTranslation:(id)sender;
- (void)retryLastFailure:(id)sender;
- (void)showSetup;
- (NSUserDefaults *)appPreferences;
- (NSURL *)cacheURL;
- (void)attemptDecodeRecovery;
- (BOOL)hasFreshDecodeMarker;
@end
@interface UIProbe:ProbeAppDelegate
@property NSDictionary *workerResult;
@property NSUInteger workerCalls;
@property NSUInteger setupCalls;
@property NSUInteger reloadCalls;
@end
@implementation UIProbe
-(void)activateMail{}
-(void)reloadMail{self.reloadCalls++;}
-(BOOL)extensionProcessRunning{return YES;}
-(void)showSetup{self.setupCalls++;}
-(NSUserDefaults *)appPreferences{return self.lifecyclePreferences;}
-(NSURL *)cacheURL{return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"mailtrans-startup-test-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];}
-(NSString *)mailSessionToken{return @"test-mail-session";}
-(NSDictionary*)runWorker:(MTMessage*)message{self.workerCalls++;return self.workerResult?:@{@"errorCode":@"launch_failed",@"message":@"Test worker unavailable"};}
@end
@interface ClosedMailProbe:UIProbe
@end
@implementation ClosedMailProbe
-(NSString *)mailSessionToken{return @"";}
@end
int main(void) {@autoreleasepool {
 [TestApplication sharedApplication];NSUInteger initialWindows=NSApp.windows.count;
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
 // Quitting while translating must not leave our subprocesses running.
 if(![automatic respondsToSelector:NSSelectorFromString(@"setTranslationTask:")]||
    ![automatic respondsToSelector:NSSelectorFromString(@"setLanguageTask:")]){
  fputs("FAIL: host shutdown must own and terminate translation/language processes\n",stderr);okay=NO;
 }else{
  NSTask *worker=[NSTask new],*language=[NSTask new];
  for(NSTask *task in @[worker,language]){task.executableURL=[NSURL fileURLWithPath:@"/bin/sleep"];task.arguments=@[@"30"];[task launchAndReturnError:nil];}
  [automatic setValue:worker forKey:@"translationTask"];[automatic setValue:language forKey:@"languageTask"];
  [automatic applicationWillTerminate:[NSNotification notificationWithName:NSApplicationWillTerminateNotification object:NSApp]];
  NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];
  while((worker.running||language.running)&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
  if(worker.running||language.running||!automatic.stopping||automatic.cache.recentMessages.count){fputs("FAIL: quitting must stop owned children and clear cache\n",stderr);okay=NO;}
  for(NSTask *task in @[worker,language])if(task.running)[task terminate];
 }
 if(![automatic respondsToSelector:NSSelectorFromString(@"quitManually:")]||
    ![automatic respondsToSelector:NSSelectorFromString(@"setLifecyclePreferences:")]){
  fputs("FAIL: manual quit must persist Mail session suppression before terminating\n",stderr);okay=NO;
 }else{
  NSString *suite=[@"local.mailtrans.tests.quit."stringByAppendingString:NSUUID.UUID.UUIDString];
  NSUserDefaults *preferences=[[NSUserDefaults alloc]initWithSuiteName:suite];
  [automatic setValue:preferences forKey:@"lifecyclePreferences"];
  __block BOOL savedBeforeExit=NO;
  ((TestApplication *)NSApp).terminationObserver=^{savedBeforeExit=[[preferences stringForKey:@"MTManualQuitMailSession"]isEqual:@"test-mail-session"];};
  [automatic quitManually:nil];
  if(![(TestApplication *)NSApp terminationRequested]||!savedBeforeExit){fputs("FAIL: manual quit must save suppression before requesting normal termination\n",stderr);okay=NO;}
  ((TestApplication *)NSApp).terminationObserver=nil;
  [preferences removePersistentDomainForName:suite];
 }
 // New-user controls must not depend on real Mail, models, or production preferences.
 if(![delegate respondsToSelector:@selector(automaticTranslationEnabled)]||![delegate respondsToSelector:@selector(retryLastFailure:)]){
  fputs("FAIL: persistent automatic pause and explicit failure retry are missing\n",stderr);okay=NO;
 }else{
  NSString *suite=[@"local.mailtrans.tests.controls."stringByAppendingString:NSUUID.UUID.UUIDString];
  NSUserDefaults *prefs=[[NSUserDefaults alloc]initWithSuiteName:suite];
  UIProbe *control=[UIProbe new];control.lifecyclePreferences=prefs;
  control.cache=[[MTCache alloc]initWithRoot:[root URLByAppendingPathComponent:@"controls"]];control.gate=[MTRequestGate new];control.automaticQueue=[MTTranslationQueue new];
  MTMessage *mail=[MTMessage messageWithData:[english dataUsingEncoding:NSUTF8StringEncoding]];[control.cache rememberMessage:mail];
  if(!control.automaticTranslationEnabled){fputs("FAIL: automatic translation must default to enabled\n",stderr);okay=NO;}
  [control toggleAutomaticTranslation:nil];[control scheduleAutomaticTranslations];
  if(control.automaticTranslationEnabled||control.busy||control.workerCalls){fputs("FAIL: paused mode must not enqueue automatic work\n",stderr);okay=NO;}
  UIProbe *reopened=[UIProbe new];reopened.lifecyclePreferences=prefs;
  if(reopened.automaticTranslationEnabled){fputs("FAIL: pause must persist across host instances\n",stderr);okay=NO;}
  control.workerResult=@{@"translations":@[@"研讨会已改至周四上午，请携带修订日程。"]};
  [control translateKey:mail.key];deadline=[NSDate dateWithTimeIntervalSinceNow:2];
  while(control.busy&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  if(control.workerCalls!=1||![control.cache displayForKey:mail.key]){fputs("FAIL: manual translation must still work while paused\n",stderr);okay=NO;}
  UIProbe *autoDefault=[UIProbe new];autoDefault.cache=[[MTCache alloc]initWithRoot:[root URLByAppendingPathComponent:@"auto-default"]];autoDefault.gate=[MTRequestGate new];autoDefault.automaticQueue=[MTTranslationQueue new];
  [autoDefault.cache rememberMessage:mail];autoDefault.workerResult=@{@"translations":@[@"默认隐藏的自动译文。"]};
  [autoDefault translateKey:mail.key automatic:YES];deadline=[NSDate dateWithTimeIntervalSinceNow:2];
  while(autoDefault.busy&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  if(![autoDefault.cache storedDisplayForKey:mail.key]||[autoDefault.cache displayForKey:mail.key]){fputs("FAIL: automatic translation must stay cached but show the original by default\n",stderr);okay=NO;}
  [control.cache clear];[control.cache rememberMessage:mail];control.workerResult=@{@"errorCode":@"timeout",@"message":@"Timed out"};
  [control translateKey:mail.key];deadline=[NSDate dateWithTimeIntervalSinceNow:2];
  while(control.busy&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  if(![[control valueForKey:@"lastFailedKey"]isEqual:mail.key]||![[control valueForKey:@"hasFailure"]boolValue]){fputs("FAIL: timeout must retain exact retry key and visible error state\n",stderr);okay=NO;}
  if(![[control valueForKey:@"lastFailureCode"]isEqual:@"timeout"]||![[control valueForKey:@"lastFailureMessage"]isEqual:@"Timed out"]||![[prefs stringForKey:@"MTLastFailureCode"]isEqual:@"timeout"]||![[prefs stringForKey:@"MTLastFailureCacheKey"]isEqual:mail.key]){
    fputs("FAIL: failure code, message and exact cache key must be persisted for diagnosis\n",stderr);okay=NO;
  }
  NSMenu *failureMenu=[control makeStatusMenu];BOOL failureInfoFound=NO,dismissFound=NO;
  for(NSMenuItem *item in failureMenu.itemArray){
    if(!item.enabled&&[item.title hasPrefix:@"上次失败："])failureInfoFound=YES;
    if(item.action==@selector(dismissFailure:))dismissFound=YES;
  }
  if(!failureInfoFound||!dismissFound){fputs("FAIL: menu must expose the persisted failure reason and a dismissal action\n",stderr);okay=NO;}
  UIProbe *restored=[UIProbe new];restored.lifecyclePreferences=prefs;restored.cache=control.cache;[restored restoreLastFailure];
  if(![[restored valueForKey:@"hasFailure"]boolValue]||![[restored valueForKey:@"lastFailureCode"]isEqual:@"timeout"]){fputs("FAIL: a recent failure must restore across host instances\n",stderr);okay=NO;}
  control.workerResult=@{@"translations":@[@"重试后的译文。"]};[control retryLastFailure:nil];deadline=[NSDate dateWithTimeIntervalSinceNow:2];
  while(control.busy&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  if(![control.cache displayForKey:mail.key]||[[control valueForKey:@"hasFailure"]boolValue]||[prefs objectForKey:@"MTLastFailureCode"]||[prefs objectForKey:@"MTLastFailureMessage"]){fputs("FAIL: explicit retry must recover the same message and clear persisted error state\n",stderr);okay=NO;}
  [control recordFailure:@"Dismissed diagnostic" key:mail.key code:@"test_dismiss"];[control dismissFailure:nil];
  if([[control valueForKey:@"hasFailure"]boolValue]||[[control valueForKey:@"lastFailureMessage"]length]||![control.cache hasSourceForKey:mail.key]){fputs("FAIL: dismissing a failure must preserve the cache and clear the error state\n",stderr);okay=NO;}
  [control setValue:mail.key forKey:@"lastFailedKey"];[control.cache clear];NSUInteger calls=control.workerCalls;[control retryLastFailure:nil];
  if(control.workerCalls!=calls||![control.statusText containsString:@"重新打开"]){fputs("FAIL: expired retry must request reopening rather than translate another message\n",stderr);okay=NO;}
  [control.cache rememberMessage:mail];control.workingKey=mail.key;control.busy=YES;[control setValue:@YES forKey:@"workingAutomatic"];
  NSUUID *token=[control.gate beginKey:mail.key];
  // Persisted mode is paused; enable then pause an active automatic operation.
  [prefs setBool:YES forKey:@"MTAutomaticTranslationEnabled"];[control toggleAutomaticTranslation:nil];
  if([control.gate isCurrent:token forKey:mail.key]){fputs("FAIL: pausing automatic translation must invalidate active results\n",stderr);okay=NO;}
  [control.cache clear];[prefs removePersistentDomainForName:suite];
 }
 if(![delegate respondsToSelector:@selector(showSetup)]||![delegate respondsToSelector:@selector(appPreferences)]||![delegate respondsToSelector:@selector(cacheURL)]){
  fputs("FAIL: setup must remain accessible when Mail is closed\n",stderr);okay=NO;
 }else{
  NSString *suite=[@"local.mailtrans.tests.setup."stringByAppendingString:NSUUID.UUID.UUIDString];
  ClosedMailProbe *closed=[ClosedMailProbe new];closed.lifecyclePreferences=[[NSUserDefaults alloc]initWithSuiteName:suite];
  ((TestApplication *)NSApp).terminationRequested=NO;[closed applicationDidFinishLaunching:[NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification object:NSApp]];
  if(((TestApplication *)NSApp).terminationRequested||closed.setupCalls!=1){fputs("FAIL: launch without Mail must show setup and remain running\n",stderr);okay=NO;}
  [closed.cache clear];[closed.lifecyclePreferences removePersistentDomainForName:suite];
  if(closed.statusItem)[NSStatusBar.systemStatusBar removeStatusItem:closed.statusItem];
 }
 // Mail can restore the previous message before its MIME data exists. The
 // host must then reload the visible message until the extension has cached it,
 // instead of waiting for the user to restart Mail.
 UIProbe *recovery=[UIProbe new];
 recovery.cache=[[MTCache alloc]initWithRoot:[root URLByAppendingPathComponent:@"decode-recovery"]];
 recovery.decodeRecoveryStartedAt=NSDate.date.timeIntervalSince1970;
 [recovery attemptDecodeRecovery];
 if(recovery.reloadCalls!=1||!recovery.decodeRecoveryInFlight){
  fputs("FAIL: an empty cache must trigger a visible-message reload\n",stderr);okay=NO;
 }
 recovery.stopping=YES;
 UIProbe *handled=[UIProbe new];
 handled.cache=[[MTCache alloc]initWithRoot:[root URLByAppendingPathComponent:@"decode-recovery-handled"]];
 NSString *stamp=[NSString stringWithFormat:@"%f",NSDate.date.timeIntervalSince1970];
 [stamp writeToURL:[handled.cache.root URLByAppendingPathComponent:@".last-handled"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 handled.decodeRecoveryStartedAt=NSDate.date.timeIntervalSince1970-10;
 [handled attemptDecodeRecovery];
 if(handled.reloadCalls||!handled.decodeRecoveryDone){
  fputs("FAIL: an extension-handled message must not force another reload\n",stderr);okay=NO;
 }
 if(!okay)return 1;
 puts("PASS: menu-only UI, English automatic policy, language setup guidance, cached switching and safe cache clearing");return 0;
}}
