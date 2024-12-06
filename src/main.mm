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
        
        // Start our application
        [appDelegate start];
        
        // Run the application's main event loop
        [app run];
    }
    return 0;
}
