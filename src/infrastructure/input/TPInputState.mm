#import "TPInputState.h"

// Button state bit masks
static const uint8_t kLeftButtonBit = 1 << 0;
static const uint8_t kRightButtonBit = 1 << 1;
static const uint8_t kMiddleButtonBit = 1 << 2;

@implementation TPInputState

+ (instancetype)sharedState {
    static TPInputState *sharedState = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedState = [[TPInputState alloc] init];
    });
    return sharedState;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _leftButtonDown = NO;
        _rightButtonDown = NO;
        _middleButtonDown = NO;
        _isScrollMode = NO;
        _middleButtonPressTime = nil;
        _savedCursorPosition = CGPointZero;
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
    }
    return self;
}

- (void)resetPendingMovements {
    _pendingDeltaX = 0;
    _pendingDeltaY = 0;
    _lastMovementTime = [NSDate date];
}

- (uint8_t)currentButtonState {
    return (_leftButtonDown ? kLeftButtonBit : 0) |
           (_rightButtonDown ? kRightButtonBit : 0) |
           (_middleButtonDown ? kMiddleButtonBit : 0);
}

- (void)toggleScrollMode {
    _isScrollMode = !_isScrollMode;
    
    if (_isScrollMode) {
        // Save current cursor position when entering scroll mode
        CGEventRef event = CGEventCreate(NULL);
        if (event) {
            _savedCursorPosition = CGEventGetLocation(event);
            CFRelease(event);
            
            // Create a mouse moved event to ensure the cursor stays put
            CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, 
                                                         kCGEventMouseMoved,
                                                         _savedCursorPosition,
                                                         kCGMouseButtonLeft);
            if (moveEvent) {
                // Set flags to prevent cursor movement
                CGEventSetFlags(moveEvent, kCGEventFlagMaskNonCoalesced);
                CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaX, 0);
                CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaY, 0);
                
                // Post the event
                CGEventPost(kCGHIDEventTap, moveEvent);
                CFRelease(moveEvent);
            }
        }
    }
    
    [self resetPendingMovements];
}

- (void)enforceSavedCursorPosition {
    if (_isScrollMode && !CGPointEqualToPoint(_savedCursorPosition, CGPointZero)) {
        // Create a mouse moved event
        CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, 
                                                     kCGEventMouseMoved,
                                                     _savedCursorPosition,
                                                     kCGMouseButtonLeft);
        if (moveEvent) {
            // Set flags to prevent cursor movement
            CGEventSetFlags(moveEvent, kCGEventFlagMaskNonCoalesced);
            CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaX, 0);
            CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaY, 0);
            
            // Post the event with high priority
            CGEventPost(kCGHIDEventTap, moveEvent);
            
            // Release the event
            CFRelease(moveEvent);
            
            // Double-check current position and correct if needed
            CGEventRef currentEvent = CGEventCreate(NULL);
            if (currentEvent) {
                CGPoint currentPos = CGEventGetLocation(currentEvent);
                CFRelease(currentEvent);
                
                if (!CGPointEqualToPoint(currentPos, _savedCursorPosition)) {
                    // If position changed, force it back immediately
                    CGEventRef forceEvent = CGEventCreateMouseEvent(NULL, 
                                                                  kCGEventMouseMoved,
                                                                  _savedCursorPosition,
                                                                  kCGMouseButtonLeft);
                    if (forceEvent) {
                        CGEventSetFlags(forceEvent, kCGEventFlagMaskNonCoalesced);
                        CGEventSetIntegerValueField(forceEvent, kCGMouseEventDeltaX, 0);
                        CGEventSetIntegerValueField(forceEvent, kCGMouseEventDeltaY, 0);
                        CGEventPost(kCGHIDEventTap, forceEvent);
                        CFRelease(forceEvent);
                    }
                }
            }
        }
    }
}

@end
