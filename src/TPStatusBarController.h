#pragma once

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "TPConfig.h"

@protocol TPStatusBarControllerDelegate <NSObject>
@optional
- (void)statusBarControllerWillQuit;
- (void)statusBarControllerDidToggleEventViewer:(BOOL)show;
@end

@interface TPStatusBarController : NSObject

@property (weak, nonatomic) id<TPStatusBarControllerDelegate> delegate;

+ (instancetype)sharedController;

// Setup
- (void)setupStatusBar;

// Update UI
- (void)updateModeDisplay;
- (void)updateDebugState;
- (void)updateEventViewerState:(BOOL)isVisible;

// Menu Actions
- (void)setDefaultMode:(id)sender;
- (void)setNormalMode:(id)sender;
- (void)toggleEventViewer:(id)sender;
- (void)toggleDebugMode:(id)sender;
- (void)quit:(id)sender;

@end

#endif // __OBJC__
