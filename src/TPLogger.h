#import <Foundation/Foundation.h>

@interface TPLogger : NSObject

// Singleton access
+ (instancetype)sharedLogger;

// Logging methods
- (void)logButtonEvent:(BOOL)leftDown right:(BOOL)rightDown middle:(BOOL)middleDown;
- (void)logTrackpointMovement:(int)deltaX deltaY:(int)deltaY buttons:(uint8_t)buttons;
- (void)logMiddleButtonEmulation:(BOOL)isDown;
- (void)logScrollEvent:(CGFloat)deltaX deltaY:(CGFloat)deltaY;
- (void)logDeviceEvent:(NSString *)deviceInfo attached:(BOOL)attached;
- (void)logMessage:(NSString *)message;

// Configuration
- (void)startLogging;
- (void)stopLogging;
- (NSString *)currentLogPath;

@end
