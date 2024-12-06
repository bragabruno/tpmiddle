#ifndef TPStatusReporter_h
#define TPStatusReporter_h

#ifdef __cplusplus
extern "C" {
#endif

#import <Cocoa/Cocoa.h>

@interface TPStatusReporter : NSObject

+ (instancetype)sharedReporter;

- (NSString *)applicationStatus:(BOOL)isInitialized 
                     debugMode:(BOOL)debugMode 
                   hidManager:(id)hidManager;
- (void)logSystemInfo;

@end

#ifdef __cplusplus
}
#endif

#endif /* TPStatusReporter_h */
