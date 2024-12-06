#import "TPHIDDevice.h"

@implementation TPHIDDevice {
    IOHIDDeviceRef _deviceRef;
    NSString *_productName;
    NSNumber *_vendorID;
    NSNumber *_productID;
}

- (instancetype)initWithDevice:(IOHIDDeviceRef)device {
    self = [super init];
    if (self) {
        _deviceRef = device;
        _productName = (__bridge_transfer NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        _vendorID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        _productID = (__bridge_transfer NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    }
    return self;
}

- (BOOL)isEqualToDevice:(IOHIDDeviceRef)device {
    return _deviceRef == device;
}

- (NSString *)productName {
    return _productName;
}

- (NSNumber *)vendorID {
    return _vendorID;
}

- (NSNumber *)productID {
    return _productID;
}

- (IOHIDDeviceRef)deviceRef {
    return _deviceRef;
}

@end
