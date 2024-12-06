#pragma once

#include <stdint.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Device identification constants
extern const uint32_t kVendorIDLenovo;
extern const uint32_t kUsagePageGenericDesktop;
extern const uint32_t kUsagePageButton;
extern const uint32_t kUsageMouse;
extern const uint32_t kUsagePointer;

// Button masks
extern const uint8_t kLeftButtonBit;
extern const uint8_t kRightButtonBit;
extern const uint8_t kMiddleButtonBit;

#ifdef __OBJC__
// Default configuration values
extern const CGFloat kDefaultScrollSpeedMultiplier;
extern const CGFloat kDefaultScrollAcceleration;
extern const NSTimeInterval kDefaultMiddleButtonDelay;
#endif

#ifdef __cplusplus
}
#endif
