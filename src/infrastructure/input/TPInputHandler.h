#ifndef TPInputHandler_h
#define TPInputHandler_h

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>
#import "TPInputState.h"

@protocol TPInputHandlerDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface TPInputHandler : NSObject

@property (nonatomic, weak) id<TPInputHandlerDelegate> delegate;
@property (nonatomic, strong) TPInputState *inputState;

- (instancetype)init;
- (void)handleInput:(IOHIDValueRef)value;
- (void)handleButtonInput:(IOHIDValueRef)value;
- (void)handleMovementInput:(IOHIDValueRef)value;
- (void)handleScrollInput:(int)verticalDelta withHorizontal:(int)horizontalDelta;

@end

@protocol TPInputHandlerDelegate <NSObject>
@optional
- (void)didReceiveButtonPress:(BOOL)left right:(BOOL)right middle:(BOOL)middle;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;
@end

NS_ASSUME_NONNULL_END

#endif /* TPInputHandler_h */
