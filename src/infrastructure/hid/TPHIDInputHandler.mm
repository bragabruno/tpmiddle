#import "TPHIDInputHandler.h"
#import "TPLogger.h"
#import "TPConfig.h"
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

@interface TPHIDInputHandler () {
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    CGPoint _savedCursorPosition;
    __weak id<TPHIDManagerDelegate> _delegate;
    dispatch_queue_t _inputQueue;
    NSLock *_stateLock;
    CFMachPortRef _eventTap;
}

- (void)enforceCursorPosition;

@end

@implementation TPHIDInputHandler

@synthesize delegate = _delegate;

- (BOOL)isMiddleButtonHeld {
    [_stateLock lock];
    BOOL isHeld = _middleButtonDown;
    [_stateLock unlock];
    return isHeld;
}

static CGEventRef eventTapCallback(CGEventTapProxy proxy __unused, CGEventType type, CGEventRef event, void *refcon) {
    TPHIDInputHandler *handler = (__bridge TPHIDInputHandler *)refcon;
    
    // Only intercept events when middle button is held down
    if (handler->_middleButtonDown) {
        // Block all mouse movement events while middle button is held
        if (type == kCGEventMouseMoved || 
            type == kCGEventLeftMouseDragged || 
            type == kCGEventRightMouseDragged || 
            type == kCGEventOtherMouseDragged) {
            [handler enforceCursorPosition];
            return NULL;
        }
        
        // For any other event while middle button is held, force cursor position
        CGEventSetLocation(event, handler->_savedCursorPosition);
        [handler enforceCursorPosition];
    }
    return event;
}

- (void)enforceCursorPosition {
    if (_middleButtonDown && !CGPointEqualToPoint(_savedCursorPosition, CGPointZero)) {
        // Force cursor back to saved position
        CGWarpMouseCursorPosition(_savedCursorPosition);
    }
}

- (instancetype)init {
    if (self = [super init]) {
        _leftButtonDown = NO;
        _rightButtonDown = NO;
        _middleButtonDown = NO;
        _savedCursorPosition = CGPointZero;
        _stateLock = [[NSLock alloc] init];
        _inputQueue = dispatch_queue_create("com.tpmiddle.inputhandler", DISPATCH_QUEUE_SERIAL);
        
        // Create event tap to block cursor movement
        _eventTap = CGEventTapCreate(kCGSessionEventTap,
                                   kCGHeadInsertEventTap,
                                   kCGEventTapOptionDefault,
                                   CGEventMaskBit(kCGEventMouseMoved) |
                                   CGEventMaskBit(kCGEventLeftMouseDragged) |
                                   CGEventMaskBit(kCGEventRightMouseDragged) |
                                   CGEventMaskBit(kCGEventOtherMouseDragged) |
                                   CGEventMaskBit(kCGEventLeftMouseDown) |
                                   CGEventMaskBit(kCGEventLeftMouseUp) |
                                   CGEventMaskBit(kCGEventRightMouseDown) |
                                   CGEventMaskBit(kCGEventRightMouseUp) |
                                   CGEventMaskBit(kCGEventOtherMouseDown) |
                                   CGEventMaskBit(kCGEventOtherMouseUp),
                                   eventTapCallback,
                                   (__bridge void *)self);
        
        if (_eventTap) {
            CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
            CGEventTapEnable(_eventTap, true);
            CFRelease(runLoopSource);
        }
    }
    return self;
}

- (void)dealloc {
    [self reset];
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
    }
    _stateLock = nil;
    _inputQueue = NULL;
}

- (void)setDelegate:(id<TPHIDManagerDelegate>)delegate {
    _delegate = delegate;
}

- (id<TPHIDManagerDelegate>)delegate {
    return _delegate;
}

- (void)reset {
    [_stateLock lock];
    _leftButtonDown = NO;
    _rightButtonDown = NO;
    _middleButtonDown = NO;
    _savedCursorPosition = CGPointZero;
    CGAssociateMouseAndMouseCursorPosition(true);
    [_stateLock unlock];
}

- (void)handleInput:(IOHIDValueRef)value {
    if (!value) return;
    
    CFRetain(value);
    dispatch_async(_inputQueue, ^{
        @autoreleasepool {
            [self processInputValue:value];
            CFRelease(value);
        }
    });
}

