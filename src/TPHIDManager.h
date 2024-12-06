#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <ApplicationServices/ApplicationServices.h>
#import "TPConstants.h"

// Constants for button states
#define kLeftButtonBit   0x01
#define kRightButtonBit  0x02
#define kMiddleButtonBit 0x04

// Error handling
extern NSString *const TPHIDManagerErrorDomain;

typedef NS_ENUM(NSInteger, TPHIDManagerErrorCode) {
    TPHIDManagerErrorPermissionDenied = 1000,
    TPHIDManagerErrorInitializationFailed = 1001,
    TPHIDManagerErrorDeviceAccessFailed = 1002,
    TPHIDManagerErrorInvalidConfiguration = 1003
};

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
- (void)didEncounterError:(NSError *)error;
@end

@interface TPHIDManager : NSObject

@property (weak, nonatomic) id<TPHIDManagerDelegate> delegate;
@property (readonly) BOOL isRunning;
@property (readonly) BOOL isScrollMode;
@property (nonatomic, readonly) NSArray *devices;

+ (instancetype)sharedManager;

// Core functionality
- (BOOL)start;
- (void)stop;

// Device matching criteria
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;

// Error handling
- (NSError *)checkPermissions;
- (NSError *)validateConfiguration;

// Debugging
- (NSString *)deviceStatus;
- (NSString *)currentConfiguration;

// Input handling
- (void)handleInput:(IOHIDValueRef)value;
- (void)handleButtonInput:(IOHIDValueRef)value;
- (void)handleMovementInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta;

// Device management
- (void)deviceAdded:(IOHIDDeviceRef)device;
- (void)deviceRemoved:(IOHIDDeviceRef)device;

@end

#endif // __OBJC__
