#include <Cocoa/Cocoa.h>
#include "TPHIDManager.h"
#include "TPButtonManager.h"
#include "TPStatusBarController.h"

@interface TPApplication : NSObject <NSApplicationDelegate, TPHIDManagerDelegate, TPButtonManagerDelegate, TPStatusBarControllerDelegate>

+ (instancetype)sharedApplication;
- (void)start;

@end

// Device identification constants
extern const uint32_t kVendorIDLenovo;
extern const uint32_t kUsagePageGenericDesktop;
extern const uint32_t kUsagePageButton;
extern const uint32_t kUsageMouse;
extern const uint32_t kUsagePointer;
