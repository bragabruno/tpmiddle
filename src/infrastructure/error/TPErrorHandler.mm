#import "TPErrorHandler.h"
#import "TPLogger.h"

@implementation TPErrorHandler

+ (instancetype)sharedHandler {
    static TPErrorHandler *sharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHandler = [[TPErrorHandler alloc] init];
    });
    return sharedHandler;
}

- (void)showError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"TPMiddle Error";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        [self logError:error];
    });
}

- (void)logError:(NSError *)error {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
}

- (void)logException:(NSException *)exception {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception: %@", exception]];
}

@end
