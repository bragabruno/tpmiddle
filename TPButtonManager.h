#import <Foundation/Foundation.h>

@protocol TPButtonManagerDelegate <NSObject>
@optional
- (void)middleButtonStateChanged:(BOOL)isPressed;
@end

@interface TPButtonManager : NSObject

@property (weak, nonatomic) id<TPButtonManagerDelegate> delegate;
@property (readonly) BOOL isMiddleButtonEmulated;
@property (readonly) BOOL isMiddleButtonPressed;

+ (instancetype)sharedManager;

// Button state management
- (void)updateButtonStates:(BOOL)leftDown right:(BOOL)rightDown middle:(BOOL)middleDown;

// Movement handling
- (void)handleMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;

// Reset state
- (void)reset;

@end

// Scroll configuration
extern const CGFloat kScrollSpeedMultiplier;  // Base scroll speed multiplier
extern const CGFloat kScrollAcceleration;     // Acceleration factor for faster movements
