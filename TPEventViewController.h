#import <Cocoa/Cocoa.h>
#import "TPButtonManager.h"
#import "TPHIDManager.h"

@interface TPEventViewController : NSViewController <TPButtonManagerDelegate, TPHIDManagerDelegate>

@property (weak) IBOutlet NSView *movementView;
@property (weak) IBOutlet NSTextField *deltaLabel;
@property (weak) IBOutlet NSButton *leftButton;
@property (weak) IBOutlet NSButton *middleButton;
@property (weak) IBOutlet NSButton *rightButton;
@property (weak) IBOutlet NSTextField *scrollLabel;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
