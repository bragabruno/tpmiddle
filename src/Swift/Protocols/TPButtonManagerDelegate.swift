import Foundation

/// Protocol for receiving button manager events
@objc public protocol TPButtonManagerDelegate: AnyObject {
    /// Called when the middle button state changes
    @objc optional func middleButtonStateChanged(_ isPressed: Bool)
}
