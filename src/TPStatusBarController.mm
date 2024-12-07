#include "TPStatusBarController.h"
#include "TPConfig.h"

@interface TPStatusBarController () {
    BOOL _eventViewerVisible;
    BOOL _isSetup;
}

@property (strong) NSStatusItem *statusItem;
@property (strong) NSMenu *statusMenu;

@end

@implementation TPStatusBarController

+ (instancetype)sharedController {
    static TPStatusBarController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[TPStatusBarController alloc] init];
    });
    return sharedController;
}

- (instancetype)init {
    if (self = [super init]) {
        _eventViewerVisible = NO;
        _isSetup = NO;
        _statusItem = nil;
        _statusMenu = nil;
    }
    return self;
}

- (void)setupStatusBar {
    if (_isSetup) return;
    
    NSLog(@"Setting up status bar...");
    
    @try {
        // Create status bar item
        NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
        _statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
        if (!_statusItem) {
            NSLog(@"Failed to create status item");
            return;
        }
        
        // Configure button
        NSButton *button = _statusItem.button;
        if (button) {
            button.font = [NSFont systemFontOfSize:14.0];
            button.title = @"●";
            NSLog(@"Button configured with title: %@", button.title);
        }
        
        // Create menu
        NSMenu *menu = [[NSMenu alloc] init];
        menu.autoenablesItems = NO;
        
        NSMenuItem *defaultModeItem = [[NSMenuItem alloc] initWithTitle:@"Default Mode" action:@selector(setDefaultMode:) keyEquivalent:@""];
        defaultModeItem.target = self;
        [menu addItem:defaultModeItem];
        
        NSMenuItem *normalModeItem = [[NSMenuItem alloc] initWithTitle:@"Normal Mode" action:@selector(setNormalMode:) keyEquivalent:@""];
        normalModeItem.target = self;
        [menu addItem:normalModeItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *eventViewerItem = [[NSMenuItem alloc] initWithTitle:@"Show Event Viewer" action:@selector(toggleEventViewer:) keyEquivalent:@"e"];
        eventViewerItem.target = self;
        [menu addItem:eventViewerItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *debugModeItem = [[NSMenuItem alloc] initWithTitle:@"Debug Mode" action:@selector(toggleDebugMode:) keyEquivalent:@""];
        debugModeItem.target = self;
        [menu addItem:debugModeItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
        quitItem.target = self;
        [menu addItem:quitItem];
        
        // Set menu
        _statusItem.menu = menu;
        _statusMenu = menu;
        
        _isSetup = YES;
        NSLog(@"Status bar setup completed");
    } @catch (NSException *exception) {
        NSLog(@"Exception in setupStatusBar: %@", exception);
    }
}

- (void)updateModeDisplay {
    if (!_isSetup || !_statusItem || !_statusItem.button) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSString *title = ([TPConfig sharedConfig].operationMode == TPOperationModeNormal) ? @"●" : @"○";
            _statusItem.button.title = title;
            NSLog(@"Updated status item title to: %@", title);
        } @catch (NSException *exception) {
            NSLog(@"Exception in updateModeDisplay: %@", exception);
        }
    });
}

- (void)updateDebugState {
    if (!_isSetup || !_statusMenu) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSMenuItem *debugItem = [_statusMenu itemWithTitle:@"Debug Mode"];
            if (debugItem) {
                debugItem.state = [TPConfig sharedConfig].debugMode ? NSControlStateValueOn : NSControlStateValueOff;
            }
        } @catch (NSException *exception) {
            NSLog(@"Exception in updateDebugState: %@", exception);
        }
    });
}

- (void)updateEventViewerState:(BOOL)isVisible {
    if (!_isSetup || !_statusMenu) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            _eventViewerVisible = isVisible;
            NSMenuItem *item = [_statusMenu itemWithTitle:isVisible ? @"Hide Event Viewer" : @"Show Event Viewer"];
            if (item) {
                item.title = isVisible ? @"Hide Event Viewer" : @"Show Event Viewer";
            }
        } @catch (NSException *exception) {
            NSLog(@"Exception in updateEventViewerState: %@", exception);
        }
    });
}

#pragma mark - Menu Actions

- (void)setDefaultMode:(id)sender {
    if (!_isSetup) return;
    [TPConfig sharedConfig].operationMode = TPOperationModeDefault;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateModeDisplay];
}

- (void)setNormalMode:(id)sender {
    if (!_isSetup) return;
    [TPConfig sharedConfig].operationMode = TPOperationModeNormal;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateModeDisplay];
}

- (void)toggleEventViewer:(id)sender {
    if (!_isSetup) return;
    if ([self.delegate respondsToSelector:@selector(statusBarControllerDidToggleEventViewer:)]) {
        [self.delegate statusBarControllerDidToggleEventViewer:!_eventViewerVisible];
    }
}

- (void)toggleDebugMode:(id)sender {
    if (!_isSetup) return;
    [TPConfig sharedConfig].debugMode = ![TPConfig sharedConfig].debugMode;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateDebugState];
}

- (void)quit:(id)sender {
    if (!_isSetup) return;
    if ([self.delegate respondsToSelector:@selector(statusBarControllerWillQuit)]) {
        [self.delegate statusBarControllerWillQuit];
    }
    [NSApp terminate:nil];
}

@end
