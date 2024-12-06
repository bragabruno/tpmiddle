#include "TPButtonManager.h"
#include "TPConfig.h"
#include "TPLogger.h"
#include <AppKit/AppKit.h>

#ifdef DEBUG
#define DebugLog(format, ...) NSLog(@"%s: " format, __FUNCTION__, ##__VA_ARGS__)
#else
#define DebugLog(format, ...)
#endif

// Scroll configuration
const CGFloat kMinMovementThreshold = 1.0;   // Minimum movement to trigger scroll
const CGFloat kMaxScrollSpeed = 50.0;        // Maximum scroll speed cap

static CGEventRef eventTapCallback(CGEventTapProxy proxy __unused, CGEventType type, CGEventRef event, void *refcon) {
    if (!event || !refcon) {
        return event;
    }
    
    @autoreleasepool {
        TPButtonManager *manager = (__bridge TPButtonManager *)refcon;
        return [manager handleEventTapEvent:type event:event];
    }
}

@interface TPButtonManager () {
    BOOL _leftDown;
    BOOL _rightDown;
    BOOL _middleEmulated;
    BOOL _middlePressed;
    NSDate *_leftDownTime;
    NSDate *_rightDownTime;
    
    // Scroll state
    CGFloat _accumulatedDeltaX;
    CGFloat _accumulatedDeltaY;
    NSTimeInterval _lastScrollTime;
    
    // Event tap
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
}
@end

@implementation TPButtonManager

+ (instancetype)sharedManager {
    static TPButtonManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPButtonManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self reset];
        [self setupEventTap];
    }
    return self;
}

- (void)dealloc {
    [self teardownEventTap];
}

#pragma mark - Event Tap Setup

- (void)setupEventTap {
    // Create event tap
    _eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventMouseMoved) |
        CGEventMaskBit(kCGEventLeftMouseDown) |
        CGEventMaskBit(kCGEventLeftMouseUp) |
        CGEventMaskBit(kCGEventRightMouseDown) |
        CGEventMaskBit(kCGEventRightMouseUp) |
        CGEventMaskBit(kCGEventOtherMouseDown) |
        CGEventMaskBit(kCGEventOtherMouseUp) |
        CGEventMaskBit(kCGEventScrollWheel),
        eventTapCallback,
        (__bridge void *)self
    );
    
    if (!_eventTap) {
        NSLog(@"Failed to create event tap - Input Monitoring permission may be required");
        return;
    }
    
    // Create run loop source
    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (!_runLoopSource) {
        NSLog(@"Failed to create run loop source");
        CFRelease(_eventTap);
        _eventTap = NULL;
        return;
    }
    
    // Add to run loop
    CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
    
    NSLog(@"Event tap setup successfully");
}

- (void)teardownEventTap {
    if (_runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
        _runLoopSource = NULL;
    }
    
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
}

- (CGEventRef)handleEventTapEvent:(CGEventType)type event:(CGEventRef)event {
    if (!event) {
        return NULL;
    }
    
    @try {
        switch (type) {
            case kCGEventMouseMoved:
                if (_middlePressed || _middleEmulated) {
                    CGPoint delta = CGEventGetLocation(event);
                    [self handleMovement:(int)delta.x deltaY:(int)delta.y withButtonState:0];
                    return NULL; // Consume the event
                }
                break;
                
            case kCGEventLeftMouseDown:
                _leftDown = YES;
                _leftDownTime = [NSDate date];
                break;
                
            case kCGEventLeftMouseUp:
                _leftDown = NO;
                break;
                
            case kCGEventRightMouseDown:
                _rightDown = YES;
                _rightDownTime = [NSDate date];
                break;
                
            case kCGEventRightMouseUp:
                _rightDown = NO;
                break;
                
            default:
                break;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in handleEventTapEvent: %@", exception);
    }
    
    return event;
}

#pragma mark - Public Methods

- (void)updateButtonStates:(BOOL)leftDown right:(BOOL)rightDown middle:(BOOL)middleDown {
    // Log button state
    [[TPLogger sharedLogger] logButtonEvent:leftDown right:rightDown middle:middleDown];
    
    // Real middle button press takes precedence
    if (middleDown != _middlePressed) {
        _middlePressed = middleDown;
        if (!_middlePressed) {
            // Reset scroll state when middle button is released
            _accumulatedDeltaX = 0;
            _accumulatedDeltaY = 0;
        }
    }
    
    if (middleDown) {
        if (!_middleEmulated) {
            [self postMiddleButtonEvent:YES];
            _middleEmulated = YES;
        }
        return;
    }
    
    // Handle left button state change
    if (leftDown != _leftDown) {
        _leftDown = leftDown;
        if (leftDown) {
            _leftDownTime = [NSDate date];
        }
    }
    
    // Handle right button state change
    if (rightDown != _rightDown) {
        _rightDown = rightDown;
        if (rightDown) {
            _rightDownTime = [NSDate date];
        }
    }
    
    // Check for middle button emulation
    if (leftDown && rightDown && !_middleEmulated) {
        NSTimeInterval timeDiff = fabs([_leftDownTime timeIntervalSinceDate:_rightDownTime]);
        if (timeDiff <= [TPConfig sharedConfig].middleButtonDelay) {
            [self postMiddleButtonEvent:YES];
            _middleEmulated = YES;
            _middlePressed = YES;
        }
    }
    
    // Release emulated middle button when both buttons are released
    if (!leftDown && !rightDown && _middleEmulated) {
        [self postMiddleButtonEvent:NO];
        _middleEmulated = NO;
        _middlePressed = NO;
        
        // Reset scroll state
        _accumulatedDeltaX = 0;
        _accumulatedDeltaY = 0;
    }
}

- (void)handleMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    if (!_middlePressed && !_middleEmulated) return;
    
    TPConfig *config = [TPConfig sharedConfig];
    
    // Calculate time since last scroll for acceleration
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval timeDelta = currentTime - _lastScrollTime;
    if (timeDelta > 0.1) timeDelta = 0.1; // Cap the time delta
    
    // Apply acceleration based on movement speed
    CGFloat speed = sqrt(deltaX * deltaX + deltaY * deltaY);
    CGFloat accelerationFactor = 1.0 + (speed * config.scrollAcceleration * timeDelta);
    
    // Apply direction adjustments
    CGFloat adjustedDeltaX = deltaX * (config.invertScrollX ? -1 : 1);
    CGFloat adjustedDeltaY = deltaY * (config.invertScrollY ? -1 : 1);
    
    // Accumulate movement with acceleration and speed multiplier
    _accumulatedDeltaX += adjustedDeltaX * config.scrollSpeedMultiplier * accelerationFactor;
    _accumulatedDeltaY += adjustedDeltaY * config.scrollSpeedMultiplier * accelerationFactor;
    
    // Only scroll if accumulated movement exceeds threshold
    if (fabs(_accumulatedDeltaX) >= kMinMovementThreshold || 
        fabs(_accumulatedDeltaY) >= kMinMovementThreshold) {
        
        // Cap scroll speed
        CGFloat scrollX = MIN(MAX(_accumulatedDeltaX, -kMaxScrollSpeed), kMaxScrollSpeed);
        CGFloat scrollY = MIN(MAX(_accumulatedDeltaY, -kMaxScrollSpeed), kMaxScrollSpeed);
        
        // Apply natural scrolling if enabled
        if (config.naturalScrolling) {
            scrollX = -scrollX;
            scrollY = -scrollY;
        }
        
        // Create and post scroll event
        [self postScrollEvent:scrollY deltaX:scrollX];
        
        // Reset accumulated deltas
        _accumulatedDeltaX = 0;
        _accumulatedDeltaY = 0;
        _lastScrollTime = currentTime;
    }
}

