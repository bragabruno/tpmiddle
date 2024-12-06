#include "TPApplication.h"
#include "TPConfig.h"
#include "TPEventViewController.h"
#include "TPConstants.h"

@interface TPApplication () {
    BOOL _isInitialized;
}

@property (strong) TPHIDManager *hidManager;
@property (strong) TPButtonManager *buttonManager;
@property (strong) TPStatusBarController *statusBarController;
@property (strong) NSWindow *eventWindow;
@property (strong) TPEventViewController *eventViewController;

@end

@implementation TPApplication

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
        
        @try {
            // Process command line arguments
            NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
            [[TPConfig sharedConfig] applyCommandLineArguments:arguments];
            
            // Initialize status bar first
            self.statusBarController = [TPStatusBarController sharedController];
            if (!self.statusBarController) {
                NSLog(@"Failed to create status bar controller");
                return nil;
            }
            self.statusBarController.delegate = self;
            
            // Initialize HID and button managers
            self.hidManager = [TPHIDManager sharedManager];
            if (!self.hidManager) {
                NSLog(@"Failed to create HID manager");
                return nil;
            }
            self.hidManager.delegate = self;
            
            self.buttonManager = [TPButtonManager sharedManager];
            if (!self.buttonManager) {
                NSLog(@"Failed to create button manager");
                return nil;
            }
            self.buttonManager.delegate = self;
            
            _isInitialized = YES;
        } @catch (NSException *exception) {
            NSLog(@"Exception in TPApplication init: %@", exception);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup {
    @try {
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
    } @catch (NSException *exception) {
        NSLog(@"Exception in cleanup: %@", exception);
    }
}

#pragma mark - Public Methods

- (void)start {
    if (!_isInitialized) {
        NSLog(@"TPApplication not properly initialized");
        [NSApp terminate:nil];
        return;
    }
    
    @try {
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
            NSLog(@"Failed to start HID manager");
            [NSApp terminate:nil];
            return;
        }
        
        // Initialize event viewer only if in debug mode
        if ([TPConfig sharedConfig].debugMode) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupEventViewer];
                [self showEventViewer];
            });
        }
        
        NSLog(@"TPMiddle application started successfully");
    } @catch (NSException *exception) {
        NSLog(@"Exception in start: %@", exception);
        [NSApp terminate:nil];
    }
}

#pragma mark - Event Viewer

- (void)setupEventViewer {
    @try {
        if (self.eventWindow && self.eventViewController) {
            return;  // Already set up
        }
        
        // Create window
        self.eventWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 400)
                                                      styleMask:NSWindowStyleMaskTitled |
                                                               NSWindowStyleMaskClosable |
                                                               NSWindowStyleMaskMiniaturizable
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
        if (!self.eventWindow) {
            NSLog(@"Failed to create event window");
            return;
        }
        
        self.eventWindow.title = @"TrackPoint Events";
        self.eventWindow.releasedWhenClosed = NO;
        
        // Create and setup view controller
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSLog(@"Main bundle path: %@", mainBundle.bundlePath);
        NSLog(@"Resources path: %@", [mainBundle resourcePath]);
        
        // Initialize view controller with nib
        self.eventViewController = [[TPEventViewController alloc] initWithNibName:@"TPEventViewController" bundle:mainBundle];
        if (!self.eventViewController.view) {
            NSLog(@"Failed to load view from nib, trying absolute path");
            NSString *nibPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TPEventViewController"];
            self.eventViewController = [[TPEventViewController alloc] initWithNibName:nibPath bundle:mainBundle];
        }
        
        if (!self.eventViewController || !self.eventViewController.view) {
            NSLog(@"Failed to create TPEventViewController");
            return;
        }
        
        NSLog(@"Successfully created TPEventViewController");
        NSLog(@"View outlets - movementView: %@, deltaLabel: %@, scrollLabel: %@",
              self.eventViewController.movementView,
              self.eventViewController.deltaLabel,
              self.eventViewController.scrollLabel);
        
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
        NSLog(@"Exception in setupEventViewer: %@", exception);
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
        NSLog(@"Exception in showEventViewer: %@", exception);
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
        NSLog(@"Exception in hideEventViewer: %@", exception);
    }
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    NSLog(@"Device attached:\n%@", deviceInfo);
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    NSLog(@"Device detached:\n%@", deviceInfo);
    [self.buttonManager reset];
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
            NSLog(@"Button press - left: %d, right: %d, middle: %d", leftButton, rightButton, middleButton);
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in didReceiveButtonPress: %@", exception);
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
            NSLog(@"Movement - X: %d, Y: %d, Buttons: %02X", deltaX, deltaY, buttons);
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in didReceiveMovement: %@", exception);
    }
}

#pragma mark - TPButtonManagerDelegate

- (void)middleButtonStateChanged:(BOOL)isPressed {
    if ([TPConfig sharedConfig].debugMode) {
        NSLog(@"Middle button %@", isPressed ? @"pressed" : @"released");
    }
}

#pragma mark - TPStatusBarControllerDelegate

- (void)statusBarControllerWillQuit {
    @try {
        // Clean up before quitting
        [self cleanup];
    } @catch (NSException *exception) {
        NSLog(@"Exception in statusBarControllerWillQuit: %@", exception);
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
        NSLog(@"Exception in statusBarControllerDidToggleEventViewer: %@", exception);
    }
}

@end
