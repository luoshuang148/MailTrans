#import <Cocoa/Cocoa.h>
@class MTAppManagement;
NS_ASSUME_NONNULL_BEGIN
@interface MTSetupController : NSWindowController <NSWindowDelegate>
- (instancetype)initWithPreferences:(NSUserDefaults *)preferences;
@property(nonatomic,copy,nullable) void(^languagePreparationHandler)(void);
@property(nonatomic,copy,nullable) void(^cacheClearHandler)(void);
@property(nonatomic,copy,nullable) void(^quitHandler)(void);
@property(nonatomic,strong) MTAppManagement *management;
@property(nonatomic,readonly) BOOL needsSetup;
- (void)showWindow;
- (void)markSetupComplete;
@end
NS_ASSUME_NONNULL_END
