import Foundation

/// Protocol for managing application state and lifecycle
@objc public protocol TPApplicationDelegate: AnyObject {
    /// Called when the application state changes
    @objc optional func applicationDidChangeState(_ state: TPApplicationState)
    
    /// Called when a critical error occurs
    @objc optional func applicationDidEncounterCriticalError(_ error: Error)
    
    /// Called when permissions change
    @objc optional func applicationDidUpdatePermissions(granted: Bool)
    
    /// Called when device connectivity changes
    @objc optional func applicationDidUpdateDeviceConnectivity(connected: Bool)
}

/// Application states
@objc public enum TPApplicationState: Int {
    case notInitialized
    case initializing
    case checkingPermissions
    case waitingForPermissions
    case starting
    case running
    case stopping
    case stopped
    case error
    
    public var description: String {
        switch self {
        case .notInitialized: return "Not Initialized"
        case .initializing: return "Initializing"
        case .checkingPermissions: return "Checking Permissions"
        case .waitingForPermissions: return "Waiting for Permissions"
        case .starting: return "Starting"
        case .running: return "Running"
        case .stopping: return "Stopping"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}
