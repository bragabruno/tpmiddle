#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "infrastructure/hid/TPHIDManager.h"

@interface TPEventViewController : NSViewController <TPHIDManagerDelegate>

@property (strong) IBOutlet NSView *movementView;
@property (strong) IBOutlet NSTextField *deltaLabel;
@property (strong) IBOutlet NSTextField *scrollLabel;
@property (strong) IBOutlet NSButton *leftButton;
@property (strong) IBOutlet NSButton *middleButton;
@property (strong) IBOutlet NSButton *rightButton;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

#endif
