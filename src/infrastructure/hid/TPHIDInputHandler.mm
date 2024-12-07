#import "TPHIDInputHandler.h"
#import "TPLogger.h"
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

@interface TPHIDInputHandler () {
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    BOOL _isScrollMode;
    NSDate *_middleButtonPressTime;
    CGPoint _savedCursorPosition;
    __weak id<TPHIDManagerDelegate> _delegate;
}
@end

@implementation TPHIDInputHandler

@synthesize isScrollMode = _isScrollMode;
@synthesize delegate = _delegate;

- (instancetype)init {
    if (self = [super init]) {
        _isScrollMode = NO;
        _leftButtonDown = NO;
        _rightButtonDown = NO;
        _middleButtonDown = NO;
        _savedCursorPosition = CGPointZero;
    }
    return self;
}

- (void)setDelegate:(id<TPHIDManagerDelegate>)delegate {
    _delegate = delegate;
}

- (id<TPHIDManagerDelegate>)delegate {
    return _delegate;
}

- (void)reset {
    _leftButtonDown = NO;
    _rightButtonDown = NO;
    _middleButtonDown = NO;
    _isScrollMode = NO;
}

- (void)handleInput:(IOHIDValueRef)value {
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
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
                [self handleScrollInput:value];
                break;
        }
    }
}

- (void)handleButtonInput:(IOHIDValueRef)value {
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex buttonState = IOHIDValueGetIntegerValue(value);
    
    switch (usage) {
        case 1:
            _leftButtonDown = buttonState;
            break;
        case 2:
            _rightButtonDown = buttonState;
            break;
        case 3:
            if (buttonState && !_middleButtonDown) {
                _middleButtonPressTime = [NSDate date];
                _middleButtonDown = YES;
                [[NSCursor openHandCursor] set];
                CGEventRef event = CGEventCreate(NULL);
                if (event) {
                    _savedCursorPosition = CGEventGetLocation(event);
                    CFRelease(event);
                }
            } else if (!buttonState && _middleButtonDown) {
                if ([[NSDate date] timeIntervalSinceDate:_middleButtonPressTime] < 0.3) {
                    _isScrollMode = !_isScrollMode;
                    if (!_isScrollMode) {
                        [[NSCursor arrowCursor] set];
                    }
                }
                _middleButtonDown = NO;
            }
            break;
    }
    
    if ([_delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        [_delegate didReceiveButtonPress:_leftButtonDown right:_rightButtonDown middle:_middleButtonDown];
    }
}

- (void)handleMovementInput:(IOHIDValueRef)value {
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    // Increased multiplier for faster response
    const int multiplier = 15;
    int deltaX = 0;
    int deltaY = 0;
    
    if (usage == kHIDUsage_GD_X) {
        deltaX = -(int)movement * multiplier;
    }
    else if (usage == kHIDUsage_GD_Y) {
        deltaY = -(int)movement * multiplier;
    }
    
    if (_isScrollMode && !_middleButtonDown) {
        if (deltaX != 0 || deltaY != 0) {
            CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, deltaY, deltaX);
            if (scrollEvent) {
                CGEventPost(kCGHIDEventTap, scrollEvent);
                CFRelease(scrollEvent);
            }
            
            CGWarpMouseCursorPosition(_savedCursorPosition);
        }
    } else {
        if (deltaX != 0 || deltaY != 0) {
            uint8_t buttons = (_leftButtonDown ? 1 : 0) | (_rightButtonDown ? 2 : 0);
            if ([_delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                [_delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
            }
        }
    }
}

- (void)handleScrollInput:(IOHIDValueRef)value {
    if (!value) return;
    
    CFIndex scrollDelta = IOHIDValueGetIntegerValue(value);
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, scrollDelta, 0);
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
    }
}

@end
