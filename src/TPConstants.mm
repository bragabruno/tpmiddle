#include "TPConstants.h"

// Device identification constants
const uint32_t kVendorIDLenovo = 0x17EF;           // Lenovo vendor ID
const uint32_t kUsagePageGenericDesktop = 0x01;    // Generic desktop controls
const uint32_t kUsagePageButton = 0x09;            // Button
const uint32_t kUsageMouse = 0x02;                 // Mouse
const uint32_t kUsagePointer = 0x01;               // Pointer

// Button masks
const uint8_t kLeftButtonBit = 0x01;               // Left button mask
const uint8_t kRightButtonBit = 0x02;              // Right button mask
const uint8_t kMiddleButtonBit = 0x04;             // Middle button mask

// Default configuration values
const CGFloat kDefaultScrollSpeedMultiplier = 0.5f;
const CGFloat kDefaultScrollAcceleration = 1.2f;
const NSTimeInterval kDefaultMiddleButtonDelay = 0.02;
