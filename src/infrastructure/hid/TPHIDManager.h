#ifndef TPHIDManager_h
#define TPHIDManager_h

#import <Cocoa/Cocoa.h>
#import "TPHIDDevice.h"
#import "TPInputHandler.h"

@protocol TPHIDManagerDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface TPHIDManager : NSObject

@property (nonatomic, weak) id<TPHIDManagerDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, strong) TPInputHandler *inputHandler;

+ (instancetype)sharedManager;

- (BOOL)start;
- (void)stop;
- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage;
- (void)addVendorMatching:(uint32_t)vendorID;

@end

@protocol TPHIDManagerDelegate <NSObject>
@optional
- (void)didDetectDeviceAttached:(NSString *)productName;
- (void)didDetectDeviceDetached:(NSString *)productName;
@end

NS_ASSUME_NONNULL_END

#endif /* TPHIDManager_h */
