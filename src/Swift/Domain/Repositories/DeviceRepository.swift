import Foundation

// Import our Device model from the same module
import struct TPMiddle.Device

/// Protocol defining the contract for Device persistence operations
///
/// This protocol defines the interface for Device persistence operations.
/// Following the Repository pattern, it abstracts the data access layer.
protocol DeviceRepository: AnyObject {
    /// Find a device by its ID
    /// - Parameter id: The device ID to search for
    /// - Returns: The device if found, nil otherwise
    /// - Throws: RepositoryError if the operation fails
    func findById(_ id: String) async throws -> Device?
    
    /// Get all connected devices
    /// - Returns: List of all connected devices
    /// - Throws: RepositoryError if the operation fails
    func getConnectedDevices() async throws -> [Device]
    
    /// Get devices by type
    /// - Parameter deviceType: The type of devices to retrieve
    /// - Returns: List of devices of the specified type
    /// - Throws: RepositoryError if the operation fails
    func getDevicesByType(_ deviceType: String) async throws -> [Device]
    
    /// Add a new device to the repository
    /// - Parameter device: The device to add
    /// - Throws: RepositoryError if the operation fails
    func add(_ device: Device) async throws
    
    /// Remove a device from the repository
    /// - Parameter id: The ID of the device to remove
    /// - Throws: RepositoryError if the operation fails or device not found
    func remove(id: String) async throws
    
    /// Update device information
    /// - Parameter device: The device with updated information
    /// - Throws: RepositoryError if the operation fails or device not found
    func update(_ device: Device) async throws
    
    /// Add an observer for repository events
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: DeviceRepositoryObserver)
    
    /// Remove an observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: DeviceRepositoryObserver)
}

/// Errors that can occur during repository operations
enum RepositoryError: LocalizedError {
    case deviceNotFound(String)
    case deviceAlreadyExists(String)
    case operationFailed(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Device not found with ID: \(id)"
        case .deviceAlreadyExists(let id):
            return "Device already exists with ID: \(id)"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        }
    }
}

/// A concrete implementation of DeviceRepository using in-memory storage
final class InMemoryDeviceRepository: DeviceRepository {
    /// Thread-safe storage for devices
    private let queue = DispatchQueue(label: "com.tpmiddle.devicerepository", attributes: .concurrent)
    private var devices: [String: Device] = [:]
    private var observers: [ObjectIdentifier: WeakRepositoryObserver] = [:]
    
    /// Singleton instance
    static let shared = InMemoryDeviceRepository()
    
    private init() {}
    
    func findById(_ id: String) async throws -> Device? {
        queue.sync { devices[id] }
    }
    
    func getConnectedDevices() async throws -> [Device] {
        queue.sync { devices.values.filter { $0.isConnected } }
    }
    
    func getDevicesByType(_ deviceType: String) async throws -> [Device] {
        queue.sync { devices.values.filter { $0.deviceType == deviceType } }
    }
    
    func add(_ device: Device) async throws {
        try queue.sync(flags: .barrier) {
            guard devices[device.id] == nil else {
                throw RepositoryError.deviceAlreadyExists(device.id)
            }
            devices[device.id] = device
            notifyDeviceAdded(device)
        }
    }
    
    func remove(id: String) async throws {
        try queue.sync(flags: .barrier) {
            guard devices[id] != nil else {
                throw RepositoryError.deviceNotFound(id)
            }
            devices.removeValue(forKey: id)
            notifyDeviceRemoved(id)
        }
    }
    
    func update(_ device: Device) async throws {
        try queue.sync(flags: .barrier) {
            guard devices[device.id] != nil else {
                throw RepositoryError.deviceNotFound(device.id)
            }
            devices[device.id] = device
            notifyDeviceUpdated(device)
        }
    }
    
    func addObserver(_ observer: DeviceRepositoryObserver) {
        queue.sync(flags: .barrier) {
            let id = ObjectIdentifier(observer as AnyObject)
            observers[id] = WeakRepositoryObserver(observer)
        }
    }
    
    func removeObserver(_ observer: DeviceRepositoryObserver) {
        queue.sync(flags: .barrier) {
            let id = ObjectIdentifier(observer as AnyObject)
            observers.removeValue(forKey: id)
        }
    }
    
    /// Notify observers of device addition
    private func notifyDeviceAdded(_ device: Device) {
        observers.values.forEach { weakObserver in
            weakObserver.observer?.deviceRepository(self, didAddDevice: device)
        }
    }
    
    /// Notify observers of device removal
    private func notifyDeviceRemoved(_ deviceId: String) {
        observers.values.forEach { weakObserver in
            weakObserver.observer?.deviceRepository(self, didRemoveDeviceWithId: deviceId)
        }
    }
    
    /// Notify observers of device update
    private func notifyDeviceUpdated(_ device: Device) {
        observers.values.forEach { weakObserver in
            weakObserver.observer?.deviceRepository(self, didUpdateDevice: device)
        }
    }
}

/// Protocol for observing repository changes
protocol DeviceRepositoryObserver: AnyObject {
    /// Called when a device is added to the repository
    /// - Parameter device: The device that was added
    func deviceRepository(_ repository: DeviceRepository, didAddDevice device: Device)
    
    /// Called when a device is removed from the repository
    /// - Parameter deviceId: The ID of the device that was removed
    func deviceRepository(_ repository: DeviceRepository, didRemoveDeviceWithId deviceId: String)
    
    /// Called when a device is updated in the repository
    /// - Parameter device: The updated device
    func deviceRepository(_ repository: DeviceRepository, didUpdateDevice device: Device)
}

/// Wrapper to hold weak references to repository observers
private class WeakRepositoryObserver {
    weak var observer: DeviceRepositoryObserver?
    
    init(_ observer: DeviceRepositoryObserver) {
        self.observer = observer
    }
}
