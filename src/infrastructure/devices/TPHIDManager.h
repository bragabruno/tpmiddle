#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <ApplicationServices/ApplicationServices.h>
#import "../../common/TPConstants.h"

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
@end

@interface TPHIDManager : NSObject {
    @private
    IOHIDManagerRef _hidManager;
    NSMutableArray *_devices;
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    BOOL _isRunning;
    BOOL _isScrollMode;
    NSDate *_middleButtonPressTime;
    int _pendingDeltaX;
    int _pendingDeltaY;
    NSDate *_lastMovementTime;
    CGPoint _savedCursorPosition;
    dispatch_queue_t _eventQueue;
}

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
