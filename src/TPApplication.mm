#import "TPApplication.h"
#import "TPConfig.h"
#import "TPEventViewController.h"

#ifdef DEBUG
#define DebugLog(format, ...) NSLog(@"%s: " format, __FUNCTION__, ##__VA_ARGS__)
#else
#define DebugLog(format, ...)
#endif

@interface TPApplication ()

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
        // Process command line arguments
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        [[TPConfig sharedConfig] applyCommandLineArguments:arguments];
        
        // Initialize components
        self.hidManager = [TPHIDManager sharedManager];
        self.buttonManager = [TPButtonManager sharedManager];
        self.statusBarController = [TPStatusBarController sharedController];
        
        // Set up delegates
        self.hidManager.delegate = self;
        self.buttonManager.delegate = self;
        self.statusBarController.delegate = self;
        
        // Create event viewer window
        [self setupEventViewer];
    }
    return self;
}

- (void)setupEventViewer {
    // Create window
    self.eventWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 400)
                                                  styleMask:NSWindowStyleMaskTitled |
                                                           NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    self.eventWindow.title = @"TrackPoint Events";
    self.eventWindow.releasedWhenClosed = NO;
    
    // Create and setup view controller
    self.eventViewController = [[TPEventViewController alloc] initWithNibName:@"TPEventViewController" bundle:nil];
    self.eventWindow.contentViewController = self.eventViewController;
    
    // Center window on screen
    [self.eventWindow center];
    
    // Handle window close button
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(windowWillClose:)
                                               name:NSWindowWillCloseNotification
                                             object:self.eventWindow];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.eventWindow) {
        [self.eventViewController stopMonitoring];
        [self.statusBarController updateEventViewerState:NO];
    }
}

- (void)showEventViewer {
    [self.eventViewController startMonitoring];
    [self.eventWindow makeKeyAndOrderFront:nil];
    [self.statusBarController updateEventViewerState:YES];
}

- (void)hideEventViewer {
    [self.eventViewController stopMonitoring];
    [self.eventWindow orderOut:nil];
    [self.statusBarController updateEventViewerState:NO];
}

#pragma mark - Public Methods

- (void)start {
    // Configure HID device matching
    [self.hidManager addDeviceMatching:kUsagePageGenericDesktop usage:kUsageMouse];
    [self.hidManager addDeviceMatching:kUsagePageGenericDesktop usage:kUsagePointer];
    [self.hidManager addVendorMatching:kVendorIDLenovo];
    
    // Start HID monitoring
    if (![self.hidManager start]) {
        DebugLog(@"Failed to start HID manager");
        [NSApp terminate:nil];
        return;
    }
    
    // Show event viewer in debug mode
    if ([TPConfig sharedConfig].debugMode) {
        [self showEventViewer];
    }
    
    DebugLog(@"TPMiddle application started successfully");
}

#pragma mark - TPHIDManagerDelegate

- (void)didDetectDeviceAttached:(NSString *)deviceInfo {
    DebugLog(@"Device attached:\n%@", deviceInfo);
}

- (void)didDetectDeviceDetached:(NSString *)deviceInfo {
    DebugLog(@"Device detached:\n%@", deviceInfo);
    [self.buttonManager reset];
}

- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton {
    // Post notification for EventViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TPButtonNotification"
                                                      object:nil
                                                    userInfo:@{
        @"left": @(leftButton),
        @"right": @(rightButton),
        @"middle": @(middleButton)
    }];
    
    // Forward to button manager
    [self.buttonManager updateButtonStates:leftButton right:rightButton middle:middleButton];
}

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    // Post notification for EventViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TPMovementNotification"
                                                      object:nil
                                                    userInfo:@{
        @"deltaX": @(deltaX),
        @"deltaY": @(deltaY),
        @"buttons": @(buttons)
    }];
    
    // Forward movement data to button manager for scroll processing
    [self.buttonManager handleMovement:deltaX deltaY:deltaY withButtonState:buttons];
    
    if ([TPConfig sharedConfig].debugMode) {
        DebugLog(@"Movement - X: %d, Y: %d, Buttons: %02X", deltaX, deltaY, buttons);
    }
}

#pragma mark - TPButtonManagerDelegate

- (void)middleButtonStateChanged:(BOOL)isPressed {
    if ([TPConfig sharedConfig].debugMode) {
        DebugLog(@"Middle button %@", isPressed ? @"pressed" : @"released");
    }
}

#pragma mark - TPStatusBarControllerDelegate

- (void)statusBarControllerWillQuit {
    // Clean up before quitting
    [self.hidManager stop];
    [self.buttonManager reset];
}

- (void)statusBarControllerDidToggleEventViewer:(BOOL)show {
    if (show) {
        [self showEventViewer];
    } else {
        [self hideEventViewer];
    }
}

@end
