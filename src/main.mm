#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create and setup NSApplication
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Create and setup application delegate
        TPApplication *appDelegate = [TPApplication sharedApplication];
        [application setDelegate:appDelegate];
        
        // Finish launching the application
        [application finishLaunching];
        
        // Start our application
        [appDelegate start];
        
        // Activate the application
        [application activateIgnoringOtherApps:YES];
        
        // Run the application
        [application run];
    }
    return 0;
}