- (void)reset {
    _leftDown = NO;
    _rightDown = NO;
    if (_middleEmulated) {
        [self postMiddleButtonEvent:NO];
        _middleEmulated = NO;
    }
    _middlePressed = NO;
    _leftDownTime = nil;
    _rightDownTime = nil;
    
    // Reset scroll state
    _accumulatedDeltaX = 0;
    _accumulatedDeltaY = 0;
    _lastScrollTime = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL)isMiddleButtonEmulated {
    return _middleEmulated;
}

- (BOOL)isMiddleButtonPressed {
    return _middlePressed;
}

#pragma mark - Private Methods

- (void)postMiddleButtonEvent:(BOOL)isDown {
    @try {
        CGEventRef event = CGEventCreate(NULL);
        if (!event) {
            NSLog(@"Failed to create CGEvent for getting cursor position");
            return;
        }
        
        CGPoint pos = CGEventGetLocation(event);
        CFRelease(event);
        
        // Create and post middle button event
        CGEventRef mouseEvent = CGEventCreateMouseEvent(
            NULL,
            isDown ? kCGEventOtherMouseDown : kCGEventOtherMouseUp,
            pos,
            kCGMouseButtonCenter
        );
        
        if (mouseEvent) {
            CGEventPost(kCGHIDEventTap, mouseEvent);
            CFRelease(mouseEvent);
            
            // Log middle button emulation
            [[TPLogger sharedLogger] logMiddleButtonEmulation:isDown];
            
            // Notify delegate
            if ([self.delegate respondsToSelector:@selector(middleButtonStateChanged:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate middleButtonStateChanged:isDown];
                });
            }
            
            if ([TPConfig sharedConfig].debugMode) {
                DebugLog(@"Posted middle button %@ event at {%f, %f}",
                        isDown ? @"down" : @"up", pos.x, pos.y);
            }
        } else {
            NSLog(@"Failed to create mouse event");
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in postMiddleButtonEvent: %@", exception);
    }
}

- (void)postScrollEvent:(CGFloat)deltaY deltaX:(CGFloat)deltaX {
    @try {
        // Create scroll event (using pixel units for smoother scrolling)
        CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(
            NULL,
            kCGScrollEventUnitPixel,
            2,  // number of axes
            (int32_t)deltaY,
            (int32_t)deltaX
        );
        
        if (scrollEvent) {
            // Post the event
            CGEventPost(kCGHIDEventTap, scrollEvent);
            CFRelease(scrollEvent);
            
            // Log scroll event
            [[TPLogger sharedLogger] logScrollEvent:deltaX deltaY:deltaY];
            
            if ([TPConfig sharedConfig].debugMode) {
                DebugLog(@"Posted scroll event - deltaX: %.2f, deltaY: %.2f", deltaX, deltaY);
            }
        } else {
            NSLog(@"Failed to create scroll event");
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in postScrollEvent: %@", exception);
    }
}

@end
