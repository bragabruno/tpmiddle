#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "infrastructure/hid/TPHIDManager.h"
#import "TPButtonManager.h"
#import "TPStatusBarController.h"
#import "TPEventViewController.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

+ (instancetype)sharedApplication;
- (void)start;
- (void)cleanup;
- (NSString *)applicationStatus;

@end

#endif
