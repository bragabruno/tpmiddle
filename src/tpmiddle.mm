#include <Cocoa/Cocoa.h>
#include "TPApplication.h"
#include "TPHIDManager.h"
#include "TPStatusBarController.h"
#include "TPConfig.h"
#include "TPLogger.h"

namespace TPMiddle {

class TPMiddleMacOS {
public:
    TPMiddleMacOS() = default;
    ~TPMiddleMacOS() = default;

    bool Initialize() {
        // Initialize logger
        if (!TPLogger::Instance().Initialize()) {
            NSLog(@"Failed to initialize logger");
            return false;
        }

        // Load configuration
        if (!TPConfig::Instance().LoadConfig()) {
            TPLogger::Instance().LogError("Failed to load configuration");
            return false;
        }

        // Initialize HID Manager
        if (!TPHIDManager::Instance().Initialize()) {
            TPLogger::Instance().LogError("Failed to initialize HID Manager");
            return false;
        }

        // Initialize Status Bar
        statusBarController = [[TPStatusBarController alloc] init];
        if (!statusBarController) {
            TPLogger::Instance().LogError("Failed to create status bar controller");
            return false;
        }

        return true;
    }

    void Run() {
        [NSApp run];
    }

private:
    TPStatusBarController* statusBarController;
};

} // namespace TPMiddle

int main(int argc, const char* argv[]) {
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
