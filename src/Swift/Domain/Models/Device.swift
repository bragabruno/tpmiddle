import Foundation

/// Represents a connected device
public protocol Device {
    /// Unique identifier for the device
    var id: String { get }
    
    /// Type of the device
    var deviceType: String { get }
    
    /// Whether the device is currently connected
    var isConnected: Bool { get }
    
    /// Reset the device to its default state
    /// - Returns: True if reset successful, false otherwise
    /// - Throws: DeviceError if the device is not connected or reset fails
    func reset() async throws -> Bool
}

extension Device {
    /// Validates that the device is connected before performing operations
    /// - Throws: DeviceError.disconnected if the device is not connected
    func validateConnection() throws {
        guard isConnected else {
            throw DeviceError.disconnected
        }
    }
    
    /// Reset the device with connection validation
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
