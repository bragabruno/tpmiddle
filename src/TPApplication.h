#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "infrastructure/hid/TPHIDManager.h"
#import "TPButtonManager.h"
#import "TPStatusBarController.h"
#import "TPEventViewController.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

@property (nonatomic, assign) BOOL waitingForPermissions;
@property (nonatomic, assign) BOOL showingPermissionAlert;
@property (nonatomic, assign) BOOL shouldKeepRunning;

+ (instancetype)sharedApplication;
- (void)start;
- (void)cleanup;
- (NSString *)applicationStatus;

// NSApplicationDelegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender;

@end

#endif
