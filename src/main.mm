#import <Cocoa/Cocoa.h>
#include "TPMiddleMacOS.h"
#include <memory>
#include <iostream>

int main(int argc, const char * argv[]) {
    (void)argc;  // Suppress unused parameter warning
    (void)argv;  // Suppress unused parameter warning
    
    @autoreleasepool {
        // Create and initialize NSApplication
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        // Create menu bar
        NSMenu* menubar = [[NSMenu alloc] init];
        [NSApp setMainMenu:menubar];

        // Initialize our application
        auto app = std::make_unique<TPMiddle::TPMiddleMacOS>();
        if (!app->Initialize()) {
            NSLog(@"Failed to initialize application");
            return 1;
        }

        // Run the application
        app->Run();

        return 0;
    }
}
