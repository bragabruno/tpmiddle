#ifndef TPMiddle_h
#define TPMiddle_h

#import <Foundation/Foundation.h>

//! Project version number for TPMiddle.
FOUNDATION_EXPORT double TPMiddleVersionNumber;

//! Project version string for TPMiddle.
FOUNDATION_EXPORT const unsigned char TPMiddleVersionString[];

// Forward declarations for Swift types
NS_ASSUME_NONNULL_BEGIN

// HID Module
@class TPHIDManager;
@class TPHIDDevice;
@class TPHIDInputHandler;

// Protocol declarations
@protocol TPHIDManagerDelegate;
@protocol TPButtonManagerDelegate;
@protocol TPStatusBarControllerDelegate;

// Utils Module
@class TPLogger;

// Presentation Module
@class TPEventViewController;

NS_ASSUME_NONNULL_END

#endif /* TPMiddle_h */
