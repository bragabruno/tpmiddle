import Foundation

/// Protocol defining the interface for HID manager event handling
public protocol TPHIDManagerDelegate: AnyObject {
    func didDetectDeviceAttached(_ deviceInfo: String)
    func didDetectDeviceDetached(_ deviceInfo: String)
    func didEncounterError(_ error: Error)
    func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
    func didReceiveMovement(deltaX: Int, deltaY: Int, buttonState: UInt8)
}

/// Errors that can occur during HID operations
public enum TPHIDError: LocalizedError {
    case hidError(String)
    
    public var errorDescription: String? {
        switch self {
        case .hidError(let message):
            return "HID error: \(message)"
        }
    }
}
