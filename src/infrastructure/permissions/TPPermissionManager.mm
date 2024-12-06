#import "TPPermissionManager.h"
#import "TPLogger.h"

NSString * const TPPermissionManagerErrorDomain = @"com.tpmiddle.permissions";

@interface TPPermissionManager () {
    NSAlert *_permissionAlert;
}
@end

@implementation TPPermissionManager

@synthesize waitingForPermissions = _waitingForPermissions;
@synthesize showingPermissionAlert = _showingPermissionAlert;
@synthesize currentPermissionRequest = _currentPermissionRequest;

+ (instancetype)sharedManager {
    static TPPermissionManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TPPermissionManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _waitingForPermissions = NO;
        _showingPermissionAlert = NO;
        _permissionAlert = nil;
        _currentPermissionRequest = TPPermissionTypeAccessibility;
    }
    return self;
}

- (NSError *)checkPermissions {
    // Check accessibility permissions first
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        self.currentPermissionRequest = TPPermissionTypeAccessibility;
        return [NSError errorWithDomain:TPPermissionManagerErrorDomain
                                 code:TPPermissionManagerErrorDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Accessibility permissions not granted. Please grant permission in System Settings > Privacy & Security > Accessibility"}];
    }
    
    // Then check input monitoring permissions
    IOHIDManagerRef testManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!testManager) {
        return [NSError errorWithDomain:TPPermissionManagerErrorDomain
                                 code:TPPermissionManagerErrorDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create test HID manager"}];
    }
    
    IOReturn result = IOHIDManagerOpen(testManager, kIOHIDOptionsTypeNone);
    CFRelease(testManager);
    
    if (result == kIOReturnNotPermitted) {
        self.currentPermissionRequest = TPPermissionTypeInputMonitoring;
        return [NSError errorWithDomain:TPPermissionManagerErrorDomain
                                 code:TPPermissionManagerErrorDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Input monitoring permissions not granted. Please grant permission in System Settings > Privacy & Security > Input Monitoring"}];
    }
    
    return nil;
}

- (void)showPermissionError:(NSError *)error withCompletion:(void(^)(BOOL shouldRetry))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        _waitingForPermissions = YES;
        _showingPermissionAlert = YES;
        
        self->_permissionAlert = [[NSAlert alloc] init];
        self->_permissionAlert.messageText = @"Permission Required";
        self->_permissionAlert.informativeText = [NSString stringWithFormat:@"%@\n\nPlease grant the required permissions in System Settings and try again.", error.localizedDescription];
        self->_permissionAlert.alertStyle = NSAlertStyleWarning;
        [self->_permissionAlert addButtonWithTitle:@"Open System Settings"];
        [self->_permissionAlert addButtonWithTitle:@"Try Again"];
        [self->_permissionAlert addButtonWithTitle:@"Quit"];
        
        NSModalResponse response = [self->_permissionAlert runModal];
        self->_permissionAlert = nil;
        _showingPermissionAlert = NO;
        
        if (response == NSAlertFirstButtonReturn) {
            // Open System Settings
            NSString *urlString;
            if (self.currentPermissionRequest == TPPermissionTypeAccessibility) {
                urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
            } else {
                urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
            }
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
            
            // Wait a moment and try again
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _waitingForPermissions = NO;
                completion(YES);
            });
        } else if (response == NSAlertSecondButtonReturn) {
            // Try again immediately
            _waitingForPermissions = NO;
            completion(YES);
        } else {
            // Quit was selected
            _waitingForPermissions = NO;
            completion(NO);
        }
    });
}

@end
