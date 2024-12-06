#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        TPApplication *delegate = [TPApplication sharedApplication];
        [NSApp setDelegate:delegate];
        [NSApp run];
    }
    return 0;
}
