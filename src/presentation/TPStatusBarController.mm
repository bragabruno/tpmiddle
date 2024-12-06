#include "TPStatusBarController.h"
#include "../core/TPConfig.h"

#ifdef DEBUG
#define DebugLog(format, ...) NSLog(@"%s: " format, __FUNCTION__, ##__VA_ARGS__)
#else
#define DebugLog(format, ...)
#endif

@interface TPStatusBarController () {
    BOOL _eventViewerVisible;
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
        [self setupStatusBar];
    }
    return self;
}

#pragma mark - Setup

- (void)setupStatusBar {
    @try {
        // Create status bar item
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
        // Ensure the button is created
        if (self.statusItem.button == nil) {
            NSLog(@"Failed to create status item button");
            return;
        }
        
        // Set initial title
        NSString *title = ([TPConfig sharedConfig].operationMode == TPOperationModeNormal) ? @"●" : @"○";
        self.statusItem.button.title = title;
        
        // Create menu
        @autoreleasepool {
            self.statusMenu = [self createStatusMenu];
            if (self.statusMenu) {
                self.statusItem.menu = self.statusMenu;
                NSLog(@"Status bar setup completed - title: %@", title);
            } else {
                NSLog(@"Failed to create status menu");
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in setupStatusBar: %@", exception);
    }
}

- (NSMenu *)createStatusMenu {
    @try {
        NSMenu *menu = [[NSMenu alloc] init];
        if (!menu) return nil;
        
        menu.autoenablesItems = NO;  // Manually control item state
        
        // Mode selection
        NSMenuItem *defaultModeItem = [[NSMenuItem alloc] initWithTitle:@"Default Mode"
                                                               action:@selector(setDefaultMode:)
                                                        keyEquivalent:@""];
        defaultModeItem.target = self;
        defaultModeItem.enabled = YES;
        [menu addItem:defaultModeItem];
        
        NSMenuItem *normalModeItem = [[NSMenuItem alloc] initWithTitle:@"Normal Mode"
                                                              action:@selector(setNormalMode:)
                                                       keyEquivalent:@""];
        normalModeItem.target = self;
        normalModeItem.enabled = YES;
        [menu addItem:normalModeItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        // Event Viewer
        NSMenuItem *eventViewerItem = [[NSMenuItem alloc] initWithTitle:@"Show Event Viewer"
                                                               action:@selector(toggleEventViewer:)
                                                        keyEquivalent:@"e"];
        eventViewerItem.target = self;
        eventViewerItem.enabled = YES;
        [menu addItem:eventViewerItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        // Debug mode toggle
        NSMenuItem *debugItem = [[NSMenuItem alloc] initWithTitle:@"Debug Mode"
                                                          action:@selector(toggleDebugMode:)
                                                   keyEquivalent:@""];
        debugItem.target = self;
        debugItem.enabled = YES;
        [menu addItem:debugItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        // Quit menu item
        NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                         action:@selector(quit:)
                                                  keyEquivalent:@"q"];
        quitItem.target = self;
        quitItem.enabled = YES;
        [menu addItem:quitItem];
        
        // Update initial states
        [self updateMenuStates:menu];
        
        return menu;
    } @catch (NSException *exception) {
        NSLog(@"Exception in createStatusMenu: %@", exception);
        return nil;
    }
}

#pragma mark - Public Methods

- (void)updateModeDisplay {
    @try {
        NSString *title = ([TPConfig sharedConfig].operationMode == TPOperationModeNormal) ? @"●" : @"○";
        if (self.statusItem && self.statusItem.button) {
            self.statusItem.button.title = title;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in updateModeDisplay: %@", exception);
    }
}

- (void)updateDebugState {
    [self updateMenuStates:self.statusMenu];
}

- (void)updateEventViewerState:(BOOL)isVisible {
    @try {
        _eventViewerVisible = isVisible;
        NSMenuItem *eventViewerItem = [self.statusMenu itemWithTitle:@"Show Event Viewer"];
        if (eventViewerItem) {
            eventViewerItem.title = isVisible ? @"Hide Event Viewer" : @"Show Event Viewer";
            eventViewerItem.state = isVisible ? NSControlStateValueOn : NSControlStateValueOff;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in updateEventViewerState: %@", exception);
    }
}

#pragma mark - Private Methods

- (void)updateMenuStates:(NSMenu *)menu {
    if (!menu) return;
    
    @try {
        TPConfig *config = [TPConfig sharedConfig];
        
        // Update mode checkmarks
        BOOL isNormalMode = config.operationMode == TPOperationModeNormal;
        NSMenuItem *defaultModeItem = [menu itemAtIndex:0];
        NSMenuItem *normalModeItem = [menu itemAtIndex:1];
        if (defaultModeItem && normalModeItem) {
            defaultModeItem.state = isNormalMode ? NSControlStateValueOff : NSControlStateValueOn;
            normalModeItem.state = isNormalMode ? NSControlStateValueOn : NSControlStateValueOff;
        }
        
        // Update event viewer state
        NSMenuItem *eventViewerItem = [menu itemWithTitle:_eventViewerVisible ? @"Hide Event Viewer" : @"Show Event Viewer"];
        if (eventViewerItem) {
            eventViewerItem.state = _eventViewerVisible ? NSControlStateValueOn : NSControlStateValueOff;
        }
        
        // Update debug mode
        NSMenuItem *debugItem = [menu itemWithTitle:@"Debug Mode"];
        if (debugItem) {
            debugItem.state = config.debugMode ? NSControlStateValueOn : NSControlStateValueOff;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in updateMenuStates: %@", exception);
    }
}

#pragma mark - Menu Actions

- (void)setDefaultMode:(id)sender {
    [self setMode:TPOperationModeDefault];
}

- (void)setNormalMode:(id)sender {
    [self setMode:TPOperationModeNormal];
}

- (void)setMode:(TPOperationMode)mode {
    @try {
        [TPConfig sharedConfig].operationMode = mode;
        [[TPConfig sharedConfig] saveToDefaults];
        [self updateModeDisplay];
        [self updateMenuStates:self.statusMenu];
        DebugLog(@"Switched to %@ mode", mode == TPOperationModeNormal ? @"Normal" : @"Default");
    } @catch (NSException *exception) {
        NSLog(@"Exception in setMode: %@", exception);
    }
}

- (void)toggleEventViewer:(id)sender {
    @try {
        if ([self.delegate respondsToSelector:@selector(statusBarControllerDidToggleEventViewer:)]) {
            [self.delegate statusBarControllerDidToggleEventViewer:!_eventViewerVisible];
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in toggleEventViewer: %@", exception);
    }
}

- (void)toggleDebugMode:(id)sender {
    @try {
        TPConfig *config = [TPConfig sharedConfig];
        config.debugMode = !config.debugMode;
        [config saveToDefaults];
        [self updateMenuStates:self.statusMenu];
        DebugLog(@"Debug mode %@", config.debugMode ? @"enabled" : @"disabled");
    } @catch (NSException *exception) {
        NSLog(@"Exception in toggleDebugMode: %@", exception);
    }
}

- (void)quit:(id)sender {
    @try {
        if ([self.delegate respondsToSelector:@selector(statusBarControllerWillQuit)]) {
            [self.delegate statusBarControllerWillQuit];
        }
        [NSApp terminate:nil];
    } @catch (NSException *exception) {
        NSLog(@"Exception in quit: %@", exception);
        [NSApp terminate:nil];
    }
}

@end
