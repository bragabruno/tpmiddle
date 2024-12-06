#import "TPStatusReporter.h"
#import "TPLogger.h"
#import "TPHIDManager.h"

@implementation TPStatusReporter

+ (instancetype)sharedReporter {
    static TPStatusReporter *sharedReporter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedReporter = [[TPStatusReporter alloc] init];
    });
    return sharedReporter;
}

- (NSString *)applicationStatus:(BOOL)isInitialized 
                     debugMode:(BOOL)debugMode 
                   hidManager:(TPHIDManager *)hidManager {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"=== TPMiddle Status ===\n"];
    [status appendFormat:@"Initialized: %@\n", isInitialized ? @"Yes" : @"No"];
    [status appendFormat:@"Debug Mode: %@\n", debugMode ? @"Enabled" : @"Disabled"];
    
    if (hidManager) {
        [status appendString:[hidManager deviceStatus]];
    }
    
    [status appendString:@"===================\n"];
    return status;
}

- (void)logSystemInfo {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *systemInfo = [NSString stringWithFormat:@"System Information:\n"
                           "OS Version: %@\n"
                           "Process Name: %@\n"
                           "Process ID: %d\n"
                           "Physical Memory: %.2f GB\n"
                           "Number of Processors: %lu\n"
                           "Active Processor Count: %lu\n"
                           "Thermal State: %ld\n"
                           "Low Power Mode Enabled: %@",
                           processInfo.operatingSystemVersionString,
                           processInfo.processName,
                           processInfo.processIdentifier,
                           processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0),
                           (unsigned long)processInfo.processorCount,
                           (unsigned long)processInfo.activeProcessorCount,
                           (long)processInfo.thermalState,
                           processInfo.lowPowerModeEnabled ? @"Yes" : @"No"];
    
    [[TPLogger sharedLogger] logMessage:systemInfo];
}

@end
