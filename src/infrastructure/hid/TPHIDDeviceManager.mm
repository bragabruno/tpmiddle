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
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)showPermissionAlert:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Permissions Required";
        alert.informativeText = message;
        [alert addButtonWithTitle:@"Open System Settings"];
        [alert addButtonWithTitle:@"Try Again"];
        [alert addButtonWithTitle:@"Quit"];
        
        _waitingForPermissions = YES;
        NSModalResponse response = [alert runModal];
        _waitingForPermissions = NO;
        
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
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:permissionError];
        }
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
        if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
            [self.delegate didEncounterError:configError];
        }
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
    
    _isRunning = NO;
    _isInitialized = NO;
    [[TPLogger sharedLogger] logMessage:@"HID Manager stopped"];
}

- (NSString *)deviceStatus {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"=== HID Manager Device Status ===\n"];
    [status appendFormat:@"Running: %@\n", _isRunning ? @"Yes" : @"No"];
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
            
            if ([self.delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
                [self.delegate didDetectDeviceDetached:product];
            }
        }
    }
}

#pragma mark - Callbacks

static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device matching callback failed with result: %d", result);
        return;
    }
    
    TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceAdded:device];
    });
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) {
        NSLog(@"Device removal callback failed with result: %d", result);
        return;
    }
    
    TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager deviceRemoved:device];
    });
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess || !context || !value) {
        NSLog(@"Input value callback failed with result: %d", result);
        return;
    }
    
    TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
    if ([manager.delegate respondsToSelector:@selector(didReceiveHIDValue:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [manager.delegate performSelector:@selector(didReceiveHIDValue:) withObject:(__bridge id)value];
        });
    }
}

@end
