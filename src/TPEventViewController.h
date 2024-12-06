#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "infrastructure/hid/TPHIDManager.h"

@interface TPEventViewController : NSViewController <TPHIDManagerDelegate>

@property (weak) IBOutlet NSView *movementView;
@property (weak) IBOutlet NSTextField *deltaLabel;
@property (weak) IBOutlet NSTextField *scrollLabel;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

#endif
