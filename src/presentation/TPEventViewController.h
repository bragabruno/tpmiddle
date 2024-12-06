#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "../infrastructure/devices/TPButtonManager.h"
#import "../infrastructure/devices/TPHIDManager.h"

@interface TPEventViewController : NSViewController

@property (weak) IBOutlet NSView *movementView;
@property (weak) IBOutlet NSTextField *deltaLabel;
@property (weak) IBOutlet NSButton *leftButton;
@property (weak) IBOutlet NSButton *middleButton;
@property (weak) IBOutlet NSButton *rightButton;
@property (weak) IBOutlet NSTextField *scrollLabel;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

#endif // __OBJC__
