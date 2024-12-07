#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>
#import "TPHIDManagerDelegate.h"

// Button state bits
#define kLeftButtonBit   0x01
#define kRightButtonBit  0x02
#define kMiddleButtonBit 0x04

@interface TPHIDInputHandler : NSObject

@property (atomic, weak) id<TPHIDManagerDelegate> delegate;

- (void)handleInput:(IOHIDValueRef)value;
- (void)reset;
- (BOOL)isMiddleButtonHeld;

@end

#endif
