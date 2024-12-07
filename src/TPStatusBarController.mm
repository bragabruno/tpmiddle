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
        
        // Initialize immediately
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupStatusBar];
            
            // Force an update after a short delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self updateModeDisplay];
            });
        });
    }
    return self;
}

- (void)setupStatusBar {
    if (_isSetup) return;
    
    NSLog(@"Setting up status bar...");
    
    @try {
        // Create status bar item
        NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
        self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
        if (!self.statusItem) {
            NSLog(@"Failed to create status item");
            return;
        }
        
        // Configure button
        NSButton *button = self.statusItem.button;
        if (button) {
            button.font = [NSFont systemFontOfSize:14.0];
            button.title = @"●";
            NSLog(@"Button configured with title: %@", button.title);
        }
        
        // Create menu
        NSMenu *menu = [[NSMenu alloc] init];
        menu.autoenablesItems = NO;
        
        [menu addItemWithTitle:@"Default Mode" action:@selector(setDefaultMode:) keyEquivalent:@""].target = self;
        [menu addItemWithTitle:@"Normal Mode" action:@selector(setNormalMode:) keyEquivalent:@""].target = self;
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Show Event Viewer" action:@selector(toggleEventViewer:) keyEquivalent:@"e"].target = self;
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Debug Mode" action:@selector(toggleDebugMode:) keyEquivalent:@""].target = self;
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"].target = self;
        
        // Set menu
        self.statusItem.menu = menu;
        self.statusMenu = menu;
        
        _isSetup = YES;
        NSLog(@"Status bar setup completed");
    } @catch (NSException *exception) {
        NSLog(@"Exception in setupStatusBar: %@", exception);
    }
}

- (void)updateModeDisplay {
    if (!self.statusItem || !self.statusItem.button) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *title = ([TPConfig sharedConfig].operationMode == TPOperationModeNormal) ? @"●" : @"○";
        self.statusItem.button.title = title;
        NSLog(@"Updated status item title to: %@", title);
    });
}

- (void)updateDebugState {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMenuItem *debugItem = [self.statusMenu itemWithTitle:@"Debug Mode"];
        if (debugItem) {
            debugItem.state = [TPConfig sharedConfig].debugMode ? NSControlStateValueOn : NSControlStateValueOff;
        }
    });
}

- (void)updateEventViewerState:(BOOL)isVisible {
    dispatch_async(dispatch_get_main_queue(), ^{
        _eventViewerVisible = isVisible;
        NSMenuItem *item = [self.statusMenu itemWithTitle:isVisible ? @"Hide Event Viewer" : @"Show Event Viewer"];
        if (item) {
            item.title = isVisible ? @"Hide Event Viewer" : @"Show Event Viewer";
        }
    });
}

#pragma mark - Menu Actions

- (void)setDefaultMode:(id)sender {
    [TPConfig sharedConfig].operationMode = TPOperationModeDefault;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateModeDisplay];
}

- (void)setNormalMode:(id)sender {
    [TPConfig sharedConfig].operationMode = TPOperationModeNormal;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateModeDisplay];
}

- (void)toggleEventViewer:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarControllerDidToggleEventViewer:)]) {
        [self.delegate statusBarControllerDidToggleEventViewer:!_eventViewerVisible];
    }
}

- (void)toggleDebugMode:(id)sender {
    [TPConfig sharedConfig].debugMode = ![TPConfig sharedConfig].debugMode;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateDebugState];
}

- (void)quit:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarControllerWillQuit)]) {
        [self.delegate statusBarControllerWillQuit];
    }
    [NSApp terminate:nil];
}

@end
