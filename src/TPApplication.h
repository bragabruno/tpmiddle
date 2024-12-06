#ifndef TPApplication_h
#define TPApplication_h

#include <stdint.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "TPHIDManager.h"
#import "TPButtonManager.h"
#import "TPStatusBarController.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

+ (instancetype)sharedApplication;
- (void)start;

@end

@interface TPApplication (Methods)
@end
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Device identification constants
extern const uint32_t kVendorIDLenovo;
extern const uint32_t kUsagePageGenericDesktop;
extern const uint32_t kUsagePageButton;
extern const uint32_t kUsageMouse;
extern const uint32_t kUsagePointer;

#ifdef __cplusplus
}
#endif

#endif /* TPApplication_h */
