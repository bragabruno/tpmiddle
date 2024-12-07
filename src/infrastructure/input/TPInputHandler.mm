#import "TPInputHandler.h"
#import "TPLogger.h"

@implementation TPInputHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _inputState = [TPInputState sharedState];
    }
    return self;
}

- (void)handleInput:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    
    if (usagePage == kHIDPage_Button) {
        [self handleButtonInput:value];
    }
    else if (usagePage == kHIDPage_GenericDesktop) {
        switch (usage) {
            case kHIDUsage_GD_X:
            case kHIDUsage_GD_Y:
                [self handleMovementInput:value];
                break;
            case kHIDUsage_GD_Wheel:
                [self handleScrollInput:IOHIDValueGetIntegerValue(value) withHorizontal:0];
                break;
        }
    }
}

- (void)handleButtonInput:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex buttonState = IOHIDValueGetIntegerValue(value);
    
    switch (usage) {
        case 1:
            self.inputState.leftButtonDown = buttonState;
            break;
        case 2:
            self.inputState.rightButtonDown = buttonState;
            break;
        case 3:
            if (buttonState && !self.inputState.middleButtonDown) {
                self.inputState.middleButtonPressTime = [NSDate date];
                self.inputState.middleButtonDown = YES;
            } else if (!buttonState && self.inputState.middleButtonDown) {
                if ([[NSDate date] timeIntervalSinceDate:self.inputState.middleButtonPressTime] < 0.3) {
                    [self.inputState toggleScrollMode];
                }
                self.inputState.middleButtonDown = NO;
            }
            self.inputState.middleButtonDown = buttonState;
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        [self.delegate didReceiveButtonPress:self.inputState.leftButtonDown 
                                     right:self.inputState.rightButtonDown 
                                    middle:self.inputState.middleButtonDown];
    }
}

- (void)handleMovementInput:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    // Extreme multiplier for instant response
    const int multiplier = 12;
    
    int deltaX = 0;
    int deltaY = 0;
    
    if (usage == kHIDUsage_GD_X) {
        deltaX = -(int)movement * multiplier;
    }
    else if (usage == kHIDUsage_GD_Y) {
        deltaY = -(int)movement * multiplier;
    }
    
    if (self.inputState.isScrollMode && !self.inputState.middleButtonDown) {
        if (deltaX != 0 || deltaY != 0) {
            CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, deltaY, deltaX);
            if (scrollEvent) {
                CGEventPost(kCGHIDEventTap, scrollEvent);
                CFRelease(scrollEvent);
            }
            
            // Keep cursor fixed
            CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,
                                                         self.inputState.savedCursorPosition,
                                                         kCGMouseButtonLeft);
            if (moveEvent) {
                CGEventPost(kCGHIDEventTap, moveEvent);
                CFRelease(moveEvent);
            }
        }
    } else {
        if (deltaX != 0 || deltaY != 0) {
            if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                [self.delegate didReceiveMovement:deltaX 
                                        deltaY:deltaY 
                              withButtonState:[self.inputState currentButtonState]];
            }
        }
    }
}

- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta {
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, verticalDelta, horizontalDelta);
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
    }
}

@end
