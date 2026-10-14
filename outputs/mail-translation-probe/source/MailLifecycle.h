#import <AppKit/AppKit.h>

FOUNDATION_EXPORT NSString * const MTLifecycleDefaultsDomain;
FOUNDATION_EXPORT NSString * const MTManualQuitMailSession;
FOUNDATION_EXPORT NSString *MTMailSessionToken(NSArray<NSRunningApplication *> *applications);

@interface MTMailLifecycle : NSObject
+ (NSUserDefaults *)preferencesForDomain:(NSString *)domain;
- (instancetype)initWithMailBundleIdentifier:(NSString *)mailID hostBundleIdentifier:(NSString *)hostID hostURL:(NSURL *)url preferences:(NSUserDefaults *)preferences;
@property(nonatomic,readonly) NSString *mailSessionToken;
- (void)start;
- (void)stop;
@end
