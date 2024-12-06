#import "TPHIDManager.h"
#import "TPLogger.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation TPHIDManager {
    IOHIDManagerRef hidManager;
    NSMutableArray *devices;
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    BOOL _isRunning;
    BOOL _isScrollMode;
    NSDate *_middleButtonPressTime;
    int _pendingDeltaX;
    int _pendingDeltaY;
    NSDate *_lastMovementTime;
}

@synthesize isRunning = _isRunning;
@synthesize isScrollMode = _isScrollMode;

+ (instancetype)sharedManager {
    static TPHIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPHIDManager alloc] init];
    });
    return sharedManager;
}

static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess) {
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    [manager deviceAdded:device];
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess) {
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    [manager deviceRemoved:device];
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess) {
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    [manager handleInput:value];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        devices = [[NSMutableArray alloc] init];
        _isScrollMode = NO;
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
        [self setupHIDManager];
    }
    return self;
}

- (void)dealloc {
    if (hidManager) {
        IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
        CFRelease(hidManager);
    }
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    IOReturn result = IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
    _isRunning = (result == kIOReturnSuccess);
    return _isRunning;
}

- (void)stop {
    if (!_isRunning) return;
    
    IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
    _isRunning = NO;
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    NSDictionary *criteria = @{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    };
    IOHIDManagerSetDeviceMatching(hidManager, (__bridge CFDictionaryRef)criteria);
}

- (void)addVendorMatching:(uint32_t)vendorID {
    NSDictionary *criteria = @{
        @(kIOHIDVendorIDKey): @(vendorID)
    };
    IOHIDManagerSetDeviceMatching(hidManager, (__bridge CFDictionaryRef)criteria);
}

- (void)setupHIDManager {
    hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    
    IOHIDManagerRegisterDeviceMatchingCallback(hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
}

- (void)deviceAdded:(IOHIDDeviceRef)device {
    if (![devices containsObject:(__bridge id)device]) {
        [devices addObject:(__bridge id)device];
        
        NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        [[TPLogger sharedLogger] logDeviceEvent:product attached:YES];
        
        if ([self.delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
            [self.delegate didDetectDeviceAttached:product];
        }
    }
}

- (void)deviceRemoved:(IOHIDDeviceRef)device {
    if ([devices containsObject:(__bridge id)device]) {
        [devices removeObject:(__bridge id)device];
        
        NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        [[TPLogger sharedLogger] logDeviceEvent:product attached:NO];
        
        if ([self.delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
            [self.delegate didDetectDeviceDetached:product];
        }
    }
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
                [self handleScrollInput:value];
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
            _leftButtonDown = buttonState;
            break;
        case 2: // Right button
            _rightButtonDown = buttonState;
            break;
        case 3: // Middle button
            if (buttonState && !_middleButtonDown) {
                // Middle button just pressed
                _middleButtonPressTime = [NSDate date];
            } else if (!buttonState && _middleButtonDown) {
                // Middle button just released
                NSTimeInterval pressDuration = [[NSDate date] timeIntervalSinceDate:_middleButtonPressTime];
                if (pressDuration < 0.5) { // Toggle only on quick press
                    _isScrollMode = !_isScrollMode;
                    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Scroll mode %@", 
                        _isScrollMode ? @"enabled" : @"disabled"]];
                }
            }
            _middleButtonDown = buttonState;
            break;
        default:
            break;
    }
    
    [[TPLogger sharedLogger] logButtonEvent:_leftButtonDown right:_rightButtonDown middle:_middleButtonDown];
    
    if ([self.delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        [self.delegate didReceiveButtonPress:_leftButtonDown right:_rightButtonDown middle:_middleButtonDown];
    }
}

- (void)handleMovementInput:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex movement = IOHIDValueGetIntegerValue(value);
    
    // Store the movement in the appropriate pending delta
    if (usage == kHIDUsage_GD_X) {
        _pendingDeltaX = -(int)movement;  // Invert X for natural movement
    }
    else if (usage == kHIDUsage_GD_Y) {
        _pendingDeltaY = -(int)movement;  // Invert Y for natural movement
    }
    
    // Check if we should process the movement
    NSTimeInterval timeSinceLastMovement = [[NSDate date] timeIntervalSinceDate:_lastMovementTime];
    if (timeSinceLastMovement >= 0.001) { // Process movements every millisecond
        uint8_t buttons = (_leftButtonDown ? kLeftButtonBit : 0) | 
                         (_rightButtonDown ? kRightButtonBit : 0) | 
                         (_middleButtonDown ? kMiddleButtonBit : 0);
        
        if (_isScrollMode && !_middleButtonDown) {
            // In scroll mode, convert movement to scroll events
            if (_pendingDeltaX != 0 || _pendingDeltaY != 0) {
                [self handleScrollInput:_pendingDeltaY withHorizontal:_pendingDeltaX];
            }
        } else {
            // Normal pointer movement
            if (_pendingDeltaX != 0 || _pendingDeltaY != 0) {
                [[TPLogger sharedLogger] logTrackpointMovement:_pendingDeltaX deltaY:_pendingDeltaY buttons:buttons];
                
                if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                    [self.delegate didReceiveMovement:_pendingDeltaX deltaY:_pendingDeltaY withButtonState:buttons];
                }
            }
        }
        
        // Reset pending movements and update timestamp
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
    }
}

- (void)handleScrollInput:(IOHIDValueRef)value {
    CFIndex scrollDelta = IOHIDValueGetIntegerValue(value);
    [self handleScrollInput:scrollDelta withHorizontal:0];
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
