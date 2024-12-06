#include "TPApplication.h"
#include "TPConfig.h"
#include "TPEventViewController.h"
#include "TPConstants.h"
#include "TPLogger.h"
#include <IOKit/hid/IOHIDManager.h>
#include <ApplicationServices/ApplicationServices.h>

@interface TPApplication () {
    BOOL _isInitialized;
}

@property (strong) TPHIDManager *hidManager;
@property (strong) TPButtonManager *buttonManager;
@property (strong) TPStatusBarController *statusBarController;
@property (strong) NSWindow *eventWindow;
@property (strong) TPEventViewController *eventViewController;
@property (strong) NSAlert *permissionAlert;

@end

@implementation TPApplication

@synthesize waitingForPermissions = _waitingForPermissions;
@synthesize showingPermissionAlert = _showingPermissionAlert;
@synthesize shouldKeepRunning = _shouldKeepRunning;

+ (instancetype)sharedApplication {
    static TPApplication *sharedApplication = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApplication = [[TPApplication alloc] init];
    });
    return sharedApplication;
}

- (instancetype)init {
    if (self = [super init]) {
        _isInitialized = NO;
        _waitingForPermissions = NO;
        _showingPermissionAlert = NO;
        _shouldKeepRunning = YES;
        _permissionAlert = nil;
        
        // Start logging immediately
        [[TPLogger sharedLogger] startLogging];
        [[TPLogger sharedLogger] logMessage:@"TPApplication initializing..."];
        [self logSystemInfo];
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup {
    if (self.waitingForPermissions || self.showingPermissionAlert) {
        return;
    }
    
    @try {
        [[TPLogger sharedLogger] logMessage:@"TPApplication cleaning up..."];
        
        if (self.eventWindow) {
            [self hideEventViewer];
            self.eventWindow = nil;
        }
        
        if (self.eventViewController) {
            [self.eventViewController stopMonitoring];
            self.eventViewController = nil;
        }
        
        if (self.hidManager) {
            [self.hidManager stop];
            self.hidManager = nil;
        }
        
        if (self.buttonManager) {
            [self.buttonManager reset];
            self.buttonManager = nil;
        }
        
        self.statusBarController = nil;
        
        [[TPLogger sharedLogger] stopLogging];
    } @catch (NSException *exception) {
        NSLog(@"Exception in cleanup: %@", exception);
    }
}

#pragma mark - Error Handling

- (void)showError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"TPMiddle Error";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Error shown to user: %@", error.localizedDescription]];
    });
}

- (void)showPermissionError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.waitingForPermissions = YES;
        self.showingPermissionAlert = YES;
        
        self.permissionAlert = [[NSAlert alloc] init];
        self.permissionAlert.messageText = @"Permission Required";
        self.permissionAlert.informativeText = [NSString stringWithFormat:@"%@\n\nPlease grant the required permissions in System Settings and try again.", error.localizedDescription];
        self.permissionAlert.alertStyle = NSAlertStyleWarning;
        [self.permissionAlert addButtonWithTitle:@"Open System Settings"];
        [self.permissionAlert addButtonWithTitle:@"Try Again"];
        [self.permissionAlert addButtonWithTitle:@"Quit"];
        
        NSModalResponse response = [self.permissionAlert runModal];
        self.permissionAlert = nil;
        self.showingPermissionAlert = NO;
        
        if (response == NSAlertFirstButtonReturn) {
            // Open System Settings
            if ([error.localizedDescription containsString:@"Accessibility"]) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
            } else if ([error.localizedDescription containsString:@"Input Monitoring"]) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"]];
            }
            
            // Wait a moment and try again
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.waitingForPermissions = NO;
                [self start];
            });
        } else if (response == NSAlertSecondButtonReturn) {
            // Try again immediately
            self.waitingForPermissions = NO;
            [self start];
        } else {
            // Quit was selected
            self.waitingForPermissions = NO;
            self.shouldKeepRunning = NO;
            [NSApp terminate:nil];
        }
        
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Permission error shown to user: %@", error.localizedDescription]];
    });
}

#pragma mark - Status Reporting

- (NSString *)applicationStatus {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"=== TPMiddle Status ===\n"];
    [status appendFormat:@"Initialized: %@\n", _isInitialized ? @"Yes" : @"No"];
    [status appendFormat:@"Debug Mode: %@\n", [TPConfig sharedConfig].debugMode ? @"Enabled" : @"Disabled"];
    
    if (self.hidManager) {
        [status appendString:[self.hidManager deviceStatus]];
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

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    @try {
        [[TPLogger sharedLogger] logMessage:@"Application did finish launching"];
        
        // Process command line arguments
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        [[TPConfig sharedConfig] applyCommandLineArguments:arguments];
        
        // Initialize status bar first
        self.statusBarController = [TPStatusBarController sharedController];
        if (!self.statusBarController) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create status bar controller"];
            [NSApp terminate:nil];
            return;
        }
        self.statusBarController.delegate = self;
        
        // Setup status bar UI
        [self.statusBarController setupStatusBar];
        
        _isInitialized = YES;
        [[TPLogger sharedLogger] logMessage:@"Application initialization complete"];
        
        // Check permissions before starting HID manager
        NSError *permissionError = [self checkPermissions];
        if (permissionError) {
            [self showPermissionError:permissionError];
            return;
        }
        
        // Start the application after a brief delay to ensure run loop is ready
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self start];
        });
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in applicationDidFinishLaunching: %@", exception]];
        [NSApp terminate:nil];
    }
}

