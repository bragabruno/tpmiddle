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
        dispatch_set_target_queue(_deviceQueue, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
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
            if ([message containsString:@"Accessibility"]) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
            } else {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"]];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self start];
            });
        } else if (response == NSAlertSecondButtonReturn) {
            [self start];
        } else {
            [[NSApplication sharedApplication] terminate:nil];
        }
    });
}

- (NSError *)checkPermissions {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Accessibility permissions not granted"}];
    }
    
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
                             userInfo:@{NSLocalizedDescriptionKey: @"Input monitoring permissions not granted"}];
    }
    
    return nil;
}

- (BOOL)setupHIDManager {
    if (_hidManager) {
        return YES;
    }
    
    NSError *permissionError = [self checkPermissions];
    if (permissionError) {
        if (!_waitingForPermissions) {
            [self showPermissionAlert:permissionError.localizedDescription];
        }
        [self notifyDelegateOfError:permissionError];
        return NO;
    }
    
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!_hidManager) {
        return NO;
    }
    
    IOReturn openResult = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    if (openResult != kIOReturnSuccess) {
        CFRelease(_hidManager);
        _hidManager = NULL;
        return NO;
    }
    
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(_hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    if (_matchingCriteria.count > 0) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
    
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    _isInitialized = YES;
    _isRunning = YES;
    return YES;
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    NSDictionary *criteria = @{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    };
    
    [_matchingCriteria addObject:criteria];
    
    if (_hidManager) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
}

- (void)addVendorMatching:(uint32_t)vendorID {
    NSDictionary *criteria = @{
        @(kIOHIDVendorIDKey): @(vendorID)
    };
    
    [_matchingCriteria addObject:criteria];
    
    if (_hidManager) {
        NSArray *criteriaArray = [_matchingCriteria copy];
        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteriaArray);
    }
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    NSError *configError = [self validateConfiguration];
    if (configError) {
        [self notifyDelegateOfError:configError];
        return NO;
    }
    
    if (!_isInitialized && ![self setupHIDManager]) {
        return NO;
    }
    
    return _isRunning;
}

- (void)stop {
    if (!_isRunning) return;
    
    if (_hidManager) {
        IOHIDManagerUnscheduleFromRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        
        [_deviceLock lock];
        for (id device in _devices) {
            CFRelease((__bridge IOHIDDeviceRef)device);
        }
        [_devices removeAllObjects];
        [_deviceLock unlock];
        
        IOHIDManagerClose(_hidManager, kIOHIDOptionsTypeNone);
        CFRelease(_hidManager);
        _hidManager = NULL;
    }
    
    _isRunning = NO;
    _isInitialized = NO;
}

- (NSError *)validateConfiguration {
    if (_matchingCriteria.count == 0) {
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

- (void)notifyDelegateOfError:(NSError *)error {
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = self.delegate;
    [_delegateLock unlock];
    
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
                CFRetain(device);
                [self->_devices addObject:(__bridge id)device];
                
                NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
                
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
            NSString *product = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
            
            if ([self->_devices containsObject:(__bridge id)device]) {
                [self->_devices removeObject:(__bridge id)device];
                CFRelease(device);
                
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
    if (result != kIOReturnSuccess || !context || !device) return;
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        [manager deviceAdded:device];
    }
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender __unused, IOHIDDeviceRef device) {
    if (result != kIOReturnSuccess || !context || !device) return;
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        [manager deviceRemoved:device];
    }
}

static void Handle_IOHIDInputValueCallback(void *context, IOReturn result, void *sender __unused, IOHIDValueRef value) {
    if (result != kIOReturnSuccess || !context || !value) return;
    
    @autoreleasepool {
        TPHIDDeviceManager *manager = (__bridge TPHIDDeviceManager *)context;
        
        [manager->_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = manager.delegate;
        [manager->_delegateLock unlock];
        
        if ([delegate respondsToSelector:@selector(didReceiveHIDValue:)]) {
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
