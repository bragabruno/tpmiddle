import Foundation
import IOKit.hid

final class TPHIDDevice {
    // MARK: - Properties
    
    let device: IOHIDDevice
    let name: String
    let vendorID: Int
    let productID: Int
    let serialNumber: String?
    let manufacturer: String?
    let transport: String?
    
    private(set) var isConnected: Bool
    
    // MARK: - Initialization
    
    init?(device: IOHIDDevice) {
        self.device = device
        
        // Get device properties
        guard let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int else {
            return nil
        }
        
        self.vendorID = vendorID
        self.productID = productID
        
        // Get optional properties
        self.name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
        self.serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String
        self.manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String
        self.transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
        
        self.isConnected = true
    }
    
    // MARK: - Public Methods
    
    func open() -> Bool {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        return result == kIOReturnSuccess
    }
    
    func close() {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        isConnected = false
    }
    
    func setInputValueCallback(_ callback: @escaping IOHIDValueCallback) {
        IOHIDDeviceRegisterInputValueCallback(device, callback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    func setRemovalCallback(_ callback: @escaping IOHIDCallback) {
        IOHIDDeviceRegisterRemovalCallback(device, callback, Unmanaged.passUnretained(self).toOpaque())
    }
}

// MARK: - CustomStringConvertible

extension TPHIDDevice: CustomStringConvertible {
    var description: String {
        """
        HID Device:
        - Name: \(name)
        - Vendor ID: 0x\(String(format: "%04X", vendorID))
        - Product ID: 0x\(String(format: "%04X", productID))
        - Serial Number: \(serialNumber ?? "N/A")
        - Manufacturer: \(manufacturer ?? "N/A")
        - Transport: \(transport ?? "N/A")
        - Connected: \(isConnected ? "Yes" : "No")
        """
    }
}

// MARK: - Equatable

extension TPHIDDevice: Equatable {
    static func == (lhs: TPHIDDevice, rhs: TPHIDDevice) -> Bool {
        lhs.device == rhs.device
    }
}

// MARK: - Hashable

extension TPHIDDevice: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(device)
    }
}

// MARK: - Device Properties

extension TPHIDDevice {
    var usagePage: Int {
        IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
    }
    
    var usage: Int {
        IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
    }
    
    var locationID: Int {
        IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? Int ?? 0
    }
    
    var uniqueID: String {
        "\(vendorID)-\(productID)-\(locationID)"
    }
}
