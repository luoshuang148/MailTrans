#import "MailLifecycle.h"

NSString * const MTLifecycleDefaultsDomain=@"local.codex.mailtranslationprobe";
NSString * const MTManualQuitMailSession=@"MTManualQuitMailSession";
NSString *MTMailSessionToken(NSArray<NSRunningApplication *> *applications) {
    NSMutableArray *tokens=[NSMutableArray new];
    for(NSRunningApplication *app in applications)if(!app.terminated)
        [tokens addObject:[NSString stringWithFormat:@"%d:%.6f",app.processIdentifier,app.launchDate.timeIntervalSince1970]];
    return [[tokens sortedArrayUsingSelector:@selector(compare:)]componentsJoinedByString:@"\n"];
}
static BOOL Suppressed(NSUserDefaults *preferences,NSString *session) {
    NSString *saved=[preferences stringForKey:MTManualQuitMailSession];
    if(!saved.length||!session.length)return NO;
    NSMutableSet *tokens=[NSMutableSet setWithArray:[saved componentsSeparatedByString:@"\n"]];
    [tokens intersectSet:[NSSet setWithArray:[session componentsSeparatedByString:@"\n"]]];
    return tokens.count>0;
}
@interface MTMailLifecycle ()
@property NSString *mailID;
@property NSString *hostID;
@property NSURL *hostURL;
@property NSUserDefaults *preferences;
@property NSMutableDictionary<NSNumber *,NSRunningApplication *> *mails;
@property NSMutableDictionary<NSNumber *,NSString *> *tokens;
@property NSArray<NSRunningApplication *> *hosts;
@property NSMutableSet<NSNumber *> *retiringHosts;
@property BOOL observing;
@property BOOL attempted;
@property BOOL pending;
@property NSUInteger generation;
@end
@implementation MTMailLifecycle
- (instancetype)initWithMailBundleIdentifier:(NSString *)mailID hostBundleIdentifier:(NSString *)hostID hostURL:(NSURL *)url preferences:(NSUserDefaults *)preferences {
    if((self=[super init])){_mailID=mailID.copy;_hostID=hostID.copy;_hostURL=url.URLByResolvingSymlinksInPath;_preferences=preferences;_mails=[NSMutableDictionary new];_tokens=[NSMutableDictionary new];_hosts=@[];_retiringHosts=[NSMutableSet new];}
    return self;
}
- (NSString *)mailSessionToken {return [[self.tokens.allValues sortedArrayUsingSelector:@selector(compare:)]componentsJoinedByString:@"\n"];}
- (BOOL)ownsHost:(NSRunningApplication *)app {
    return [app.bundleIdentifier isEqual:self.hostID]&&[app.bundleURL.URLByResolvingSymlinksInPath isEqual:self.hostURL];
}
- (void)stopHost {
    for(NSRunningApplication *app in self.hosts){
        NSNumber *pid=@(app.processIdentifier);
        if(!app.terminated&&![self.retiringHosts containsObject:pid]){
            [self.retiringHosts addObject:pid];
            if(![app terminate])[self.retiringHosts removeObject:pid];
        }
    }
}
- (void)ensureHost {
    if(!self.mails.count||self.attempted||self.pending)return;
    if(Suppressed(self.preferences,self.mailSessionToken)){self.attempted=YES;return;}
    // A previous session's host can still be processing its normal quit.
    // Wait for its exit; do not count it as this session's launch attempt.
    for(NSRunningApplication *app in self.hosts)
        if(!app.terminated){if(![self.retiringHosts containsObject:@(app.processIdentifier)])self.attempted=YES;return;}
    self.attempted=YES;
    self.pending=YES;NSUInteger requestGeneration=self.generation;
    NSWorkspaceOpenConfiguration *configuration=NSWorkspaceOpenConfiguration.configuration;
    configuration.activates=NO;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:self.hostURL configuration:configuration completionHandler:^(NSRunningApplication *app,NSError *error){
        // AppKit invokes this completion on a concurrent queue. All lifecycle
        // state and decisions are serialized with workspace KVO on the main queue.
        dispatch_async(dispatch_get_main_queue(),^{
            self.pending=NO;
            if(!self.mails.count){if([self ownsHost:app])[app terminate];[self stopHost];}
            else if(self.generation!=requestGeneration)[self ensureHost];
        });
        // A failed launch is tried again only in a new Mail session, not in a loop.
    }];
}
- (void)rememberSuppression:(BOOL)suppressed {
    if(suppressed&&self.mails.count){[self.preferences setObject:self.mailSessionToken forKey:MTManualQuitMailSession];[self.preferences synchronize];}
}
- (void)reconcile {
    NSMutableDictionary *mails=[NSMutableDictionary new],*tokens=[NSMutableDictionary new];
    NSMutableArray *hosts=[NSMutableArray new];NSMutableSet *hostPIDs=[NSMutableSet new];
    for(NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications){
        if(!app.terminated&&[self ownsHost:app]){[hosts addObject:app];[hostPIDs addObject:@(app.processIdentifier)];}
        if(!app.terminated&&[app.bundleIdentifier isEqual:self.mailID]){
            NSNumber *pid=@(app.processIdentifier);mails[pid]=app;
            tokens[pid]=self.tokens[pid]?:MTMailSessionToken(@[app]);
        }
    }
    BOOL hadMail=self.mails.count>0,suppressed=Suppressed(self.preferences,self.mailSessionToken);
    NSMutableSet *overlap=[NSMutableSet setWithArray:self.mails.allKeys];
    [overlap intersectSet:[NSSet setWithArray:mails.allKeys]];
    BOOL sameSession=hadMail&&mails.count&&overlap.count;
    self.mails=mails;self.tokens=tokens;self.hosts=hosts;
    [self.retiringHosts intersectSet:hostPIDs];
    if(!mails.count){if(hadMail){self.generation++;self.attempted=NO;}[self stopHost];}
    else if(!sameSession){self.generation++;self.attempted=NO;[self ensureHost];}
    else {[self rememberSuppression:suppressed];[self ensureHost];}
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context==(__bridge void *)self){[self reconcile];return;}
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)start {
    if(self.observing)return;
    self.observing=YES;self.attempted=NO;[self.mails removeAllObjects];[self.tokens removeAllObjects];
    // Workspace launch/quit notifications exclude LSUIElement apps. KVO also
    // sees the menu-only host, including a launch that finishes after Mail quits.
    [NSWorkspace.sharedWorkspace addObserver:self forKeyPath:@"runningApplications" options:0 context:(__bridge void *)self];
    [self reconcile];
}
- (void)stop {
    if(!self.observing)return;
    [NSWorkspace.sharedWorkspace removeObserver:self forKeyPath:@"runningApplications" context:(__bridge void *)self];
    self.observing=NO;
}
- (void)dealloc {[self stop];}
@end
