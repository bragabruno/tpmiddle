#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import "TPConstants.h"

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
@end

@interface TPHIDManager : NSObject

@property (weak, nonatomic) id<TPHIDManagerDelegate> delegate;
@property (readonly) BOOL isRunning;
@property (readonly) BOOL isScrollMode;

+ (instancetype)sharedManager;

- (BOOL)start;
- (void)stop;

// Device matching criteria
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;

@end

#endif // __OBJC__
