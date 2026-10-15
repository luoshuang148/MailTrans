#import <Cocoa/Cocoa.h>
#import <stdio.h>
@protocol ManagementAPI
- (instancetype)initWithAppURL:(NSURL *)appURL homeURL:(NSURL *)homeURL serviceLabel:(NSString *)label;
@property(copy) NSDictionary *(^commandHandler)(NSString *,NSArray<NSString *> *);
@property(copy) BOOL (^mailRunningHandler)(void);
@property(copy) BOOL (^trashHandler)(NSURL *,NSError **);
- (BOOL)enableAutomaticLaunch:(NSError **)error;
- (BOOL)disableAutomaticLaunch:(NSError **)error;
- (NSDictionary *)statusSnapshot;
- (BOOL)uninstallConfirmed:(BOOL)confirmed error:(NSError **)error;
@end
static int failures;
#define CHECK(c,s) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",s);failures++;}}while(0)
static void Write(NSURL *url,NSDictionary *value){[value writeToURL:url error:nil];}
int main(void){@autoreleasepool{
 Class cls=NSClassFromString(@"MTAppManagement");if(!cls){fputs("FAIL: native app management missing\n",stderr);return 1;}
 NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 [NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:nil];
 root=root.URLByResolvingSymlinksInPath;
 NSURL *app=[root URLByAppendingPathComponent:@"Applications/MailTrans.app"],*mac=[app URLByAppendingPathComponent:@"Contents/MacOS"];
 [NSFileManager.defaultManager createDirectoryAtURL:mac withIntermediateDirectories:YES attributes:nil error:nil];
 Write([app URLByAppendingPathComponent:@"Contents/Info.plist"],@{@"CFBundleIdentifier":@"local.codex.mailtranslationprobe",@"CFBundleExecutable":@"MailTrans"});
 NSURL *exe=[mac URLByAppendingPathComponent:@"MailTransLifecycle"];
 [@"#!/bin/sh\nexit 0\n" writeToURL:exe atomically:YES encoding:NSUTF8StringEncoding error:nil];
 [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0755} ofItemAtPath:exe.path error:nil];
 NSString *label=[@"local.mailtrans.test." stringByAppendingString:NSUUID.UUID.UUIDString];
 id<ManagementAPI> m=[[cls alloc]initWithAppURL:app homeURL:root serviceLabel:label];
 __block BOOL loaded=NO,failBootout=NO,failSignature=NO,unknownPrint=NO;__block NSUInteger commandCount=0,trashes=0;NSMutableArray *commands=[NSMutableArray new];
 m.commandHandler=^NSDictionary *(NSString *path,NSArray *args){
  commandCount++;[commands addObject:@[path,args]];
  if([path isEqual:@"/usr/bin/codesign"]&&failSignature)return @{@"exitStatus":@1};
  if([path isEqual:@"/bin/launchctl"]){
   if([args.firstObject isEqual:@"print"]&&unknownPrint)return @{@"errorCode":@"timeout"};
   if([args.firstObject isEqual:@"print"])return @{@"exitStatus":loaded?@0:@113,@"output":[NSData data]};
   if([args.firstObject isEqual:@"bootstrap"]){loaded=YES;}
   if([args.firstObject isEqual:@"bootout"]){if(failBootout)return @{@"exitStatus":@1};loaded=NO;}
  }
  return @{@"exitStatus":@0,@"output":[NSData data]};
 };
 m.mailRunningHandler=^BOOL{return NO;};
 m.trashHandler=^BOOL(NSURL *url,NSError **error){CHECK([url.path isEqual:app.path],"trash only exact configured application");trashes++;return YES;};
 CHECK(![m uninstallConfirmed:NO error:nil]&&commandCount==0&&trashes==0,"cancelled uninstall does nothing");
 NSURL *transient=[root URLByAppendingPathComponent:@"Downloads/MailTrans.app"];
 [NSFileManager.defaultManager createDirectoryAtURL:transient.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];[NSFileManager.defaultManager copyItemAtURL:app toURL:transient error:nil];
 id<ManagementAPI> transientManager=[[cls alloc]initWithAppURL:transient homeURL:root serviceLabel:label];transientManager.commandHandler=m.commandHandler;
 NSUInteger beforeTransient=commandCount;CHECK(![transientManager enableAutomaticLaunch:nil]&&commandCount==beforeTransient,"transient Downloads app cannot persist automatic lifecycle path");
 __block BOOL transientTrashed=NO;transientManager.mailRunningHandler=^BOOL{return NO;};transientManager.trashHandler=^BOOL(NSURL *url,NSError **error){transientTrashed=[url.path isEqual:transient.path];return transientTrashed;};
 CHECK([transientManager uninstallConfirmed:YES error:nil]&&transientTrashed,"confirmed uninstall can remove exact current Downloads app");
 NSURL *alias=[root URLByAppendingPathComponent:@"Alias.app"];[NSFileManager.defaultManager createSymbolicLinkAtURL:alias withDestinationURL:app error:nil];
 id<ManagementAPI> aliasManager=[[cls alloc]initWithAppURL:alias homeURL:root serviceLabel:label];aliasManager.commandHandler=m.commandHandler;aliasManager.mailRunningHandler=^BOOL{return NO;};aliasManager.trashHandler=m.trashHandler;
 CHECK(![aliasManager uninstallConfirmed:YES error:nil]&&trashes==0,"application symlink cannot trash an unrelated target");
 NSError *firstError=nil;BOOL enabled=[m enableAutomaticLaunch:&firstError];if(!enabled)fprintf(stderr,"ENABLE: %s\n",firstError.description.UTF8String);CHECK(enabled,"valid app enables automatic lifecycle");
 NSURL *plist=[root URLByAppendingPathComponent:[NSString stringWithFormat:@"Library/LaunchAgents/%@.plist",label]];
 NSDictionary *definition=[NSDictionary dictionaryWithContentsOfURL:plist];
 CHECK([definition[@"Label"]isEqual:label]&&[definition[@"ProgramArguments"]isEqual:@[exe.path]],"write exact known launch agent and helper path");
 CHECK([definition[@"RunAtLoad"]boolValue]&&[definition[@"KeepAlive"]boolValue],"watcher ready across Mail sessions");
 CHECK([m.statusSnapshot[@"automaticLaunch"]isEqual:@"enabled"],"loaded lifecycle status is enabled");
 unknownPrint=YES;CHECK([m.statusSnapshot[@"automaticLaunch"]isEqual:@"unknown"],"failed launchctl query must not claim disabled");
 CHECK(![m disableAutomaticLaunch:nil]&&[NSFileManager.defaultManager fileExistsAtPath:plist.path],"unknown service state preserves agent instead of abandoning running watcher");unknownPrint=NO;
 CHECK([m disableAutomaticLaunch:nil]&&!loaded&&![NSFileManager.defaultManager fileExistsAtPath:plist.path],"disable removes only isolated agent");
 Write([app URLByAppendingPathComponent:@"Contents/Info.plist"],@{@"CFBundleIdentifier":@"unrelated.application"});
 NSUInteger before=commandCount;
 CHECK(![m enableAutomaticLaunch:nil]&&commandCount==before,"wrong bundle identifier rejected before commands");
 CHECK(![m uninstallConfirmed:YES error:nil]&&trashes==0,"wrong application cannot be trashed");
 Write([app URLByAppendingPathComponent:@"Contents/Info.plist"],@{@"CFBundleIdentifier":@"local.codex.mailtranslationprobe",@"CFBundleExecutable":@"MailTrans"});
 failSignature=YES;CHECK(![m enableAutomaticLaunch:nil]&&![NSFileManager.defaultManager fileExistsAtPath:plist.path],"invalid signature cannot install watcher");CHECK(![m uninstallConfirmed:YES error:nil]&&trashes==0,"invalid signature cannot trash app");failSignature=NO;
 m.mailRunningHandler=^BOOL{return YES;};before=commandCount;
 CHECK(![m uninstallConfirmed:YES error:nil]&&trashes==0&&commandCount==before,"Mail running refuses uninstall before mutation");
 m.mailRunningHandler=^BOOL{return NO;};CHECK([m enableAutomaticLaunch:nil],"re-enable fixture");failBootout=YES;
 CHECK(![m uninstallConfirmed:YES error:nil]&&trashes==0&&[NSFileManager.defaultManager fileExistsAtPath:plist.path],"bootout failure preserves app and agent");
 failBootout=NO;CHECK([m uninstallConfirmed:YES error:nil]&&trashes==1&&!loaded,"confirmed uninstall stops watcher before trash");
 BOOL unregister=NO;for(NSArray *command in commands)if([command[0]isEqual:@"/usr/bin/pluginkit"]&&[command[1][0]isEqual:@"-r"])unregister=YES;
 CHECK(unregister,"uninstall unregisters exact bundled extension");
 NSURL *target=[root URLByAppendingPathComponent:@"unrelated.plist"];[@"keep" writeToURL:target atomically:YES encoding:NSUTF8StringEncoding error:nil];
 [NSFileManager.defaultManager createSymbolicLinkAtURL:plist withDestinationURL:target error:nil];
 CHECK(![m enableAutomaticLaunch:nil]&&[[NSString stringWithContentsOfURL:target encoding:NSUTF8StringEncoding error:nil]isEqual:@"keep"],"symlink agent cannot overwrite unrelated file");
 [NSFileManager.defaultManager removeItemAtURL:root error:nil];
 if(failures)return 1;puts("PASS: native lifecycle plist, isolated controls, cancellation and safe exact-app uninstall");return 0;
}}
