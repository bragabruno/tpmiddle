#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import "TPHIDManagerTypes.h"
#import "TPHIDManagerDelegate.h"

@interface TPHIDManager : NSObject

@property (weak) id<TPHIDManagerDelegate> delegate;
@property (readonly) NSArray *devices;
@property (readonly) BOOL isRunning;
@property (nonatomic, readonly) BOOL isScrollMode;  // Updated isScrollMode property

+ (instancetype)sharedManager;

- (BOOL)start;
- (void)stop;
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;
- (NSString *)deviceStatus;
- (NSString *)currentConfiguration;

@end

#endif // __OBJC__

#ifdef __cplusplus
}
#endif
