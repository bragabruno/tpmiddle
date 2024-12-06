#ifndef TPErrorHandler_h
#define TPErrorHandler_h

#ifdef __cplusplus
extern "C" {
#endif

#import <Cocoa/Cocoa.h>

@interface TPErrorHandler : NSObject

+ (instancetype)sharedHandler;

- (void)showError:(NSError *)error;
- (void)logError:(NSError *)error;
- (void)logException:(NSException *)exception;

@end

#ifdef __cplusplus
}
#endif

#endif /* TPErrorHandler_h */
