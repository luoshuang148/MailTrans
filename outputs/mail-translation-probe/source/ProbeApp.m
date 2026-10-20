#import <AppKit/AppKit.h>
#import <MailKit/MailKit.h>
#import "MIMECore.h"
#import <NaturalLanguage/NaturalLanguage.h>
#import "MailLifecycle.h"
#import "MTProcessRunner.h"
#import "MTSetupController.h"

@interface ProbeAppDelegate : NSObject <NSApplicationDelegate, NSMenuItemValidation>
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
@property MTProcessRunner *translationRunner;
@property MTProcessRunner *languageRunner;
@property MTSetupController *setupController;
@property BOOL workingAutomatic;
@property BOOL hasFailure;
@property(copy) NSString *lastFailedKey;
@property BOOL scanScheduled;
@property BOOL scanAgain;
@end
static dispatch_queue_t MTBackgroundWorkQueue(void){
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once,^{queue=dispatch_queue_create("local.codex.mailtranslationprobe.background",DISPATCH_QUEUE_SERIAL);});
    return queue;
}
@implementation ProbeAppDelegate
- (void)setStatusText:(NSString *)text {
    _statusText=[text copy]?:@"";
    self.statusItem.button.toolTip=_statusText;
    [self updateStatusIcon];
}
- (NSURL *)cacheURL {return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/local.codex.mailtranslationprobe.extension/Data/Library/Caches/MailTranslation"] isDirectory:YES];}
- (NSUserDefaults *)appPreferences {return [MTMailLifecycle preferencesForDomain:MTLifecycleDefaultsDomain];}
- (BOOL)automaticTranslationEnabled {
    id value=[self.lifecyclePreferences objectForKey:@"MTAutomaticTranslationEnabled"];
    return value?[value boolValue]:YES;
}
- (void)updateStatusIcon {
    NSString *symbol=self.hasFailure?@"exclamationmark.bubble":(self.automaticTranslationEnabled?@"character.bubble":@"pause.circle");
    NSImage *icon=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:self.hasFailure?@"MailTrans · 请检查翻译状态":@"MailTrans"];
    icon.template=YES;if(icon)self.statusItem.button.image=icon;
}
- (void)recordFailure:(NSString *)text key:(NSString *)key {
    self.hasFailure=YES;if([MTCache isValidKey:key])self.lastFailedKey=key;
    self.statusText=text;
}
- (void)cancelTranslationForKey:(NSString *)key {
    if(!key.length)return;
    [self.gate invalidateKey:key];[self.automaticQueue cancelKey:key];
    @synchronized(self){if([self.workingKey isEqual:key]){[self.translationRunner cancel];if(self.translationTask.running)[self.translationTask terminate];}}
}
- (void)cancelCurrentTranslation:(id)sender {
    [self cancelTranslationForKey:self.workingKey];
    self.statusText=@"已取消当前翻译，原文已保留。";
}
- (void)toggleAutomaticTranslation:(id)sender {
    BOOL enabled=!self.automaticTranslationEnabled;
    [self.lifecyclePreferences setBool:enabled forKey:@"MTAutomaticTranslationEnabled"];[self.lifecyclePreferences synchronize];
    if(!enabled){
        self.automaticQueue=[MTTranslationQueue new];
        if(self.workingAutomatic)[self cancelTranslationForKey:self.workingKey];
    }
    self.statusText=enabled?@"英文自动翻译已开启。":@"自动翻译已暂停，仍可点击邮件中的按钮手动翻译。";
    if(enabled){self.automaticQueue=[MTTranslationQueue new];[self scheduleAutomaticTranslations];}
}
- (void)retryLastFailure:(id)sender {
    NSString *key=self.lastFailedKey.copy;
    if(!key.length||![self.cache hasSourceForKey:key]){[self recordFailure:@"这封邮件缓存已过期，请在 Mail 中重新打开后再翻译。" key:nil];return;}
    [self translateKey:key];
}
- (void)showSetup {
    if(!self.setupController){
        self.setupController=[[MTSetupController alloc]initWithPreferences:self.lifecyclePreferences];
        __weak ProbeAppDelegate *weakSelf=self;
        self.setupController.languagePreparationHandler=^{[weakSelf prepareLanguage:@"en" completion:^(BOOL ready){if(ready)[weakSelf scheduleAutomaticTranslations];}];};
        self.setupController.cacheClearHandler=^{[weakSelf clearCache:nil];};
        self.setupController.quitHandler=^{[weakSelf quitManually:nil];};
    }
    [self.setupController showWindow];
}
- (void)showSetupAction:(id)sender {[self showSetup];}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if(item.action==@selector(toggleAutomaticTranslation:)){item.state=self.automaticTranslationEnabled?NSControlStateValueOn:NSControlStateValueOff;return YES;}
    if(item.action==@selector(cancelCurrentTranslation:))return self.busy&&self.workingKey.length;
    if(item.action==@selector(retryLastFailure:))return !self.busy&&self.lastFailedKey.length;
    return YES;
}
- (NSMenu *)makeStatusMenu {
    NSMenu *menu=[NSMenu new];
    NSMenuItem *clear=[[NSMenuItem alloc]initWithTitle:@"清空本地缓存" action:@selector(clearCache:) keyEquivalent:@""];clear.target=self;[menu addItem:clear];
    NSMenuItem *refresh=[[NSMenuItem alloc]initWithTitle:@"重新加载当前邮件" action:@selector(refreshAction:) keyEquivalent:@""];refresh.target=self;[menu addItem:refresh];
    [menu addItem:NSMenuItem.separatorItem];
    for(NSDictionary *entry in @[@{@"title":@"自动翻译英文邮件",@"action":NSStringFromSelector(@selector(toggleAutomaticTranslation:))},
                                @{@"title":@"取消当前翻译",@"action":NSStringFromSelector(@selector(cancelCurrentTranslation:))},
                                @{@"title":@"重试上次失败的邮件",@"action":NSStringFromSelector(@selector(retryLastFailure:))},
                                @{@"title":@"设置与帮助…",@"action":NSStringFromSelector(@selector(showSetupAction:))}]){
        NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""];item.target=self;[menu addItem:item];
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[[NSMenuItem alloc]initWithTitle:@"退出 MailTrans" action:@selector(quitManually:) keyEquivalent:@""];quit.target=self;[menu addItem:quit];
    return menu;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.lifecyclePreferences=[self appPreferences];
    if(!self.mailSessionToken.length&&[NSProcessInfo.processInfo.arguments containsObject:@"--mail-session"]){[NSApp terminate:nil];return;}
    [self.lifecyclePreferences removeObjectForKey:MTManualQuitMailSession];
    [self.lifecyclePreferences synchronize];
    self.providerID=@"apple-local";self.gate=[MTRequestGate new];self.automaticQueue=[MTTranslationQueue new];
    self.cache=[[MTCache alloc]initWithRoot:[self cacheURL]];
    // Invalidate old rendered controls once when upgrading from the two-action UI.
    if(![self.lifecyclePreferences boolForKey:@"MTMenuOnlyMigration5"]){[self.cache clear];[self.lifecyclePreferences setBool:YES forKey:@"MTMenuOnlyMigration5"];}
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon=[NSImage imageWithSystemSymbolName:@"character.bubble" accessibilityDescription:@"MailTrans"];icon.template=YES;
    if(icon)self.statusItem.button.image=icon;else self.statusItem.button.title=@"译";
    self.statusItem.menu=[self makeStatusMenu];self.statusText=@"MailTrans · 就绪";
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(cacheChanged:) name:@"local.codex.mailtranslationprobe.cacheChanged" object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [self refreshState];[self scheduleAutomaticTranslations];
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cleanExpired:) userInfo:nil repeats:YES];
    if(!self.mailSessionToken.length||![self.lifecyclePreferences boolForKey:@"MTSetupCompleted"])[self showSetup];
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
        self.stopping=YES;[self.translationRunner cancel];[self.languageRunner cancel];
        if(self.translationTask.running)[self.translationTask terminate];
        if(self.languageTask.running)[self.languageTask terminate];
    }
    [self.translationRunner cancelAndWait];[self.languageRunner cancelAndWait];
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
    NSRunningApplication *mail=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.mail"].firstObject;
    if(mail&&!mail.isActive)[mail activateWithOptions:0];
}
- (BOOL)shouldAutoTranslateMessage:(MTMessage *)message {
    if(!message.eligible)return NO;
    NSString *body=[message.texts componentsJoinedByString:@"\n"];
    if(body.length>20000)body=[body substringToIndex:20000];
    return [[NLLanguageRecognizer dominantLanguageForString:body]isEqual:NLLanguageEnglish];
}
- (void)scheduleAutomaticTranslations {
    if(self.stopping||!self.automaticTranslationEnabled||!self.mailSessionToken.length)return;
    if(self.scanScheduled){self.scanAgain=YES;return;}
    self.scanScheduled=YES;
    dispatch_async(MTBackgroundWorkQueue(),^{
        NSArray *recent=[self.cache recentMessages];NSMutableArray *keys=[NSMutableArray new];
        for(NSDictionary *entry in recent){
            if(self.stopping||!self.automaticTranslationEnabled)break;
            if([entry[@"translated"]boolValue]||[entry[@"original"]boolValue])continue;
            NSString *key=entry[@"key"];NSData *source=[self.cache sourceForKey:key];
            MTMessage *message=source?[MTMessage messageWithData:source]:nil;
            if([self shouldAutoTranslateMessage:message])[keys addObject:key];
        }
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.stopping)return;
            self.scanScheduled=NO;
            for(NSString *key in keys)[self.automaticQueue enqueueKey:key];
            [self startNextAutomaticTranslation];
            if(self.scanAgain){self.scanAgain=NO;[self scheduleAutomaticTranslations];}
        });
    });
}
- (void)startNextAutomaticTranslation {
    if(self.busy||self.stopping||!self.automaticTranslationEnabled)return;
    NSString *key=nil;
    while((key=[self.automaticQueue takeNextKey])){
        if([self.cache prefersOriginalForKey:key]||[self.cache hasStoredDisplayForKey:key]||![self.cache hasSourceForKey:key])continue;
        [self translateKey:key automatic:YES];return;
    }
}
- (void)restoreKey:(NSString *)key {
    if(![MTCache isValidKey:key]){self.statusText=@"请先选择一封邮件。";return;}
    [self cancelTranslationForKey:key];[self.cache restoreKey:key];[self refreshState];[self reloadMail];
    self.statusText=@"已显示原文，可通过上方控制条随时切回中文。";[self activateMail];
}
- (NSURL *)workerURL {return [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"TranslationWorker"];}
- (NSTimeInterval)workerTimeout {return 120;}
- (NSDictionary *)runWorker:(MTMessage *)message {
    MTProcessRunner *runner=nil;NSTask *task=nil;
    @synchronized(self){runner=self.translationRunner;task=self.translationTask;}
    if(!runner||self.stopping)return @{@"errorCode":@"cancelled"};
    if(!task.executableURL)return @{@"errorCode":@"launch_failed",@"message":@"本地翻译程序未能启动，请检查安装。"};
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"texts":message.texts,@"target":@"zh-Hans",@"provider":self.providerID?:@"apple-local"} options:0 error:nil];
    NSDictionary *result=[runner runWithInput:data?:NSData.data];
    @synchronized(self){if(self.translationRunner==runner){self.translationRunner=nil;self.translationTask=nil;}}
    NSString *error=result[@"errorCode"];
    if(error){NSString *text=[error isEqual:@"timeout"]?@"翻译超时，原文已保留。可从菜单重试上次失败的邮件。":([error isEqual:@"cancelled"]?@"翻译已取消，原文已保留。":@"本地翻译未完成，原文已保留。可从菜单重试。");return @{@"errorCode":error,@"message":text};}
    id value=[NSJSONSerialization JSONObjectWithData:result[@"output"]?:NSData.data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class]?value:@{@"errorCode":@"worker_failed",@"message":@"本地翻译未完成，原文已保留。可从菜单重试。"};
}
- (void)translateKey:(NSString *)key {[self translateKey:key automatic:NO];}
- (void)translateKey:(NSString *)key automatic:(BOOL)automatic {
    if(self.stopping||(automatic&&!self.automaticTranslationEnabled))return;
    if(![MTCache isValidKey:key]){if(!automatic){self.statusText=@"请在 Mail 中打开邮件，并点击正文上方的翻译按钮。";}else [self startNextAutomaticTranslation];return;}
    if(!automatic&&[self.cache hasStoredDisplayForKey:key]&&[self.cache activateStoredDisplayForKey:key]){
        [self.gate invalidateKey:key];[self.automaticQueue completeKey:key];
        self.statusText=[NSString stringWithFormat:@"已切回中文：%@",[self.cache subjectForKey:key]?:@"邮件"];
        [self reloadMail];[self activateMail];return;
    }
    if(self.busy){if(!automatic){self.statusText=@"正在翻译，请等待当前任务完成。";}return;}
    [self.automaticQueue cancelKey:key];
    NSString *requestKey=key.copy;NSUUID *token=[self.gate beginKey:requestKey];
    NSString *subject=[self.cache subjectForKey:requestKey]?:@"邮件";
    NSTask *task=[NSTask new];NSURL *workerURL=[self workerURL];if(workerURL)task.executableURL=workerURL;
    MTProcessRunner *runner=[[MTProcessRunner alloc]initWithTask:task];runner.timeout=[self workerTimeout];
    @synchronized(self){self.translationTask=task;self.translationRunner=runner;}
    self.busy=YES;self.workingKey=requestKey;self.workingAutomatic=automatic;self.hasFailure=self.lastFailedKey.length>0;self.statusText=[NSString stringWithFormat:@"正在本地翻译：%@",subject];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        // Never hash or parse the full message on the main thread.
        NSData *source=[self.cache sourceForKey:requestKey];MTMessage *message=source?[MTMessage messageWithData:source]:nil;
        NSDictionary *result=message.eligible?[self runWorker:message]:@{@"errorCode":@"source_missing",@"message":@"邮件缓存已过期或类型暂不支持，请重新打开邮件。"};
        NSData *display=nil;
        if(message&&[result[@"translations"] isKindOfClass:NSArray.class])display=[message renderTranslations:result[@"translations"] includeControls:YES];
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.stopping)return;
            @synchronized(self){self.translationTask=nil;self.translationRunner=nil;}
            self.busy=NO;self.workingKey=nil;self.workingAutomatic=NO;
            if(![self.gate isCurrent:token forKey:requestKey]){self.statusText=@"已保留原文，取消了迟到的翻译结果。";[self startNextAutomaticTranslation];return;}
            if(automatic&&[result[@"errorCode"] isEqual:@"source_missing"]){[self startNextAutomaticTranslation];return;}
            if([result[@"errorCode"] isEqual:@"model_missing"]){
                if(automatic){[self recordFailure:@"本邮件还缺少本地语言包。请在邮件上方点“翻译为中文”，按提示准备后继续。原文已保留。" key:requestKey];[self startNextAutomaticTranslation];return;}
                NSString *language=[result[@"source"] isKindOfClass:NSString.class]?result[@"source"]:@"en";
                self.statusText=@"需要准备本地语言包。完成后将继续翻译这封邮件。";
                [self prepareLanguage:language completion:^(BOOL ready){
                    if(ready&&[self.gate isCurrent:token forKey:requestKey])[self translateKey:requestKey];else [self startNextAutomaticTranslation];
                }];return;
            }
            if(!display || ![self.cache setDisplay:display forKey:requestKey activate:!automatic]){
                [self recordFailure:([result[@"message"] isKindOfClass:NSString.class]?result[@"message"]:@"译文未能显示，原文已保留。") key:requestKey];[self startNextAutomaticTranslation];return;
            }
            [self.automaticQueue completeKey:requestKey];if([self.lastFailedKey isEqual:requestKey])self.lastFailedKey=nil;self.hasFailure=self.lastFailedKey.length>0;
            self.statusText=automatic?[NSString stringWithFormat:@"译文已就绪：%@。默认显示原文，点击“翻译为中文”即可查看。",subject]:[NSString stringWithFormat:@"已翻译：%@。可随时显示原文。",subject];
            [self refreshState];if(!automatic){[self reloadMail];[self activateMail];}[self startNextAutomaticTranslation];
        });
    });
}
- (void)prepareLanguage:(NSString *)language completion:(void (^)(BOOL))completion {
    if(self.stopping)return;
    if(self.busy){self.statusText=@"请先取消或等待当前翻译，再准备语言包。";completion(NO);return;}
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    if(language.length>35||[language rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound){completion(NO);return;}
    NSURL *helper=[[NSBundle mainBundle].bundleURL URLByAppendingPathComponent:@"Contents/Helpers/LanguageSetup.app/Contents/MacOS/LanguageSetup"];
    self.busy=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSTask *task=[NSTask new];task.executableURL=helper;task.arguments=@[language];
        MTProcessRunner *runner=[[MTProcessRunner alloc]initWithTask:task];runner.timeout=900;runner.outputLimit=1024*1024;
        BOOL ready=NO;
        @synchronized(self){if(self.stopping)[runner cancel];else{self.languageTask=task;self.languageRunner=runner;}}
        NSDictionary *result=[runner runWithInput:NSData.data];
        NSString *text=[[NSString alloc]initWithData:result[@"output"]?:NSData.data encoding:NSUTF8StringEncoding];
        ready=!result[@"errorCode"]&&[result[@"exitStatus"]intValue]==0&&[text containsString:@"MAIL_TRANSLATION_MODELS_READY"];
        @synchronized(self){if(self.languageTask==task){self.languageTask=nil;self.languageRunner=nil;}}
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
    if(self.workingKey)[self cancelTranslationForKey:self.workingKey];
    self.lastFailedKey=nil;self.hasFailure=NO;
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
