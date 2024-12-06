#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import "infrastructure/hid/TPHIDManagerTypes.h"

// Notification names
extern NSString *const kTPMovementNotification;
extern NSString *const kTPButtonNotification;

// Device identification constants
extern const uint32_t kUsagePageGenericDesktop;
extern const uint32_t kUsagePageButton;
extern const uint32_t kUsageMouse;
extern const uint32_t kUsagePointer;

// Default configuration values
extern const CGFloat kDefaultScrollSpeedMultiplier;
extern const CGFloat kDefaultScrollAcceleration;
extern const NSTimeInterval kDefaultMiddleButtonDelay;

#endif
