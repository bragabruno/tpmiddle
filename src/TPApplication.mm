#import "TPApplication.h"
#import "TPConfig.h"
#import "TPEventViewController.h"
#import "TPConstants.h"
#import "TPLogger.h"
#import "infrastructure/permissions/TPPermissionManager.h"
#import "infrastructure/error/TPErrorHandler.h"
#import "infrastructure/status/TPStatusReporter.h"
#import <IOKit/hid/IOHIDManager.h>
#import <ApplicationServices/ApplicationServices.h>

@interface TPApplication () {
    BOOL _isInitialized;
    NSLock *_stateLock;
    dispatch_queue_t _setupQueue;
}

@property (strong) TPHIDManager *hidManager;
@property (strong) TPButtonManager *buttonManager;
@property (strong) TPStatusBarController *statusBarController;
@property (strong) NSWindow *eventWindow;
@property (strong) TPEventViewController *eventViewController;
@property (strong) TPPermissionManager *permissionManager;
@property (strong) TPErrorHandler *errorHandler;
@property (strong) TPStatusReporter *statusReporter;

- (void)hideEventViewer;
- (void)setupEventViewer;
- (void)showEventViewer;

@end

@implementation TPApplication

@synthesize shouldKeepRunning = _shouldKeepRunning;
@synthesize waitingForPermissions = _waitingForPermissions;
@synthesize showingPermissionAlert = _showingPermissionAlert;

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
        _shouldKeepRunning = YES;
        _waitingForPermissions = NO;
        _showingPermissionAlert = NO;
        _stateLock = [[NSLock alloc] init];
        _setupQueue = dispatch_queue_create("com.tpmiddle.application.setup", DISPATCH_QUEUE_SERIAL);
        
        // Start logging immediately
        [[TPLogger sharedLogger] startLogging];
        [[TPLogger sharedLogger] logMessage:@"TPApplication initializing..."];
        
        // Initialize managers
        self.permissionManager = [TPPermissionManager sharedManager];
        self.errorHandler = [TPErrorHandler sharedHandler];
        self.statusReporter = [TPStatusReporter sharedReporter];
        
        [self.statusReporter logSystemInfo];
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
    _stateLock = nil;
    _setupQueue = NULL;
}

- (void)hideEventViewer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventWindow) {
            [self.eventWindow orderOut:nil];
        }
    });
}

- (void)setupEventViewer {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.eventViewController) {
                // Load view controller from NIB
                NSBundle *mainBundle = [NSBundle mainBundle];
                NSString *nibPath = [mainBundle pathForResource:@"TPEventViewController" ofType:@"nib"];
                if (!nibPath) {
                    [[TPLogger sharedLogger] logMessage:@"Failed to find TPEventViewController.nib"];
                    return;
                }
                
                TPEventViewController *viewController = [[TPEventViewController alloc] initWithNibName:@"TPEventViewController" bundle:mainBundle];
                if (!viewController) {
                    [[TPLogger sharedLogger] logMessage:@"Failed to initialize TPEventViewController from nib"];
                    return;
                }
                
                // Load the view to ensure outlets are connected
                [viewController loadView];
                [viewController startMonitoring];
                self.eventViewController = viewController;
                [[TPLogger sharedLogger] logMessage:@"TPEventViewController loaded from nib"];
            }
            
            if (!self.eventWindow) {
                NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
                                                             styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO];
                [window setContentViewController:self.eventViewController];
                [window setTitle:@"Event Viewer"];
                [window center];
                self.eventWindow = window;
            }
        } @catch (NSException *exception) {
            [self.errorHandler logException:exception];
        }
    });
}

- (void)showEventViewer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventWindow) {
            [self.eventWindow makeKeyAndOrderFront:nil];
        }
    });
}

- (NSString *)applicationStatus {
    [_stateLock lock];
    NSString *status = [NSString stringWithFormat:@"TPMiddle Status:\nInitialized: %@\nDebug Mode: %@\nHID Manager: %@",
                       _isInitialized ? @"Yes" : @"No",
                       [TPConfig sharedConfig].debugMode ? @"Enabled" : @"Disabled",
                       self.hidManager ? @"Running" : @"Stopped"];
    [_stateLock unlock];
    return status;
}

