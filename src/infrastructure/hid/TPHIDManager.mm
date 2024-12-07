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
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [_delegateLock lock];
    _inputHandler.delegate = delegate;
    [_delegateLock unlock];
}

- (id<TPHIDManagerDelegate>)delegate {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return nil;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    [_delegateLock unlock];
    return delegate;
}

- (NSArray *)devices {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return @[];
    return [_deviceManager.devices copy];
}

- (BOOL)isRunning {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return NO;
    return _deviceManager.isRunning;
}

- (BOOL)isScrollMode {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return NO;
    return _inputHandler.isScrollMode;
}

- (BOOL)start {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return NO;
    return [_deviceManager start];
}

- (void)stop {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [_deviceManager stop];
    [_inputHandler reset];
}

- (void)addDeviceMatching:(uint32_t)usagePage usage:(uint32_t)usage {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    [_deviceManager addDeviceMatching:usagePage usage:usage];
}

- (void)addVendorMatching:(uint32_t)vendorID {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    [_deviceManager addVendorMatching:vendorID];
}

- (NSString *)deviceStatus {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return @"Not initialized";
    return [_deviceManager deviceStatus];
}

- (NSString *)currentConfiguration {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return @"Not initialized";
    return [_deviceManager currentConfiguration];
}

#pragma mark - Private Methods

- (void)notifyDelegateOnMainQueue:(dispatch_block_t)block {
    if (!block) return;
    
    [_delegateLock lock];
    id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
    [_delegateLock unlock];
    
    if (!delegate) return;
    
    dispatch_async(_delegateQueue, ^{
        @try {
            block();
        } @catch (NSException *exception) {
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in delegate notification: %@", exception]];
        }
    });
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [self notifyDelegateOnMainQueue:^{
        [_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
        if ([delegate respondsToSelector:@selector(didDetectDeviceAttached:)]) {
            [delegate didDetectDeviceAttached:deviceInfo];
        }
        [_delegateLock unlock];
    }];
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [self notifyDelegateOnMainQueue:^{
        [_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
        if ([delegate respondsToSelector:@selector(didDetectDeviceDetached:)]) {
            [delegate didDetectDeviceDetached:deviceInfo];
        }
        [_delegateLock unlock];
    }];
    
    [_inputHandler reset];
}

- (void)didEncounterError:(NSError *)error {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [self notifyDelegateOnMainQueue:^{
        [_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
        if ([delegate respondsToSelector:@selector(didEncounterError:)]) {
            [delegate didEncounterError:error];
        }
        [_delegateLock unlock];
    }];
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [self notifyDelegateOnMainQueue:^{
        [_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
        if ([delegate respondsToSelector:@selector(didReceiveButtonPress:right:middle:)]) {
            [delegate didReceiveButtonPress:leftButton right:rightButton middle:middleButton];
        }
        [_delegateLock unlock];
    }];
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) return;
    
    [self notifyDelegateOnMainQueue:^{
        [_delegateLock lock];
        id<TPHIDManagerDelegate> delegate = _inputHandler.delegate;
        if ([delegate respondsToSelector:@selector(didReceiveMovement:deltaY:withButtonState:)]) {
            [delegate didReceiveMovement:deltaX deltaY:deltaY withButtonState:buttons];
        }
        [_delegateLock unlock];
    }];
}

- (void)didReceiveHIDValue:(id)value {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized || !_inputHandler) return;
    
    @try {
        // Create a local strong reference to the value
        IOHIDValueRef hidValue = (__bridge IOHIDValueRef)value;
        if (!hidValue) return;
        
        // Retain the value before passing it to the handler
        CFRetain(hidValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                [self->_inputHandler handleInput:hidValue];
            } @catch (NSException *exception) {
                [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception handling HID value: %@", exception]];
            } @finally {
                CFRelease(hidValue);
            }
        });
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in didReceiveHIDValue: %@", exception]];
    }
}

@end
