#include "TPEventViewController.h"
#include "../core/TPConfig.h"
#include "../core/TPApplication.h"
#include "../common/TPConstants.h"

@interface TPEventViewController () {
    NSView *_centerIndicator;
    NSPoint _lastPoint;
    CGFloat _accumulatedScrollX;
    CGFloat _accumulatedScrollY;
    BOOL _isMonitoring;
    __weak TPHIDManager *_hidManager;  // Weak reference to HID manager
}
@end

@implementation TPEventViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    NSLog(@"TPEventViewController initWithNibName:%@ bundle:%@", nibNameOrNil, nibBundleOrNil);
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        NSLog(@"TPEventViewController initialized with nib");
        _isMonitoring = NO;
        _hidManager = [TPHIDManager sharedManager];  // Store weak reference
        [self registerForNotifications];
    }
    return self;
}

- (void)registerForNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Unregister first to prevent duplicates
    [center removeObserver:self];
    
    // Register for movement notifications
    [center addObserver:self
               selector:@selector(handleMovementNotification:)
                   name:kTPMovementNotification
                 object:nil];
    
    // Register for button notifications
    [center addObserver:self
               selector:@selector(handleButtonNotification:)
                   name:kTPButtonNotification
                 object:nil];
                 
    NSLog(@"TPEventViewController registered for notifications: %@ and %@", 
          kTPMovementNotification, kTPButtonNotification);
}

- (void)dealloc {
    NSLog(@"TPEventViewController dealloc - removing notification observers");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    [super loadView];
    NSLog(@"TPEventViewController loadView called");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"TPEventViewController viewDidLoad");
    
    // Initialize UI
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    
    // Log outlet connections
    NSLog(@"Checking outlet connections:");
    NSLog(@"movementView: %@", self.movementView);
    NSLog(@"deltaLabel: %@", self.deltaLabel);
    NSLog(@"scrollLabel: %@", self.scrollLabel);
    NSLog(@"leftButton: %@", self.leftButton);
    NSLog(@"middleButton: %@", self.middleButton);
    NSLog(@"rightButton: %@", self.rightButton);
    
    if (!self.movementView) {
        NSLog(@"Error: movementView outlet not connected!");
        return;
    }
    
    // Setup movement view
    self.movementView.wantsLayer = YES;
    self.movementView.layer.backgroundColor = [NSColor gridColor].CGColor;
    self.movementView.layer.cornerRadius = 4.0;
    
    // Create center point indicator
    _centerIndicator = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 8, 8)];
    _centerIndicator.wantsLayer = YES;
    _centerIndicator.layer.backgroundColor = [NSColor systemBlueColor].CGColor;
    _centerIndicator.layer.cornerRadius = 4.0;
    [self.movementView addSubview:_centerIndicator];
    
    // Center the indicator
    [self centerIndicator];
    
    // Initialize labels
    self.deltaLabel.stringValue = @"X: 0, Y: 0";
    self.scrollLabel.stringValue = @"Scroll: 0, 0";
    
    // Setup buttons
    self.leftButton.state = NSControlStateValueOff;
    self.middleButton.state = NSControlStateValueOff;
    self.rightButton.state = NSControlStateValueOff;
    
    // Reset accumulated values
    _accumulatedScrollX = 0;
    _accumulatedScrollY = 0;
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [self centerIndicator];
}

- (void)centerIndicator {
    if (!self.movementView) return;
    
    NSRect bounds = self.movementView.bounds;
    _centerIndicator.frame = NSMakeRect(
        NSMidX(bounds) - 4,
        NSMidY(bounds) - 4,
        8, 8
    );
    _lastPoint = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
}

- (void)startMonitoring {
    if (_isMonitoring) return;
    
    NSLog(@"TPEventViewController startMonitoring");
    _isMonitoring = YES;
    
    // Reset the view
    [self centerIndicator];
    _accumulatedScrollX = 0;
    _accumulatedScrollY = 0;
    self.deltaLabel.stringValue = @"X: 0, Y: 0";
    self.scrollLabel.stringValue = @"Scroll: 0, 0";
    self.leftButton.state = NSControlStateValueOff;
    self.middleButton.state = NSControlStateValueOff;
    self.rightButton.state = NSControlStateValueOff;
}

