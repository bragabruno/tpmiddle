#import "TPHIDManager.h"
#import "TPHIDDeviceManager.h"
#import "TPHIDInputHandler.h"
#import "TPLogger.h"

@interface TPHIDManager () <TPHIDManagerDelegate> {
    TPHIDDeviceManager *_deviceManager;
    TPHIDInputHandler *_inputHandler;
    NSLock *_delegateLock;
    NSLock *_stateLock;
    BOOL _isInitialized;
    dispatch_queue_t _delegateQueue;
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
        _stateLock = [[NSLock alloc] init];
        _isInitialized = NO;
        _delegateQueue = dispatch_queue_create("com.tpmiddle.hidmanager.delegate", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_delegateQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        
        @try {
            _inputHandler = [[TPHIDInputHandler alloc] init];
            if (!_inputHandler) {
                return nil;
            }
            
            _deviceManager = [[TPHIDDeviceManager alloc] init];
            if (!_deviceManager) {
                _inputHandler = nil;
                return nil;
            }
            
            _deviceManager.delegate = self;
            
            [_stateLock lock];
            _isInitialized = YES;
            [_stateLock unlock];
        } @catch (NSException *exception) {
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in TPHIDManager init: %@", exception]];
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stop];
    
    [_stateLock lock];
    _isInitialized = NO;
    [_stateLock unlock];
    
    _deviceManager.delegate = nil;
    _deviceManager = nil;
    _inputHandler.delegate = nil;
    _inputHandler = nil;
    _delegateLock = nil;
    _stateLock = nil;
    _delegateQueue = NULL;
}

- (void)setDelegate:(id<TPHIDManagerDelegate>)delegate {
    if (!_isInitialized) return;
    _inputHandler.delegate = delegate;
}

- (id<TPHIDManagerDelegate>)delegate {
    if (!_isInitialized) return nil;
    return _inputHandler.delegate;
}

- (NSArray *)devices {
    if (!_isInitialized) return @[];
    return [_deviceManager.devices copy];
}

- (BOOL)isRunning {
    if (!_isInitialized) return NO;
    return _deviceManager.isRunning;
}

- (BOOL)isScrollMode {
    if (!_isInitialized) return NO;
    return [_inputHandler isMiddleButtonHeld];
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
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
        [delegate didDetectDeviceAttached:deviceInfo];
    }
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    if (!_isInitialized) return;
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
        [delegate didDetectDeviceDetached:deviceInfo];
    }
    [_inputHandler reset];
}

- (void)didEncounterError:(NSError *)error {
    if (!_isInitialized) return;
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didEncounterError:)]) {
        [delegate didEncounterError:error];
    }
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    if (!_isInitialized) return;
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
        [delegate didReceiveButtonPress:leftButton right:rightButton middle:middleButton];
    }
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    if (!_isInitialized) return;
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    if ([delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
        [delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
    }
}

- (void)didReceiveHIDValue:(id)value {
    if (!_isInitialized || !_inputHandler) return;
    
    @try {
        IOHIDValueRef hidValue = (__bridge IOHIDValueRef)value;
        if (!hidValue) return;
        
        // Process HID value immediately without dispatch
        [_inputHandler handleInput:hidValue];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in didReceiveHIDValue: %@", exception]];
    }
}

@end
