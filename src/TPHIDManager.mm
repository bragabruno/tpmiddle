#include "TPHIDManager.h"
#include "TPLogger.h"
#include <CoreGraphics/CoreGraphics.h>
#include <IOKit/hid/IOHIDKeys.h>

// Define the error domain
NSString *const TPHIDManagerErrorDomain = @"com.tpmiddle.HIDManager";

// Forward declarations for callbacks
static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);
static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);
static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value);

@interface TPHIDManager () {
    IOHIDManagerRef _hidManager;
    NSMutableArray *_devices;
    BOOL _leftButtonDown;
    BOOL _rightButtonDown;
    BOOL _middleButtonDown;
    BOOL _isRunning;
    BOOL _isScrollMode;
    NSDate *_middleButtonPressTime;
    int _pendingDeltaX;
    int _pendingDeltaY;
    NSDate *_lastMovementTime;
    CGPoint _savedCursorPosition;
    dispatch_queue_t _eventQueue;
}

- (void)setupHIDManager;
- (void)handleInput:(IOHIDValueRef)value;
- (void)handleButtonInput:(IOHIDValueRef)value;
- (void)handleMovementInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta;

@end

@implementation TPHIDManager

@synthesize devices = _devices;

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

- (NSError *)checkPermissions {
    // Check accessibility permissions
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Accessibility permissions not granted"}];
    }
    
    // Check input monitoring permissions
    if (!CGRequestScreenCaptureAccess()) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Input monitoring permissions not granted"}];
    }
    
    return nil;
}

- (NSError *)validateConfiguration {
    if (!_hidManager) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorInvalidConfiguration
                             userInfo:@{NSLocalizedDescriptionKey: @"HID Manager not properly configured"}];
    }
    
    // Check if any device matching criteria have been added
    CFSetRef deviceSet = IOHIDManagerCopyDevices(_hidManager);
    NSUInteger deviceCount = 0;
    if (deviceSet) {
        deviceCount = CFSetGetCount(deviceSet);
        CFRelease(deviceSet);
    }
    
    if (deviceCount == 0) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorInvalidConfiguration
                             userInfo:@{NSLocalizedDescriptionKey: @"No device matching criteria configured"}];
    }
    
    return nil;
}

- (NSString *)deviceStatus {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"=== HID Manager Device Status ===\n"];
    [status appendFormat:@"Running: %@\n", _isRunning ? @"Yes" : @"No"];
    [status appendFormat:@"Scroll Mode: %@\n", _isScrollMode ? @"Enabled" : @"Disabled"];
    [status appendFormat:@"Connected Devices: %lu\n", (unsigned long)_devices.count];
    
    @synchronized(_devices) {
        for (id device in _devices) {
            IOHIDDeviceRef deviceRef = (__bridge IOHIDDeviceRef)device;
            NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDProductKey));
            NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDVendorIDKey));
            NSNumber *productID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDProductIDKey));
            [status appendFormat:@"- Device: %@\n  Vendor ID: 0x%04X\n  Product ID: 0x%04X\n",
             product, vendorID.unsignedIntValue, productID.unsignedIntValue];
        }
    }
    
    [status appendString:@"===========================\n"];
    return status;
}

- (NSString *)currentConfiguration {
    NSMutableString *config = [NSMutableString string];
    [config appendString:@"=== HID Manager Configuration ===\n"];
    
    CFSetRef deviceSet = IOHIDManagerCopyDevices(_hidManager);
    if (deviceSet) {
        NSSet *devices = (__bridge_transfer NSSet *)deviceSet;
        [config appendFormat:@"Connected Devices: %lu\n", (unsigned long)devices.count];
        
        for (id device in devices) {
            IOHIDDeviceRef deviceRef = (__bridge IOHIDDeviceRef)device;
            NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDProductKey));
            NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDVendorIDKey));
            [config appendFormat:@"Device: %@, Vendor ID: 0x%04X\n", product, vendorID.unsignedIntValue];
        }
    }
    
    [config appendString:@"==============================\n"];
    return config;
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    // Check permissions first
    NSError *permissionError = [self checkPermissions];
    if (permissionError) {
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:permissionError];
        }
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Permission error: %@", permissionError.localizedDescription]];
        return NO;
    }
    
    // Validate configuration
    NSError *configError = [self validateConfiguration];
    if (configError) {
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:configError];
        }
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Configuration error: %@", configError.localizedDescription]];
        return NO;
    }
    
    if (!_hidManager) {
        NSError *error = [NSError errorWithDomain:TPHIDManagerErrorDomain
                                           code:TPHIDManagerErrorInitializationFailed
                                       userInfo:@{NSLocalizedDescriptionKey: @"HID Manager not initialized"}];
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:error];
        }
        [[TPLogger sharedLogger] logMessage:@"HID Manager not initialized"];
        return NO;
    }
    
    IOReturn result = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    _isRunning = (result == kIOReturnSuccess);
    
    if (_isRunning) {
        [[TPLogger sharedLogger] logMessage:@"HID Manager started successfully"];
        [[TPLogger sharedLogger] logMessage:[self deviceStatus]];
    } else {
        NSError *error = [NSError errorWithDomain:TPHIDManagerErrorDomain
                                           code:TPHIDManagerErrorDeviceAccessFailed
                                       userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to start HID Manager with result: %d", result]}];
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:error];
        }
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Failed to start HID Manager with result: %d", result]];
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
    [[TPLogger sharedLogger] logMessage:@"HID Manager stopped"];
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    if (!_hidManager) return;
    
    NSDictionary *criteria = @{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    };
    
    IOHIDManagerSetDeviceMatching(_hidManager, (__bridge CFDictionaryRef)criteria);
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Added device matching criteria - Usage Page: %d, Usage: %d", usagePage, usage]];
}

- (void)addVendorMatching:(uint32_t)vendorID {
    if (!_hidManager) return;
    
    NSDictionary *criteria = @{
        @(kIOHIDVendorIDKey): @(vendorID)
    };
    
    IOHIDManagerSetDeviceMatching(_hidManager, (__bridge CFDictionaryRef)criteria);
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Added vendor matching criteria - Vendor ID: %d", vendorID]];
}

#pragma mark - Private Methods

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

#pragma mark - Device Management

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

#pragma mark - Input Handling

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
