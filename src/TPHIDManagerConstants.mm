#include "TPHIDManager.h"

// Constants for device identification
const uint32_t kVendorIDLenovo = 0x17EF;  // Lenovo vendor ID
const uint32_t kUsagePageGenericDesktop = kHIDPage_GenericDesktop;
const uint32_t kUsagePageButton = kHIDPage_Button;
const uint32_t kUsageMouse = kHIDUsage_GD_Mouse;
const uint32_t kUsagePointer = kHIDUsage_GD_Pointer;

// Button masks
const uint8_t kLeftButtonBit = 0x01;
const uint8_t kRightButtonBit = 0x02;
const uint8_t kMiddleButtonBit = 0x04;
