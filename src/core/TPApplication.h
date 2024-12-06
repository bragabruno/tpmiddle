#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../infrastructure/devices/TPHIDManager.h"
#import "../infrastructure/devices/TPButtonManager.h"
#import "../presentation/TPStatusBarController.h"
#import "../common/TPConstants.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

+ (instancetype)sharedApplication;
- (void)start;

@end

@interface TPApplication (Methods)
@end

#endif // __OBJC__
