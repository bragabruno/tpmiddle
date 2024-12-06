#include "TPStatusBarController.h"
#include "TPConfig.h"

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
    self.statusMenu = [self createStatusMenu];
    self.statusItem.menu = self.statusMenu;
    
    NSLog(@"Status bar setup completed - title: %@", title);
}

- (NSMenu *)createStatusMenu {
    NSMenu *menu = [[NSMenu alloc] init];
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
    
    // Scroll settings submenu
    NSMenuItem *scrollSettingsItem = [[NSMenuItem alloc] initWithTitle:@"Scroll Settings" action:nil keyEquivalent:@""];
    NSMenu *scrollMenu = [[NSMenu alloc] init];
    scrollMenu.autoenablesItems = NO;
    scrollSettingsItem.submenu = scrollMenu;
    
    // Natural scrolling toggle
    NSMenuItem *naturalScrollItem = [[NSMenuItem alloc] initWithTitle:@"Natural Scrolling"
                                                             action:@selector(toggleNaturalScrolling:)
                                                      keyEquivalent:@""];
    naturalScrollItem.target = self;
    naturalScrollItem.enabled = YES;
    [scrollMenu addItem:naturalScrollItem];
    
    // Scroll direction settings
    NSMenuItem *invertXItem = [[NSMenuItem alloc] initWithTitle:@"Invert Horizontal"
                                                       action:@selector(toggleHorizontalScroll:)
                                                keyEquivalent:@""];
    invertXItem.target = self;
    invertXItem.enabled = YES;
    [scrollMenu addItem:invertXItem];
    
    NSMenuItem *invertYItem = [[NSMenuItem alloc] initWithTitle:@"Invert Vertical"
                                                       action:@selector(toggleVerticalScroll:)
                                                keyEquivalent:@""];
    invertYItem.target = self;
    invertYItem.enabled = YES;
    [scrollMenu addItem:invertYItem];
    
    [scrollMenu addItem:[NSMenuItem separatorItem]];
    
    // Scroll speed submenu
    NSMenuItem *speedSettingsItem = [[NSMenuItem alloc] initWithTitle:@"Scroll Speed" action:nil keyEquivalent:@""];
    NSMenu *speedMenu = [[NSMenu alloc] init];
    speedMenu.autoenablesItems = NO;
    speedSettingsItem.submenu = speedMenu;
    
    NSArray *speeds = @[@"Very Slow", @"Slow", @"Normal", @"Fast", @"Very Fast"];
    for (NSUInteger i = 0; i < speeds.count; i++) {
        NSMenuItem *speedItem = [[NSMenuItem alloc] initWithTitle:speeds[i]
                                                         action:@selector(setScrollSpeed:)
                                                  keyEquivalent:@""];
        speedItem.target = self;
        speedItem.tag = (NSInteger)i;
        speedItem.enabled = YES;
        [speedMenu addItem:speedItem];
    }
    
    [scrollMenu addItem:speedSettingsItem];
    
    // Acceleration submenu
    NSMenuItem *accelSettingsItem = [[NSMenuItem alloc] initWithTitle:@"Acceleration" action:nil keyEquivalent:@""];
    NSMenu *accelMenu = [[NSMenu alloc] init];
    accelMenu.autoenablesItems = NO;
    accelSettingsItem.submenu = accelMenu;
    
    NSArray *accels = @[@"None", @"Light", @"Medium", @"Heavy"];
    for (NSUInteger i = 0; i < accels.count; i++) {
        NSMenuItem *accelItem = [[NSMenuItem alloc] initWithTitle:accels[i]
                                                         action:@selector(setAcceleration:)
                                                  keyEquivalent:@""];
        accelItem.target = self;
        accelItem.tag = (NSInteger)i;
        accelItem.enabled = YES;
        [accelMenu addItem:accelItem];
    }
    
    [scrollMenu addItem:accelSettingsItem];
    
    [menu addItem:scrollSettingsItem];
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
}

#pragma mark - Public Methods

- (void)updateModeDisplay {
    NSString *title = ([TPConfig sharedConfig].operationMode == TPOperationModeNormal) ? @"●" : @"○";
    if (self.statusItem && self.statusItem.button) {
        self.statusItem.button.title = title;
    }
}

- (void)updateDebugState {
    [self updateMenuStates:self.statusMenu];
}

- (void)updateScrollSettings {
    [self updateMenuStates:self.statusMenu];
}

