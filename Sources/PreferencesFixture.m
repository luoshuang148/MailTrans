#import <AppKit/AppKit.h>
#import <stdio.h>
@protocol PreferencesAPI
+ (NSUserDefaults *)preferencesForDomain:(NSString *)domain;
@end
int main(int argc,const char *argv[]) {@autoreleasepool {
    if(argc!=5)return 2;
    NSString *domain=@(argv[1]),*action=@(argv[2]),*key=@(argv[3]),*value=@(argv[4]);
    if([action isEqual:@"clean"]){[NSUserDefaults.standardUserDefaults removePersistentDomainForName:domain];[NSUserDefaults.standardUserDefaults synchronize];return 0;}
    Class<PreferencesAPI> lifecycle=NSClassFromString(@"MTMailLifecycle");
    if(![(id)lifecycle respondsToSelector:@selector(preferencesForDomain:)]){
        fputs("FAIL: lifecycle preference factory is missing\n",stderr);return 1;
    }
    NSUserDefaults *preferences=[lifecycle preferencesForDomain:domain];
    if([action isEqual:@"write"]){[preferences setObject:value forKey:key];return [preferences synchronize]?0:3;}
    if(![[preferences stringForKey:key]isEqual:value]){
        fputs("FAIL: manual-quit preference is invisible across bundled processes\n",stderr);return 1;
    }
    return 0;
}}
