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
    // If in scroll mode, enforce cursor position before any input processing
    if (self.inputState.isScrollMode) {
        [self.inputState enforceSavedCursorPosition];
    }
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    
    // In scroll mode, only process button and scroll inputs
    if (self.inputState.isScrollMode) {
        if (usagePage == kHIDPage_Button) {
            [self handleButtonInput:value];
        }
        else if (usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Wheel) {
            [self handleScrollInput:IOHIDValueGetIntegerValue(value) withHorizontal:0];
        }
        // Enforce cursor position after any input processing
        [self.inputState enforceSavedCursorPosition];
        return;
    }
    
    // Normal mode processing
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
    if (self.inputState.isScrollMode) {
        // Convert movement to scroll in scroll mode
        IOHIDElementRef element = IOHIDValueGetElement(value);
        uint32_t usage = IOHIDElementGetUsage(element);
        CFIndex movement = IOHIDValueGetIntegerValue(value);
        
        const int multiplier = 12;
        int deltaX = 0;
        int deltaY = 0;
        
        if (usage == kHIDUsage_GD_X) {
            deltaX = -(int)movement * multiplier;
        }
        else if (usage == kHIDUsage_GD_Y) {
            deltaY = -(int)movement * multiplier;
        }
        
        if (deltaX != 0 || deltaY != 0) {
            // Enforce position before scroll
            [self.inputState enforceSavedCursorPosition];
            
            // Create and post scroll event
            CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, deltaY, deltaX);
            if (scrollEvent) {
                CGEventPost(kCGHIDEventTap, scrollEvent);
                CFRelease(scrollEvent);
            }
            
            // Enforce position after scroll
            [self.inputState enforceSavedCursorPosition];
        }
        return;
    }
    
    // Normal mouse movement mode
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    const int multiplier = 12;
    int deltaX = 0;
    int deltaY = 0;
    
    if (usage == kHIDUsage_GD_X) {
        deltaX = -(int)movement * multiplier;
    }
    else if (usage == kHIDUsage_GD_Y) {
        deltaY = -(int)movement * multiplier;
    }
    
    if (deltaX != 0 || deltaY != 0) {
        if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
            [self.delegate didReceiveMovement:deltaX 
                                    deltaY:deltaY 
                          withButtonState:[self.inputState currentButtonState]];
        }
    }
}

- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta {
    // Enforce position before scroll if in scroll mode
    if (self.inputState.isScrollMode) {
        [self.inputState enforceSavedCursorPosition];
    }
    
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, verticalDelta, horizontalDelta);
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
    }
    
    // Enforce position after scroll if in scroll mode
    if (self.inputState.isScrollMode) {
        [self.inputState enforceSavedCursorPosition];
    }
}

@end
