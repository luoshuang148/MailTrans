#import <AppKit/AppKit.h>
#import <stdio.h>

@protocol LifecycleAPI
- (instancetype)initWithMailBundleIdentifier:(NSString *)mailID hostBundleIdentifier:(NSString *)hostID hostURL:(NSURL *)url preferences:(NSUserDefaults *)preferences;
- (void)start;
- (void)stop;
- (NSString *)mailSessionToken;
@end
static int failures;
#define CHECK(condition,label) do {if(!(condition)){fprintf(stderr,"FAIL: %s\n",label);failures++;}}while(0)
static BOOL Wait(BOOL(^condition)(void),NSTimeInterval seconds) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while(!condition()&&deadline.timeIntervalSinceNow>0) {
        NSEvent *event=[NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]inMode:NSDefaultRunLoopMode dequeue:YES];
        if(event)[NSApp sendEvent:event];
    }
    return condition();
}
static void Pump(NSTimeInterval seconds) {Wait(^BOOL{return NO;},seconds);}
static NSArray<NSRunningApplication *> *Apps(NSString *identifier) {
    NSPredicate *alive=[NSPredicate predicateWithBlock:^BOOL(NSRunningApplication *app,NSDictionary *bindings){return !app.terminated;}];
    return [[NSRunningApplication runningApplicationsWithBundleIdentifier:identifier]filteredArrayUsingPredicate:alive];
}
static void QuitAll(NSString *identifier) {for(NSRunningApplication *app in Apps(identifier))[app terminate];}
static NSRunningApplication *Open(NSURL *url,BOOL newInstance) {
    __block NSRunningApplication *result=nil;__block BOOL done=NO;
    NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration;
    config.activates=NO;config.createsNewApplicationInstance=newInstance;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){if(error)fprintf(stderr,"OPEN FAILED: %s\n",error.description.UTF8String);result=app;done=YES;}];
    Wait(^BOOL{return done;},8);return result;
}
static NSURL *Fixture(NSURL *root,NSString *name,NSString *identifier,NSString *binary) {
    NSURL *url=[root URLByAppendingPathComponent:[name stringByAppendingString:@".app"]];
    NSURL *mac=[url URLByAppendingPathComponent:@"Contents/MacOS"];
    [NSFileManager.defaultManager createDirectoryAtURL:mac withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *exe=[mac URLByAppendingPathComponent:@"Fixture"];
    [NSFileManager.defaultManager copyItemAtPath:binary toPath:exe.path error:nil];
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0755}ofItemAtPath:exe.path error:nil];
    NSDictionary *info=@{@"CFBundleIdentifier":identifier,@"CFBundleName":name,@"CFBundleExecutable":@"Fixture",@"CFBundlePackageType":@"APPL",@"CFBundleVersion":@"1",@"LSUIElement":@YES};
    NSData *plist=[NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    [plist writeToURL:[url URLByAppendingPathComponent:@"Contents/Info.plist"]atomically:YES];
    NSTask *sign=[NSTask new];sign.executableURL=[NSURL fileURLWithPath:@"/usr/bin/codesign"];sign.arguments=@[@"--sign",@"-",url.path];sign.standardError=NSFileHandle.fileHandleWithNullDevice;
    [sign launchAndReturnError:nil];[sign waitUntilExit];return url;
}
int main(int argc,const char *argv[]) {@autoreleasepool {
    Class lifecycle=NSClassFromString(@"MTMailLifecycle");
    if(!lifecycle){fputs("FAIL: Mail lifecycle observer is not implemented\n",stderr);return 1;}
    if(argc!=2){fputs("FAIL: fixture executable path required\n",stderr);return 1;}
    [NSApplication sharedApplication];[NSApp finishLaunching];
    NSString *suffix=NSUUID.UUID.UUIDString.lowercaseString;
    NSString *mailID=[@"local.mailtrans.tests.mail."stringByAppendingString:suffix];
    NSString *hostID=[@"local.mailtrans.tests.host."stringByAppendingString:suffix];
    NSString *otherID=[@"local.mailtrans.tests.other."stringByAppendingString:suffix];
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory()stringByAppendingPathComponent:suffix]isDirectory:YES];
    NSURL *mail=Fixture(root,@"FixtureMail",mailID,@(argv[1]));
    NSURL *host=Fixture(root,@"FixtureHost",hostID,@(argv[1]));
    NSURL *other=Fixture(root,@"FixtureOther",otherID,@(argv[1]));
    NSUserDefaults *prefs=[[NSUserDefaults alloc]initWithSuiteName:hostID];
    id<LifecycleAPI> observer=[[lifecycle alloc]initWithMailBundleIdentifier:mailID hostBundleIdentifier:hostID hostURL:host preferences:prefs];
    [observer start];Pump(0.15);
    CHECK(Apps(hostID).count==0,"no Mail means no host");
    Open(other,NO);Pump(0.15);
    CHECK(Apps(hostID).count==0,"unrelated application must not start host");
    Open(mail,NO);
    CHECK(Wait(^BOOL{return Apps(hostID).count==1;},8),"Mail launch starts exactly one host");
    NSString *firstSession=observer.mailSessionToken;
    [prefs setObject:firstSession forKey:@"MTManualQuitMailSession"];[prefs synchronize];
    QuitAll(hostID);CHECK(Wait(^BOOL{return Apps(hostID).count==0;},5),"manual host quit completes");
    Pump(0.2);CHECK(Apps(hostID).count==0,"manual quit stays stopped in same Mail session");
    [observer stop];
    observer=[[lifecycle alloc]initWithMailBundleIdentifier:mailID hostBundleIdentifier:hostID hostURL:host preferences:prefs];
    [observer start];Pump(0.3);
    CHECK(Apps(hostID).count==0,"helper restart honors persisted manual quit");
    QuitAll(mailID);CHECK(Wait(^BOOL{return Apps(mailID).count==0;},5),"first Mail session ends");
    Pump(0.1);Open(mail,NO);
    CHECK(Wait(^BOOL{return Apps(hostID).count==1;},8),"new Mail session starts host after manual quit");
    CHECK(![observer.mailSessionToken isEqual:firstSession],"new process gets a distinct session");
    Open(mail,YES);
    CHECK(Wait(^BOOL{return Apps(mailID).count==2;},5),"multiple Mail fixture instances run");
    CHECK(Apps(hostID).count==1,"multiple Mail instances do not duplicate host");
    [Apps(mailID).firstObject terminate];
    CHECK(Wait(^BOOL{return Apps(mailID).count==1;},5),"one Mail instance closes");
    Pump(0.2);CHECK(Apps(hostID).count==1,"host stays until last Mail instance closes");
    QuitAll(mailID);
    CHECK(Wait(^BOOL{return Apps(hostID).count==0;},8),"last Mail quit normally terminates host");
    Open(host,NO);
    CHECK(Wait(^BOOL{return Apps(hostID).count==0;},5),"late host launch is stopped while Mail is closed");
    [observer stop];Open(mail,NO);
    observer=[[lifecycle alloc]initWithMailBundleIdentifier:mailID hostBundleIdentifier:hostID hostURL:host preferences:prefs];
    [observer start];
    CHECK(Wait(^BOOL{return Apps(hostID).count==1;},8),"helper starts host when Mail already running");
    [observer stop];QuitAll(mailID);QuitAll(hostID);QuitAll(otherID);
    Wait(^BOOL{return Apps(mailID).count+Apps(hostID).count+Apps(otherID).count==0;},5);
    [prefs removePersistentDomainForName:hostID];
    [NSFileManager.defaultManager removeItemAtURL:root error:nil];
    if(failures)return 1;
    puts("PASS: real workspace lifecycle, manual quit persistence, helper recovery, multiple Mail instances and late launch cleanup");
    return 0;
}}
