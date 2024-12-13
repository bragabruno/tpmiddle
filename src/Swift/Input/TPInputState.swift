import Foundation
import CoreGraphics
import AppKit

/// Manages the current state of input devices and scroll mode
@objcMembers
public final class TPInputState: NSObject {
    // MARK: - Constants
    
    private struct ButtonMask {
        static let left: UInt8 = 1 << 0
        static let right: UInt8 = 1 << 1
        static let middle: UInt8 = 1 << 2
    }
    
    // MARK: - Properties
    
    /// Whether the left button is currently pressed
    public var leftButtonDown = false
    
    /// Whether the right button is currently pressed
    public var rightButtonDown = false
    
    /// Whether the middle button is currently pressed
    public var middleButtonDown = false
    
    /// Whether scroll mode is currently active
    public var isScrollMode = false
    
    /// The saved cursor position during scroll mode
    public var savedCursorPosition = CGPoint.zero
    
    /// Pending X-axis movement
    public var pendingDeltaX = 0
    
    /// Pending Y-axis movement
    public var pendingDeltaY = 0
    
    /// Time of last movement
    public var lastMovementTime = Date()
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = TPInputState()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Reset all pending movements and update last movement time
    public func resetPendingMovements() {
        pendingDeltaX = 0
        pendingDeltaY = 0
        lastMovementTime = Date()
    }
    
    /// Get the current button state as a bitmask
    /// - Returns: Button state bitmask where each bit represents a button state
    public func currentButtonState() -> UInt8 {
        return (leftButtonDown ? ButtonMask.left : 0) |
               (rightButtonDown ? ButtonMask.right : 0) |
               (middleButtonDown ? ButtonMask.middle : 0)
    }
    
    /// Enable scroll mode and save current cursor position
    public func enableScrollMode() {
        guard !isScrollMode else { return }
        
        isScrollMode = true
        
        // Save current cursor position when entering scroll mode
        if let event = CGEvent(source: nil) {
            savedCursorPosition = event.location
            
            // Create a mouse moved event to ensure the cursor stays put
            if let moveEvent = CGEvent(mouseEventSource: nil,
                                     mouseType: .mouseMoved,
                                     mouseCursorPosition: savedCursorPosition,
                                     mouseButton: .left) {
                // Set flags to prevent cursor movement
                moveEvent.flags = .maskNonCoalesced
                moveEvent.setIntegerValueField(.mouseEventDeltaX, value: 0)
                moveEvent.setIntegerValueField(.mouseEventDeltaY, value: 0)
                
                // Post the event
                moveEvent.post(tap: .cghidEventTap)
            }
        }
        
        resetPendingMovements()
    }
    
    /// Disable scroll mode and reset cursor position
    public func disableScrollMode() {
        guard isScrollMode else { return }
        
        isScrollMode = false
        savedCursorPosition = .zero
        resetPendingMovements()
    }
    
    /// Enforce the saved cursor position during scroll mode
    public func enforceSavedCursorPosition() {
        guard isScrollMode && savedCursorPosition != .zero else { return }
        
        // Create a mouse moved event
        if let moveEvent = CGEvent(mouseEventSource: nil,
                                 mouseType: .mouseMoved,
                                 mouseCursorPosition: savedCursorPosition,
                                 mouseButton: .left) {
            // Set flags to prevent cursor movement
            moveEvent.flags = .maskNonCoalesced
            moveEvent.setIntegerValueField(.mouseEventDeltaX, value: 0)
            moveEvent.setIntegerValueField(.mouseEventDeltaY, value: 0)
            
            // Post the event with high priority
            moveEvent.post(tap: .cghidEventTap)
            
            // Double-check current position and correct if needed
            if let currentEvent = CGEvent(source: nil) {
                let currentPos = currentEvent.location
                
                if currentPos != savedCursorPosition {
                    // If position changed, force it back immediately
                    if let forceEvent = CGEvent(mouseEventSource: nil,
                                              mouseType: .mouseMoved,
                                              mouseCursorPosition: savedCursorPosition,
                                              mouseButton: .left) {
                        forceEvent.flags = .maskNonCoalesced
                        forceEvent.setIntegerValueField(.mouseEventDeltaX, value: 0)
                        forceEvent.setIntegerValueField(.mouseEventDeltaY, value: 0)
                        forceEvent.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension TPInputState: CustomStringConvertible {
    public var description: String {
        return """
        TPInputState(
            leftButton: \(leftButtonDown),
            rightButton: \(rightButtonDown),
            middleButton: \(middleButtonDown),
            scrollMode: \(isScrollMode),
            cursorPosition: \(savedCursorPosition),
            pendingDelta: (\(pendingDeltaX), \(pendingDeltaY))
        )
        """
    }
}
