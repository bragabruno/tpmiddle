import Foundation

/// Repository-specific errors
public enum RepositoryError: TPError {
    case deviceNotFound(String)
    case deviceAlreadyExists(String)
    case invalidData(String)
    case persistenceFailed(String)
    case concurrencyError(String)
    
    public var severity: TPErrorHandler.Severity {
        switch self {
        case .deviceNotFound:
            return .warning
        case .deviceAlreadyExists:
            return .warning
        case .invalidData:
            return .error
        case .persistenceFailed:
            return .error
        case .concurrencyError:
            return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Device not found: \(id)"
        case .deviceAlreadyExists(let id):
            return "Device already exists: \(id)"
        case .invalidData(let detail):
            return "Invalid data: \(detail)"
        case .persistenceFailed(let operation):
            return "Failed to persist data: \(operation)"
        case .concurrencyError(let detail):
            return "Concurrency error: \(detail)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .deviceNotFound:
            return "The requested device does not exist in the repository"
        case .deviceAlreadyExists:
            return "A device with this identifier already exists"
        case .invalidData:
            return "The data provided is invalid or corrupted"
        case .persistenceFailed:
            return "Could not save or load data from storage"
        case .concurrencyError:
            return "A concurrent operation conflict occurred"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Verify the device identifier and try again"
        case .deviceAlreadyExists:
            return "Use a different identifier or update the existing device"
        case .invalidData:
            return "Check the data format and try again"
        case .persistenceFailed:
            return "Check storage permissions and available space"
        case .concurrencyError:
            return "Try the operation again"
        }
    }
}
