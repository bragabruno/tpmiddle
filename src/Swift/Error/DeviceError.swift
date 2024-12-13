import Foundation

/// Device-specific errors
public enum DeviceError: TPError {
    case disconnected
    case resetFailed(String)
    case invalidOperation(String)
    case communicationFailed(String)
    case timeout(String)
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .disconnected:
            return .warning
        case .resetFailed:
            return .error
        case .invalidOperation:
            return .error
        case .communicationFailed:
            return .error
        case .timeout:
            return .warning
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .disconnected:
            return "Device is disconnected"
        case .resetFailed(let reason):
            return "Failed to reset device: \(reason)"
        case .invalidOperation(let operation):
            return "Invalid device operation: \(operation)"
        case .communicationFailed(let detail):
            return "Device communication failed: \(detail)"
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .disconnected:
            return "The device is not connected to the system"
        case .resetFailed:
            return "The device reset operation failed to complete"
        case .invalidOperation:
            return "The requested operation is not valid for this device"
        case .communicationFailed:
            return "Could not communicate with the device"
        case .timeout:
            return "The operation took too long to complete"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .disconnected:
            return "Check if the device is properly connected and powered on"
        case .resetFailed:
            return "Try disconnecting and reconnecting the device"
        case .invalidOperation:
            return "Verify that the device supports this operation"
        case .communicationFailed:
            return "Check the device connection and try again"
        case .timeout:
            return "Try the operation again. If the problem persists, check the device connection"
        }
    }
}
