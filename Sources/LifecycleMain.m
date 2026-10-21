#import "MailLifecycle.h"
int main(int argc,const char *argv[]) {@autoreleasepool {
    NSURL *executable=[NSURL fileURLWithPath:@(argv[0])].URLByResolvingSymlinksInPath;
    NSURL *app=executable.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
    if(![[NSBundle bundleWithURL:app].bundleIdentifier isEqual:MTLifecycleDefaultsDomain])return 1;
    NSUserDefaults *preferences=[MTMailLifecycle preferencesForDomain:MTLifecycleDefaultsDomain];
    MTMailLifecycle *lifecycle=[[MTMailLifecycle alloc]initWithMailBundleIdentifier:@"com.apple.mail" hostBundleIdentifier:MTLifecycleDefaultsDomain hostURL:app preferences:preferences];
    [lifecycle start];
    [NSRunLoop.mainRunLoop run];
}}
