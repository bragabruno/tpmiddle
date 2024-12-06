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
            default:
                break;
        }
    }
}

- (void)handleButtonInput:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex buttonState = IOHIDValueGetIntegerValue(value);
    
    switch (usage) {
        case 1: // Left button
            self.inputState.leftButtonDown = buttonState;
            break;
        case 2: // Right button
            self.inputState.rightButtonDown = buttonState;
            break;
        case 3: // Middle button
            if (buttonState && !self.inputState.middleButtonDown) {
                // Middle button just pressed
                self.inputState.middleButtonPressTime = [NSDate date];
                self.inputState.middleButtonDown = YES;
            } else if (!buttonState && self.inputState.middleButtonDown) {
                // Middle button just released
                NSTimeInterval pressDuration = [[NSDate date] timeIntervalSinceDate:self.inputState.middleButtonPressTime];
                if (pressDuration < 0.3) {
                    [self.inputState toggleScrollMode];
                    
                    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Scroll mode %@", 
                        self.inputState.isScrollMode ? @"enabled" : @"disabled"]];
                }
                self.inputState.middleButtonDown = NO;
            }
            self.inputState.middleButtonDown = buttonState;
            break;
        default:
            break;
    }
    
    [[TPLogger sharedLogger] logButtonEvent:self.inputState.leftButtonDown 
                                    right:self.inputState.rightButtonDown 
                                   middle:self.inputState.middleButtonDown];
    
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
    
    // Store the movement in the appropriate pending delta
    if (usage == kHIDUsage_GD_X) {
        self.inputState.pendingDeltaX = -(int)movement;  // Invert X for natural movement
    }
    else if (usage == kHIDUsage_GD_Y) {
        self.inputState.pendingDeltaY = -(int)movement;  // Invert Y for natural movement
    }
    
    // Check if we should process the movement
    NSTimeInterval timeSinceLastMovement = [[NSDate date] timeIntervalSinceDate:self.inputState.lastMovementTime];
    if (timeSinceLastMovement >= 0.001) { // Process movements every millisecond
        if (self.inputState.isScrollMode && !self.inputState.middleButtonDown) {
            // In scroll mode, convert movement to scroll events
            if (self.inputState.pendingDeltaX != 0 || self.inputState.pendingDeltaY != 0) {
                [self handleScrollInput:self.inputState.pendingDeltaY 
                       withHorizontal:self.inputState.pendingDeltaX];
                
                // Keep cursor at saved position during scroll mode
                CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,
                                                             self.inputState.savedCursorPosition,
                                                             kCGMouseButtonLeft);
                CGEventPost(kCGHIDEventTap, moveEvent);
                CFRelease(moveEvent);
            }
        } else {
            // Normal pointer movement
            if (self.inputState.pendingDeltaX != 0 || self.inputState.pendingDeltaY != 0) {
                uint8_t buttons = [self.inputState currentButtonState];
                
                [[TPLogger sharedLogger] logTrackpointMovement:self.inputState.pendingDeltaX 
                                                      deltaY:self.inputState.pendingDeltaY 
                                                    buttons:buttons];
                
                if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                    [self.delegate didReceiveMovement:self.inputState.pendingDeltaX 
                                            deltaY:self.inputState.pendingDeltaY 
                                  withButtonState:buttons];
                }
            }
        }
        
        [self.inputState resetPendingMovements];
    }
}

- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta {
    // Create and post scroll wheel event
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(
        NULL,
        kCGScrollEventUnitPixel,
        2,  // number of axes
        verticalDelta,
        horizontalDelta
    );
    
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
        
        [[TPLogger sharedLogger] logScrollEvent:horizontalDelta deltaY:verticalDelta];
    }
}

@end
