import Foundation

/// Operation modes for the application
@objc public enum TPOperationMode: Int {
    /// Default operation mode
    case `default`
    
    /// Normal operation mode
    case normal
    
    /// String representation of the mode
    public var description: String {
        switch self {
        case .default:
            return "Default"
        case .normal:
            return "Normal"
        }
    }
}
