import Foundation
import IOKit.hid
import CoreGraphics

/// Handles input events from HID devices and manages input state
@objcMembers
public final class TPInputHandler: NSObject {
    // MARK: - Properties
    
    /// Delegate for receiving input events
    public weak var delegate: TPInputHandlerDelegate?
    
    /// Current input state
    public let inputState: TPInputState
    
    // MARK: - Initialization
    
    public override init() {
        self.inputState = TPInputState.shared
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Handle an input value from a HID device
    /// - Parameter value: The HID value to process
    public func handleInput(_ value: IOHIDValue) {
        guard let element = IOHIDValueGetElement(value) else { return }
        
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        
        switch usagePage {
        case TPHIDUsage.Page.button:
            handleButtonInput(value)
            
        case TPHIDUsage.Page.genericDesktop:
            switch usage {
            case TPHIDUsage.GenericDesktop.x,
                 TPHIDUsage.GenericDesktop.y:
                handleMovementInput(value)
                
            case TPHIDUsage.GenericDesktop.wheel:
                let delta = Int(IOHIDValueGetIntegerValue(value))
                handleScrollInput(vertical: delta, horizontal: 0)
                
            default:
                break
            }
            
        default:
            break
        }
    }
    
    /// Handle button input from a HID device
    /// - Parameter value: The HID value containing button information
    public func handleButtonInput(_ value: IOHIDValue) {
        guard let element = IOHIDValueGetElement(value) else { return }
        
        let usage = IOHIDElementGetUsage(element)
        let buttonState = IOHIDValueGetIntegerValue(value) != 0
        
        switch usage {
        case 1: // Left button
            inputState.leftButtonDown = buttonState
            
        case 2: // Right button
            inputState.rightButtonDown = buttonState
            
        case 3: // Middle button
            inputState.middleButtonDown = buttonState
            if buttonState {
                inputState.enableScrollMode()
            } else {
                inputState.disableScrollMode()
            }
            
        default:
            break
        }
        
        // Notify delegate of button state change
        delegate?.didReceiveButtonPress?(
            left: inputState.leftButtonDown,
            right: inputState.rightButtonDown,
            middle: inputState.middleButtonDown
        )
    }
    
    /// Handle movement input from a HID device
    /// - Parameter value: The HID value containing movement information
    public func handleMovementInput(_ value: IOHIDValue) {
        guard let element = IOHIDValueGetElement(value) else { return }
        
        let usage = IOHIDElementGetUsage(element)
        let movement = Int(IOHIDValueGetIntegerValue(value))
        
        // Update pending deltas based on axis
        switch usage {
        case TPHIDUsage.GenericDesktop.x:
            inputState.pendingDeltaX = movement
            
        case TPHIDUsage.GenericDesktop.y:
            inputState.pendingDeltaY = movement
            
        default:
            return
        }
        
        // Only process movement if we have both X and Y deltas
        if inputState.pendingDeltaX != 0 || inputState.pendingDeltaY != 0 {
            let deltaX = inputState.pendingDeltaX
            let deltaY = inputState.pendingDeltaY
            let buttonState = inputState.currentButtonState()
            
            // Reset pending movements
            inputState.resetPendingMovements()
            
            // If in scroll mode, enforce cursor position
            if inputState.isScrollMode {
                inputState.enforceSavedCursorPosition()
            }
            
            // Notify delegate of movement
            delegate?.didReceiveMovement?(
                deltaX: deltaX,
                deltaY: deltaY,
                withButtonState: buttonState
            )
        }
    }
    
    /// Handle scroll input
    /// - Parameters:
    ///   - vertical: Vertical scroll delta
    ///   - horizontal: Horizontal scroll delta
    public func handleScrollInput(vertical: Int, horizontal: Int) {
        // Create and post scroll wheel event
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                   units: .pixel,
                                   wheelCount: 2,
                                   wheel1: Int32(vertical),
                                   wheel2: Int32(horizontal)) {
            // Apply natural scrolling if configured
            if TPConfig.shared.naturalScrolling {
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(-vertical))
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(-horizontal))
            }
            
            // Post the scroll event
            scrollEvent.post(tap: .cghidEventTap)
            
            // If in scroll mode, ensure cursor stays in place
            if inputState.isScrollMode {
                inputState.enforceSavedCursorPosition()
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension TPInputHandler: CustomStringConvertible {
    public var description: String {
        return """
        TPInputHandler(
            state: \(inputState)
        )
        """
    }
}
