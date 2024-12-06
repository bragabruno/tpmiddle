#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import "TPHIDManagerDelegate.h"
#import "TPHIDManagerTypes.h"

@interface TPHIDInputHandler : NSObject

@property (weak) id<TPHIDManagerDelegate> delegate;
@property (readonly) BOOL isScrollMode;

- (instancetype)init;
- (void)handleInput:(IOHIDValueRef)value;
- (void)handleButtonInput:(IOHIDValueRef)value;
- (void)handleMovementInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta;
- (void)reset;

@end

#endif // __OBJC__

#ifdef __cplusplus
}
#endif
