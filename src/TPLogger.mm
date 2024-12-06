#include "TPLogger.h"
#include "TPConfig.h"

@interface TPLogger () {
    NSFileHandle *_logFile;
    NSString *_logPath;
    dispatch_queue_t _logQueue;
    BOOL _isLogging;
}
@end

@implementation TPLogger

+ (instancetype)sharedLogger {
    static TPLogger *sharedLogger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLogger = [[TPLogger alloc] init];
    });
    return sharedLogger;
}

- (instancetype)init {
    if (self = [super init]) {
        _logQueue = dispatch_queue_create("com.tpmiddle.logger", DISPATCH_QUEUE_SERIAL);
        _isLogging = NO;
        [self setupLogFile];
    }
    return self;
}

- (void)dealloc {
    [self stopLogging];
}

#pragma mark - Logging Setup

- (void)setupLogFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = paths.firstObject;
    NSString *logsPath = [libraryPath stringByAppendingPathComponent:@"Logs/TPMiddle"];
    
    // Create logs directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logsPath]) {
        [fileManager createDirectoryAtPath:logsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // Create log file path with timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    _logPath = [logsPath stringByAppendingFormat:@"/tpmiddle-%@.log", dateString];
}

- (void)startLogging {
    if (_isLogging) return;
    
    dispatch_async(_logQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:self->_logPath]) {
            [fileManager createFileAtPath:self->_logPath contents:nil attributes:nil];
        }
        
        self->_logFile = [NSFileHandle fileHandleForWritingAtPath:self->_logPath];
        [self->_logFile seekToEndOfFile];
        self->_isLogging = YES;
        
        // Log system information
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        TPConfig *config = [TPConfig sharedConfig];
        NSString *systemInfo = [NSString stringWithFormat:@"=== TPMiddle Logging Started ===\n"
                              "System Information:\n"
                              "- OS Version: %@\n"
                              "- Host Name: %@\n"
                              "- Process Name: %@\n"
                              "- Process ID: %d\n"
                              "- Physical Memory: %.2f GB\n"
                              "- Log Path: %@\n"
                              "=== Configuration ===\n"
                              "- Operation Mode: %@\n"
                              "- Debug Mode: %@\n"
                              "- Middle Button Delay: %.2f ms\n"
                              "- Scroll Speed Multiplier: %.2f\n"
                              "- Scroll Acceleration: %.2f\n"
                              "- Natural Scrolling: %@\n"
                              "- Invert Scroll X: %@\n"
                              "- Invert Scroll Y: %@\n"
                              "===================",
                              processInfo.operatingSystemVersionString,
                              processInfo.hostName,
                              processInfo.processName,
                              processInfo.processIdentifier,
                              processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0),
                              self->_logPath,
                              config.operationMode == TPOperationModeDefault ? @"Default" : @"Normal",
                              config.debugMode ? @"ON" : @"OFF",
                              config.middleButtonDelay * 1000.0,
                              config.scrollSpeedMultiplier,
                              config.scrollAcceleration,
                              config.naturalScrolling ? @"ON" : @"OFF",
                              config.invertScrollX ? @"ON" : @"OFF",
                              config.invertScrollY ? @"ON" : @"OFF"];
        
        [self logMessage:systemInfo];
    });
}

- (void)stopLogging {
    if (!_isLogging) return;
    
    dispatch_sync(_logQueue, ^{
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        NSString *stopMessage = [NSString stringWithFormat:@"=== TPMiddle Logging Stopped ===\n"
                               "- Process Uptime: %.2f seconds\n"
                               "===================",
                               processInfo.systemUptime];
        [self logMessage:stopMessage];
        [self->_logFile closeFile];
        self->_logFile = nil;
        self->_isLogging = NO;
    });
}

#pragma mark - Logging Methods

- (void)logButtonEvent:(BOOL)leftDown right:(BOOL)rightDown middle:(BOOL)middleDown {
    NSString *message = [NSString stringWithFormat:@"[Button Event] State Change:\n"
                        "- Left Button: %@\n"
                        "- Right Button: %@\n"
                        "- Middle Button: %@",
                        leftDown ? @"PRESSED" : @"RELEASED",
                        rightDown ? @"PRESSED" : @"RELEASED",
                        middleDown ? @"PRESSED" : @"RELEASED"];
    [self logMessage:message];
}

- (void)logTrackpointMovement:(int)deltaX deltaY:(int)deltaY buttons:(uint8_t)buttons {
    NSString *message = [NSString stringWithFormat:@"[TrackPoint] Movement Detected:\n"
                        "- Delta X: %d\n"
                        "- Delta Y: %d\n"
                        "- Button State: 0x%02X",
                        deltaX, deltaY, buttons];
    [self logMessage:message];
}

- (void)logMiddleButtonEmulation:(BOOL)isDown {
    NSString *message = [NSString stringWithFormat:@"[Middle Button] Emulation Event:\n"
                        "- State: %@\n"
                        "- Delay Setting: %.2f ms",
                        isDown ? @"ACTIVATED" : @"DEACTIVATED",
                        [TPConfig sharedConfig].middleButtonDelay * 1000.0];
    [self logMessage:message];
}

- (void)logScrollEvent:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    TPConfig *config = [TPConfig sharedConfig];
    NSString *message = [NSString stringWithFormat:@"[Scroll] Event Generated:\n"
                        "- Delta X: %.2f\n"
                        "- Delta Y: %.2f\n"
                        "- Speed Multiplier: %.2f\n"
                        "- Acceleration: %.2f\n"
                        "- Natural Scrolling: %@",
                        deltaX, deltaY,
                        config.scrollSpeedMultiplier,
                        config.scrollAcceleration,
                        config.naturalScrolling ? @"ON" : @"OFF"];
    [self logMessage:message];
}

- (void)logDeviceEvent:(NSString *)deviceInfo attached:(BOOL)attached {
    NSString *message = [NSString stringWithFormat:@"[Device] %@ Event:\n%@",
                        attached ? @"Connection" : @"Disconnection",
                        deviceInfo];
    [self logMessage:message];
}

#pragma mark - Private Methods

- (void)logMessage:(NSString *)message {
    if (!_isLogging) return;
    
    dispatch_async(_logQueue, ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        
        // Write to file
        [self->_logFile writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [self->_logFile synchronizeFile];
        
        // Also output to console for immediate visibility
        NSLog(@"%@", logLine);
    });
}

- (NSString *)currentLogPath {
    return _logPath;
}

@end
