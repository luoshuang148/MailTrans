#import "MTProcessRunner.h"
#import <errno.h>
#import <fcntl.h>
#import <signal.h>
#import <unistd.h>
#import <math.h>

@interface MTProcessRunner ()
@property(nonatomic,readwrite) NSTask *task;
@property(atomic) BOOL cancellationRequested;
@property(nonatomic) BOOL started;
@end
@implementation MTProcessRunner
- (instancetype)initWithTask:(NSTask *)task {
    if((self=[super init])){_task=task;_timeout=120;_outputLimit=8*1024*1024;}return self;
}
- (void)cancel {@synchronized(self){self.cancellationRequested=YES;}}
- (void)cancelAndWait {
    [self cancel];
    NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+0.5;
    if(self.task.running)[self.task terminate];
    while(self.task.running&&NSProcessInfo.processInfo.systemUptime<deadline)usleep(5000);
    if(self.task.running){pid_t pid=self.task.processIdentifier;if(pid>0)kill(pid,SIGKILL);}
    deadline=NSProcessInfo.processInfo.systemUptime+0.5;
    while(self.task.running&&NSProcessInfo.processInfo.systemUptime<deadline)usleep(5000);
    if(!self.task.running)[self.task waitUntilExit];
}
- (NSDictionary *)runWithInput:(NSData *)input {
    if(!isfinite(self.timeout)||self.timeout<=0||!self.outputLimit)return @{@"errorCode":@"invalid_configuration"};
    NSPipe *stdinPipe=[NSPipe pipe],*stdoutPipe=[NSPipe pipe];
    self.task.standardInput=stdinPipe;self.task.standardOutput=stdoutPipe;
    self.task.standardError=NSFileHandle.fileHandleWithNullDevice;
    NSError *launchError=nil;
    @synchronized(self){
        if(self.cancellationRequested)return @{@"errorCode":@"cancelled"};
        if(self.started)return @{@"errorCode":@"already_started"};
        self.started=YES;
        if(![self.task launchAndReturnError:&launchError])return @{@"errorCode":@"launch_failed"};
    }
    NSFileHandle *writer=stdinPipe.fileHandleForWriting,*reader=stdoutPipe.fileHandleForReading;
    int inputFD=writer.fileDescriptor,outputFD=reader.fileDescriptor;
    fcntl(inputFD,F_SETFL,fcntl(inputFD,F_GETFL)|O_NONBLOCK);
    fcntl(inputFD,F_SETNOSIGPIPE,1);
    fcntl(outputFD,F_SETFL,fcntl(outputFD,F_GETFL)|O_NONBLOCK);
    NSUInteger offset=0;BOOL inputClosed=NO,outputClosed=NO,killed=NO;
    NSString *failure=nil;NSMutableData *output=[NSMutableData new];
    NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+self.timeout,killDeadline=0,exitDrainDeadline=0,hardDeadline=0;
    while(YES){
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
        if(!failure&&self.cancellationRequested)failure=@"cancelled";
        if(!failure&&now>=deadline)failure=@"timeout";
        // A grandchild can inherit stdout and keep the pipe open after the
        // worker exits. Never wait for EOF forever in that case.
        if(!failure&&!self.task.running&&!outputClosed&&exitDrainDeadline==0)exitDrainDeadline=now+0.5;
        if(!failure&&exitDrainDeadline>0&&now>=exitDrainDeadline){outputClosed=YES;exitDrainDeadline=0;}
        if(!failure&&!inputClosed){
            if(offset>=input.length){[writer closeFile];inputClosed=YES;}
            else{
                ssize_t count=write(inputFD,(const char *)input.bytes+offset,MIN(input.length-offset,(NSUInteger)16384));
                if(count>0)offset+=(NSUInteger)count;
                else if(count<0&&errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR){[writer closeFile];inputClosed=YES;}
            }
        }
        if(!outputClosed){
            char bytes[16384];ssize_t count;
            while((count=read(outputFD,bytes,sizeof(bytes)))>0){
                NSUInteger room=self.outputLimit-output.length;
                if((NSUInteger)count>room){if(room)[output appendBytes:bytes length:room];failure=@"output_limit";break;}
                [output appendBytes:bytes length:(NSUInteger)count];
            }
            if(count==0||(count<0&&errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR))outputClosed=YES;
        }
        if(failure){
            if(!inputClosed){[writer closeFile];inputClosed=YES;}
            if(killDeadline==0){if(self.task.running)[self.task terminate];killDeadline=now+0.5;}
            if(self.task.running&&!killed&&now>=killDeadline){
                pid_t pid=self.task.processIdentifier;if(pid>0)kill(pid,SIGKILL);killed=YES;hardDeadline=now+0.5;
            }
            if(!self.task.running)break;
            if(hardDeadline>0&&now>=hardDeadline)break;
        }else if(!self.task.running&&outputClosed)break;
        usleep(5000);
    }
    if(!inputClosed)[writer closeFile];[reader closeFile];
    if(!self.task.running)[self.task waitUntilExit];
    if(failure)return @{@"errorCode":failure,@"output":output};
    return @{@"output":output,@"exitStatus":@(self.task.terminationStatus)};
}
@end
