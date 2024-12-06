#ifndef TPHIDDevice_h
#define TPHIDDevice_h

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPHIDDevice : NSObject

@property (nonatomic, readonly, strong) NSString *productName;
@property (nonatomic, readonly, strong) NSNumber *vendorID;
@property (nonatomic, readonly, strong) NSNumber *productID;
@property (nonatomic, readonly, assign) IOHIDDeviceRef deviceRef;

- (instancetype)initWithDevice:(IOHIDDeviceRef)device;
- (BOOL)isEqualToDevice:(IOHIDDeviceRef)device;

@end

NS_ASSUME_NONNULL_END

#endif /* TPHIDDevice_h */
