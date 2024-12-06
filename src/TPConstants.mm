#include "TPConstants.h"
#include <IOKit/hid/IOHIDUsageTables.h>

// Notification names
NSString *const kTPMovementNotification = @"TPMovementNotification";
NSString *const kTPButtonNotification = @"TPButtonNotification";

// Device identification constants
const uint32_t kUsagePageGenericDesktop = kHIDPage_GenericDesktop;
const uint32_t kUsagePageButton = kHIDPage_Button;
const uint32_t kUsageMouse = kHIDUsage_GD_Mouse;
const uint32_t kUsagePointer = kHIDUsage_GD_Pointer;

// Default configuration values
const CGFloat kDefaultScrollSpeedMultiplier = 1.0;
const CGFloat kDefaultScrollAcceleration = 1.2;
const NSTimeInterval kDefaultMiddleButtonDelay = 0.3;
