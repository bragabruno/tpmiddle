#import "TPMiddleMacOS.h"
#import "TPStatusBarController.h"
#import "TPHIDManager.h"
#import "TPConfig.h"
#import "TPLogger.h"

namespace TPMiddle {

TPMiddleMacOS::TPMiddleMacOS() : statusBarController(nil) {
}

TPMiddleMacOS::~TPMiddleMacOS() {
    statusBarController = nil;
}

bool TPMiddleMacOS::Initialize() {
    // Initialize logger
    TPLogger* logger = [TPLogger sharedLogger];
    [logger startLogging];
    [logger logMessage:@"Initializing TPMiddle"];

    // Load configuration
    TPConfig* config = [TPConfig sharedConfig];
    [config loadFromDefaults];
    [logger logMessage:@"Configuration loaded"];

    // Initialize HID Manager
    TPHIDManager* hidManager = [TPHIDManager sharedManager];
    if (![hidManager start]) {
        [logger logMessage:@"Failed to initialize HID Manager"];
        return false;
    }
    [logger logMessage:@"HID Manager initialized"];

    // Initialize Status Bar
    statusBarController = [[TPStatusBarController alloc] init];
    if (!statusBarController) {
        [logger logMessage:@"Failed to create status bar controller"];
        return false;
    }
    [logger logMessage:@"Status bar controller initialized"];

    return true;
}

void TPMiddleMacOS::Run() {
    [NSApp run];
}

} // namespace TPMiddle
