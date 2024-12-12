import Foundation

// MARK: - Protocols

/// Protocol defining the interface for HID manager event handling
protocol TPHIDManagerDelegate: AnyObject {
    /// Called when a new HID device is attached
    func didDetectDeviceAttached(_ deviceInfo: String)
    
    /// Called when a HID device is detached
    func didDetectDeviceDetached(_ deviceInfo: String)
    
    /// Called when an error occurs during HID operations
    func didEncounterError(_ error: Error)
    
    /// Called when a button press is detected
    func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
    
    /// Called when movement is detected
    func didReceiveMovement(deltaX: Int, deltaY: Int, buttonState: UInt8)
}

// MARK: - Error Types

/// Errors that can occur during HID operations
enum TPHIDError: LocalizedError {
    case hidError(String)
    
    var errorDescription: String? {
        switch self {
        case .hidError(let message):
            return "HID error: \(message)"
        }
    }
}
