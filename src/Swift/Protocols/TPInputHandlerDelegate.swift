import Foundation

/// Protocol for receiving input handler events
@objc public protocol TPInputHandlerDelegate: AnyObject {
    /// Called when a button press is detected
    @objc optional func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
    
    /// Called when movement is detected
    @objc optional func didReceiveMovement(deltaX: Int, deltaY: Int, withButtonState buttons: UInt8)
}
