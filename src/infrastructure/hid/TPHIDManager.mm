#import "TPHIDManager.h"
#import "TPLogger.h"

@implementation TPHIDManager {
    IOHIDManagerRef _hidManager;
    NSMutableArray<TPHIDDevice *> *_devices;
    BOOL _isRunning;
}

@synthesize isRunning = _isRunning;

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
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager.inputHandler handleInput:value];
    });
}

+ (instancetype)sharedManager {
    static TPHIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPHIDManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _devices = [[NSMutableArray alloc] init];
        _inputHandler = [[TPInputHandler alloc] init];
        _isRunning = NO;
        [self setupHIDManager];
    }
    return self;
}

- (void)dealloc {
    if (_hidManager) {
        IOHIDManagerClose(_hidManager, kIOHIDOptionsTypeNone);
        CFRelease(_hidManager);
    }
}

- (BOOL)start {
    if (_isRunning) return YES;
    
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
    
    IOHIDManagerClose(_hidManager, kIOHIDOptionsTypeNone);
    _isRunning = NO;
    NSLog(@"HID Manager stopped");
}

- (void)setupHIDManager {
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!_hidManager) {
        NSLog(@"Failed to create HID Manager");
        return;
    }
    
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, Handle_DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, Handle_DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(_hidManager, Handle_IOHIDInputValueCallback, (__bridge void *)self);
    
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    NSLog(@"HID Manager created and scheduled with run loop");
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    NSMutableArray *criteria = [NSMutableArray array];
    
    CFDictionaryRef existingCriteria = IOHIDManagerGetDeviceMatching(_hidManager);
    if (existingCriteria) {
        [criteria addObject:(__bridge_transfer id)existingCriteria];
    }
    
    [criteria addObject:@{
        @(kIOHIDDeviceUsagePageKey): @(usagePage),
        @(kIOHIDDeviceUsageKey): @(usage)
    }];
    
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteria);
}

- (void)addVendorMatching:(uint32_t)vendorID {
    NSMutableArray *criteria = [NSMutableArray array];
    
    CFDictionaryRef existingCriteria = IOHIDManagerGetDeviceMatching(_hidManager);
    if (existingCriteria) {
        [criteria addObject:(__bridge_transfer id)existingCriteria];
    }
    
    [criteria addObject:@{
        @(kIOHIDVendorIDKey): @(vendorID)
    }];
    
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)criteria);
}

- (void)deviceAdded:(IOHIDDeviceRef)deviceRef {
    TPHIDDevice *device = [[TPHIDDevice alloc] initWithDevice:deviceRef];
    if (![_devices containsObject:device]) {
        [_devices addObject:device];
        
        NSLog(@"Device added - Product: %@, Vendor ID: %@, Product ID: %@", 
              device.productName, device.vendorID, device.productID);
        [[TPLogger sharedLogger] logDeviceEvent:device.productName attached:YES];
        
        if ([self.delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
            [self.delegate didDetectDeviceAttached:device.productName];
        }
    }
}

- (void)deviceRemoved:(IOHIDDeviceRef)deviceRef {
    NSUInteger index = [_devices indexOfObjectPassingTest:^BOOL(TPHIDDevice *device, NSUInteger idx, BOOL *stop) {
        return [device isEqualToDevice:deviceRef];
    }];
    
    if (index != NSNotFound) {
        TPHIDDevice *device = _devices[index];
        [_devices removeObjectAtIndex:index];
        
        NSLog(@"Device removed - Product: %@", device.productName);
        [[TPLogger sharedLogger] logDeviceEvent:device.productName attached:NO];
        
        if ([self.delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
            [self.delegate didDetectDeviceDetached:device.productName];
        }
    }
}

@end
