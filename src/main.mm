#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        // Create NSApplication instance
        NSApplication *app = [NSApplication sharedApplication];
        
        // Create and setup application delegate
        TPApplication *appDelegate = [TPApplication sharedApplication];
        [app setDelegate:appDelegate];
        
        // Set activation policy for status bar app
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Finish launching
        [app finishLaunching];
        
        // Create a menu bar
        NSMenu *mainMenu = [[NSMenu alloc] init];
        [NSApp setMainMenu:mainMenu];
        
        // Run the application
        [app run];
    }
    return 0;
}
