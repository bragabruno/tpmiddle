#include "TPHIDManager.h"
#include "TPLogger.h"
#include <CoreGraphics/CoreGraphics.h>

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
    CGPoint _savedCursorPosition;  // Store cursor position for scroll mode
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
        NSLog(@"Device matching callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceAdded:device];
    });
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess) {
        NSLog(@"Device removal callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceRemoved:device];
    });
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess) {
        NSLog(@"Input value callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Input received on main thread - Usage Page: %d, Usage: %d", usagePage, usage);
        [manager handleInput:value];
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        devices = [[NSMutableArray alloc] init];
        _isScrollMode = NO;
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
        _savedCursorPosition = CGPointZero;
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
    
    if (_isRunning) {
        NSLog(@"HID Manager started successfully");
    } else {
        NSLog(@"Failed to start HID Manager with result: %d", result);
    }
    
    return _isRunning;
}

- (void)stop {
    if (!_isRunning) return;
    
    IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
    _isRunning = NO;
    NSLog(@"HID Manager stopped");
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    NSMutableArray *criteria = [NSMutableArray array];
    
    // Get existing devices if any
    CFSetRef existingDevices = IOHIDManagerCopyDevices(hidManager);
    if (existingDevices) {
        NSArray *existingCriteria = [self getCurrentMatchingCriteria];
        if (existingCriteria) {
            [criteria addObjectsFromArray:existingCriteria];
        }
        CFRelease(existingDevices);
    }
    
    // Add new criteria
    [criteria addObject:@{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    }];
    
    // Set all criteria
    IOHIDManagerSetDeviceMatchingMultiple(hidManager, (__bridge CFArrayRef)criteria);
    NSLog(@"Added device matching criteria - Usage Page: %d, Usage: %d", usagePage, usage);
}

- (void)addVendorMatching:(uint32_t)vendorID {
    NSMutableArray *criteria = [NSMutableArray array];
    
    // Get existing devices if any
    CFSetRef existingDevices = IOHIDManagerCopyDevices(hidManager);
    if (existingDevices) {
        NSArray *existingCriteria = [self getCurrentMatchingCriteria];
        if (existingCriteria) {
            [criteria addObjectsFromArray:existingCriteria];
        }
        CFRelease(existingDevices);
    }
    
    // Add new criteria
    [criteria addObject:@{
        @(kIOHIDVendorIDKey): @(vendorID)
    }];
    
    // Set all criteria
    IOHIDManagerSetDeviceMatchingMultiple(hidManager, (__bridge CFArrayRef)criteria);
    NSLog(@"Added vendor matching criteria - Vendor ID: %d", vendorID);
}

- (NSArray *)getCurrentMatchingCriteria {
    NSMutableArray *criteria = [NSMutableArray array];
    CFSetRef devicesSet = IOHIDManagerCopyDevices(hidManager);
    
    if (devicesSet) {
        NSSet *deviceSet = (__bridge_transfer NSSet *)devicesSet;
        for (id device in deviceSet) {
            IOHIDDeviceRef deviceRef = (__bridge IOHIDDeviceRef)device;
            
            NSNumber *usagePage = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDPrimaryUsagePageKey));
            NSNumber *usage = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDPrimaryUsageKey));
            NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDVendorIDKey));
            
            if (usagePage && usage) {
                [criteria addObject:@{
                    @(kIOHIDDeviceUsagePageKey): usagePage,
                    @(kIOHIDDeviceUsageKey): usage
                }];
            } else if (vendorID) {
                [criteria addObject:@{
                    @(kIOHIDVendorIDKey): vendorID
                }];
            }
        }
    }
    
    return criteria;
}

- (void)setupHIDManager {
    hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!hidManager) {
        NSLog(@"Failed to create HID Manager");
        return;
    }
    NSLog(@"HID Manager created successfully");
    
    IOHIDManagerRegisterDeviceMatchingCallback(hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    NSLog(@"HID Manager scheduled with run loop");
}

- (void)deviceAdded:(IOHIDDeviceRef)device {
    if (![devices containsObject:(__bridge id)device]) {
        [devices addObject:(__bridge id)device];
        
        NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        NSNumber *productID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        
        NSLog(@"Device added - Product: %@, Vendor ID: %@, Product ID: %@", product, vendorID, productID);
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
        NSLog(@"Device removed - Product: %@", product);
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
    
    NSLog(@"Processing input on main thread - Usage Page: %d, Usage: %d", usagePage, usage);
    
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
    
    NSLog(@"Button input - Usage: %d, State: %ld", usage, (long)buttonState);
    
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
                _middleButtonDown = YES;
            } else if (!buttonState && _middleButtonDown) {
                // Middle button just released
                NSTimeInterval pressDuration = [[NSDate date] timeIntervalSinceDate:_middleButtonPressTime];
                if (pressDuration < 0.3) { // Reduced from 0.5 to 0.3 for better responsiveness
                    _isScrollMode = !_isScrollMode;
                    
                    if (_isScrollMode) {
                        // Save current cursor position when entering scroll mode
                        CGEventRef event = CGEventCreate(NULL);
                        _savedCursorPosition = CGEventGetLocation(event);
                        CFRelease(event);
                    }
                    
                    NSLog(@"Scroll mode %@", _isScrollMode ? @"enabled" : @"disabled");
                    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Scroll mode %@", 
                        _isScrollMode ? @"enabled" : @"disabled"]];
                    
                    // Reset pending movements when toggling scroll mode
                    _pendingDeltaX = 0;
                    _pendingDeltaY = 0;
                }
                _middleButtonDown = NO;
            }
            _middleButtonDown = buttonState;
            break;
        default:
            break;
    }
    
    [[TPLogger sharedLogger] logButtonEvent:_leftButtonDown right:_rightButtonDown middle:_middleButtonDown];
    
    if ([self.delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        NSLog(@"Forwarding button press to delegate - left: %d, right: %d, middle: %d",
              _leftButtonDown, _rightButtonDown, _middleButtonDown);
        [self.delegate didReceiveButtonPress:_leftButtonDown right:_rightButtonDown middle:_middleButtonDown];
    } else {
        NSLog(@"No delegate to receive button press");
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
                NSLog(@"Scroll movement - X: %d, Y: %d", _pendingDeltaX, _pendingDeltaY);
                [self handleScrollInput:_pendingDeltaY withHorizontal:_pendingDeltaX];
                
                // Keep cursor at saved position during scroll mode
                CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,
                                                             _savedCursorPosition,
                                                             kCGMouseButtonLeft);
                CGEventPost(kCGHIDEventTap, moveEvent);
                CFRelease(moveEvent);
            }
        } else {
            // Normal pointer movement
            if (_pendingDeltaX != 0 || _pendingDeltaY != 0) {
                NSLog(@"Pointer movement - X: %d, Y: %d, Buttons: %02X", _pendingDeltaX, _pendingDeltaY, buttons);
                [[TPLogger sharedLogger] logTrackpointMovement:_pendingDeltaX deltaY:_pendingDeltaY buttons:buttons];
                
                if ([self.delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
                    NSLog(@"Forwarding movement to delegate - X: %d, Y: %d, Buttons: %02X",
                          _pendingDeltaX, _pendingDeltaY, buttons);
                    [self.delegate didReceiveMovement:_pendingDeltaX deltaY:_pendingDeltaY withButtonState:buttons];
                } else {
                    NSLog(@"No delegate to receive movement");
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
