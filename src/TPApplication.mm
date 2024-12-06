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
        
        // Start logging immediately
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
}

- (void)hideEventViewer {
    if (self.eventWindow) {
        [self.eventWindow orderOut:nil];
    }
}

- (void)setupEventViewer {
    if (!self.eventViewController) {
        self.eventViewController = [[TPEventViewController alloc] init];
    }
    
    if (!self.eventWindow) {
        self.eventWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
                                                     styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
        [self.eventWindow setContentViewController:self.eventViewController];
        [self.eventWindow setTitle:@"Event Viewer"];
        [self.eventWindow center];
    }
}

- (void)showEventViewer {
    if (self.eventWindow) {
        [self.eventWindow makeKeyAndOrderFront:nil];
    }
}

- (NSString *)applicationStatus {
    return [NSString stringWithFormat:@"TPMiddle Status:\nInitialized: %@\nDebug Mode: %@\nHID Manager: %@",
            _isInitialized ? @"Yes" : @"No",
            [TPConfig sharedConfig].debugMode ? @"Enabled" : @"Disabled",
            self.hidManager ? @"Running" : @"Stopped"];
}

- (void)cleanup {
    if (self.permissionManager.waitingForPermissions || self.permissionManager.showingPermissionAlert) {
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
        
        // Start the application after a brief delay to ensure run loop is ready
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    if (!_isInitialized) {
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
            if (!self.permissionManager.waitingForPermissions && !self.permissionManager.showingPermissionAlert) {
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
        [self.errorHandler logException:exception];
        if (!self.permissionManager.waitingForPermissions && !self.permissionManager.showingPermissionAlert) {
            [NSApp terminate:nil];
        }
    }
}

@end
