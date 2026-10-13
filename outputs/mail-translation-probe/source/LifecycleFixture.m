#import <AppKit/AppKit.h>
int main(void) {@autoreleasepool {
    NSApplication *app=NSApplication.sharedApplication;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [app run];
}}
