#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import "MTAppManagement.h"
@protocol SetupAPI
- (instancetype)initWithPreferences:(NSUserDefaults *)preferences;
@property MTAppManagement *management;
@property(readonly) BOOL needsSetup;
@property(readonly) NSWindow *window;
@property(copy) void(^languagePreparationHandler)(void);
@property(copy) void(^cacheClearHandler)(void);
@property(copy) void(^quitHandler)(void);
- (void)showWindow;
- (void)markSetupComplete;
@end
static NSButton *FindButton(NSView *view,NSString *title){if([view isKindOfClass:NSButton.class]&&[((NSButton *)view).title isEqual:title])return (NSButton *)view;for(NSView *child in view.subviews){NSButton *b=FindButton(child,title);if(b)return b;}return nil;}
static int failures;
#define CHECK(c,s) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",s);failures++;}}while(0)
int main(void){@autoreleasepool{
 [NSApplication sharedApplication];[NSApp finishLaunching];Class cls=NSClassFromString(@"MTSetupController");if(!cls){fputs("FAIL: native setup controller missing\n",stderr);return 1;}
 NSString *suite=[@"local.mailtrans.setup-tests."stringByAppendingString:NSUUID.UUID.UUIDString];NSUserDefaults *prefs=[[NSUserDefaults alloc]initWithSuiteName:suite];
 id<SetupAPI> setup=[[cls alloc]initWithPreferences:prefs];CHECK(setup.needsSetup,"first launch requests setup");
 MTAppManagement *management=[[MTAppManagement alloc]initWithAppURL:[NSURL fileURLWithPath:@"/isolated/MailTrans.app"] homeURL:[NSURL fileURLWithPath:@"/isolated"]serviceLabel:@"local.mailtrans.test.setup"];
 management.mailRunningHandler=^BOOL{return NO;};management.commandHandler=^NSDictionary *(NSString *path,NSArray *args){return @{@"exitStatus":@1,@"output":[NSData data]};};setup.management=management;
 [setup showWindow];CHECK(setup.window.visible,"setup window usable when Mail is absent");
 CHECK(FindButton(setup.window.contentView,@"打开“邮件”")!=nil,"offer Mail opening when closed");
 NSButton *prepare=FindButton(setup.window.contentView,@"准备英中语言包");__block BOOL prepared=NO;setup.languagePreparationHandler=^{prepared=YES;};[prepare performClick:nil];CHECK(prepared,"language preparation invokes native host callback");
 CHECK(FindButton(setup.window.contentView,@"打开示例邮件")!=nil&&FindButton(setup.window.contentView,@"检查更新")!=nil,"sample and release actions available");
 CHECK(FindButton(setup.window.contentView,@"卸载 MailTrans…")!=nil,"explicit uninstall action available");
 CHECK(![prefs boolForKey:@"MTSetupCompleted"],"viewing settings does not silently complete setup");
 [setup markSetupComplete];CHECK([prefs boolForKey:@"MTSetupCompleted"]&&!setup.needsSetup,"explicit completion persists across launches");
 id<SetupAPI> reopened=[[cls alloc]initWithPreferences:prefs];CHECK(!reopened.needsSetup,"automatic launch will not repeat completed setup");
 NSString *snapshotPath=NSProcessInfo.processInfo.environment[@"MT_SETUP_SNAPSHOT"];
 if(snapshotPath){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];[setup.window.contentView layoutSubtreeIfNeeded];[setup.window display];NSBitmapImageRep *bitmap=[setup.window.contentView bitmapImageRepForCachingDisplayInRect:setup.window.contentView.bounds];[setup.window.contentView cacheDisplayInRect:setup.window.contentView.bounds toBitmapImageRep:bitmap];[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:snapshotPath atomically:YES];}
 if([NSProcessInfo.processInfo.environment[@"MT_SETUP_PREVIEW"]boolValue])[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:45]];
 [setup.window close];[prefs removePersistentDomainForName:suite];
 if(failures)return 1;puts("PASS: native setup with Mail closed, language callback and persistent explicit completion");return 0;
}}
