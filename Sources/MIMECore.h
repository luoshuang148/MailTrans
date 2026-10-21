#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface MTMessage : NSObject
@property(readonly,copy) NSData *original;
@property(readonly,copy) NSString *key;
@property(readonly,copy) NSString *subject;
@property(readonly) BOOL eligible;
@property(readonly) BOOL malformed;
@property(readonly) BOOL protectedContent;
@property(readonly,copy) NSArray<NSString *> *texts;
+ (nullable instancetype)messageWithData:(NSData *)data;
+ (NSString *)keyForData:(NSData *)data;
- (nullable NSData *)renderTranslations:(nullable NSArray<NSString *> *)translations includeControls:(BOOL)controls;
- (NSString *)bodyTextForLanguageRecognition;
@end

@interface MTCache : NSObject
@property(readonly,strong) NSURL *root;
- (instancetype)initWithRoot:(NSURL *)root;
+ (BOOL)isValidKey:(NSString *)key;
- (BOOL)rememberMessage:(MTMessage *)message;
- (BOOL)rememberMessage:(MTMessage *)message changed:(nullable BOOL *)changed;
- (nullable NSString *)subjectForKey:(NSString *)key;
- (BOOL)hasSourceForKey:(NSString *)key;
- (BOOL)hasTranslatableSourceForKey:(NSString *)key;
- (BOOL)markTranslatableSourceForKey:(NSString *)key;
- (BOOL)hasStoredDisplayForKey:(NSString *)key;
- (BOOL)hasTranslatedDisplayForKey:(NSString *)key;
- (BOOL)activateStoredDisplayForKey:(NSString *)key;
- (nullable NSData *)sourceForKey:(NSString *)key;
- (nullable NSData *)storedDisplayForKey:(NSString *)key;
- (nullable NSData *)displayForKey:(NSString *)key;
- (BOOL)setDisplay:(NSData *)data forKey:(NSString *)key;
- (BOOL)setDisplay:(NSData *)data forKey:(NSString *)key activate:(BOOL)activate;
- (BOOL)prefersOriginalForKey:(NSString *)key;
- (void)restoreKey:(NSString *)key;
- (NSArray<NSDictionary *> *)recentMessages;
- (void)clear;
@end

@interface MTTranslationQueue : NSObject
- (instancetype)initWithClock:(NSTimeInterval (^)(void))clock;
- (void)enqueueKey:(NSString *)key;
- (nullable NSString *)takeNextKey;
- (void)cancelKey:(NSString *)key;
- (void)completeKey:(NSString *)key;
@end

@interface MTRequestGate : NSObject
- (NSUUID *)beginKey:(NSString *)key;
- (void)invalidateKey:(NSString *)key;
- (BOOL)isCurrent:(NSUUID *)token forKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
