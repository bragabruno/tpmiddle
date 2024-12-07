#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initialize the application
        [NSApplication sharedApplication];
        
        // Set up the application delegate
        TPApplication *delegate = [TPApplication sharedApplication];
        [NSApp setDelegate:delegate];
        
        // Configure the application
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Set as agent application (no dock icon)
        ProcessSerialNumber psn = { 0, kCurrentProcess };
        TransformProcessType(&psn, kProcessTransformToUIElementApplication);
        
        // Finish launching
        [NSApp finishLaunching];
        
        // Run the application
        return NSApplicationMain(argc, argv);
    }
}
