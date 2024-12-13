import Foundation

/// Protocol representing a HID device
///
/// This protocol defines the contract for HID devices in the system.
/// Following Domain-Driven Design principles, this is a core domain entity.
protocol Device {
    /// The unique identifier of the device
    var id: String { get }
    
    /// The name of the device
    var name: String { get }
    
    /// Whether the device is currently connected
    var isConnected: Bool { get }
    
    /// The device type identifier
    var deviceType: String { get }
    
    /// The last error message if any, or nil if no error
    var lastError: String? { get }
    
    /// Reset the device to its default state
    /// - Returns: True if reset successful, false otherwise
    func reset() async throws -> Bool
}

/// Errors that can occur during device operations
enum DeviceError: LocalizedError {
    case resetFailed(String)
    case disconnected
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .resetFailed(let reason):
            return "Failed to reset device: \(reason)"
        case .disconnected:
            return "Device is not connected"
        case .invalidOperation(let reason):
            return "Invalid operation: \(reason)"
        }
    }
}

/// Default implementations for common device operations
extension Device {
    /// Validates that the device is connected before performing operations
    /// - Throws: DeviceError.disconnected if the device is not connected
    func validateConnection() throws {
        guard isConnected else {
            throw DeviceError.disconnected
        }
    }
    
    /// Resets the device with validation
    /// - Returns: True if reset successful, false otherwise
    /// - Throws: DeviceError if the device is not connected or reset fails
    func resetWithValidation() async throws -> Bool {
        try validateConnection()
        
        do {
            return try await reset()
        } catch {
            throw DeviceError.resetFailed(error.localizedDescription)
        }
    }
}

/// A concrete implementation of a HID device
final class HIDDevice: Device {
    let id: String
    let name: String
    private(set) var isConnected: Bool
    let deviceType: String
    private(set) var lastError: String?
    
    init(id: String, name: String, deviceType: String) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.isConnected = false
        self.lastError = nil
    }
    
    /// Updates the connection status of the device
    /// - Parameter connected: The new connection status
    func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
    }
    
    /// Updates the last error message
    /// - Parameter error: The error message to store
    func updateLastError(_ error: String?) {
        lastError = error
    }
    
    /// Resets the device to its default state
    /// - Returns: True if reset successful, false otherwise
    func reset() async throws -> Bool {
        try validateConnection()
        
        // Implement actual reset logic here
        // For now, just return true to indicate success
        return true
    }
}

/// Protocol for observing device state changes
protocol DeviceObserver: AnyObject {
    /// Called when a device's connection status changes
    /// - Parameters:
    ///   - device: The device that changed status
    ///   - connected: The new connection status
    func device(_ device: Device, didChangeConnectionStatus connected: Bool)
    
    /// Called when a device encounters an error
    /// - Parameters:
    ///   - device: The device that encountered the error
    ///   - error: The error message
    func device(_ device: Device, didEncounterError error: String)
}

/// A device manager that maintains a collection of devices
final class DeviceManager {
    /// Singleton instance
    static let shared = DeviceManager()
    
    /// The collection of managed devices
    private var devices: [String: Device] = [:]
    
    /// Device observers
    private var observers: [ObjectIdentifier: WeakDeviceObserver] = [:]
    
    private init() {}
    
    /// Adds a device to the manager
    /// - Parameter device: The device to add
    func addDevice(_ device: Device) {
        devices[device.id] = device
    }
    
    /// Removes a device from the manager
    /// - Parameter deviceId: The ID of the device to remove
    func removeDevice(withId deviceId: String) {
        devices.removeValue(forKey: deviceId)
    }
    
    /// Gets a device by its ID
    /// - Parameter deviceId: The ID of the device to get
    /// - Returns: The device if found, nil otherwise
    func getDevice(withId deviceId: String) -> Device? {
        return devices[deviceId]
    }
    
    /// Adds an observer for device events
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: DeviceObserver) {
        let id = ObjectIdentifier(observer as AnyObject)
        observers[id] = WeakDeviceObserver(observer)
    }
    
    /// Removes an observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: DeviceObserver) {
        let id = ObjectIdentifier(observer as AnyObject)
        observers.removeValue(forKey: id)
    }
    
    /// Notifies observers of a connection status change
    /// - Parameters:
    ///   - device: The device that changed status
    ///   - connected: The new connection status
    private func notifyConnectionStatusChange(for device: Device, connected: Bool) {
        observers.values.forEach { weakObserver in
            weakObserver.observer?.device(device, didChangeConnectionStatus: connected)
        }
    }
    
    /// Notifies observers of a device error
    /// - Parameters:
    ///   - device: The device that encountered the error
    ///   - error: The error message
    private func notifyError(for device: Device, error: String) {
        observers.values.forEach { weakObserver in
            weakObserver.observer?.device(device, didEncounterError: error)
        }
    }
}

/// Wrapper to hold weak references to observers
private class WeakDeviceObserver {
    weak var observer: DeviceObserver?
    
    init(_ observer: DeviceObserver) {
        self.observer = observer
    }
}
