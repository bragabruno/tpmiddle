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
    
    // Process button inputs first to ensure proper scroll mode state
    if (usagePage == kHIDPage_Button) {
        [self handleButtonInput:value];
    }
    
    // Check if middle button is held down to determine scroll mode
    BOOL shouldBeInScrollMode = self.inputState.middleButtonDown;
    if (shouldBeInScrollMode != self.inputState.isScrollMode) {
        if (shouldBeInScrollMode) {
            [self.inputState enableScrollMode];
        } else {
            [self.inputState disableScrollMode];
        }
    }
    
    // If in scroll mode, enforce cursor position
    if (self.inputState.isScrollMode) {
        [self.inputState enforceSavedCursorPosition];
    }
    
    // Handle other inputs based on current mode
    if (usagePage == kHIDPage_GenericDesktop) {
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
    
    // Ensure cursor position is maintained in scroll mode
    if (self.inputState.isScrollMode) {
        [self.inputState enforceSavedCursorPosition];
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
            // Update middle button state
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
        
        const int multiplier = 1; // Set to 1 for 1:1 movement to scroll
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
    
    const int multiplier = 1; // Set to 1 for 1:1 movement to scroll
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
