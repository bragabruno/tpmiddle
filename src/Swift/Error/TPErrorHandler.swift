import Cocoa
import Combine

/// Handles application errors and exceptions
public final class TPErrorHandler {
    // MARK: - Types
    
    /// Error severity level
    public enum Severity {
        case debug
        case info
        case warning
        case error
        case critical
        
        var title: String {
            switch self {
            case .debug: return "Debug"
            case .info: return "Information"
            case .warning: return "Warning"
            case .error: return "Error"
            case .critical: return "Critical Error"
            }
        }
        
        var alertStyle: NSAlert.Style {
            switch self {
            case .debug, .info:
                return .informational
            case .warning:
                return .warning
            case .error, .critical:
                return .critical
            }
        }
    }
    
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = TPErrorHandler()
    
    /// Publisher for error events
    @available(macOS 10.15, *)
    public let errorPublisher = PassthroughSubject<(Error, Severity), Never>()
    
    // MARK: - Private Properties
    
    private let queue = DispatchQueue(label: "com.tpmiddle.errorhandler", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handle an error with specified severity
    /// - Parameters:
    ///   - error: The error to handle
    ///   - severity: The severity level of the error
    ///   - showAlert: Whether to show an alert to the user
    public func handle(_ error: Error, severity: Severity = .error, showAlert: Bool = true) {
        queue.async { [weak self] in
            // Log the error
            self?.logError(error, severity: severity)
            
            // Publish error event
            if #available(macOS 10.15, *) {
                self?.errorPublisher.send((error, severity))
            }
            
            // Show alert if requested
            if showAlert {
                self?.showError(error, severity: severity)
            }
        }
    }
    
    /// Handle an exception
    /// - Parameter exception: The exception to handle
    public func handle(_ exception: NSException) {
        queue.async { [weak self] in
            // Log the exception
            self?.logException(exception)
            
            // Convert to error and publish
            let error = NSError(
                domain: "TPMiddle",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "An exception occurred: \(exception.name.rawValue)",
                    NSLocalizedFailureReasonErrorKey: exception.reason ?? "Unknown reason",
                    "ExceptionCallStackSymbols": exception.callStackSymbols
                ]
            )
            
            if #available(macOS 10.15, *) {
                self?.errorPublisher.send((error, .critical))
            }
            
            // Show alert
            self?.showError(error, severity: .critical)
        }
    }
    
    /// Log an error without showing an alert
    /// - Parameters:
    ///   - error: The error to log
    ///   - severity: The severity level of the error
    public func logError(_ error: Error, severity: Severity = .error) {
        let message: String
        
        if let localizedError = error as? LocalizedError {
            message = """
            [\(severity.title)]
            Description: \(localizedError.localizedDescription)
            Failure Reason: \(localizedError.failureReason ?? "None")
            Recovery Suggestion: \(localizedError.recoverySuggestion ?? "None")
            """
        } else {
            message = "[\(severity.title)] \(error.localizedDescription)"
        }
        
        TPLogger.shared.log(message)
    }
    
    /// Log an exception
    /// - Parameter exception: The exception to log
    public func logException(_ exception: NSException) {
        let message = """
        [Exception]
        Name: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        User Info: \(exception.userInfo?.description ?? "None")
        Call Stack:
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        
        TPLogger.shared.log(message)
    }
    
    // MARK: - Private Methods
    
    private func showError(_ error: Error, severity: Severity) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "TPMiddle \(severity.title)"
            
            if let localizedError = error as? LocalizedError {
                alert.informativeText = localizedError.localizedDescription
                
                if let failureReason = localizedError.failureReason {
                    alert.informativeText += "\n\nReason: \(failureReason)"
                }
                
                if let recoverySuggestion = localizedError.recoverySuggestion {
                    alert.informativeText += "\n\nSuggestion: \(recoverySuggestion)"
                }
            } else {
                alert.informativeText = error.localizedDescription
            }
            
            alert.alertStyle = severity.alertStyle
            alert.addButton(withTitle: "OK")
            
            if severity == .critical {
                alert.addButton(withTitle: "Quit")
            }
            
            let response = alert.runModal()
            if severity == .critical && response == .alertSecondButtonReturn {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Error Types

/// Base protocol for TPMiddle errors
public protocol TPError: LocalizedError {
    var severity: TPErrorHandler.Severity { get }
}

/// System-level errors
public enum TPSystemError: TPError {
    case permissionDenied(String)
    case resourceNotFound(String)
    case initializationFailed(String)
    case operationFailed(String)
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .permissionDenied:
            return .critical
        case .resourceNotFound:
            return .error
        case .initializationFailed:
            return .critical
        case .operationFailed:
            return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        case .initializationFailed(let component):
            return "Failed to initialize: \(component)"
        case .operationFailed(let operation):
            return "Operation failed: \(operation)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "The application doesn't have the required permissions"
        case .resourceNotFound:
            return "A required resource could not be located"
        case .initializationFailed:
            return "A component failed to initialize properly"
        case .operationFailed:
            return "An operation could not be completed"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant the required permissions in System Settings"
        case .resourceNotFound:
            return "Try reinstalling the application"
        case .initializationFailed:
            return "Try restarting the application"
        case .operationFailed:
            return "Try the operation again"
        }
    }
}
