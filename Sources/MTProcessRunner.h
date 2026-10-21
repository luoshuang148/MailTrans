#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Owns one child process. runWithInput is blocking and belongs on a background queue.
@interface MTProcessRunner : NSObject
- (instancetype)initWithTask:(NSTask *)task;
@property(nonatomic,readonly) NSTask *task;
@property(nonatomic) NSTimeInterval timeout;
@property(nonatomic) NSUInteger outputLimit;
- (NSDictionary *)runWithInput:(NSData *)input;
- (void)cancel;
/// Used during normal app termination; does not return with a live owned child.
- (void)cancelAndWait;
@end
NS_ASSUME_NONNULL_END
