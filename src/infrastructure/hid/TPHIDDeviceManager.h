#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import "TPHIDManagerDelegate.h"
#import "TPHIDManagerTypes.h"

@interface TPHIDDeviceManager : NSObject

@property (weak) id<TPHIDManagerDelegate> delegate;
@property (readonly) NSArray *devices;
@property (readonly) BOOL isRunning;

- (instancetype)init;
- (BOOL)start;
- (void)stop;
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;
- (NSString *)deviceStatus;
- (NSString *)currentConfiguration;
- (NSError *)checkPermissions;
- (NSError *)validateConfiguration;
- (void)deviceAdded:(IOHIDDeviceRef)device;
- (void)deviceRemoved:(IOHIDDeviceRef)device;

@end

#endif // __OBJC__

#ifdef __cplusplus
}
#endif
