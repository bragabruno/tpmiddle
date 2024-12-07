#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Set up the application delegate
        TPApplication *delegate = [TPApplication sharedApplication];
        [NSApp setDelegate:delegate];
        
        // Configure the application
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Set as agent application (no dock icon)
        ProcessSerialNumber psn = { 0, kCurrentProcess };
        TransformProcessType(&psn, kProcessTransformToUIElementApplication);
        
        // Run the application
        return NSApplicationMain(argc, argv);
    }
}
