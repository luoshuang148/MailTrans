#import "MTAppManagement.h"
#import <unistd.h>
#import "MTProcessRunner.h"
static NSString *const MTBundleID=@"local.codex.mailtranslationprobe";
@interface MTAppManagement ()
@property(nonatomic,readwrite) NSURL *appURL;
@property(nonatomic) NSURL *homeURL;
@property(nonatomic,copy) NSString *label;
@end
@implementation MTAppManagement
- (instancetype)init {return [self initWithAppURL:NSBundle.mainBundle.bundleURL homeURL:[NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES] serviceLabel:@"local.codex.mailtranslationprobe.lifecycle"];}
- (instancetype)initWithAppURL:(NSURL *)appURL homeURL:(NSURL *)homeURL serviceLabel:(NSString *)label {
 if((self=[super init])){
  _appURL=appURL.URLByStandardizingPath;_homeURL=homeURL.URLByStandardizingPath;_label=[label copy];
  _commandHandler=^NSDictionary *(NSString *path,NSArray *args){
   NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:path];task.arguments=args;
   MTProcessRunner *runner=[[MTProcessRunner alloc]initWithTask:task];runner.timeout=15;runner.outputLimit=1024*1024;
   return [runner runWithInput:[NSData data]];
  };
  _mailRunningHandler=^BOOL{return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.mail"].count>0;};
  _trashHandler=^BOOL(NSURL *url,NSError **error){return [NSFileManager.defaultManager trashItemAtURL:url resultingItemURL:nil error:error];};
 }
 return self;
}
- (NSURL *)agentURL{return [self.homeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Library/LaunchAgents/%@.plist",self.label]];}
- (NSString *)domain{return [NSString stringWithFormat:@"gui/%u",getuid()];}
- (NSString *)service{return [NSString stringWithFormat:@"%@/%@",self.domain,self.label];}
- (BOOL)fail:(NSString *)description error:(NSError **)error {if(error)*error=[NSError errorWithDomain:@"MailTrans.Management" code:1 userInfo:@{NSLocalizedDescriptionKey:description}];return NO;}
- (BOOL)success:(NSDictionary *)result{return !result[@"errorCode"]&&result[@"exitStatus"]&&[result[@"exitStatus"]intValue]==0;}
- (BOOL)command:(NSString *)path arguments:(NSArray *)args {return [self success:self.commandHandler(path,args)];}
- (NSInteger)loadState {
 NSDictionary *result=self.commandHandler(@"/bin/launchctl",@[@"print",self.service]);
 if([self success:result])return 1;
 // launchctl uses ESRCH (113) when the exact named service is absent.
 if(!result[@"errorCode"]&&[result[@"exitStatus"]isEqual:@113])return 0;
 return -1;
}
- (BOOL)validAgentPath:(NSError **)error {
 if(!self.label.length||[self.label rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"]invertedSet]].location!=NSNotFound)
  return [self fail:@"自动启动服务名称无效。" error:error];
 NSURL *directory=self.agentURL.URLByDeletingLastPathComponent;
 // Refuse symlinks in every existing component, not just the final plist.
 NSURL *cursor=self.agentURL;
 while(cursor.path.length>=self.homeURL.path.length&&cursor.path.length>1){NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:cursor.path error:nil];if([attrs[NSFileType]isEqual:NSFileTypeSymbolicLink])return [self fail:@"自动启动路径含符号链接，请检查 LaunchAgents 文件夹。" error:error];cursor=cursor.URLByDeletingLastPathComponent;}
 if(![directory.path hasPrefix:[self.homeURL.path stringByAppendingString:@"/"]])return [self fail:@"自动启动路径无效。" error:error];
 return YES;
}
- (BOOL)validateApp:(NSError **)error {
 if(!self.appURL.isFileURL||![self.appURL.pathExtension isEqual:@"app"]||![self.appURL.path isEqual:self.appURL.URLByResolvingSymlinksInPath.path])return [self fail:@"请从真实的 MailTrans.app 打开设置，不能操作别名或符号链接。" error:error];
 NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[self.appURL URLByAppendingPathComponent:@"Contents/Info.plist"]];
 if(![info[@"CFBundleIdentifier"]isEqual:MTBundleID]||![info[@"CFBundleExecutable"]isEqual:@"MailTrans"]||![NSFileManager.defaultManager isExecutableFileAtPath:[self.appURL URLByAppendingPathComponent:@"Contents/MacOS/MailTransLifecycle"].path])
  return [self fail:@"此路径不是完整的 MailTrans 应用，请重新安装后再试。" error:error];
 if(![self command:@"/usr/bin/codesign" arguments:@[@"--verify",@"--deep",@"--strict",self.appURL.path]])return [self fail:@"应用签名验证失败，请重新下载完整的 MailTrans 应用。" error:error];
 return YES;
}
- (BOOL)enableAutomaticLaunch:(NSError **)error {
 NSString *userInstallation=[self.homeURL URLByAppendingPathComponent:@"Applications/MailTrans.app"].path;
 if(![self.appURL.path isEqual:@"/Applications/MailTrans.app"]&&![self.appURL.path isEqual:userInstallation])return [self fail:@"请先将 MailTrans.app 移到“应用程序”文件夹（系统或个人文件夹），退出后从该位置重新打开，再启用自动启动。" error:error];
 if(![self validAgentPath:error]||![self validateApp:error])return NO;
 NSInteger state=[self loadState];
 if(state<0)return [self fail:@"无法确认自动启动服务状态，请稍后重试。" error:error];
 if(state==1&&![self command:@"/bin/launchctl" arguments:@[@"bootout",self.service]])return [self fail:@"无法停止已有的自动启动服务，请重试。" error:error];
 NSDictionary *definition=@{@"Label":self.label,@"ProgramArguments":@[[self.appURL URLByAppendingPathComponent:@"Contents/MacOS/MailTransLifecycle"].path],@"RunAtLoad":@YES,@"KeepAlive":@YES,@"ThrottleInterval":@10,@"ProcessType":@"Background",@"LimitLoadToSessionType":@"Aqua",@"AssociatedBundleIdentifiers":@[MTBundleID]};
 NSFileManager *fm=NSFileManager.defaultManager;
 if(![fm createDirectoryAtURL:self.agentURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:definition format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
 if(!data||![data writeToURL:self.agentURL options:NSDataWritingAtomic error:error])return NO;
 [fm setAttributes:@{NSFilePosixPermissions:@0644}ofItemAtPath:self.agentURL.path error:nil];
 if(![self command:@"/bin/launchctl" arguments:@[@"enable",self.service]]||![self command:@"/bin/launchctl" arguments:@[@"bootstrap",self.domain,self.agentURL.path]])return [self fail:@"自动启动服务未能载入，请在设置中关闭后重试。" error:error];
 return YES;
}
- (BOOL)disableAutomaticLaunch:(NSError **)error {
 if(![self validAgentPath:error])return NO;
 NSInteger state=[self loadState];
 if(state<0)return [self fail:@"无法确认自动启动服务状态，请稍后重试。" error:error];
 if(state==1&&![self command:@"/bin/launchctl" arguments:@[@"bootout",self.service]])return [self fail:@"无法停止自动启动服务。应用尚未移除，请稍后重试。" error:error];
 if([NSFileManager.defaultManager fileExistsAtPath:self.agentURL.path]&&![NSFileManager.defaultManager removeItemAtURL:self.agentURL error:error])return NO;
 return YES;
}
- (NSDictionary *)statusSnapshot {
 NSInteger loaded=[self loadState];
 NSURL *extension=[self.appURL URLByAppendingPathComponent:@"Contents/PlugIns/MailTranslationProbe.appex"];
 NSDictionary *registration=self.commandHandler(@"/usr/bin/pluginkit",@[@"-m",@"-A",@"-D",@"-v",@"-i",@"local.codex.mailtranslationprobe.extension"]);
 NSString *listing=[[NSString alloc]initWithData:registration[@"output"]?:[NSData data] encoding:NSUTF8StringEncoding]?:@"";
 BOOL registered=[self success:registration]&&[listing containsString:extension.path];
 NSDictionary *model=self.commandHandler([self.appURL URLByAppendingPathComponent:@"Contents/MacOS/TranslationWorker"].path,@[@"--model-status"]);
 NSDictionary *json=[self success:model]?[NSJSONSerialization JSONObjectWithData:model[@"output"]?:[NSData data] options:0 error:nil]:nil;
 NSString *state=[json isKindOfClass:NSDictionary.class]&&[@[@"installed",@"supported",@"unsupported"]containsObject:json[@"status"]]?json[@"status"]:@"unknown";
 return @{@"mailRunning":@(self.mailRunningHandler()),@"automaticLaunch":loaded==1?@"enabled":(loaded==0?@"disabled":@"unknown"),@"extensionRegistered":@(registered),@"modelStatus":state};
}
- (BOOL)uninstallConfirmed:(BOOL)confirmed error:(NSError **)error {
 if(!confirmed)return NO;
 if(self.mailRunningHandler())return [self fail:@"请先退出“邮件”，再卸载 MailTrans。" error:error];
 if(![self validAgentPath:error]||![self validateApp:error]||![self disableAutomaticLaunch:error])return NO;
 NSURL *extension=[self.appURL URLByAppendingPathComponent:@"Contents/PlugIns/MailTranslationProbe.appex"];
 if(![self command:@"/usr/bin/pluginkit" arguments:@[@"-r",extension.path]])return [self fail:@"扩展注销失败，应用尚未移除。请重试。" error:error];
 // Revalidate the exact target after stopping external processes, before trashing.
 if(self.mailRunningHandler())return [self fail:@"“邮件”已启动，请退出后重新卸载。" error:error];
 if(![self validateApp:error])return NO;
 return self.trashHandler(self.appURL,error);
}
@end
