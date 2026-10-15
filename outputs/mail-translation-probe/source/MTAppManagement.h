#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
/// Synchronous filesystem/process operations; call from a background queue in UI.
@interface MTAppManagement : NSObject
@property(nonatomic,readonly) NSURL *appURL;
@property(nonatomic,copy) NSDictionary *(^commandHandler)(NSString *path,NSArray<NSString *> *arguments);
@property(nonatomic,copy) BOOL (^mailRunningHandler)(void);
@property(nonatomic,copy) BOOL (^trashHandler)(NSURL *url,NSError **error);
- (instancetype)init;
- (instancetype)initWithAppURL:(NSURL *)appURL homeURL:(NSURL *)homeURL serviceLabel:(NSString *)label NS_DESIGNATED_INITIALIZER;
- (BOOL)enableAutomaticLaunch:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableAutomaticLaunch:(NSError * _Nullable * _Nullable)error;
- (NSDictionary *)statusSnapshot;
/// Caller must show an explicit native confirmation before passing YES.
- (BOOL)uninstallConfirmed:(BOOL)confirmed error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
