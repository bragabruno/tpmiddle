#import "TPEventViewController.h"
#import "TPConfig.h"
#import "TPApplication.h"

@interface TPEventViewController () {
    NSView *_centerIndicator;
    NSPoint _lastPoint;
    CGFloat _accumulatedScrollX;
    CGFloat _accumulatedScrollY;
}
@end

@implementation TPEventViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize UI
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    
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
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [self centerIndicator];
}

- (void)centerIndicator {
    NSRect bounds = self.movementView.bounds;
    _centerIndicator.frame = NSMakeRect(
        NSMidX(bounds) - 4,
        NSMidY(bounds) - 4,
        8, 8
    );
    _lastPoint = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
}

- (void)startMonitoring {
    // Register for notifications instead of setting delegates directly
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleMovementNotification:)
                                               name:@"TPMovementNotification"
                                             object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleButtonNotification:)
                                               name:@"TPButtonNotification"
                                             object:nil];
}

- (void)stopMonitoring {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self centerIndicator];
}

#pragma mark - Notification Handlers

- (void)handleMovementNotification:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    int deltaX = [info[@"deltaX"] intValue];
    int deltaY = [info[@"deltaY"] intValue];
    uint8_t buttons = [info[@"buttons"] unsignedCharValue];
    
    // Update delta label
    self.deltaLabel.stringValue = [NSString stringWithFormat:@"X: %d, Y: %d", deltaX, deltaY];
    
    // Move indicator
    NSRect bounds = self.movementView.bounds;
    CGFloat baseScale = 1.0; // Base scale factor
    
    // Calculate movement magnitude for diagonal scaling
    CGFloat magnitude = sqrt(deltaX * deltaX + deltaY * deltaY);
    CGFloat scaleFactor = baseScale * (1.0 + magnitude * 0.05); // Unified scaling based on total movement
    
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
    CGFloat newX = _lastPoint.x - scaledDeltaX;
    CGFloat newY = _lastPoint.y - scaledDeltaY;
    
    // Ensure the center of the indicator stays within bounds
    CGFloat minX = 4.0;
    CGFloat maxX = NSWidth(bounds) - 4.0;
    CGFloat minY = 4.0;
    CGFloat maxY = NSHeight(bounds) - 4.0;
    
    _lastPoint.x = fmin(maxX, fmax(minX, newX));
    _lastPoint.y = fmin(maxY, fmax(minY, newY));
    
    _centerIndicator.frame = NSMakeRect(
        _lastPoint.x - 4,
        _lastPoint.y - 4,
        8, 8
    );
    
    // If middle button is pressed, update scroll accumulation
    if (buttons & 0x04) { // Middle button mask
        _accumulatedScrollX += deltaX;
        _accumulatedScrollY += deltaY;
        self.scrollLabel.stringValue = [NSString stringWithFormat:@"Scroll: %.0f, %.0f",
                                      _accumulatedScrollX, _accumulatedScrollY];
    }
}

- (void)handleButtonNotification:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    BOOL left = [info[@"left"] boolValue];
    BOOL right = [info[@"right"] boolValue];
    BOOL middle = [info[@"middle"] boolValue];
    
    self.leftButton.state = left ? NSControlStateValueOn : NSControlStateValueOff;
    self.rightButton.state = right ? NSControlStateValueOn : NSControlStateValueOff;
    self.middleButton.state = middle ? NSControlStateValueOn : NSControlStateValueOff;
}

@end
