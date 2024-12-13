import Foundation

/// Errors that can occur during HID operations
public enum TPHIDError: TPError {
    case deviceNotFound(String)
    case connectionFailed(String)
    case communicationError(String)
    case invalidResponse(String)
    case permissionDenied(String)
    case initializationFailed(String)
    case deviceAccessFailed(String)
    case invalidConfiguration(String)
    case unsupportedDevice(String)
    case timeout(String)
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .deviceNotFound,
             .connectionFailed,
             .communicationError:
            return .error
        case .invalidResponse,
             .timeout:
            return .warning
        case .permissionDenied,
             .initializationFailed,
             .deviceAccessFailed,
             .invalidConfiguration,
             .unsupportedDevice:
            return .critical
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "HID device not found: \(id)"
        case .connectionFailed(let reason):
            return "Failed to connect to HID device: \(reason)"
        case .communicationError(let details):
            return "HID communication error: \(details)"
        case .invalidResponse(let details):
            return "Invalid HID response: \(details)"
        case .permissionDenied(let permission):
            return "HID permission denied: \(permission)"
        case .initializationFailed(let reason):
            return "Failed to initialize HID manager: \(reason)"
        case .deviceAccessFailed(let details):
            return "Failed to access HID device: \(details)"
        case .invalidConfiguration(let details):
            return "Invalid HID configuration: \(details)"
        case .unsupportedDevice(let details):
            return "Unsupported HID device: \(details)"
        case .timeout(let operation):
            return "HID operation timed out: \(operation)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .deviceNotFound:
            return "The specified HID device could not be found on the system"
        case .connectionFailed:
            return "Could not establish a connection with the HID device"
        case .communicationError:
            return "An error occurred while communicating with the HID device"
        case .invalidResponse:
            return "The HID device returned an unexpected response"
        case .permissionDenied:
            return "The application doesn't have permission to access the HID device"
        case .initializationFailed:
            return "The HID manager could not be initialized properly"
        case .deviceAccessFailed:
            return "The system denied access to the HID device"
        case .invalidConfiguration:
            return "The HID device configuration is invalid or unsupported"
        case .unsupportedDevice:
            return "The HID device is not supported by this application"
        case .timeout:
            return "The HID operation took too long to complete"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Please check if the device is properly connected and powered on"
        case .connectionFailed:
            return "Try disconnecting and reconnecting the device"
        case .communicationError:
            return "Try reconnecting the device or restart the application"
        case .invalidResponse:
            return "Try updating the device firmware or restart the application"
        case .permissionDenied:
            return "Grant HID device access permissions in System Settings > Security & Privacy"
        case .initializationFailed:
            return "Try restarting the application. If the problem persists, check system resources"
        case .deviceAccessFailed:
            return "Check device permissions and try reconnecting the device"
        case .invalidConfiguration:
            return "Check the device configuration and ensure it's compatible"
        case .unsupportedDevice:
            return "Check the list of supported devices in the documentation"
        case .timeout:
            return "Try the operation again. If the problem persists, check the device connection"
        }
    }
}