- (NSError *)checkPermissions {
    // Check accessibility permissions
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    
    if (!accessibilityEnabled) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Accessibility permissions not granted. Please grant permission in System Settings > Privacy & Security > Accessibility"}];
    }
    
    // Check input monitoring permissions by attempting to create and open a test manager
    IOHIDManagerRef testManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!testManager) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create test HID manager"}];
    }
    
    IOReturn result = IOHIDManagerOpen(testManager, kIOHIDOptionsTypeNone);
    CFRelease(testManager);
    
    if (result == kIOReturnNotPermitted) {
        return [NSError errorWithDomain:TPHIDManagerErrorDomain
                                 code:TPHIDManagerErrorPermissionDenied
                             userInfo:@{NSLocalizedDescriptionKey: @"Input monitoring permissions not granted. Please grant permission in System Settings > Privacy & Security > Input Monitoring"}];
    }
    
    return nil;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (!self.waitingForPermissions && !self.showingPermissionAlert) {
        [[TPLogger sharedLogger] logMessage:@"Application will terminate"];
        [self cleanup];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;  // Keep running even when all windows are closed
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (!self.shouldKeepRunning) {
        return NSTerminateNow;
    }
    
    if (self.waitingForPermissions || self.showingPermissionAlert || self.permissionAlert != nil) {
        return NSTerminateCancel;
    }
    
    return NSTerminateNow;
}

#pragma mark - Public Methods

- (void)start {
    if (!_isInitialized) {
        [[TPLogger sharedLogger] logMessage:@"TPApplication not properly initialized"];
        [NSApp terminate:nil];
        return;
    }
    
    @try {
        [[TPLogger sharedLogger] logMessage:@"Starting application..."];
        
        // Initialize managers
        self.hidManager = [TPHIDManager sharedManager];
        if (!self.hidManager) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create HID manager"];
            [NSApp terminate:nil];
            return;
        }
        self.hidManager.delegate = self;
        
        self.buttonManager = [TPButtonManager sharedManager];
        if (!self.buttonManager) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create button manager"];
            [NSApp terminate:nil];
            return;
        }
        self.buttonManager.delegate = self;
        
        // Configure HID device matching
        [self.hidManager addDeviceMatching:kUsagePageGenericDesktop usage:kUsageMouse];
        [self.hidManager addDeviceMatching:kUsagePageGenericDesktop usage:kUsagePointer];
        
        // Add multiple vendor IDs for broader device support
        [self.hidManager addVendorMatching:kVendorIDLenovo];  // Lenovo
        [self.hidManager addVendorMatching:0x04B3];  // IBM
        [self.hidManager addVendorMatching:0x0451];  // Texas Instruments (some trackpoint controllers)
        [self.hidManager addVendorMatching:0x046D];  // Logitech (some external keyboards with trackpoint)
        
        // Start HID monitoring
        if (![self.hidManager start]) {
            if (!self.waitingForPermissions && !self.showingPermissionAlert) {
                [[TPLogger sharedLogger] logMessage:@"Failed to start HID manager"];
                [NSApp terminate:nil];
            }
            return;
        }
        
        // Initialize event viewer only if in debug mode
        if ([TPConfig sharedConfig].debugMode) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupEventViewer];
                [self showEventViewer];
            });
        }
        
        [[TPLogger sharedLogger] logMessage:@"TPMiddle application started successfully"];
        [[TPLogger sharedLogger] logMessage:[self applicationStatus]];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in start: %@", exception]];
        if (!self.waitingForPermissions && !self.showingPermissionAlert) {
            [NSApp terminate:nil];
        }
    }
}

#pragma mark - Event Viewer

