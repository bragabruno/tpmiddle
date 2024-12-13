import Foundation
import IOKit.hid

/// Represents a HID device with its properties
@objcMembers
public final class TPHIDDevice: NSObject {
    // MARK: - Properties
    
    /// The product name of the device
    public let productName: String
    
    /// The vendor ID of the device
    public let vendorID: NSNumber
    
    /// The product ID of the device
    public let productID: NSNumber
    
    /// The underlying IOKit device reference
    public let deviceRef: IOHIDDevice
    
    // MARK: - Initialization
    
    /// Initialize with an IOKit HID device
    /// - Parameter device: The IOKit HID device reference
    public init(device: IOHIDDevice) {
        self.deviceRef = device
        
        // Get device properties using IOKit
        self.productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
        self.vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber ?? 0
        self.productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber ?? 0
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Check if this device is equal to another IOKit HID device reference
    /// - Parameter device: The IOKit HID device reference to compare against
    /// - Returns: True if the devices are the same, false otherwise
    public func isEqual(to device: IOHIDDevice) -> Bool {
        return deviceRef == device
    }
    
    // MARK: - NSObject Overrides
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TPHIDDevice else { return false }
        return deviceRef == other.deviceRef
    }
    
    public override var hash: Int {
        return ObjectIdentifier(deviceRef).hashValue
    }
    
    public override var description: String {
        return """
        TPHIDDevice(
            productName: \(productName),
            vendorID: \(String(format: "0x%04X", vendorID.uint32Value)),
            productID: \(String(format: "0x%04X", productID.uint32Value))
        )
        """
    }
}

// MARK: - Hashable Conformance

extension TPHIDDevice: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(deviceRef))
    }
    
    public static func == (lhs: TPHIDDevice, rhs: TPHIDDevice) -> Bool {
        return lhs.deviceRef == rhs.deviceRef
    }
}

// MARK: - Identifiable Conformance

extension TPHIDDevice: Identifiable {
    public var id: ObjectIdentifier {
        return ObjectIdentifier(deviceRef)
    }
}
