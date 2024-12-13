import Foundation

/// Button mask constants
public struct TPHIDButtonMask {
    public static let leftButton: UInt8 = 0x01
    public static let rightButton: UInt8 = 0x02
    public static let middleButton: UInt8 = 0x04
}

/// HID Usage Pages and Usages
public struct TPHIDUsage {
    public struct Page {
        public static let genericDesktop: UInt32 = 0x01
        public static let button: UInt32 = 0x09
    }
    
    public struct GenericDesktop {
        public static let mouse: UInt32 = 0x02
        public static let pointer: UInt32 = 0x01
        public static let x: UInt32 = 0x30
        public static let y: UInt32 = 0x31
        public static let wheel: UInt32 = 0x38
    }
}

/// Common vendor IDs
public struct TPHIDVendorID {
    public static let lenovo: UInt32 = 0x17EF
    public static let ibm: UInt32 = 0x04B3
    public static let ti: UInt32 = 0x0451
    public static let logitech: UInt32 = 0x046D
}

/// HID Device Configuration
public struct TPHIDDeviceConfiguration {
    public let usagePage: UInt32
    public let usage: UInt32
    public let vendorID: UInt32?
    
    public init(usagePage: UInt32, usage: UInt32, vendorID: UInt32? = nil) {
        self.usagePage = usagePage
        self.usage = usage
        self.vendorID = vendorID
    }
    
    /// Common configurations
    public static let mouse = TPHIDDeviceConfiguration(
        usagePage: TPHIDUsage.Page.genericDesktop,
        usage: TPHIDUsage.GenericDesktop.mouse
    )
    
    public static let pointer = TPHIDDeviceConfiguration(
        usagePage: TPHIDUsage.Page.genericDesktop,
        usage: TPHIDUsage.GenericDesktop.pointer
    )
}

/// HID Device State
public struct TPHIDDeviceState {
    public var deltaX: Int = 0
    public var deltaY: Int = 0
    public var buttonState: UInt8 = 0
    
    public var isLeftButtonPressed: Bool {
        buttonState & TPHIDButtonMask.leftButton != 0
    }
    
    public var isRightButtonPressed: Bool {
        buttonState & TPHIDButtonMask.rightButton != 0
    }
    
    public var isMiddleButtonPressed: Bool {
        buttonState & TPHIDButtonMask.middleButton != 0
    }
    
    public init(deltaX: Int = 0, deltaY: Int = 0, buttonState: UInt8 = 0) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.buttonState = buttonState
    }
}