- (void)updateEventViewerState:(BOOL)isVisible {
    _eventViewerVisible = isVisible;
    NSMenuItem *eventViewerItem = [self.statusMenu itemWithTitle:@"Show Event Viewer"];
    if (eventViewerItem) {
        eventViewerItem.title = isVisible ? @"Hide Event Viewer" : @"Show Event Viewer";
        eventViewerItem.state = isVisible ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

#pragma mark - Private Methods

- (void)updateMenuStates:(NSMenu *)menu {
    if (!menu) return;
    
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
    
    // Update scroll settings
    NSMenu *scrollMenu = [[menu itemWithTitle:@"Scroll Settings"] submenu];
    if (scrollMenu) {
        [[scrollMenu itemWithTitle:@"Natural Scrolling"] setState:config.naturalScrolling ? NSControlStateValueOn : NSControlStateValueOff];
        [[scrollMenu itemWithTitle:@"Invert Horizontal"] setState:config.invertScrollX ? NSControlStateValueOn : NSControlStateValueOff];
        [[scrollMenu itemWithTitle:@"Invert Vertical"] setState:config.invertScrollY ? NSControlStateValueOn : NSControlStateValueOff];
        
        // Update speed selection
        NSInteger speedIndex = [self speedIndexForMultiplier:config.scrollSpeedMultiplier];
        NSMenu *speedMenu = [[scrollMenu itemWithTitle:@"Scroll Speed"] submenu];
        if (speedMenu) {
            for (NSMenuItem *item in speedMenu.itemArray) {
                item.state = (item.tag == speedIndex) ? NSControlStateValueOn : NSControlStateValueOff;
            }
        }
        
        // Update acceleration selection
        NSInteger accelIndex = [self accelerationIndexForValue:config.scrollAcceleration];
        NSMenu *accelMenu = [[scrollMenu itemWithTitle:@"Acceleration"] submenu];
        if (accelMenu) {
            for (NSMenuItem *item in accelMenu.itemArray) {
                item.state = (item.tag == accelIndex) ? NSControlStateValueOn : NSControlStateValueOff;
            }
        }
    }
    
    // Update debug mode
    [[menu itemWithTitle:@"Debug Mode"] setState:config.debugMode ? NSControlStateValueOn : NSControlStateValueOff];
}

- (NSInteger)speedIndexForMultiplier:(CGFloat)multiplier {
    if (multiplier <= 0.25) return 0;      // Very Slow
    if (multiplier <= 0.5)  return 1;      // Slow
    if (multiplier <= 1.0)  return 2;      // Normal
    if (multiplier <= 2.0)  return 3;      // Fast
    return 4;                              // Very Fast
}

- (CGFloat)multiplierForSpeedIndex:(NSInteger)index {
    switch (index) {
        case 0: return 0.25;   // Very Slow
        case 1: return 0.5;    // Slow
        case 2: return 1.0;    // Normal
        case 3: return 2.0;    // Fast
        case 4: return 4.0;    // Very Fast
        default: return 1.0;
    }
}

- (NSInteger)accelerationIndexForValue:(CGFloat)acceleration {
    if (acceleration <= 0.0) return 0;     // None
    if (acceleration <= 1.0) return 1;     // Light
    if (acceleration <= 2.0) return 2;     // Medium
    return 3;                              // Heavy
}

- (CGFloat)accelerationForIndex:(NSInteger)index {
    switch (index) {
        case 0: return 0.0;    // None
        case 1: return 1.0;    // Light
        case 2: return 2.0;    // Medium
        case 3: return 3.0;    // Heavy
        default: return 1.0;
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
    [TPConfig sharedConfig].operationMode = mode;
    [[TPConfig sharedConfig] saveToDefaults];
    [self updateModeDisplay];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Switched to %@ mode", mode == TPOperationModeNormal ? @"Normal" : @"Default");
}

- (void)toggleEventViewer:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarControllerDidToggleEventViewer:)]) {
        [self.delegate statusBarControllerDidToggleEventViewer:!_eventViewerVisible];
    }
}

- (void)toggleDebugMode:(id)sender {
    TPConfig *config = [TPConfig sharedConfig];
    config.debugMode = !config.debugMode;
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Debug mode %@", config.debugMode ? @"enabled" : @"disabled");
}

- (void)toggleNaturalScrolling:(id)sender {
    TPConfig *config = [TPConfig sharedConfig];
    config.naturalScrolling = !config.naturalScrolling;
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Natural scrolling %@", config.naturalScrolling ? @"enabled" : @"disabled");
}

- (void)toggleHorizontalScroll:(id)sender {
    TPConfig *config = [TPConfig sharedConfig];
    config.invertScrollX = !config.invertScrollX;
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Horizontal scroll direction %@", config.invertScrollX ? @"inverted" : @"normal");
}

- (void)toggleVerticalScroll:(id)sender {
    TPConfig *config = [TPConfig sharedConfig];
    config.invertScrollY = !config.invertScrollY;
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Vertical scroll direction %@", config.invertScrollY ? @"inverted" : @"normal");
}

- (void)setScrollSpeed:(id)sender {
    NSMenuItem *item = (NSMenuItem *)sender;
    TPConfig *config = [TPConfig sharedConfig];
    config.scrollSpeedMultiplier = [self multiplierForSpeedIndex:item.tag];
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Scroll speed set to %@", item.title);
}

- (void)setAcceleration:(id)sender {
    NSMenuItem *item = (NSMenuItem *)sender;
    TPConfig *config = [TPConfig sharedConfig];
    config.scrollAcceleration = [self accelerationForIndex:item.tag];
    [config saveToDefaults];
    [self updateMenuStates:self.statusMenu];
    DebugLog(@"Acceleration set to %@", item.title);
}

- (void)quit:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarControllerWillQuit)]) {
        [self.delegate statusBarControllerWillQuit];
    }
    [NSApp terminate:nil];
}

@end
