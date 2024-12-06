#include <Foundation/Foundation.h>
#include <IOKit/hid/IOHIDManager.h>

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
@end

@interface TPHIDManager : NSObject

@property (weak, nonatomic) id<TPHIDManagerDelegate> delegate;
@property (readonly) BOOL isRunning;
@property (readonly) BOOL isScrollMode;

+ (instancetype)sharedManager;

- (BOOL)start;
- (void)stop;

// Device matching criteria
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;

@end

// Constants for device identification
extern const uint32_t kVendorIDLenovo;
extern const uint32_t kUsagePageGenericDesktop;
extern const uint32_t kUsagePageButton;
extern const uint32_t kUsageMouse;
extern const uint32_t kUsagePointer;

// Button masks
extern const uint8_t kLeftButtonBit;
extern const uint8_t kRightButtonBit;
extern const uint8_t kMiddleButtonBit;
