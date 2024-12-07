#import "TPHIDInputHandler.h"
#import "TPLogger.h"
#import <CoreGraphics/CoreGraphics.h>

@interface TPHIDInputHandler () {
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    BOOL _isScrollMode;
    NSDate *_middleButtonPressTime;
    int _pendingDeltaX;
    int _pendingDeltaY;
    NSDate *_lastMovementTime;
    CGPoint _savedCursorPosition;
    dispatch_queue_t _eventQueue;
    NSLock *_stateLock;
}
@end

@implementation TPHIDInputHandler

@synthesize isScrollMode = _isScrollMode;

- (instancetype)init {
    if (self = [super init]) {
        _isScrollMode = NO;
        _leftButtonDown = NO;
        _rightButtonDown = NO;
        _middleButtonDown = NO;
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
        _savedCursorPosition = CGPointZero;
        _eventQueue = dispatch_queue_create("com.tpmiddle.inputQueue", DISPATCH_QUEUE_SERIAL);
        _stateLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc {
    _eventQueue = NULL;
    _stateLock = nil;
}

- (void)reset {
    [_stateLock lock];
    _leftButtonDown = NO;
    _rightButtonDown = NO;
    _middleButtonDown = NO;
    _isScrollMode = NO;
    _pendingDeltaX = 0;
    _pendingDeltaY = 0;
    [_stateLock unlock];
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
            default:
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
    
    [_stateLock lock];
    switch (usage) {
        case 1: // Left button
            _leftButtonDown = buttonState;
            break;
        case 2: // Right button
            _rightButtonDown = buttonState;
            break;
        case 3: // Middle button
            if (buttonState && !_middleButtonDown) {
                _middleButtonPressTime = [NSDate date];
                _middleButtonDown = YES;
            } else if (!buttonState && _middleButtonDown) {
                NSTimeInterval pressDuration = [[NSDate date] timeIntervalSinceDate:_middleButtonPressTime];
                if (pressDuration < 0.3) {
                    _isScrollMode = !_isScrollMode;
                    if (_isScrollMode) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CGEventRef event = CGEventCreate(NULL);
                            if (event) {
                                self->_savedCursorPosition = CGEventGetLocation(event);
                                CFRelease(event);
                            }
                        });
                    }
                }
                _middleButtonDown = NO;
            }
            break;
        default:
            break;
    }
    
    BOOL leftDown = _leftButtonDown;
    BOOL rightDown = _rightButtonDown;
    BOOL middleDown = _middleButtonDown;
    [_stateLock unlock];
    
    if ([self.delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didReceiveButtonPress:leftDown right:rightDown middle:middleDown];
        });
    }
}

- (void)handleMovementInput:(IOHIDValueRef)value {
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    [_stateLock lock];
    if (usage == kHIDUsage_GD_X) {
        _pendingDeltaX = -(int)movement;
    }
    else if (usage == kHIDUsage_GD_Y) {
        _pendingDeltaY = -(int)movement;
    }
    
    NSTimeInterval timeSinceLastMovement = [[NSDate date] timeIntervalSinceDate:_lastMovementTime];
    if (timeSinceLastMovement >= 0.001) {
        uint8_t buttons = (_leftButtonDown ? kLeftButtonBit : 0) | 
                         (_rightButtonDown ? kRightButtonBit : 0) | 
                         (_middleButtonDown ? kMiddleButtonBit : 0);
        
        int deltaX = _pendingDeltaX;
        int deltaY = _pendingDeltaY;
        BOOL scrollMode = _isScrollMode;
        BOOL middleDown = _middleButtonDown;
        CGPoint cursorPos = _savedCursorPosition;
        
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
        [_stateLock unlock];
        
        if (scrollMode && !middleDown) {
            if (deltaX != 0 || deltaY != 0) {
                [self handleScrollInput:deltaY withHorizontal:deltaX];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,
                                                               cursorPos,
                                                               kCGMouseButtonLeft);
                    if (moveEvent) {
                        CGEventPost(kCGHIDEventTap, moveEvent);
                        CFRelease(moveEvent);
                    }
                });
            }
        } else {
            if (deltaX != 0 || deltaY != 0) {
                if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
                    });
                }
            }
        }
    } else {
        [_stateLock unlock];
    }
}

- (void)handleScrollInput:(IOHIDValueRef)value {
    if (!value) return;
    
    CFIndex scrollDelta = IOHIDValueGetIntegerValue(value);
    [self handleScrollInput:scrollDelta withHorizontal:0];
}

- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta {
    dispatch_async(dispatch_get_main_queue(), ^{
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
        }
    });
}

@end
