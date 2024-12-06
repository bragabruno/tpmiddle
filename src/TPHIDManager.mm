#include "TPHIDManager.h"
#include "TPLogger.h"
#include <CoreGraphics/CoreGraphics.h>

@implementation TPHIDManager

+ (instancetype)sharedManager {
    static TPHIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPHIDManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _devices = [[NSMutableArray alloc] init];
        _isScrollMode = NO;
        _pendingDeltaX = 0;
        _pendingDeltaY = 0;
        _lastMovementTime = [NSDate date];
        _savedCursorPosition = CGPointZero;
        _eventQueue = dispatch_queue_create("com.tpmiddle.eventQueue", DISPATCH_QUEUE_SERIAL);
        [self setupHIDManager];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_eventQueue) {
        _eventQueue = NULL;
    }
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    // Check accessibility permissions
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @NO};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        NSLog(@"Accessibility permissions not granted");
        return NO;
    }
    
    // Check input monitoring permissions
    if (!CGPreflightScreenCaptureAccess()) {
        NSLog(@"Input monitoring permissions not granted");
        return NO;
    }
    
    if (!_hidManager) {
        NSLog(@"HID Manager not initialized");
        return NO;
    }
    
    IOReturn result = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
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
    
    if (_hidManager) {
        IOHIDManagerUnscheduleFromRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDManagerClose(_hidManager, kIOHIDOptionsTypeNone);
        CFRelease(_hidManager);
        _hidManager = NULL;
    }
    
    _isRunning = NO;
    NSLog(@"HID Manager stopped");
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    if (!_hidManager) return;
    
    NSMutableArray *criteria = [NSMutableArray array];
    
    // Get existing devices if any
    CFSetRef existingDevices = IOHIDManagerCopyDevices(_hidManager);
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
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteria);
    NSLog(@"Added device matching criteria - Usage Page: %d, Usage: %d", usagePage, usage);
}

- (void)addVendorMatching:(uint32_t)vendorID {
    if (!_hidManager) return;
    
    NSMutableArray *criteria = [NSMutableArray array];
    
    // Get existing devices if any
    CFSetRef existingDevices = IOHIDManagerCopyDevices(_hidManager);
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
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteria);
    NSLog(@"Added vendor matching criteria - Vendor ID: %d", vendorID);
}

- (NSArray *)getCurrentMatchingCriteria {
    if (!_hidManager) return nil;
    
    NSMutableArray *criteria = [NSMutableArray array];
    CFSetRef devicesSet = IOHIDManagerCopyDevices(_hidManager);
    
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

static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device matching callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceAdded:device];
    });
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device removal callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceRemoved:device];
    });
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess || !context || !value) {
        NSLog(@"Input value callback failed with result: %d", result);
        return;
    }
    
    TPHIDManager *manager = (__bridge TPHIDManager *)context;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Input received on main thread - Usage Page: %d, Usage: %d", usagePage, usage);
        [manager handleInput:value];
    });
}

- (void)setupHIDManager {
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!_hidManager) {
        NSLog(@"Failed to create HID Manager");
        return;
    }
    NSLog(@"HID Manager created successfully");
    
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(_hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    NSLog(@"HID Manager scheduled with run loop");
}

- (void)deviceAdded:(IOHIDDeviceRef)device {
    if (!device) return;
    
    @synchronized(_devices) {
        if (![_devices containsObject:(__bridge id)device]) {
            [_devices addObject:(__bridge id)device];
            
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
}

- (void)deviceRemoved:(IOHIDDeviceRef)device {
    if (!device) return;
    
    @synchronized(_devices) {
        if ([_devices containsObject:(__bridge id)device]) {
            NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
            [_devices removeObject:(__bridge id)device];
            
            NSLog(@"Device removed - Product: %@", product);
            [[TPLogger sharedLogger] logDeviceEvent:product attached:NO];
            
            if ([self.delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
                [self.delegate didDetectDeviceDetached:product];
            }
        }
    }
}

- (void)handleInput:(IOHIDValueRef)value {
    if (!_isRunning || !value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
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
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
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
                        dispatch_sync(_eventQueue, ^{
                            CGEventRef event = CGEventCreate(NULL);
                            if (event) {
                                _savedCursorPosition = CGEventGetLocation(event);
                                CFRelease(event);
                            }
                        });
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
    if (!value) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) return;
    
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
                dispatch_sync(_eventQueue, ^{
                    CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved,
                                                                 _savedCursorPosition,
                                                                 kCGMouseButtonLeft);
                    if (moveEvent) {
                        CGEventPost(kCGHIDEventTap, moveEvent);
                        CFRelease(moveEvent);
                    }
                });
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
    if (!value) return;
    
    CFIndex scrollDelta = IOHIDValueGetIntegerValue(value);
    [self handleScrollInput:scrollDelta withHorizontal:0];
}

- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta {
    dispatch_sync(_eventQueue, ^{
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
    });
}

@end
