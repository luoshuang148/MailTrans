#import <AppKit/AppKit.h>
#import <MailKit/MailKit.h>
#import "MIMECore.h"
#import <NaturalLanguage/NaturalLanguage.h>
#import "MailLifecycle.h"

@interface ProbeAppDelegate : NSObject <NSApplicationDelegate>
@property NSStatusItem *statusItem;
@property(nonatomic,copy) NSString *statusText;
@property MTCache *cache;
@property MTRequestGate *gate;
@property NSArray<NSDictionary *> *recent;
@property NSString *workingKey;
@property BOOL busy;
@property NSString *providerID;
@property MTTranslationQueue *automaticQueue;
@property BOOL stopping;
@property NSTask *translationTask;
@property NSTask *languageTask;
@property NSUserDefaults *lifecyclePreferences;
@end
@implementation ProbeAppDelegate
- (void)setStatusText:(NSString *)text {
    _statusText=[text copy]?:@"";
    self.statusItem.button.toolTip=_statusText;
}
- (NSMenu *)makeStatusMenu {
    NSMenu *menu=[NSMenu new];
    NSMenuItem *clear=[[NSMenuItem alloc]initWithTitle:@"清空本地缓存" action:@selector(clearCache:) keyEquivalent:@""];clear.target=self;[menu addItem:clear];
    NSMenuItem *refresh=[[NSMenuItem alloc]initWithTitle:@"重新加载当前邮件" action:@selector(refreshAction:) keyEquivalent:@""];refresh.target=self;[menu addItem:refresh];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[[NSMenuItem alloc]initWithTitle:@"退出 MailTrans" action:@selector(quitManually:) keyEquivalent:@""];quit.target=self;[menu addItem:quit];
    return menu;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.lifecyclePreferences=[[NSUserDefaults alloc]initWithSuiteName:MTLifecycleDefaultsDomain];
    if(!self.mailSessionToken.length){[NSApp terminate:nil];return;}
    [self.lifecyclePreferences removeObjectForKey:MTManualQuitMailSession];
    self.providerID=@"apple-local";self.gate=[MTRequestGate new];self.automaticQueue=[MTTranslationQueue new];
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/local.codex.mailtranslationprobe.extension/Data/Library/Caches/MailTranslation"];
    self.cache=[[MTCache alloc]initWithRoot:[NSURL fileURLWithPath:path isDirectory:YES]];
    // Invalidate old rendered controls once when upgrading from the two-action UI.
    if(![NSUserDefaults.standardUserDefaults boolForKey:@"MTMenuOnlyMigration5"]){[self.cache clear];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"MTMenuOnlyMigration5"];}
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon=[NSImage imageWithSystemSymbolName:@"character.bubble" accessibilityDescription:@"MailTrans"];icon.template=YES;
    if(icon)self.statusItem.button.image=icon;else self.statusItem.button.title=@"译";
    self.statusItem.menu=[self makeStatusMenu];self.statusText=@"MailTrans · 就绪";
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(cacheChanged:) name:@"local.codex.mailtranslationprobe.cacheChanged" object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [self refreshState];[self scheduleAutomaticTranslations];
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cleanExpired:) userInfo:nil repeats:YES];
}
- (void)refreshState {self.recent=self.cache.recentMessages;}
- (void)cleanExpired:(NSTimer *)timer {[self refreshState];}
- (NSString *)mailSessionToken {return MTMailSessionToken([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.mail"]);}
- (void)quitManually:(id)sender {
    NSString *session=self.mailSessionToken;
    if(session.length)[self.lifecyclePreferences setObject:session forKey:MTManualQuitMailSession];
    else [self.lifecyclePreferences removeObjectForKey:MTManualQuitMailSession];
    [self.lifecyclePreferences synchronize];
    [NSApp terminate:sender];
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    @synchronized(self){
        self.stopping=YES;
        if(self.translationTask.running)[self.translationTask terminate];
        if(self.languageTask.running)[self.languageTask terminate];
    }
    [self.cache clear];
    if(self.mailSessionToken.length)[self reloadMail];
}
- (void)cacheChanged:(NSNotification *)note {dispatch_async(dispatch_get_main_queue(),^{if(!self.stopping){[self refreshState];[self scheduleAutomaticTranslations];}});}
- (void)reloadMail {
    [MEExtensionManager reloadVisibleMessagesWithCompletionHandler:^(NSError *error){
        if(error)dispatch_async(dispatch_get_main_queue(),^{self.statusText=@"Mail 暂未刷新。请重新打开这封邮件，译文已保存在本地。";});
    }];
}
- (void)refreshAction:(id)sender {[self reloadMail];[self refreshState];if(!self.recent.count)self.statusText=@"请先启用 Mail 的“MailTrans”扩展，再切换或重新打开一封普通邮件。";}
- (void)activateMail {
    [[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.mail"].firstObject activateWithOptions:0];
}
- (BOOL)shouldAutoTranslateMessage:(MTMessage *)message {
    if(!message.eligible)return NO;
    NSString *body=[message.texts componentsJoinedByString:@"\n"];
    if(body.length>20000)body=[body substringToIndex:20000];
    return [[NLLanguageRecognizer dominantLanguageForString:body]isEqual:NLLanguageEnglish];
}
- (void)scheduleAutomaticTranslations {
    if(self.stopping)return;
    for(NSDictionary *entry in self.cache.recentMessages){
        if([entry[@"translated"]boolValue]||[entry[@"original"]boolValue])continue;
        NSString *key=entry[@"key"];NSData *source=[self.cache sourceForKey:key];
        MTMessage *message=source?[MTMessage messageWithData:source]:nil;
        if([self shouldAutoTranslateMessage:message])[self.automaticQueue enqueueKey:key];
    }
    [self startNextAutomaticTranslation];
}
- (void)startNextAutomaticTranslation {
    if(self.busy||self.stopping)return;
    NSString *key=nil;
    while((key=[self.automaticQueue takeNextKey])){
        if([self.cache prefersOriginalForKey:key]||[self.cache displayForKey:key]||![self.cache sourceForKey:key])continue;
        [self translateKey:key automatic:YES];return;
    }
}
- (void)restoreKey:(NSString *)key {
    if(![MTCache isValidKey:key]){self.statusText=@"请先选择一封邮件。";return;}
    [self.gate invalidateKey:key];[self.automaticQueue cancelKey:key];[self.cache restoreKey:key];[self refreshState];[self reloadMail];
    self.statusText=@"已显示原文，可通过上方控制条随时切回中文。";[self activateMail];
}
- (NSDictionary *)runWorker:(MTMessage *)message {
    NSURL *url=[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"TranslationWorker"];
    NSTask *task=[NSTask new];task.executableURL=url;
    NSPipe *input=[NSPipe pipe],*output=[NSPipe pipe];task.standardInput=input;task.standardOutput=output;task.standardError=NSFileHandle.fileHandleWithNullDevice;
    NSError *error=nil;
    @synchronized(self){
        if(self.stopping)return @{@"errorCode":@"cancelled"};
        if(!url||![task launchAndReturnError:&error])return @{@"errorCode":@"launch_failed",@"message":@"本地翻译程序未能启动。"};
        self.translationTask=task;
    }
    @try {
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"texts":message.texts,@"target":@"zh-Hans",@"provider":self.providerID} options:0 error:nil];
    @try {[input.fileHandleForWriting writeData:data];[input.fileHandleForWriting closeFile];}
    @catch(NSException *exception){[task terminate];return @{@"errorCode":@"worker_failed",@"message":@"本地翻译未完成，原文已保留。"};}
    NSData *result=[output.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];
    id value=[NSJSONSerialization JSONObjectWithData:result options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class]?value:@{@"errorCode":@"worker_failed",@"message":@"本地翻译未完成，原文已保留。"};
    } @finally {
        @synchronized(self){if(self.translationTask==task)self.translationTask=nil;}
    }
}
- (void)translateKey:(NSString *)key {[self translateKey:key automatic:NO];}
- (void)translateKey:(NSString *)key automatic:(BOOL)automatic {
    if(self.stopping)return;
    if(![MTCache isValidKey:key]){if(!automatic){self.statusText=@"请在 Mail 中打开邮件，并点击正文上方的翻译按钮。";}else [self startNextAutomaticTranslation];return;}
    NSData *source=[self.cache sourceForKey:key];MTMessage *message=source?[MTMessage messageWithData:source]:nil;
    if(!message.eligible){if(!automatic){self.statusText=@"邮件缓存已过期或类型暂不支持，请重新打开邮件。";}else [self startNextAutomaticTranslation];return;}
    if(!automatic){
        NSData *cached=[self.cache storedDisplayForKey:key];
        if(cached&&[self.cache setDisplay:cached forKey:key]){
            [self.gate invalidateKey:key];[self.automaticQueue completeKey:key];
            self.statusText=[NSString stringWithFormat:@"已切回中文：%@",message.subject];
            [self refreshState];[self reloadMail];[self activateMail];return;
        }
    }
    if(self.busy){if(!automatic){self.statusText=@"正在翻译，请等待当前任务完成。";}return;}
    [self.automaticQueue cancelKey:key];
    NSString *requestKey=key.copy;NSUUID *token=[self.gate beginKey:requestKey];
    self.busy=YES;self.workingKey=requestKey;self.statusText=[NSString stringWithFormat:@"正在本地翻译：%@",message.subject];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSDictionary *result=[self runWorker:message];
        NSData *display=nil;
        if([result[@"translations"] isKindOfClass:NSArray.class])display=[message renderTranslations:result[@"translations"] includeControls:YES];
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.stopping)return;
            self.busy=NO;self.workingKey=nil;
            if(![self.gate isCurrent:token forKey:requestKey]){self.statusText=@"已保留原文，取消了迟到的翻译结果。";[self startNextAutomaticTranslation];return;}
            if([result[@"errorCode"] isEqual:@"model_missing"]){
                if(automatic){self.statusText=@"本邮件还缺少本地语言包。请在邮件上方点“翻译为中文”，按提示准备后继续。原文已保留。";[self startNextAutomaticTranslation];return;}
                NSString *language=[result[@"source"] isKindOfClass:NSString.class]?result[@"source"]:@"en";
                self.statusText=@"需要准备本地语言包。完成后将继续翻译这封邮件。";
                [self prepareLanguage:language completion:^(BOOL ready){
                    if(ready&&[self.gate isCurrent:token forKey:requestKey])[self translateKey:requestKey];else [self startNextAutomaticTranslation];
                }];return;
            }
            if(!display || ![self.cache setDisplay:display forKey:requestKey]){
                self.statusText=[result[@"message"] isKindOfClass:NSString.class]?result[@"message"]:@"译文未能显示，原文已保留。";[self startNextAutomaticTranslation];return;
            }
            [self.automaticQueue completeKey:requestKey];
            self.statusText=[NSString stringWithFormat:@"已翻译：%@。可随时显示原文。",message.subject];
            [self refreshState];[self reloadMail];if(!automatic)[self activateMail];[self startNextAutomaticTranslation];
        });
    });
}
- (void)prepareLanguage:(NSString *)language completion:(void (^)(BOOL))completion {
    if(self.stopping)return;
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    if(language.length>35||[language rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound){completion(NO);return;}
    NSURL *helper=[[NSBundle mainBundle].bundleURL URLByAppendingPathComponent:@"Contents/Helpers/LanguageSetup.app/Contents/MacOS/LanguageSetup"];
    self.busy=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSTask *task=[NSTask new];task.executableURL=helper;task.arguments=@[language];
        NSPipe *output=[NSPipe pipe];task.standardOutput=output;task.standardError=NSFileHandle.fileHandleWithNullDevice;
        BOOL ready=NO;NSError *error=nil;
        BOOL launched=NO;
        @synchronized(self){
            if(!self.stopping){launched=[task launchAndReturnError:&error];if(launched)self.languageTask=task;}
        }
        if(launched){
            NSData *result=[output.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];
            NSString *text=[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
            ready=task.terminationStatus==0&&[text containsString:@"MAIL_TRANSLATION_MODELS_READY"];
        }
        @synchronized(self){if(self.languageTask==task)self.languageTask=nil;}
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.stopping)return;
            self.busy=NO;self.statusText=ready?@"本地语言包已准备好。":@"语言包准备未完成，原文已保留。";
            completion(ready);
        });
    });
}
- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    for(NSURL *url in urls){
        NSString *key=url.lastPathComponent;
        if(![url.scheme.lowercaseString isEqual:@"mailtranslationprobe"]||url.query||url.fragment||
           ![url.path isEqual:[@"/" stringByAppendingString:key]]||![MTCache isValidKey:key])continue;
        NSString *action=url.host.lowercaseString;if(![@[@"translate",@"restore"] containsObject:action])continue;
        if([action isEqual:@"translate"])[self translateKey:key];else [self restoreKey:key];
    }
}
- (void)clearCache:(id)sender {
    for(NSDictionary *mail in self.cache.recentMessages){[self.gate invalidateKey:mail[@"key"]];[self.automaticQueue cancelKey:mail[@"key"]];}
    if(self.workingKey){[self.gate invalidateKey:self.workingKey];[self.automaticQueue cancelKey:self.workingKey];}
    [self.cache clear];[self refreshState];[self reloadMail];self.statusText=@"本地缓存已清空，原邮箱中的邮件未改动。";
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
@end
#ifndef MT_APP_TEST
int main(int argc,const char *argv[]) {
 @autoreleasepool {
    NSApplication *app=NSApplication.sharedApplication;
    ProbeAppDelegate *delegate=[ProbeAppDelegate new];app.delegate=delegate;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];[app run];
 }
}


#endif
