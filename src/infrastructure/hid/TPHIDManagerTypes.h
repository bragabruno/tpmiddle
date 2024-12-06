#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>

// Error domain
extern NSString *const TPHIDManagerErrorDomain;

// Error codes
typedef NS_ENUM(NSInteger, TPHIDManagerError) {
    TPHIDManagerErrorPermissionDenied = 1,
    TPHIDManagerErrorInitializationFailed,
    TPHIDManagerErrorDeviceAccessFailed,
    TPHIDManagerErrorInvalidConfiguration
};

// Button masks
extern const uint8_t kLeftButtonBit;
extern const uint8_t kRightButtonBit;
extern const uint8_t kMiddleButtonBit;

// HID Usage Pages and Usages
extern const uint32_t kHIDUsagePageGenericDesktop;
extern const uint32_t kHIDUsagePageButton;
extern const uint32_t kHIDUsageMouse;
extern const uint32_t kHIDUsagePointer;
extern const uint32_t kHIDUsageX;
extern const uint32_t kHIDUsageY;
extern const uint32_t kHIDUsageWheel;

// Common vendor IDs
extern const uint32_t kVendorIDLenovo;
extern const uint32_t kVendorIDIBM;
extern const uint32_t kVendorIDTI;
extern const uint32_t kVendorIDLogitech;

#endif // __OBJC__

#ifdef __cplusplus
}
#endif
