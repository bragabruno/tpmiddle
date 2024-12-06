#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/hid/IOHIDManager.h>

extern NSString * const TPPermissionManagerErrorDomain;

typedef NS_ENUM(NSInteger, TPPermissionManagerError) {
    TPPermissionManagerErrorDenied = 1000
};

typedef NS_ENUM(NSInteger, TPPermissionType) {
    TPPermissionTypeAccessibility,
    TPPermissionTypeInputMonitoring
};

@interface TPPermissionManager : NSObject {
    BOOL _waitingForPermissions;
    BOOL _showingPermissionAlert;
}

@property (nonatomic, readonly) BOOL waitingForPermissions;
@property (nonatomic, readonly) BOOL showingPermissionAlert;
@property (nonatomic, assign) TPPermissionType currentPermissionRequest;

+ (instancetype)sharedManager;

- (NSError *)checkPermissions;
- (void)showPermissionError:(NSError *)error withCompletion:(void(^)(BOOL shouldRetry))completion;

@end
