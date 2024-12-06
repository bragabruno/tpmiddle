#import <Cocoa/Cocoa.h>
#import "TPApplication.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        TPApplication *appDelegate = [TPApplication sharedApplication];
        
        [application setDelegate:appDelegate];
        [appDelegate start];
        
        [application run];
    }
    return 0;
}
