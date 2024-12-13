import Foundation

/// Protocol for receiving status bar controller events
@objc public protocol TPStatusBarControllerDelegate: AnyObject {
    /// Called when the user initiates a quit action
    @objc optional func statusBarControllerWillQuit()
    
    /// Called when the event viewer visibility changes
    /// - Parameter show: Whether the event viewer should be shown
    @objc optional func statusBarControllerDidToggleEventViewer(_ show: Bool)
}
