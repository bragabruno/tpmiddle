import Cocoa
import os.log

// Import local modules
@_exported import class Foundation.NSException

final class TPErrorHandler {
    static let shared = TPErrorHandler()
    
    // MARK: - Properties
    
    private let logger: os.Logger
    
    // MARK: - Initialization
    
    private init() {
        self.logger = os.Logger(subsystem: "com.tpmiddle", category: "error")
    }
    
    // MARK: - Public Methods
    
    func showError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            alert.runModal()
        }
    }
    
    func logError(_ error: Error) {
        logger.error("\(error.localizedDescription)")
        
        if let nsError = error as NSError? {
            logger.error("Domain: \(nsError.domain)")
            logger.error("Code: \(nsError.code)")
            
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                logger.error("Underlying error: \(underlyingError)")
            }
        }
    }
    
    func logException(_ exception: NSException) {
        logger.error("Exception: \(exception.name.rawValue)")
        logger.error("Reason: \(exception.reason ?? "Unknown reason")")
        
        if let callStackSymbols = exception.callStackSymbols as? [String] {
            logger.error("Call stack:")
            callStackSymbols.forEach { symbol in
                logger.error("  \(symbol)")
            }
        }
    }
}

// MARK: - Error Types

enum TPError: LocalizedError {
    case permissionDenied(String)
    case deviceNotFound(String)
    case configurationError(String)
    case hidError(String)
    case resourceNotFound(String)
    case managerInitializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .deviceNotFound(let message):
            return "Device not found: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .hidError(let message):
            return "HID error: \(message)"
        case .resourceNotFound(let message):
            return "Resource not found: \(message)"
        case .managerInitializationFailed(let message):
            return "Manager initialization failed: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "The application does not have the required permissions."
        case .deviceNotFound:
            return "The requested device could not be found or accessed."
        case .configurationError:
            return "There was an error in the application configuration."
        case .hidError:
            return "An error occurred while interacting with the HID system."
        case .resourceNotFound:
            return "A required resource file or asset could not be found."
        case .managerInitializationFailed:
            return "A system component failed to initialize properly."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please check the application permissions in System Preferences."
        case .deviceNotFound:
            return "Please ensure your device is properly connected and try again."
        case .configurationError:
            return "Try resetting the application preferences or reinstalling the application."
        case .hidError:
            return "Try disconnecting and reconnecting your device, or restart the application."
        case .resourceNotFound:
            return "Try reinstalling the application to restore missing resources."
        case .managerInitializationFailed:
            return "Try restarting the application. If the problem persists, please reinstall."
        }
    }
}
