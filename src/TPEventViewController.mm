#import "TPEventViewController.h"
#import "infrastructure/hid/TPHIDManager.h"
#import "TPLogger.h"
#import <QuartzCore/QuartzCore.h>

@interface TPEventViewController () {
    TPHIDManager *_hidManager;
    NSTimer *_updateTimer;
    NSPoint _lastPoint;
    NSPoint _currentPoint;
    NSPoint _deltaPoint;
    uint8_t _buttonState;
    NSLock *_stateLock;
    dispatch_queue_t _updateQueue;
}

@property (nonatomic, strong) NSView *contentView;

@end

@implementation TPEventViewController

- (instancetype)init {
    [[TPLogger sharedLogger] logMessage:@"TPEventViewController init called"];
    return [self initWithNibName:@"TPEventViewController" bundle:[NSBundle mainBundle]];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    [[TPLogger sharedLogger] logMessage:@"TPEventViewController initWithNibName called"];
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _stateLock = [[NSLock alloc] init];
        _updateQueue = dispatch_queue_create("com.tpmiddle.viewController.update", DISPATCH_QUEUE_SERIAL);
        
        // Initialize HID manager
        _hidManager = [TPHIDManager sharedManager];
        if (_hidManager) {
            _hidManager.delegate = self;
        }
        
        // Initialize state
        CGRect bounds = CGRectMake(0, 0, 100, 100); // Default size
        CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        _lastPoint = NSMakePoint(center.x, center.y);
        _currentPoint = _lastPoint;
        _deltaPoint = NSZeroPoint;
        _buttonState = 0;
        
        [[TPLogger sharedLogger] logMessage:@"TPEventViewController initialized"];
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    _hidManager.delegate = nil;
    _hidManager = nil;
    _stateLock = nil;
    _updateQueue = NULL;
}

- (void)loadView {
    [[TPLogger sharedLogger] logMessage:@"TPEventViewController loadView called"];
    [super loadView];
    
    if (!self.movementView || !self.deltaLabel || !self.scrollLabel) {
        [[TPLogger sharedLogger] logMessage:@"Failed to load view outlets"];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Enable layer-backed view for movement visualization
        self.movementView.wantsLayer = YES;
        self.movementView.layer.backgroundColor = NSColor.clearColor.CGColor;
        
        // Initialize center point
        CGRect bounds = self.movementView.bounds;
        CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        [self->_stateLock lock];
        self->_lastPoint = NSMakePoint(center.x, center.y);
        self->_currentPoint = self->_lastPoint;
        [self->_stateLock unlock];
    });
    
    [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"View outlets - movementView: %@, deltaLabel: %@, scrollLabel: %@",
                                       self.movementView,
                                       self.deltaLabel,
                                       self.scrollLabel]];
}

- (void)viewDidLoad {
    [[TPLogger sharedLogger] logMessage:@"TPEventViewController viewDidLoad called"];
    [super viewDidLoad];
}

- (void)startMonitoring {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_updateTimer) {
            [self stopMonitoring];
        }
        
        self->_updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016  // ~60 FPS
                                                          repeats:YES
                                                            block:^(NSTimer * __unused timer) {
            [self updateView];
        }];
        
        [[TPLogger sharedLogger] logMessage:@"Started monitoring"];
    });
}

- (void)stopMonitoring {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_updateTimer) {
            [self->_updateTimer invalidate];
            self->_updateTimer = nil;
        }
        
        [[TPLogger sharedLogger] logMessage:@"Stopped monitoring"];
    });
}

- (void)updateView {
    if (!self.movementView) return;
    
    [_stateLock lock];
    NSPoint lastPoint = _lastPoint;
    NSPoint currentPoint = _currentPoint;
    NSPoint deltaPoint = _deltaPoint;
    uint8_t buttonState = _buttonState;
    [_stateLock unlock];
    
    // Update movement visualization
    if (!NSEqualPoints(lastPoint, currentPoint)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSRect bounds = self.movementView.bounds;
            NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
            
            // Scale the movement for visualization
            CGFloat scale = 2.0;
            NSPoint scaledDelta = NSMakePoint(deltaPoint.x * scale, deltaPoint.y * scale);
            
            // Calculate new point
            NSPoint newPoint = NSMakePoint(center.x + scaledDelta.x, center.y + scaledDelta.y);
            
            // Keep point within bounds
            newPoint.x = MAX(0, MIN(newPoint.x, bounds.size.width));
            newPoint.y = MAX(0, MIN(newPoint.y, bounds.size.height));
            
            // Draw movement
            @try {
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:lastPoint];
                [path lineToPoint:newPoint];
                
                // Create tracking layer if needed
                CAShapeLayer *trackingLayer = nil;
                if (self.movementView.layer.sublayers.count > 0) {
                    trackingLayer = self.movementView.layer.sublayers[0];
                } else {
                    trackingLayer = [CAShapeLayer layer];
                    [self.movementView.layer addSublayer:trackingLayer];
                }
                
                // Configure layer
                trackingLayer.strokeColor = NSColor.systemBlueColor.CGColor;
                trackingLayer.fillColor = nil;
                trackingLayer.lineWidth = 2.0;
                trackingLayer.path = path.CGPath;
                
                // Add fade out animation
                CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
                fadeOut.fromValue = @1.0;
                fadeOut.toValue = @0.0;
                fadeOut.duration = 0.5;
                fadeOut.removedOnCompletion = YES;
                
                [trackingLayer addAnimation:fadeOut forKey:@"fadeOut"];
                
                [self->_stateLock lock];
                self->_lastPoint = newPoint;
                [self->_stateLock unlock];
            } @catch (NSException *exception) {
                [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception in updateView: %@", exception]];
            }
        });
    }
    
    // Update labels
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Update delta label
            NSString *deltaText = [NSString stringWithFormat:@"Delta: (%.1f, %.1f)",
                                 deltaPoint.x, deltaPoint.y];
            if (buttonState > 0) {
                deltaText = [deltaText stringByAppendingFormat:@"\nButtons: %@%@%@",
                            (buttonState & 0x01) ? @"L" : @"-",
                            (buttonState & 0x02) ? @"R" : @"-",
                            (buttonState & 0x04) ? @"M" : @"-"];
            }
            self.deltaLabel.stringValue = deltaText;
            
            // Update scroll label if in scroll mode
            if ((buttonState & 0x04) || (self->_hidManager && self->_hidManager.isScrollMode)) {
                self.scrollLabel.stringValue = [NSString stringWithFormat:@"Scroll: (%.1f, %.1f)",
                                              deltaPoint.x, deltaPoint.y];
            }
        } @catch (NSException *exception) {
            [[TPLogger sharedLogger] logMessage:[NSString stringWithFormat:@"Exception updating labels: %@", exception]];
        }
    });
}

#pragma mark - TPHIDManagerDelegate

- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons {
    [_stateLock lock];
    _deltaPoint = NSMakePoint(deltaX, deltaY);
    _buttonState = buttons;
    [_stateLock unlock];
}

@end
