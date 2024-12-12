import Foundation

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
