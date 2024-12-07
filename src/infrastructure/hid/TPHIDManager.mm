#import "TPHIDManager.h"
#import "TPHIDDeviceManager.h"
#import "TPHIDInputHandler.h"
#import "TPLogger.h"

@interface TPHIDManager () <TPHIDManagerDelegate> {
    TPHIDDeviceManager *_deviceManager;
    TPHIDInputHandler *_inputHandler;
    NSLock *_delegateLock;
    BOOL _isInitialized;
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
        _delegateLock = [[NSLock alloc] init];
        _isInitialized = NO;
        
        // Initialize input handler first
        _inputHandler = [[TPHIDInputHandler alloc] init];
        if (!_inputHandler) {
            return nil;
        }
        
        // Then initialize device manager
        _deviceManager = [[TPHIDDeviceManager alloc] init];
        if (!_deviceManager) {
            _inputHandler = nil;
            return nil;
        }
        
        _deviceManager.delegate = self;
        _isInitialized = YES;
    }
    return self;
}

- (void)dealloc {
    [self stop];
    _deviceManager = nil;
    _inputHandler = nil;
    _delegateLock = nil;
}

- (void)setDelegate:(id<TPHIDManagerDelegate>)delegate {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    _inputHandler.delegate = delegate;
    [_delegateLock unlock];
}

- (id<TPHIDManagerDelegate>)delegate {
    if (!_isInitialized) return nil;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    [_delegateLock unlock];
    return delegate;
}

- (NSArray *)devices {
    if (!_isInitialized) return @[];
    return _deviceManager.devices;
}

- (BOOL)isRunning {
    if (!_isInitialized) return NO;
    return _deviceManager.isRunning;
}

- (BOOL)isScrollMode {
    if (!_isInitialized) return NO;
    return _inputHandler.isScrollMode;
}

- (BOOL)start {
    if (!_isInitialized) return NO;
    return [_deviceManager start];
}

- (void)stop {
    if (!_isInitialized) return;
    
    [_deviceManager stop];
    [_inputHandler reset];
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    if (!_isInitialized) return;
    [_deviceManager addDeviceMatching:usagePage usage:usage];
}

- (void)addVendorMatching:(uint32_t)vendorID {
    if (!_isInitialized) return;
    [_deviceManager addVendorMatching:vendorID];
}

- (NSString *)deviceStatus {
    if (!_isInitialized) return @"Not initialized";
    return [_deviceManager deviceStatus];
}

- (NSString *)currentConfiguration {
    if (!_isInitialized) return @"Not initialized";
    return [_deviceManager currentConfiguration];
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didDetectDeviceAttached:deviceInfo];
        });
    }
    [_delegateLock unlock];
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didDetectDeviceDetached:deviceInfo];
        });
    }
    [_delegateLock unlock];
    
    [_inputHandler reset];
}

- (void)didEncounterError:(NSError *)error {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didEncounterError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didEncounterError:error];
        });
    }
    [_delegateLock unlock];
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didReceiveButtonPress:leftButton right:rightButton middle:middleButton];
        });
    }
    [_delegateLock unlock];
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    if (!_isInitialized) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
        });
    }
    [_delegateLock unlock];
}

- (void)didReceiveHIDValue:(id)value {
    if (!_isInitialized || !_inputHandler) return;
    
    // Create a local strong reference to the value
    IOHIDValueRef hidValue = (__bridge IOHIDValueRef)value;
    if (!hidValue) return;
    
    // Retain the value before passing it to the handler
    CFRetain(hidValue);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_inputHandler handleInput:hidValue];
        CFRelease(hidValue);
    });
}

@end
