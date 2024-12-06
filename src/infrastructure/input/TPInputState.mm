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
        _savedCursorPosition = CGEventGetLocation(event);
        CFRelease(event);
    }
    
    [self resetPendingMovements];
}

@end
