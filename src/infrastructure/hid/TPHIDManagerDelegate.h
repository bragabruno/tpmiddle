#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import "TPHIDManagerTypes.h"

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didEncounterError:(NSError *)error;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
- (void)didReceiveHIDValue:(id)value;  // Added for internal use
@end

#endif // __OBJC__

#ifdef __cplusplus
}
#endif