- (void)stopMonitoring {
    if (!_isMonitoring) return;
    
    NSLog(@"TPEventViewController stopMonitoring");
    _isMonitoring = NO;
}

#pragma mark - Notification Handlers

- (void)handleMovementNotification:(NSNotification *)notification {
    if (!_isMonitoring) return;
    
    @try {
        NSDictionary *info = notification.userInfo;
        if (!info) return;
        
        int deltaX = [info[@"deltaX"] intValue];
        int deltaY = [info[@"deltaY"] intValue];
        uint8_t buttons = [info[@"buttons"] unsignedCharValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update delta label
            self.deltaLabel.stringValue = [NSString stringWithFormat:@"X: %d, Y: %d", deltaX, deltaY];
            
            // Move indicator
            if (self.movementView) {
                NSRect bounds = self.movementView.bounds;
                CGFloat baseScale = 1.0;
                
                // Calculate movement magnitude for diagonal scaling
                CGFloat magnitude = sqrt(deltaX * deltaX + deltaY * deltaY);
                CGFloat scaleFactor = baseScale * (1.0 + magnitude * 0.05);
                
                // Apply scaling uniformly to maintain direction
                CGFloat scaledDeltaX = deltaX * scaleFactor;
                CGFloat scaledDeltaY = deltaY * scaleFactor;
                
                // Get scroll configuration
                TPConfig *config = [TPConfig sharedConfig];
                
                // Apply inversion if configured
                if (config.invertScrollX) {
                    scaledDeltaX = -scaledDeltaX;
                }
                if (config.invertScrollY) {
                    scaledDeltaY = -scaledDeltaY;
                }
                
                // Calculate new position with unified scaling
                CGFloat newX = self->_lastPoint.x - scaledDeltaX;
                CGFloat newY = self->_lastPoint.y - scaledDeltaY;
                
                // Ensure the center of the indicator stays within bounds
                CGFloat minX = 4.0;
                CGFloat maxX = NSWidth(bounds) - 4.0;
                CGFloat minY = 4.0;
                CGFloat maxY = NSHeight(bounds) - 4.0;
                
                self->_lastPoint.x = fmin(maxX, fmax(minX, newX));
                self->_lastPoint.y = fmin(maxY, fmax(minY, newY));
                
                if (self->_centerIndicator) {
                    self->_centerIndicator.frame = NSMakeRect(
                        self->_lastPoint.x - 4,
                        self->_lastPoint.y - 4,
                        8, 8
                    );
                }
                
                // If middle button is pressed or in scroll mode, update scroll accumulation
                if ((buttons & 0x04) || (self->_hidManager && self->_hidManager.isScrollMode)) {
                    self->_accumulatedScrollX += deltaX;
                    self->_accumulatedScrollY += deltaY;
                    if (self.scrollLabel) {
                        self.scrollLabel.stringValue = [NSString stringWithFormat:@"Scroll: %.0f, %.0f",
                                                      self->_accumulatedScrollX, self->_accumulatedScrollY];
                    }
                }
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"Exception in handleMovementNotification: %@", exception);
    }
}

- (void)handleButtonNotification:(NSNotification *)notification {
    if (!_isMonitoring) return;
    
    @try {
        NSDictionary *info = notification.userInfo;
        if (!info) return;
        
        BOOL left = [info[@"left"] boolValue];
        BOOL right = [info[@"right"] boolValue];
        BOOL middle = [info[@"middle"] boolValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.leftButton) {
                self.leftButton.state = left ? NSControlStateValueOn : NSControlStateValueOff;
            }
            if (self.rightButton) {
                self.rightButton.state = right ? NSControlStateValueOn : NSControlStateValueOff;
            }
            if (self.middleButton) {
                self.middleButton.state = middle ? NSControlStateValueOn : NSControlStateValueOff;
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"Exception in handleButtonNotification: %@", exception);
    }
}

@end