- (void)processInputValue:(IOHIDValueRef)value {
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
    
    [_stateLock lock];
    
    switch (usage) {
        case 1:
            _leftButtonDown = buttonState;
            break;
        case 2:
            _rightButtonDown = buttonState;
            break;
        case 3:
            if (buttonState) {
                // Middle button pressed
                _middleButtonDown = YES;
                // Save cursor position
                CGEventRef event = CGEventCreate(NULL);
                if (event) {
                    _savedCursorPosition = CGEventGetLocation(event);
                    CFRelease(event);
                }
                // Disable mouse/cursor association
                CGAssociateMouseAndMouseCursorPosition(false);
            } else {
                // Middle button released
                _middleButtonDown = NO;
                _savedCursorPosition = CGPointZero;
                // Re-enable mouse/cursor association
                CGAssociateMouseAndMouseCursorPosition(true);
            }
            break;
    }
    
    BOOL leftButton = _leftButtonDown;
    BOOL rightButton = _rightButtonDown;
    BOOL middleButton = _middleButtonDown;
    
    [_stateLock unlock];
    
    id<TPHIDManagerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didReceiveButtonPress:leftButton right:rightButton middle:middleButton];
        });
    }
}

- (void)handleMovementInput:(IOHIDValueRef)value {
    if (!value) return;
    
    [_stateLock lock];
    BOOL isMiddleButtonHeld = _middleButtonDown;
    [_stateLock unlock];
    
    if (isMiddleButtonHeld) {
        // Force cursor position
        [self enforceCursorPosition];
        
        // Convert movement to scroll
        IOHIDElementRef element = IOHIDValueGetElement(value);
        uint32_t usage = IOHIDElementGetUsage(element);
        CFIndex movement = IOHIDValueGetIntegerValue(value);
        
        // Get scroll settings from config
        TPConfig *config = [TPConfig sharedConfig];
        double speedMultiplier = config.scrollSpeedMultiplier;
        double acceleration = config.scrollAcceleration;
        BOOL naturalScrolling = config.naturalScrolling;
        BOOL invertX = config.invertScrollX;
        BOOL invertY = config.invertScrollY;
        
        // Base multiplier for faster response
        const double baseMultiplier = 20.0;
        
        // Apply speed multiplier and acceleration
        double adjustedMovement = movement * baseMultiplier * speedMultiplier;
        if (fabs(adjustedMovement) > 1.0) {
            adjustedMovement *= (1.0 + (fabs(adjustedMovement) * acceleration * 0.1));
        }
        
        int deltaX = 0;
        int deltaY = 0;
        
        if (usage == kHIDUsage_GD_X) {
            deltaX = -(int)adjustedMovement;
            if (invertX) deltaX = -deltaX;
        }
        else if (usage == kHIDUsage_GD_Y) {
            deltaY = -(int)adjustedMovement;
            if (invertY) deltaY = -deltaY;
        }
        
        if (naturalScrolling) {
            deltaY = -deltaY;
        }
        
        if (deltaX != 0 || deltaY != 0) {
            // Create and post scroll event
            CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, deltaY, deltaX);
            if (scrollEvent) {
                CGEventPost(kCGHIDEventTap, scrollEvent);
                CFRelease(scrollEvent);
            }
        }
        
        // Force cursor position again after scroll
        [self enforceCursorPosition];
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
        [_stateLock lock];
        BOOL leftDown = _leftButtonDown;
        BOOL rightDown = _rightButtonDown;
        [_stateLock unlock];
        
        uint8_t buttons = (leftDown ? 1 : 0) | (rightDown ? 2 : 0);
        id<TPHIDManagerDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
            });
        }
    }
}

- (void)handleScrollInput:(IOHIDValueRef)value {
    if (!value) return;
    
    CFIndex scrollDelta = IOHIDValueGetIntegerValue(value);
    
    // Apply natural scrolling if enabled
    if ([TPConfig sharedConfig].naturalScrolling) {
        scrollDelta = -scrollDelta;
    }
    
    [_stateLock lock];
    BOOL isMiddleButtonHeld = _middleButtonDown;
    [_stateLock unlock];
    
    if (isMiddleButtonHeld) {
        [self enforceCursorPosition];
    }
    
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, scrollDelta);
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
    }
    
    if (isMiddleButtonHeld) {
        [self enforceCursorPosition];
    }
}

@end
