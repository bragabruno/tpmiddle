import Foundation
import IOKit.hid

// Vendor IDs
let kVendorIDLenovo: UInt32 = 0x17EF
let kVendorIDIBM: UInt32 = 0x04B3
let kVendorIDTI: UInt32 = 0x0451
let kVendorIDLogitech: UInt32 = 0x046D

// HID Usage Pages and Usages
let kHIDPage_GenericDesktop: UInt32 = 0x01
let kHIDUsage_GD_Mouse: UInt32 = 0x02
let kHIDUsage_GD_Pointer: UInt32 = 0x01

// Application Constants
enum TPConstants {
    static let appName = "TPMiddle"
    static let appVersion = "1.0.0"
    
    enum Defaults {
        static let debugMode = false
        static let scrollSpeed = 1.0
        static let naturalScrolling = true
        static let accelerationEnabled = true
    }
    
    enum Notifications {
        static let deviceAttached = "TPDeviceAttachedNotification"
        static let deviceDetached = "TPDeviceDetachedNotification"
        static let configurationChanged = "TPConfigurationChangedNotification"
    }
    
    enum FileNames {
        static let configFile = "config.json"
        static let eventViewerNib = "TPEventViewController"
    }
    
    enum MenuItems {
        static let quit = "Quit"
        static let preferences = "Preferences..."
        static let showEventViewer = "Show Event Viewer"
        static let hideEventViewer = "Hide Event Viewer"
    }
    
    enum Permissions {
        static let inputMonitoring = "Input Monitoring"
        static let accessibility = "Accessibility"
    }
    
    enum Windows {
        static let eventViewerTitle = "Event Viewer"
        static let eventViewerSize = CGSize(width: 400, height: 300)
    }
}

// Configuration Keys
enum ConfigKeys {
    static let debugMode = "debugMode"
    static let scrollSpeed = "scrollSpeed"
    static let naturalScrolling = "naturalScrolling"
    static let accelerationEnabled = "accelerationEnabled"
}

// Error Domains
enum ErrorDomain {
    static let application = "com.tpmiddle.application"
    static let hid = "com.tpmiddle.hid"
    static let config = "com.tpmiddle.config"
    static let permissions = "com.tpmiddle.permissions"
}

// Error Codes
enum ErrorCode {
    static let permissionDenied = 1001
    static let deviceNotFound = 1002
    static let configurationError = 1003
    static let hidError = 1004
    static let resourceNotFound = 1005
}
