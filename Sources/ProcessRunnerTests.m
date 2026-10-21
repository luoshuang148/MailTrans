#import <Foundation/Foundation.h>
#import <signal.h>
#import <unistd.h>
#if !__has_include("MTProcessRunner.h")
int main(void) { fputs("FAIL: bounded process runner is not implemented\n", stderr); return 1; }
#else
#import "MTProcessRunner.h"
static NSUInteger failures=0;
static void check(BOOL value, const char *message){if(!value){fprintf(stderr,"FAIL: %s\n",message);failures++;}}
static MTProcessRunner *runner(NSString *mode, NSTimeInterval timeout){
 NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]];task.arguments=@[mode];
 MTProcessRunner *r=[[MTProcessRunner alloc]initWithTask:task];r.timeout=timeout;return r;
}
int main(int argc,const char **argv){@autoreleasepool{
 if(argc>1){
  NSString *mode=@(argv[1]);
  if([mode isEqual:@"--echo"]){NSData *input=NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;[NSFileHandle.fileHandleWithStandardOutput writeData:input];return 0;}
  if([mode isEqual:@"--nonzero"]){fputs("structured failure",stdout);return 2;}
  if([mode isEqual:@"--exit"]){return 0;}
  if([mode isEqual:@"--exit-leak-stdout"]){if(fork()==0){sleep(2);_exit(0);}return 0;}
  if([mode isEqual:@"--ignore-term"])signal(SIGTERM,SIG_IGN);
  if([mode isEqual:@"--flood"]){char bytes[16384];memset(bytes,'x',sizeof(bytes));while(1)write(STDOUT_FILENO,bytes,sizeof(bytes));}
  while(1)usleep(10000);
 }
 NSData *big=[NSMutableData dataWithLength:2*1024*1024];
 MTProcessRunner *echo=runner(@"--echo",5);NSDictionary *result=[echo runWithInput:big];
 check(!result[@"errorCode"]&&[result[@"output"]isEqual:big]&&[result[@"exitStatus"]intValue]==0,"large input/output must round trip without pipe deadlock");
 MTProcessRunner *nonzero=runner(@"--nonzero",2);result=[nonzero runWithInput:NSData.data];
 check(!result[@"errorCode"]&&[result[@"exitStatus"]intValue]==2&&[result[@"output"]length]>0,"provider nonzero exit must preserve structured output");
 MTProcessRunner *stalled=runner(@"--hang-input",0.15);NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;
 result=[stalled runWithInput:big];
 check([result[@"errorCode"]isEqual:@"timeout"]&&!stalled.task.running&&NSProcessInfo.processInfo.systemUptime-start<2,"non-consuming stdin must time out and terminate owned child");
 MTProcessRunner *resistant=runner(@"--ignore-term",0.2);start=NSProcessInfo.processInfo.systemUptime;result=[resistant runWithInput:NSData.data];
 check([result[@"errorCode"]isEqual:@"timeout"]&&!resistant.task.running&&NSProcessInfo.processInfo.systemUptime-start<2,"SIGTERM-resistant child must be killed within grace interval");
 MTProcessRunner *cancelled=runner(@"--hang-input",10);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[cancelled cancel];});
 result=[cancelled runWithInput:big];check([result[@"errorCode"]isEqual:@"cancelled"]&&!cancelled.task.running,"cancellation must interrupt a blocked input writer");
 MTProcessRunner *before=runner(@"--hang-input",10);[before cancel];result=[before runWithInput:big];
 check([result[@"errorCode"]isEqual:@"cancelled"]&&before.task.processIdentifier==0,"cancel-before-launch must not create a child");
 MTProcessRunner *flood=runner(@"--flood",3);flood.outputLimit=256*1024;result=[flood runWithInput:NSData.data];
 check([result[@"errorCode"]isEqual:@"output_limit"]&&!flood.task.running&&[result[@"output"]length]<=flood.outputLimit,"unbounded stdout must stop at configured output cap");
 MTProcessRunner *early=runner(@"--exit",2);result=[early runWithInput:big];
 check(!result[@"errorCode"]&&!early.task.running,"early child exit while input remains must not SIGPIPE or hang parent");
 MTProcessRunner *leak=runner(@"--exit-leak-stdout",5);start=NSProcessInfo.processInfo.systemUptime;result=[leak runWithInput:NSData.data];
 check(!result[@"errorCode"]&&!leak.task.running&&result[@"output"]&&NSProcessInfo.processInfo.systemUptime-start<2,"stdout inherited by grandchild must not hang the runner");
 if(![echo respondsToSelector:NSSelectorFromString(@"cancelAndWait")]){check(NO,"normal app shutdown needs synchronous bounded child cleanup");}
 else{
  MTProcessRunner *shutdown=runner(@"--ignore-term",10);dispatch_semaphore_t finished=dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[shutdown runWithInput:NSData.data];dispatch_semaphore_signal(finished);});
  NSTimeInterval limit=NSProcessInfo.processInfo.systemUptime+2;
  while(!shutdown.task.running&&NSProcessInfo.processInfo.systemUptime<limit)usleep(1000);usleep(100000);
  [shutdown cancelAndWait];
  check(!shutdown.task.running,"shutdown must reap even a child ignoring SIGTERM before app exits");
  check(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC))==0,"shutdown must let background runner return");
 }
 if(failures)return 1;puts("PASS: bounded process I/O, timeout, cancellation, SIGKILL escalation, output cap and early exits");return 0;
}}
#endif
