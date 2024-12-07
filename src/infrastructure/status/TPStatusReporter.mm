#import "TPStatusReporter.h"
#import "TPLogger.h"
#import "infrastructure/hid/TPHIDManager.h"

@implementation TPStatusReporter

+ (instancetype)sharedReporter {
    static TPStatusReporter *sharedReporter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedReporter = [[TPStatusReporter alloc] init];
    });
    return sharedReporter;
}

- (void)logSystemInfo {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSOperatingSystemVersion osVersion = [processInfo operatingSystemVersion];
    
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"System Info:\n"
                                       "OS Version: %ld.%ld.%ld\n"
                                       "Physical Memory: %.2f GB\n"
                                       "Processor Count: %lu\n"
                                       "Active Processor Count: %lu",
                                       osVersion.majorVersion,
                                       osVersion.minorVersion,
                                       osVersion.patchVersion,
                                       [processInfo physicalMemory] / (1024.0 * 1024.0 * 1024.0),
                                       (unsigned long)[processInfo processorCount],
                                       (unsigned long)[processInfo activeProcessorCount]]];
}

- (NSString *)applicationStatus:(BOOL)isInitialized debugMode:(BOOL)debugMode hidManager:(TPHIDManager *)hidManager {
    return [NSString stringWithFormat:@"Application Status:\n"
            "Initialized: %@\n"
            "Debug Mode: %@\n"
            "HID Manager: %@",
            isInitialized ? @"Yes" : @"No",
            debugMode ? @"Enabled" : @"Disabled",
            hidManager ? @"Running" : @"Stopped"];
}

@end
