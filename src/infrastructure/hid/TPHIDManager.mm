#import "TPHIDManager.h"
#import "TPHIDDeviceManager.h"
#import "TPHIDInputHandler.h"
#import "TPLogger.h"

@interface TPHIDManager () <TPHIDManagerDelegate> {
    TPHIDDeviceManager *_deviceManager;
    TPHIDInputHandler *_inputHandler;
}
@end

@implementation TPHIDManager

+ (instancetype)sharedManager {
    static TPHIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPHIDManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _deviceManager = [[TPHIDDeviceManager alloc] init];
        _deviceManager.delegate = self;
        
        _inputHandler = [[TPHIDInputHandler alloc] init];
    }
    return self;
}

- (void)setDelegate:(id<TPHIDManagerDelegate>)delegate {
    _inputHandler.delegate = delegate;
}

- (id<TPHIDManagerDelegate>)delegate {
    return _inputHandler.delegate;
}

- (NSArray *)devices {
    return _deviceManager.devices;
}

- (BOOL)isRunning {
    return _deviceManager.isRunning;
}

- (BOOL)isScrollMode {
    return _inputHandler.isScrollMode;
}

- (BOOL)start {
    return [_deviceManager start];
}

- (void)stop {
    [_deviceManager stop];
    [_inputHandler reset];
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    [_deviceManager addDeviceMatching:usagePage usage:usage];
}

- (void)addVendorMatching:(uint32_t)vendorID {
    [_deviceManager addVendorMatching:vendorID];
}

- (NSString *)deviceStatus {
    return [_deviceManager deviceStatus];
}

- (NSString *)currentConfiguration {
    return [_deviceManager currentConfiguration];
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    if ([self.delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
        [self.delegate didDetectDeviceAttached:deviceInfo];
    }
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    if ([self.delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
        [self.delegate didDetectDeviceDetached:deviceInfo];
    }
    [_inputHandler reset];
}

- (void)didEncounterError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(didEncounterError:)]) {
        [self.delegate didEncounterError:error];
    }
}

- (void)didReceiveHIDValue:(id)value {
    [_inputHandler handleInput:(__bridge IOHIDValueRef)value];
}

@end
