#import "TPHIDDeviceManager.h"
#import "TPLogger.h"
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

// Forward declarations for callbacks
static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);
static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);
static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value);

@interface TPHIDDeviceManager () {
    IOHIDManagerRef _hidManager;
    NSMutableArray *_devices;
    NSMutableArray *_matchingCriteria;
    BOOL _isRunning;
    BOOL _isInitialized;
    BOOL _waitingForPermissions;
    NSLock *_deviceLock;
    NSLock *_delegateLock;
    dispatch_queue_t _deviceQueue;
}
@end

@implementation TPHIDDeviceManager

@synthesize devices = _devices;
@synthesize isRunning = _isRunning;

- (instancetype)init {
    if (self = [super init]) {
        _devices = [[NSMutableArray alloc] init];
        _matchingCriteria = [[NSMutableArray alloc] init];
        _isRunning = NO;
        _isInitialized = NO;
        _waitingForPermissions = NO;
        _hidManager = NULL;
        _deviceLock = [[NSLock alloc] init];
        _delegateLock = [[NSLock alloc] init];
        _deviceQueue = dispatch_queue_create("com.tpmiddle.devicemanager", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_deviceQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    }
    return self;
}

- (void)dealloc {
    [self stop];
    _deviceLock = nil;
    _delegateLock = nil;
    _deviceQueue = NULL;
}

- (void)showPermissionAlert:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Permissions Required";
        alert.informativeText = message;
        [alert addButtonWithTitle:@"Open System Settings"];
        [alert addButtonWithTitle:@"Try Again"];
        [alert addButtonWithTitle:@"Quit"];
        
        self->_waitingForPermissions = YES;
        NSModalResponse response = [alert runModal];
        self->_waitingForPermissions = NO;
        
        if (response == NSAlertFirstButtonReturn) {
            // Open System Settings
            if ([message containsString:@"Accessibility"]) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
            } else {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"]];
            }
            
            // Wait a moment and try again
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self start];
            });
        } else if (response == NSAlertSecondButtonReturn) {
            // Try again immediately
            [self start];
        } else {
            // Quit was selected
            [[NSApplication sharedApplication] terminate:nil];
        }
    });
}

- (NSError *)checkPermissions {
    // Check accessibility permissions
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Accessibility permissions not granted. Please grant permission in System Settings > Privacy & Security > Accessibility"}];
    }
    
    // Check input monitoring permissions by attempting to create and open a test manager
    IOHIDManagerRef testManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!testManager) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create test HID manager"}];
    }
    
    IOReturn result = IOHIDManagerOpen(testManager, kIOHIDOptionsTypeNone);
    CFRelease(testManager);
    
    if (result == kIOReturnNotPermitted) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Input monitoring permissions not granted. Please grant permission in System Settings > Privacy & Security > Input Monitoring"}];
    }
    
    return nil;
}

- (BOOL)setupHIDManager {
    if (_hidManager) {
        return YES;
    }
    
    // Check permissions before creating HID manager
    NSError *permissionError = [self checkPermissions];
    if (permissionError) {
        if (!_waitingForPermissions) {
            [self showPermissionAlert:permissionError.localizedDescription];
        }
        [self notifyDelegateOfError:permissionError];
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Permission error: %@", permissionError.localizedDescription]];
        return NO;
    }
    
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!_hidManager) {
        NSLog(@"Failed to create HID Manager");
        return NO;
    }
    NSLog(@"HID Manager created successfully");
    
    // First open the HID manager
    IOReturn openResult = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    if (openResult != kIOReturnSuccess) {
        NSLog(@"Failed to open HID Manager with result: %d", openResult);
        CFRelease(_hidManager);
        _hidManager = NULL;
        return NO;
    }
    
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(_hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    // Apply any existing matching criteria
    if (_matchingCriteria.count > 0) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
    
    // Then schedule with run loop
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    NSLog(@"HID Manager scheduled with run loop");
    
    _isInitialized = YES;
    _isRunning = YES;
    return YES;
}

- (NSError *)validateConfiguration {
    if (_matchingCriteria.count == 0) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorInvalidConfiguration
                             userInfo:@{NSLocalizedDescriptionKey: @"No device matching criteria configured"}];
    }
    
    return nil;
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    NSDictionary *criteria = @{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    };
    
    [_matchingCriteria addObject:criteria];
    
    // If HID manager is already set up, update its matching criteria
    if (_hidManager) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
    
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Added device matching criteria - Usage Page: %d Usage: %d", usagePage, usage]];
}

