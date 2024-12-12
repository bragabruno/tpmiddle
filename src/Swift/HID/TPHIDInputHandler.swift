import Foundation
import IOKit.hid
import os

/// Handles input processing from HID devices
final class TPHIDInputHandler {
    // MARK: - Properties
    
    private weak var delegate: TPHIDManagerDelegate?
    private let logger = Logger(subsystem: "com.tpmiddle", category: "hid.input")
    
    // MARK: - Initialization
    
    init(delegate: TPHIDManagerDelegate?) {
        self.delegate = delegate
    }
    
    // MARK: - Public Methods
    
    func handleInput(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let timestamp = IOHIDValueGetTimeStamp(value)
        
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)
        
        // Handle button input
        if usagePage == kHIDPage_Button {
            handleButtonInput(usage: usage, value: intValue)
        }
        // Handle movement input
        else if usagePage == kHIDPage_GenericDesktop {
            handleMovementInput(usage: usage, value: intValue)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleButtonInput(usage: UInt32, value: CFIndex) {
        var left = false
        var right = false
        var middle = false
        
        switch usage {
        case 1:  // Left button
            left = value == 1
        case 2:  // Right button
            right = value == 1
        case 3:  // Middle button
            middle = value == 1
        default:
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveButtonPress(left: left, right: right, middle: middle)
        }
    }
    
    private func handleMovementInput(usage: UInt32, value: CFIndex) {
        var deltaX = 0
        var deltaY = 0
        
        switch usage {
        case UInt32(kHIDUsage_GD_X):
            deltaX = Int(value)
        case UInt32(kHIDUsage_GD_Y):
            deltaY = Int(value)
        default:
            return
        }
        
        if deltaX != 0 || deltaY != 0 {
            DispatchQueue.main.async { [weak self] in
                // Get current button state (this is simplified, you might want to track actual button state)
                let buttonState: UInt8 = 0
                self?.delegate?.didReceiveMovement(deltaX: deltaX, deltaY: deltaY, buttonState: buttonState)
            }
        }
    }
}
