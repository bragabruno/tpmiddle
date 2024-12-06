#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "TPConfig.h"

@protocol TPStatusBarControllerDelegate <NSObject>
@optional
- (void)statusBarControllerWillQuit;
- (void)statusBarControllerDidToggleEventViewer:(BOOL)show;
@end

@interface TPStatusBarController : NSObject

@property (weak, nonatomic) id<TPStatusBarControllerDelegate> delegate;

+ (instancetype)sharedController;

// UI Updates
- (void)updateModeDisplay;
- (void)updateDebugState;
- (void)updateScrollSettings;
- (void)updateEventViewerState:(BOOL)isVisible;

// Menu Actions
- (void)setMode:(TPOperationMode)mode;
- (void)toggleDebugMode:(id)sender;
- (void)toggleNaturalScrolling:(id)sender;
- (void)toggleHorizontalScroll:(id)sender;
- (void)toggleVerticalScroll:(id)sender;
- (void)setScrollSpeed:(id)sender;
- (void)setAcceleration:(id)sender;
- (void)toggleEventViewer:(id)sender;

@end
