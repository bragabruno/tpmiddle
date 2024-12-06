#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

static void startApplicationCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    TPApplication *appDelegate = (__bridge TPApplication *)info;
    dispatch_async(dispatch_get_main_queue(), ^{
        [appDelegate start];
    });
    CFRunLoopObserverInvalidate(observer);
    CFRelease(observer);
}

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        // Create NSApplication instance
        [NSApplication sharedApplication];
        
        // Create and setup application delegate
        TPApplication *appDelegate = [TPApplication sharedApplication];
        [NSApp setDelegate:appDelegate];
        
        // Set activation policy for status bar app
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        // Create a run loop observer to start the application after run loop is ready
        CFRunLoopObserverContext context = {0, (__bridge void *)appDelegate, NULL, NULL, NULL};
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(
            kCFAllocatorDefault,
            kCFRunLoopEntry,
            false, // Don't repeat
            0,
            startApplicationCallback,
            &context
        );
        
        if (observer) {
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
        }
        
        // Finish launching and run
        [NSApp finishLaunching];
        [NSApp run];
    }
    return 0;
}
