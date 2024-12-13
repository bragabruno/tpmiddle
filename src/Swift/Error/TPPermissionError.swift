import Foundation

/// Permission-related errors
public enum TPPermissionError: TPError {
    case inputMonitoringDenied
    case accessibilityDenied
    case multiplePermissionsDenied
    case systemPreferencesError
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .inputMonitoringDenied,
             .accessibilityDenied,
             .multiplePermissionsDenied:
            return .critical
        case .systemPreferencesError:
            return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .inputMonitoringDenied:
            return "Input Monitoring permission is required"
        case .accessibilityDenied:
            return "Accessibility permission is required"
        case .multiplePermissionsDenied:
            return "Multiple required permissions are missing"
        case .systemPreferencesError:
            return "Failed to open System Preferences"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .inputMonitoringDenied:
            return "TPMiddle needs Input Monitoring permission to detect device inputs"
        case .accessibilityDenied:
            return "TPMiddle needs Accessibility permission to control system features"
        case .multiplePermissionsDenied:
            return "TPMiddle requires multiple system permissions to function properly"
        case .systemPreferencesError:
            return "Could not open System Preferences to manage permissions"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .inputMonitoringDenied:
            return "Open System Settings > Privacy & Security > Input Monitoring and enable TPMiddle"
        case .accessibilityDenied:
            return "Open System Settings > Privacy & Security > Accessibility and enable TPMiddle"
        case .multiplePermissionsDenied:
            return "Open System Settings > Privacy & Security and enable all required permissions for TPMiddle"
        case .systemPreferencesError:
            return "Try opening System Settings manually to manage permissions"
        }
    }
}