- (void)setupEventViewer {
    @try {
        if (self.eventWindow && self.eventViewController) {
            return;  // Already set up
        }
        
        [[TPLogger sharedLogger] logMessage:@"Setting up event viewer..."];
        
        // Create window
        self.eventWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 400)
                                                      styleMask:NSWindowStyleMaskTitled |
                                                               NSWindowStyleMaskClosable |
                                                               NSWindowStyleMaskMiniaturizable
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
        if (!self.eventWindow) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create event window"];
            return;
        }
        
        self.eventWindow.title = @"TrackPoint Events";
        self.eventWindow.releasedWhenClosed = NO;
        
        // Create and setup view controller
        NSBundle *mainBundle = [NSBundle mainBundle];
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Main bundle path: %@", mainBundle.bundlePath]];
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Resources path: %@", [mainBundle resourcePath]]];
        
        // Initialize view controller with nib
        self.eventViewController = [[TPEventViewController alloc] initWithNibName:@"TPEventViewController" bundle:mainBundle];
        if (!self.eventViewController.view) {
            [[TPLogger sharedLogger] logMessage:@"Failed to load view from nib, trying absolute path"];
            NSString *nibPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TPEventViewController"];
            self.eventViewController = [[TPEventViewController alloc] initWithNibName:nibPath bundle:mainBundle];
        }
        
        if (!self.eventViewController || !self.eventViewController.view) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create TPEventViewController"];
            return;
        }
        
        [[TPLogger sharedLogger] logMessage:@"Successfully created TPEventViewController"];
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"View outlets - movementView: %@, deltaLabel: %@, scrollLabel: %@",
                                           self.eventViewController.movementView,
                                           self.eventViewController.deltaLabel,
                                           self.eventViewController.scrollLabel]];
        
        // Set window's content view controller
        self.eventWindow.contentViewController = self.eventViewController;
        
        // Center window on screen
        [self.eventWindow center];
        
        // Handle window close button
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(windowWillClose:)
                                                   name:NSWindowWillCloseNotification
                                                 object:self.eventWindow];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in setupEventViewer: %@", exception]];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.eventWindow) {
        [self.eventViewController stopMonitoring];
        [self.statusBarController updateEventViewerState:NO];
    }
}

- (void)showEventViewer {
    @try {
        if (!self.eventWindow || !self.eventViewController) {
            [self setupEventViewer];
        }
        
        if (self.eventViewController) {
            [self.eventViewController startMonitoring];
        }
        
        if (self.eventWindow) {
            [self.eventWindow makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];
        }
        
        [self.statusBarController updateEventViewerState:YES];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in showEventViewer: %@", exception]];
    }
}

- (void)hideEventViewer {
    @try {
        if (self.eventViewController) {
            [self.eventViewController stopMonitoring];
        }
        
        if (self.eventWindow) {
            [self.eventWindow orderOut:nil];
        }
        
        [self.statusBarController updateEventViewerState:NO];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in hideEventViewer: %@", exception]];
    }
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Device attached:\n%@", deviceInfo]];
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Device detached:\n%@", deviceInfo]];
    [self.buttonManager reset];
}

- (void)didEncounterError:(NSError *)error {
    if ([error.domain isEqualToString:TPHIDManagerErrorDomain]) {
        if (error.code == TPHIDManagerErrorPermissionDenied) {
            [self showPermissionError:error];
        } else {
            [self showError:error];
        }
    } else {
        [self showError:error];
    }
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    @try {
        // Forward to button manager first
        [self.buttonManager updateButtonStates:leftButton right:rightButton middle:middleButton];
        
        // Then post notification on main thread
        if ([NSThread isMainThread]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kTPButtonNotification
                                                              object:nil
                                                            userInfo:@{
                @"left": @(leftButton),
                @"right": @(rightButton),
                @"middle": @(middleButton)
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kTPButtonNotification
                                                                  object:nil
                                                                userInfo:@{
                    @"left": @(leftButton),
                    @"right": @(rightButton),
                    @"middle": @(middleButton)
                }];
            });
        }
        
        if ([TPConfig sharedConfig].debugMode) {
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Button press - left: %d, right: %d, middle: %d",
                                               leftButton, rightButton, middleButton]];
        }
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in didReceiveButtonPress: %@", exception]];
    }
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    @try {
        // Forward movement data to button manager first
        [self.buttonManager handleMovement:deltaX deltaY:deltaY withButtonState:buttons];
        
        // Then post notification on main thread
        if ([NSThread isMainThread]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kTPMovementNotification
                                                              object:nil
                                                            userInfo:@{
                @"deltaX": @(deltaX),
                @"deltaY": @(deltaY),
                @"buttons": @(buttons)
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kTPMovementNotification
                                                                  object:nil
                                                                userInfo:@{
                    @"deltaX": @(deltaX),
                    @"deltaY": @(deltaY),
                    @"buttons": @(buttons)
                }];
            });
        }
        
        if ([TPConfig sharedConfig].debugMode) {
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Movement - X: %d, Y: %d, Buttons: %02X",
                                               deltaX, deltaY, buttons]];
        }
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in didReceiveMovement: %@", exception]];
    }
}

#pragma mark - TPButtonManagerDelegate

- (void)middleButtonStateChanged:(BOOL)isPressed {
    if ([TPConfig sharedConfig].debugMode) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Middle button %@", isPressed ? @"pressed" : @"released"]];
    }
}

#pragma mark - TPStatusBarControllerDelegate

- (void)statusBarControllerWillQuit {
    @try {
        [[TPLogger sharedLogger] logMessage:@"Status bar controller will quit"];
        // Clean up before quitting
        self.shouldKeepRunning = NO;
        [self cleanup];
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in statusBarControllerWillQuit: %@", exception]];
    }
}

- (void)statusBarControllerDidToggleEventViewer:(BOOL)show {
    @try {
        if (show) {
            [self showEventViewer];
        } else {
            [self hideEventViewer];
        }
    } @catch (NSException *exception) {
        [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in statusBarControllerDidToggleEventViewer: %@", exception]];
    }
}

@end