- (void)addVendorMatching:(uint32_t)vendorID {
    NSDictionary *criteria = @{
        @(kIOHIDVendorIDKey): @(vendorID)
    };
    
    [_matchingCriteria addObject:criteria];
    
    // If HID manager is already set up, update its matching criteria
    if (_hidManager) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
    
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Added vendor matching criteria - Vendor ID: %d", vendorID]];
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    // Validate configuration first
    NSError *configError = [self validateConfiguration];
    if (configError) {
        [self notifyDelegateOfError:configError];
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Configuration error: %@", configError.localizedDescription]];
        return NO;
    }
    
    // Set up HID manager if not already done
    if (!_isInitialized && ![self setupHIDManager]) {
        return NO;
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
    
    [_deviceLock lock];
    [_devices removeAllObjects];
    [_deviceLock unlock];
    
    _isRunning = NO;
    _isInitialized = NO;
    [[TPLogger sharedLogger] logMessage:@"HID Manager stopped"];
}

- (NSString *)deviceStatus {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"=== HID Manager Device Status ===\n"];
    [status appendFormat:@"Running: %@\n", _isRunning ? @"Yes" : @"No"];
    
    [_deviceLock lock];
    [status appendFormat:@"Connected Devices: %lu\n", (unsigned long)_devices.count];
    
    for (id device in _devices) {
        IOHIDDeviceRef deviceRef = (__bridge IOHIDDeviceRef)device;
        NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDProductKey));
        NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDVendorIDKey));
        NSNumber *productID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(deviceRef, CFSTR(kIOHIDProductIDKey));
        [status appendFormat:@"- Device: %@\n  Vendor ID: 0x%04X\n  Product ID: 0x%04X\n",
         product, vendorID.unsignedIntValue, productID.unsignedIntValue];
    }
    [_deviceLock unlock];
    
    [status appendString:@"===========================\n"];
    return status;
}

- (NSString *)currentConfiguration {
    NSMutableString *config = [NSMutableString string];
    [config appendString:@"=== HID Manager Configuration ===\n"];
    
    [config appendFormat:@"Number of Matching Criteria: %lu\n", (unsigned long)_matchingCriteria.count];
    
    for (NSDictionary *criteria in _matchingCriteria) {
        [config appendString:@"Matching Criteria:\n"];
        for (NSString *key in criteria) {
            [config appendFormat:@"  %@: %@\n", key, criteria[key]];
        }
    }
    
    [config appendString:@"==============================\n"];
    return config;
}

#pragma mark - Private Methods

- (void)notifyDelegateOfError:(NSError *)error {
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = self.delegate;
    [_delegateLock unlock];
    
    if (!delegate) return;
    
    if ([delegate respondsToSelector:@selector(didEncounterError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didEncounterError:error];
        });
    }
}

#pragma mark - Device Management

- (void)deviceAdded:(IOHIDDeviceRef)device {
    if (!device) return;
    
    dispatch_async(_deviceQueue, ^{
        @try {
            [self->_deviceLock lock];
            if (![self->_devices containsObject:(__bridge id)device]) {
                // Retain the device
                CFRetain(device);
                [self->_devices addObject:(__bridge id)device];
                
                NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
                NSNumber *vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
                NSNumber *productID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
                
                NSLog(@"Device added - Product: %@, Vendor ID: %@, Product ID: %@", product, vendorID, productID);
                
                [self->_deviceLock unlock];
                
                [self->_delegateLock lock];
                id<TPHIDManagerDelegate> delegate = self.delegate;
                [self->_delegateLock unlock];
                
                if ([delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [delegate didDetectDeviceAttached:product];
                    });
                }
            } else {
                [self->_deviceLock unlock];
            }
        } @catch (NSException *exception) {
            [self->_deviceLock unlock];
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in deviceAdded: %@", exception]];
        }
    });
}

- (void)deviceRemoved:(IOHIDDeviceRef)device {
    if (!device) return;
    
    dispatch_async(_deviceQueue, ^{
        @try {
            [self->_deviceLock lock];
            if ([self->_devices containsObject:(__bridge id)device]) {
                NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
                [self->_devices removeObject:(__bridge id)device];
                
                // Release the device
                CFRelease(device);
                
                NSLog(@"Device removed - Product: %@", product);
                
                [self->_deviceLock unlock];
                
                [self->_delegateLock lock];
                id<TPHIDManagerDelegate> delegate = self.delegate;
                [self->_delegateLock unlock];
                
                if ([delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [delegate didDetectDeviceDetached:product];
                    });
                }
            } else {
                [self->_deviceLock unlock];
            }
        } @catch (NSException *exception) {
            [self->_deviceLock unlock];
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in deviceRemoved: %@", exception]];
        }
    });
}

#pragma mark - Callbacks

static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device matching callback failed with result: %d", result);
        return;
    }
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        [manager deviceAdded:device];
    }
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device removal callback failed with result: %d", result);
        return;
    }
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        [manager deviceRemoved:device];
    }
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess || !context || !value) {
        NSLog(@"Input value callback failed with result: %d", result);
        return;
    }
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        
        [manager->_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = manager.delegate;
        [manager->_delegateLock unlock];
        
        if ([delegate respondsToSelector:@selector(didReceiveHIDValue:)]) {
            // Create a strong reference to the value
            CFRetain(value);
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    [delegate didReceiveHIDValue:(__bridge id)value];
                } @finally {
                    CFRelease(value);
                }
            });
        }
    }
}

@end
