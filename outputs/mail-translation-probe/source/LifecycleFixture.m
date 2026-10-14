#import <AppKit/AppKit.h>
@interface FixtureDelegate:NSObject<NSApplicationDelegate>
@property BOOL quitting;
@end
@implementation FixtureDelegate
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
    NSTimeInterval delay=[NSBundle.mainBundle.infoDictionary[@"MTFixtureExitDelay"]doubleValue];
    if(delay>0&&!self.quitting){
        self.quitting=YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[app replyToApplicationShouldTerminate:YES];});
        return NSTerminateLater;
    }
    return self.quitting?NSTerminateLater:NSTerminateNow;
}
@end
int main(void) {@autoreleasepool {
    [NSThread sleepForTimeInterval:[NSBundle.mainBundle.infoDictionary[@"MTFixtureStartDelay"]doubleValue]];
    NSApplication *app=NSApplication.sharedApplication;
    FixtureDelegate *delegate=[FixtureDelegate new];app.delegate=delegate;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [app run];
}}
