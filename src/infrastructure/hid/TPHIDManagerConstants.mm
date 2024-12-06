#import "TPHIDManagerTypes.h"
#import <IOKit/hid/IOHIDUsageTables.h>

// Error domain
NSString *const TPHIDManagerErrorDomain = @"com.tpmiddle.HIDManager";

// Button masks
const uint8_t kLeftButtonBit = 0x01;
const uint8_t kRightButtonBit = 0x02;
const uint8_t kMiddleButtonBit = 0x04;

// HID Usage Pages and Usages
const uint32_t kHIDUsagePageGenericDesktop = kHIDPage_GenericDesktop;
const uint32_t kHIDUsagePageButton = kHIDPage_Button;
const uint32_t kHIDUsageMouse = kHIDUsage_GD_Mouse;
const uint32_t kHIDUsagePointer = kHIDUsage_GD_Pointer;
const uint32_t kHIDUsageX = kHIDUsage_GD_X;
const uint32_t kHIDUsageY = kHIDUsage_GD_Y;
const uint32_t kHIDUsageWheel = kHIDUsage_GD_Wheel;

// Common vendor IDs
const uint32_t kVendorIDLenovo = 0x17EF;    // Lenovo
const uint32_t kVendorIDIBM = 0x04B3;       // IBM
const uint32_t kVendorIDTI = 0x0451;        // Texas Instruments
const uint32_t kVendorIDLogitech = 0x046D;  // Logitech
