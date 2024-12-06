#import "TPButtonManager.h"
#import "TPConfig.h"
#import "TPLogger.h"
#import <AppKit/AppKit.h>

#ifdef DEBUG
#define DebugLog(format, ...) NSLog(@"%s: " format, __FUNCTION__, ##__VA_ARGS__)
#else
#define DebugLog(format, ...)
#endif

// Scroll configuration
const CGFloat kMinMovementThreshold = 1.0;   // Minimum movement to trigger scroll
const CGFloat kMaxScrollSpeed = 50.0;        // Maximum scroll speed cap

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
    }
    return self;
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
    CGEventRef event = CGEventCreate(NULL);
    CGPoint pos = CGEventGetLocation(event);
    CFRelease(event);
    
    // Create and post middle button event
    CGEventRef mouseEvent = CGEventCreateMouseEvent(
        NULL,
        isDown ? kCGEventOtherMouseDown : kCGEventOtherMouseUp,
        pos,
        kCGMouseButtonCenter
    );
    
    CGEventPost(kCGHIDEventTap, mouseEvent);
    CFRelease(mouseEvent);
    
    // Log middle button emulation
    [[TPLogger sharedLogger] logMiddleButtonEmulation:isDown];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(middleButtonStateChanged:)]) {
        [self.delegate middleButtonStateChanged:isDown];
    }
    
    if ([TPConfig sharedConfig].debugMode) {
        DebugLog(@"Posted middle button %@ event at {%f, %f}",
                isDown ? @"down" : @"up", pos.x, pos.y);
    }
}

- (void)postScrollEvent:(CGFloat)deltaY deltaX:(CGFloat)deltaX {
    // Create scroll event (using pixel units for smoother scrolling)
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(
        NULL,
        kCGScrollEventUnitPixel,
        2,  // number of axes
        (int32_t)deltaY,
        (int32_t)deltaX
    );
    
    // Post the event
    CGEventPost(kCGHIDEventTap, scrollEvent);
    CFRelease(scrollEvent);
    
    // Log scroll event
    [[TPLogger sharedLogger] logScrollEvent:deltaX deltaY:deltaY];
    
    if ([TPConfig sharedConfig].debugMode) {
        DebugLog(@"Posted scroll event - deltaX: %.2f, deltaY: %.2f", deltaX, deltaY);
    }
}

@end
