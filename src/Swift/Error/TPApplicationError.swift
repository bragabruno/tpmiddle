import Foundation

/// Application-specific errors
public enum TPApplicationError: TPError {
    case componentInitializationFailed(String)
    case resourceNotFound(String)
    case invalidConfiguration(String)
    case operationFailed(String)
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .componentInitializationFailed:
            return .critical
        case .resourceNotFound:
            return .error
        case .invalidConfiguration:
            return .error
        case .operationFailed:
            return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .componentInitializationFailed(let component):
            return "Failed to initialize component: \(component)"
        case .resourceNotFound(let resource):
            return "Required resource not found: \(resource)"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .operationFailed(let operation):
            return "Operation failed: \(operation)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .componentInitializationFailed:
            return "A critical application component could not be initialized"
        case .resourceNotFound:
            return "A required application resource is missing"
        case .invalidConfiguration:
            return "The application configuration is invalid or incomplete"
        case .operationFailed:
            return "The requested operation could not be completed"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .componentInitializationFailed:
            return "Try restarting the application. If the problem persists, try reinstalling."
        case .resourceNotFound:
            return "Try reinstalling the application to restore missing resources"
        case .invalidConfiguration:
            return "Check the application settings and configuration files"
        case .operationFailed:
            return "Try the operation again. If the problem persists, restart the application."
        }
    }
}
