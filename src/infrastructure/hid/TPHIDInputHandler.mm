#import "TPHIDInputHandler.h"
#import "TPLogger.h"
#import "TPConfig.h"
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
    dispatch_queue_t _inputQueue;
    NSLock *_stateLock;
    CFMachPortRef _eventTap;
}
@end

@implementation TPHIDInputHandler

@synthesize isScrollMode = _isScrollMode;
@synthesize delegate = _delegate;

static CGEventRef eventTapCallback(CGEventTapProxy proxy __unused, CGEventType type, CGEventRef event, void *refcon) {
    TPHIDInputHandler *handler = (__bridge TPHIDInputHandler *)refcon;
    if (handler.isScrollMode) {
        CGPoint savedPos = handler->_savedCursorPosition;
        if (!CGPointEqualToPoint(savedPos, CGPointZero)) {
            // Block all mouse-related events except scroll
            if (type == kCGEventMouseMoved || 
                type == kCGEventLeftMouseDragged || 
                type == kCGEventRightMouseDragged || 
                type == kCGEventOtherMouseDragged ||
                type == kCGEventLeftMouseDown ||
                type == kCGEventLeftMouseUp ||
                type == kCGEventRightMouseDown ||
                type == kCGEventRightMouseUp ||
                type == kCGEventOtherMouseDown ||
                type == kCGEventOtherMouseUp) {
                
                // Force cursor back to saved position
                CGWarpMouseCursorPosition(savedPos);
                CGAssociateMouseAndMouseCursorPosition(true);
                
                // For non-movement events, allow them but fix position
                if (type != kCGEventMouseMoved && 
                    type != kCGEventLeftMouseDragged && 
                    type != kCGEventRightMouseDragged && 
                    type != kCGEventOtherMouseDragged) {
                    CGEventSetLocation(event, savedPos);
                    return event;
                }
                
                return NULL;
            }
        }
    }
    return event;
}

- (instancetype)init {
    if (self = [super init]) {
        _isScrollMode = NO;
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
    _isScrollMode = NO;
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
            if (buttonState && !_middleButtonDown) {
                _middleButtonPressTime = [NSDate date];
                _middleButtonDown = YES;
            } else if (!buttonState && _middleButtonDown) {
                if ([[NSDate date] timeIntervalSinceDate:_middleButtonPressTime] < 0.3) {
                    _isScrollMode = !_isScrollMode;
                    if (_isScrollMode) {
                        // Save cursor position when entering scroll mode
                        CGEventRef event = CGEventCreate(NULL);
                        if (event) {
                            _savedCursorPosition = CGEventGetLocation(event);
                            CFRelease(event);
                            // Force cursor to stay at saved position
                            CGWarpMouseCursorPosition(_savedCursorPosition);
                        }
                    } else {
                        CGAssociateMouseAndMouseCursorPosition(true);
                    }
                }
                _middleButtonDown = NO;
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
    BOOL isScrollModeActive = _isScrollMode && !_middleButtonDown;
    CGPoint savedPos = _savedCursorPosition;
    [_stateLock unlock];
    
    if (isScrollModeActive) {
        // Force cursor back to saved position
        if (!CGPointEqualToPoint(savedPos, CGPointZero)) {
            CGWarpMouseCursorPosition(savedPos);
        }
        
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
        if (!CGPointEqualToPoint(savedPos, CGPointZero)) {
            CGWarpMouseCursorPosition(savedPos);
        }
        return;
    }
    
    // Normal mouse movement mode
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    const int multiplier = 5;
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
    BOOL isScrollModeActive = _isScrollMode;
    CGPoint savedPos = _savedCursorPosition;
    [_stateLock unlock];
    
    if (isScrollModeActive && !CGPointEqualToPoint(savedPos, CGPointZero)) {
        CGWarpMouseCursorPosition(savedPos);
    }
    
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, scrollDelta);
    if (scrollEvent) {
        CGEventPost(kCGHIDEventTap, scrollEvent);
        CFRelease(scrollEvent);
    }
    
    if (isScrollModeActive && !CGPointEqualToPoint(savedPos, CGPointZero)) {
        CGWarpMouseCursorPosition(savedPos);
    }
}

@end