- (void)cleanup {
    if (self.permissionManager.waitingForPermissions || self.permissionManager.showingPermissionAlert) {
        return;
    }
    
    @try {
        [[TPLogger sharedLogger] logMessage:@"TPApplication cleaning up..."];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.eventWindow) {
                [self hideEventViewer];
                self.eventWindow = nil;
            }
            
            if (self.eventViewController) {
                [self.eventViewController stopMonitoring];
                self.eventViewController = nil;
            }
        });
        
        [_stateLock lock];
        if (self.hidManager) {
            self.hidManager.delegate = nil;
            [self.hidManager stop];
            self.hidManager = nil;
        }
        
        if (self.buttonManager) {
            self.buttonManager.delegate = nil;
            [self.buttonManager reset];
            self.buttonManager = nil;
        }
        
        if (self.statusBarController) {
            self.statusBarController.delegate = nil;
            self.statusBarController = nil;
        }
        [_stateLock unlock];
        
        [[TPLogger sharedLogger] stopLogging];
    } @catch (NSException *exception) {
        [self.errorHandler logException:exception];
    }
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    @try {
        [[TPLogger sharedLogger] logMessage:@"Application did finish launching"];
        
        // Process command line arguments
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        [[TPConfig sharedConfig] applyCommandLineArguments:arguments];
        
        // Initialize status bar first
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusBarController = [TPStatusBarController sharedController];
            if (!self.statusBarController) {
                [[TPLogger sharedLogger] logMessage:@"Failed to create status bar controller"];
                [NSApp terminate:nil];
                return;
            }
            self.statusBarController.delegate = self;
            [self.statusBarController setupStatusBar];
            
            [self->_stateLock lock];
            self->_isInitialized = YES;
            [self->_stateLock unlock];
            
            [[TPLogger sharedLogger] logMessage:@"Application initialization complete"];
            
            // Check permissions before starting HID manager
            NSError *permissionError = [self.permissionManager checkPermissions];
            if (permissionError) {
                [self.permissionManager showPermissionError:permissionError withCompletion:^(BOOL shouldRetry) {
                    if (shouldRetry) {
                        [self start];
                    } else {
                        self.shouldKeepRunning = NO;
                        [NSApp terminate:nil];
                    }
                }];
                return;
            }
            
            // Start the application
            [self start];
        });
    } @catch (NSException *exception) {
        [self.errorHandler logException:exception];
        [NSApp terminate:nil];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (!self.permissionManager.waitingForPermissions && !self.permissionManager.showingPermissionAlert) {
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
    
    if (self.permissionManager.waitingForPermissions || self.permissionManager.showingPermissionAlert) {
        return NSTerminateCancel;
    }
    
    return NSTerminateNow;
}

#pragma mark - Public Methods

- (void)start {
    [_stateLock lock];
    BOOL initialized = _isInitialized;
    [_stateLock unlock];
    
    if (!initialized) {
        [[TPLogger sharedLogger] logMessage:@"TPApplication not properly initialized"];
        [NSApp terminate:nil];
        return;
    }
    
    @try {
        [[TPLogger sharedLogger] logMessage:@"Starting application..."];
        
        // Check permissions first
        NSError *permissionError = [self.permissionManager checkPermissions];
        if (permissionError) {
            [self.permissionManager showPermissionError:permissionError withCompletion:^(BOOL shouldRetry) {
                if (shouldRetry) {
                    [self start];
                } else {
                    self.shouldKeepRunning = NO;
                    [NSApp terminate:nil];
                }
            }];
            return;
        }
        
        [_stateLock lock];
        // Initialize managers
        self.hidManager = [TPHIDManager sharedManager];
        if (!self.hidManager) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create HID manager"];
            [_stateLock unlock];
            [NSApp terminate:nil];
            return;
        }
        self.hidManager.delegate = self;
        
        self.buttonManager = [TPButtonManager sharedManager];
        if (!self.buttonManager) {
            [[TPLogger sharedLogger] logMessage:@"Failed to create button manager"];
            [_stateLock unlock];
            [NSApp terminate:nil];
            return;
        }
        self.buttonManager.delegate = self;
        [_stateLock unlock];
        
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
            if (!self.permissionManager.waitingForPermissions && !self.permissionManager.showingPermissionAlert) {
                [[TPLogger sharedLogger] logMessage:@"Failed to start HID manager"];
                [NSApp terminate:nil];
            }
            return;
        }
        
        // Initialize event viewer only if in debug mode
        if ([TPConfig sharedConfig].debugMode) {
            dispatch_async(_setupQueue, ^{
                [self setupEventViewer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showEventViewer];
                });
            });
        }
        
        [[TPLogger sharedLogger] logMessage:@"TPMiddle application started successfully"];
        [[TPLogger sharedLogger] logMessage:[self applicationStatus]];
    } @catch (NSException *exception) {
        [self.errorHandler logException:exception];
        if (!self.permissionManager.waitingForPermissions && !self.permissionManager.showingPermissionAlert) {
            [NSApp terminate:nil];
        }
    }
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Device attached: %@", deviceInfo]];
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Device detached: %@", deviceInfo]];
}

- (void)didEncounterError:(NSError *)error {
    [self.errorHandler showError:error];
    [self.errorHandler logError:error];
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    [self.buttonManager updateButtonStates:leftButton right:rightButton middle:middleButton];
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    [self.buttonManager handleMovement:deltaX deltaY:deltaY withButtonState:buttons];
}

#pragma mark - TPButtonManagerDelegate

- (void)middleButtonStateChanged:(BOOL)pressed {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventViewController) {
            [self.eventViewController startMonitoring];
        }
    });
}

#pragma mark - TPStatusBarControllerDelegate

- (void)statusBarControllerDidToggleEventViewer:(BOOL)show {
    if (show) {
        dispatch_async(_setupQueue, ^{
            [self setupEventViewer];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showEventViewer];
            });
        });
    } else {
        [self hideEventViewer];
    }
    [self.statusBarController updateEventViewerState:show];
}

- (void)statusBarControllerWillQuit {
    self.shouldKeepRunning = NO;
}

@end
