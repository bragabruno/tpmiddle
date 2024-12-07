#ifndef TPInputState_h
#define TPInputState_h

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPInputState : NSObject

@property (nonatomic, assign) BOOL leftButtonDown;
@property (nonatomic, assign) BOOL rightButtonDown;
@property (nonatomic, assign) BOOL middleButtonDown;
@property (nonatomic, assign) BOOL isScrollMode;
@property (nonatomic, assign) CGPoint savedCursorPosition;
@property (nonatomic, assign) int pendingDeltaX;
@property (nonatomic, assign) int pendingDeltaY;
@property (nonatomic, strong) NSDate *lastMovementTime;

+ (instancetype)sharedState;
- (void)resetPendingMovements;
- (uint8_t)currentButtonState;
- (void)enableScrollMode;
- (void)disableScrollMode;
- (void)enforceSavedCursorPosition;

@end

NS_ASSUME_NONNULL_END

#endif /* TPInputState_h */
