#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "infrastructure/hid/TPHIDManager.h"
#import "TPButtonManager.h"
#import "TPStatusBarController.h"
#import "TPEventViewController.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

@property (atomic, assign) BOOL waitingForPermissions;
@property (atomic, assign) BOOL showingPermissionAlert;
@property (atomic, assign) BOOL shouldKeepRunning;

// Singleton access
+ (instancetype)sharedApplication;

// Application lifecycle
- (void)start;
- (void)cleanup;
- (NSString *)applicationStatus;

// Required delegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender;

// TPHIDManagerDelegate methods
- (void)didDetectDeviceAttached:(NSString *)deviceInfo;
- (void)didDetectDeviceDetached:(NSString *)deviceInfo;
- (void)didEncounterError:(NSError *)error;
- (void)didReceiveButtonPress:(BOOL)leftButton right:(BOOL)rightButton middle:(BOOL)middleButton;
- (void)didReceiveMovement:(int)deltaX deltaY:(int)deltaY withButtonState:(uint8_t)buttons;

// TPButtonManagerDelegate methods
- (void)middleButtonStateChanged:(BOOL)pressed;

// TPStatusBarControllerDelegate methods
- (void)statusBarControllerDidToggleEventViewer:(BOOL)show;
- (void)statusBarControllerWillQuit;

@end

#endif
