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
        @try {
            return [manager handleEventTapEvent:type event:event];
        } @catch (NSException *exception) {
            NSLog(@"Exception in eventTapCallback: %@", exception);
            return event;
        }
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
    
    // Thread safety
    NSLock *_stateLock;
    NSLock *_delegateLock;
    dispatch_queue_t _eventQueue;
    dispatch_queue_t _delegateQueue;
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
        _stateLock = [[NSLock alloc] init];
        _delegateLock = [[NSLock alloc] init];
        _eventQueue = dispatch_queue_create("com.tpmiddle.buttonManager.event", DISPATCH_QUEUE_SERIAL);
        _delegateQueue = dispatch_queue_create("com.tpmiddle.buttonManager.delegate", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_eventQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        [self reset];
        [self setupEventTap];
    }
    return self;
}

- (void)dealloc {
    [self teardownEventTap];
    _stateLock = nil;
    _delegateLock = nil;
    _eventQueue = NULL;
    _delegateQueue = NULL;
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
        [_stateLock lock];
        switch (type) {
            case kCGEventMouseMoved:
                if (_middlePressed || _middleEmulated) {
                    CGPoint delta = CGEventGetLocation(event);
                    [_stateLock unlock];
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
                
            case kCGEventOtherMouseDown:
            case kCGEventOtherMouseUp:
                // Consume middle button events to prevent clicks
                if (CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) == kCGMouseButtonCenter) {
                    [_stateLock unlock];
                    return NULL;
                }
                break;
                
            case kCGEventScrollWheel:
                // Let system handle regular scroll events
                break;
                
            default:
                break;
        }
        [_stateLock unlock];
    } @catch (NSException *exception) {
        [_stateLock unlock];
        NSLog(@"Exception in handleEventTapEvent: %@", exception);
    }
    
    return event;
}

#pragma mark - Public Methods

- (void)updateButtonStates:(BOOL)leftDown right:(BOOL)rightDown middle:(BOOL)middleDown {
    [_stateLock lock];
    @try {
        // Log button state
        [[TPLogger sharedLogger] logButtonEvent:leftDown right:rightDown middle:middleDown];
        
        // Handle middle button state for scroll mode only
        if (middleDown != _middlePressed) {
            _middlePressed = middleDown;
            if (!_middlePressed) {
                // Reset scroll state when middle button is released
                _accumulatedDeltaX = 0;
                _accumulatedDeltaY = 0;
            }
            // Notify delegate of state change without generating click events
            [self notifyDelegateOfMiddleButtonState:middleDown];
        }
        
        if (middleDown) {
            _middleEmulated = YES;
            [_stateLock unlock];
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
                _middleEmulated = YES;
                _middlePressed = YES;
                [self notifyDelegateOfMiddleButtonState:YES];
            }
        }
        
        // Release emulated middle button when both buttons are released
        if (!leftDown && !rightDown && _middleEmulated) {
            _middleEmulated = NO;
            _middlePressed = NO;
            [self notifyDelegateOfMiddleButtonState:NO];
            
            // Reset scroll state
            _accumulatedDeltaX = 0;
            _accumulatedDeltaY = 0;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in updateButtonStates: %@", exception);
    }
    [_stateLock unlock];
}

- (void)handleMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    [_stateLock lock];
    BOOL shouldHandle = _middlePressed || _middleEmulated;
    [_stateLock unlock];
    
    if (!shouldHandle) return;
    
    TPConfig *config = [TPConfig sharedConfig];
    
    // Calculate time since last scroll for acceleration
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval timeDelta = currentTime - _lastScrollTime;
    if (timeDelta > 0.1) timeDelta = 0.1; // Cap the time delta
    
    // Apply acceleration based on movement speed
    CGFloat speed = sqrt(deltaX * deltaX + deltaY * deltaY);
    CGFloat accelerationFactor = 1.0 + (speed * config.scrollAcceleration * timeDelta);
    
    // Invert the movement values for natural scrolling direction
    CGFloat adjustedDeltaX = -deltaX;
    CGFloat adjustedDeltaY = -deltaY;
    
    [_stateLock lock];
    // Accumulate movement with acceleration and speed multiplier
    _accumulatedDeltaX += adjustedDeltaX * config.scrollSpeedMultiplier * accelerationFactor;
    _accumulatedDeltaY += adjustedDeltaY * config.scrollSpeedMultiplier * accelerationFactor;
    
    // Only scroll if accumulated movement exceeds threshold
    if (fabs(_accumulatedDeltaX) >= kMinMovementThreshold || 
        fabs(_accumulatedDeltaY) >= kMinMovementThreshold) {
        
        // Cap scroll speed
        CGFloat scrollX = MIN(MAX(_accumulatedDeltaX, -kMaxScrollSpeed), kMaxScrollSpeed);
        CGFloat scrollY = MIN(MAX(_accumulatedDeltaY, -kMaxScrollSpeed), kMaxScrollSpeed);
        
        // Reset accumulated deltas
        _accumulatedDeltaX = 0;
        _accumulatedDeltaY = 0;
        _lastScrollTime = currentTime;
        
        [_stateLock unlock];
        
        // Post scroll event
        [self postScrollEvent:scrollY deltaX:scrollX];
    } else {
        [_stateLock unlock];
    }
}

- (void)reset {
    [_stateLock lock];
    _leftDown = NO;
    _rightDown = NO;
    _middleEmulated = NO;
    _middlePressed = NO;
    _leftDownTime = nil;
    _rightDownTime = nil;
    
    // Reset scroll state
    _accumulatedDeltaX = 0;
    _accumulatedDeltaY = 0;
    _lastScrollTime = [NSDate timeIntervalSinceReferenceDate];
    [_stateLock unlock];
    
    // Notify delegate of reset
    [self notifyDelegateOfMiddleButtonState:NO];
}

- (BOOL)isMiddleButtonEmulated {
    [_stateLock lock];
    BOOL emulated = _middleEmulated;
    [_stateLock unlock];
    return emulated;
}

- (BOOL)isMiddleButtonPressed {
    [_stateLock lock];
    BOOL pressed = _middlePressed;
    [_stateLock unlock];
    return pressed;
}

#pragma mark - Private Methods

- (void)notifyDelegateOfMiddleButtonState:(BOOL)isDown {
    [_delegateLock lock];
    id<TPButtonManagerDelegate> delegate = self.delegate;
    [_delegateLock unlock];
    
    if (!delegate) return;
    
    if ([delegate respondsToSelector:@selector(middleButtonStateChanged:)]) {
        dispatch_async(_delegateQueue, ^{
            [delegate middleButtonStateChanged:isDown];
        });
    }
}

- (void)postScrollEvent:(CGFloat)deltaY deltaX:(CGFloat)deltaX {
    @try {
        dispatch_async(_eventQueue, ^{
            @try {
                // Create scroll event with natural scrolling
                CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(
                    NULL,
                    kCGScrollEventUnitPixel,
                    2,  // number of axes
                    (int32_t)deltaY,
                    (int32_t)deltaX
                );
                
                if (scrollEvent) {
                    // Set the phase to ensure consistent behavior
                    CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventIsContinuous, 1);
                    
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
                NSLog(@"Exception in postScrollEvent async block: %@", exception);
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"Exception in postScrollEvent: %@", exception);
    }
}

@end
