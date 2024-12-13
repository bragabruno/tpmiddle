import Foundation

/// Protocol for receiving event viewer updates
@objc public protocol TPEventViewControllerDelegate: AnyObject {
    /// Called when monitoring state changes
    @objc optional func eventViewerDidStartMonitoring()
    @objc optional func eventViewerDidStopMonitoring()
    
    /// Called when significant events occur
    @objc optional func eventViewerDidReceiveMovement(deltaX: Int, deltaY: Int, buttons: UInt8)
    @objc optional func eventViewerDidReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
}
