#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import "../common/TPConstants.h"

// Operation modes
typedef NS_ENUM(NSInteger, TPOperationMode) {
    TPOperationModeDefault,
    TPOperationModeNormal
};

@interface TPConfig : NSObject

// Basic settings
@property (nonatomic) TPOperationMode operationMode;
@property (nonatomic) BOOL debugMode;
@property (nonatomic) NSTimeInterval middleButtonDelay;

// Scroll settings
@property (nonatomic) CGFloat scrollSpeedMultiplier;
@property (nonatomic) CGFloat scrollAcceleration;
@property (nonatomic) BOOL naturalScrolling;
@property (nonatomic) BOOL invertScrollX;
@property (nonatomic) BOOL invertScrollY;

// Singleton access
+ (instancetype)sharedConfig;

// Configuration management
- (void)loadFromDefaults;
- (void)saveToDefaults;
- (void)applyCommandLineArguments:(NSArray<NSString *>*)arguments;
- (void)resetToDefaults;

@end

#endif // __OBJC__
