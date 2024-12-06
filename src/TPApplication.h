#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "TPHIDManager.h"
#import "TPButtonManager.h"
#import "TPStatusBarController.h"
#import "TPConstants.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

+ (instancetype)sharedApplication;
- (void)start;

@end

@interface TPApplication (Methods)
@end

#endif // __OBJC__
