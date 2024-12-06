#include "TPConfig.h"

#ifdef DEBUG
#define DebugLog(format, ...) NSLog(@"%s: " format, __FUNCTION__, ##__VA_ARGS__)
#else
#define DebugLog(format, ...)
#endif

// User defaults keys
static NSString* const kDefaultsKeyNormalMode = @"NormalMode";
static NSString* const kDefaultsKeyDebugMode = @"DebugMode";
static NSString* const kDefaultsKeyMiddleButtonDelay = @"MiddleButtonDelay";
static NSString* const kDefaultsKeyScrollSpeedMultiplier = @"ScrollSpeedMultiplier";
static NSString* const kDefaultsKeyScrollAcceleration = @"ScrollAcceleration";
static NSString* const kDefaultsKeyNaturalScrolling = @"NaturalScrolling";
static NSString* const kDefaultsKeyInvertScrollX = @"InvertScrollX";
static NSString* const kDefaultsKeyInvertScrollY = @"InvertScrollY";

@implementation TPConfig

+ (instancetype)sharedConfig {
    static TPConfig *sharedConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConfig = [[TPConfig alloc] init];
    });
    return sharedConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        [self resetToDefaults];
        [self loadFromDefaults];
    }
    return self;
}

- (void)resetToDefaults {
    _operationMode = TPOperationModeDefault;
    _debugMode = NO;
    _middleButtonDelay = kDefaultMiddleButtonDelay;
    
    // Scroll settings
    _scrollSpeedMultiplier = kDefaultScrollSpeedMultiplier;
    _scrollAcceleration = kDefaultScrollAcceleration;
    _naturalScrolling = YES;  // Default to natural scrolling like modern macOS
    _invertScrollX = NO;
    _invertScrollY = NO;
}

- (void)loadFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Basic settings
    if ([defaults objectForKey:kDefaultsKeyNormalMode]) {
        self.operationMode = [defaults boolForKey:kDefaultsKeyNormalMode] ? 
            TPOperationModeNormal : TPOperationModeDefault;
    }
    
    if ([defaults objectForKey:kDefaultsKeyDebugMode]) {
        self.debugMode = [defaults boolForKey:kDefaultsKeyDebugMode];
    }
    
    if ([defaults objectForKey:kDefaultsKeyMiddleButtonDelay]) {
        self.middleButtonDelay = [defaults doubleForKey:kDefaultsKeyMiddleButtonDelay];
    }
    
    // Scroll settings
    if ([defaults objectForKey:kDefaultsKeyScrollSpeedMultiplier]) {
        self.scrollSpeedMultiplier = [defaults doubleForKey:kDefaultsKeyScrollSpeedMultiplier];
    }
    
    if ([defaults objectForKey:kDefaultsKeyScrollAcceleration]) {
        self.scrollAcceleration = [defaults doubleForKey:kDefaultsKeyScrollAcceleration];
    }
    
    if ([defaults objectForKey:kDefaultsKeyNaturalScrolling]) {
        self.naturalScrolling = [defaults boolForKey:kDefaultsKeyNaturalScrolling];
    }
    
    if ([defaults objectForKey:kDefaultsKeyInvertScrollX]) {
        self.invertScrollX = [defaults boolForKey:kDefaultsKeyInvertScrollX];
    }
    
    if ([defaults objectForKey:kDefaultsKeyInvertScrollY]) {
        self.invertScrollY = [defaults boolForKey:kDefaultsKeyInvertScrollY];
    }
}

- (void)saveToDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Basic settings
    [defaults setBool:(self.operationMode == TPOperationModeNormal) forKey:kDefaultsKeyNormalMode];
    [defaults setBool:self.debugMode forKey:kDefaultsKeyDebugMode];
    [defaults setDouble:self.middleButtonDelay forKey:kDefaultsKeyMiddleButtonDelay];
    
    // Scroll settings
    [defaults setDouble:self.scrollSpeedMultiplier forKey:kDefaultsKeyScrollSpeedMultiplier];
    [defaults setDouble:self.scrollAcceleration forKey:kDefaultsKeyScrollAcceleration];
    [defaults setBool:self.naturalScrolling forKey:kDefaultsKeyNaturalScrolling];
    [defaults setBool:self.invertScrollX forKey:kDefaultsKeyInvertScrollX];
    [defaults setBool:self.invertScrollY forKey:kDefaultsKeyInvertScrollY];
    
    [defaults synchronize];
}

- (void)applyCommandLineArguments:(NSArray<NSString *>*)arguments {
    for (NSString *arg in arguments) {
        if ([arg isEqualToString:@"-n"] || [arg isEqualToString:@"--normal"]) {
            self.operationMode = TPOperationModeNormal;
            DebugLog(@"Normal mode enabled via command line");
        } else if ([arg isEqualToString:@"-r"] || [arg isEqualToString:@"--reset"]) {
            self.operationMode = TPOperationModeDefault;
            DebugLog(@"Reset to default mode via command line");
        } else if ([arg isEqualToString:@"-d"] || [arg isEqualToString:@"--debug"]) {
            self.debugMode = YES;
            DebugLog(@"Debug mode enabled via command line");
        } else if ([arg isEqualToString:@"--natural-scroll"]) {
            self.naturalScrolling = YES;
            DebugLog(@"Natural scrolling enabled via command line");
        } else if ([arg isEqualToString:@"--reverse-scroll"]) {
            self.naturalScrolling = NO;
            DebugLog(@"Natural scrolling disabled via command line");
        }
    }
    [self saveToDefaults];
}

@end
