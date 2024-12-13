import Foundation
import CoreGraphics
import IOKit.hid
import AppKit

/// Handles HID input events and manages button states and cursor behavior
@objcMembers
public final class TPHIDInputHandler: NSObject {
    // MARK: - Properties
    
    /// Delegate for receiving input events
    public weak var delegate: TPHIDManagerDelegate?
    
    // MARK: - Private Properties
    
    private var leftButtonDown = false
    private var rightButtonDown = false
    private var middleButtonDown = false
    private var savedCursorPosition = CGPoint.zero
    
    private let stateLock = NSLock()
    private let inputQueue = DispatchQueue(label: "com.tpmiddle.inputhandler", qos: .userInteractive)
    
    private var eventTap: CFMachPort?
    private var eventTapSource: DispatchSourceMachReceive?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupEventTap()
    }
    
    deinit {
        reset()
        teardownEventTap()
    }
    
    // MARK: - Public Methods
    
    /// Reset all button states and cursor behavior
    public func reset() {
        stateLock.lock()
        leftButtonDown = false
        rightButtonDown = false
        middleButtonDown = false
        savedCursorPosition = .zero
        CGAssociateMouseAndMouseCursorPosition(true)
        stateLock.unlock()
    }
    
    /// Check if the middle button is currently held down
    /// - Returns: True if middle button is held, false otherwise
    public func isMiddleButtonHeld() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return middleButtonDown
    }
    
    /// Handle an input value from a HID device
    /// - Parameter value: The HID value to process
    public func handleInput(_ value: IOHIDValue) {
        // Retain the value for async processing
        let retained = Unmanaged.passRetained(value as CFTypeRef)
        
        inputQueue.async { [weak self] in
            guard let self = self else {
                retained.release()
                return
            }
            
            autoreleasepool {
                self.processInputValue(value)
                retained.release()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEventTap() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Clean up existing tap if any
            self.teardownEventTap()
            
            // Create event tap
            let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                           (1 << CGEventType.leftMouseDragged.rawValue) |
                           (1 << CGEventType.rightMouseDragged.rawValue) |
                           (1 << CGEventType.otherMouseDragged.rawValue) |
                           (1 << CGEventType.leftMouseDown.rawValue) |
                           (1 << CGEventType.leftMouseUp.rawValue) |
                           (1 << CGEventType.rightMouseDown.rawValue) |
                           (1 << CGEventType.rightMouseUp.rawValue) |
                           (1 << CGEventType.otherMouseDown.rawValue) |
                           (1 << CGEventType.otherMouseUp.rawValue)
            
            let callback: CGEventTapCallBack = { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                
                let handler = Unmanaged<TPHIDInputHandler>.fromOpaque(refcon).takeUnretainedValue()
                
                handler.stateLock.lock()
                let isMiddleButtonDown = handler.middleButtonDown
                let savedPosition = handler.savedCursorPosition
                handler.stateLock.unlock()
                
                // Only intercept events when middle button is held down
                if isMiddleButtonDown {
                    // Block all mouse movement events while middle button is held
                    if type.rawValue == CGEventType.mouseMoved.rawValue ||
                       type.rawValue == CGEventType.leftMouseDragged.rawValue ||
                       type.rawValue == CGEventType.rightMouseDragged.rawValue ||
                       type.rawValue == CGEventType.otherMouseDragged.rawValue {
                        DispatchQueue.main.async {
                            handler.enforceCursorPosition()
                        }
                        return nil
                    }
                    
                    // For any other event while middle button is held, force cursor position
                    if savedPosition != .zero {
                        event.location = savedPosition
                        DispatchQueue.main.async {
                            handler.enforceCursorPosition()
                        }
                    }
                }
                
                return Unmanaged.passUnretained(event)
            }
            
            let context = Unmanaged.passUnretained(self).toOpaque()
            
            self.eventTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: callback,
                userInfo: context
            )
            
            if let eventTap = self.eventTap {
                // Create run loop source
                let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
                if let runLoopSource = runLoopSource {
                    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                    
                    // Create dispatch source to monitor event tap
                    let port = CFMachPortGetPort(eventTap)
                    self.eventTapSource = DispatchSource.makeMachReceiveSource(port: port, queue: .main)
                    
                    self.eventTapSource?.setEventHandler { [weak self] in
                        guard let self = self,
                              let eventTap = self.eventTap else { return }
                        
                        // Re-enable if disabled
                        if !CGEvent.tapIsEnabled(tap: eventTap) {
                            CGEvent.tapEnable(tap: eventTap, enable: true)
                            TPLogger.shared.log("Re-enabled event tap")
                        }
                    }
                    
                    self.eventTapSource?.resume()
                }
            }
        }
    }
    
    private func teardownEventTap() {
        eventTapSource?.cancel()
        eventTapSource = nil
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            eventTap = nil
        }
    }
    
    private func enforceCursorPosition() {
        stateLock.lock()
        let isMiddleDown = middleButtonDown
        let savedPos = savedCursorPosition
        stateLock.unlock()
        
        if isMiddleDown && savedPos != .zero {
            CGWarpMouseCursorPosition(savedPos)
        }
    }
    
    private func processInputValue(_ value: IOHIDValue) {
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
                handleScrollInput(value)
            default:
                break
            }
        default:
            break
        }
    }
    
    private func handleButtonInput(_ value: IOHIDValue) {
        guard let element = IOHIDValueGetElement(value) else { return }
        
        let usage = IOHIDElementGetUsage(element)
        let buttonState = IOHIDValueGetIntegerValue(value)
        
        stateLock.lock()
        
        switch usage {
        case 1:
            leftButtonDown = buttonState != 0
        case 2:
            rightButtonDown = buttonState != 0
        case 3:
            if buttonState != 0 {
                // Middle button pressed
                middleButtonDown = true
                // Save cursor position
                if let event = CGEvent(source: nil) {
                    savedCursorPosition = event.location
                }
                // Disable mouse/cursor association
                CGAssociateMouseAndMouseCursorPosition(false)
            } else {
                // Middle button released
                middleButtonDown = false
                savedCursorPosition = .zero
                // Re-enable mouse/cursor association
                CGAssociateMouseAndMouseCursorPosition(true)
            }
        default:
            break
        }
        
        let left = leftButtonDown
        let right = rightButtonDown
        let middle = middleButtonDown
        
        stateLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveButtonPress?(left: left, right: right, middle: middle)
        }
    }
    
    private func handleMovementInput(_ value: IOHIDValue) {
        stateLock.lock()
        let isMiddleButtonHeld = middleButtonDown
        stateLock.unlock()
        
        guard let element = IOHIDElementGetElement(value) else { return }
        let usage = IOHIDElementGetUsage(element)
        let movement = IOHIDValueGetIntegerValue(value)
        
        if isMiddleButtonHeld {
            // Force cursor position
            DispatchQueue.main.async { [weak self] in
                self?.enforceCursorPosition()
            }
            
            // Convert movement to scroll
            let config = TPConfig.shared
            let speedMultiplier = config.scrollSpeedMultiplier
            let acceleration = config.scrollAcceleration
            let naturalScrolling = config.naturalScrolling
            let invertX = config.invertScrollX
            let invertY = config.invertScrollY
            
            // Base multiplier for faster response
            let baseMultiplier = 20.0
            
            // Apply speed multiplier and acceleration
            var adjustedMovement = Double(movement) * baseMultiplier * speedMultiplier
            if abs(adjustedMovement) > 1.0 {
                adjustedMovement *= (1.0 + (abs(adjustedMovement) * acceleration * 0.1))
            }
            
            var deltaX = 0
            var deltaY = 0
            
            switch usage {
            case TPHIDUsage.GenericDesktop.x:
                deltaX = -(Int(adjustedMovement))
                if invertX { deltaX = -deltaX }
            case TPHIDUsage.GenericDesktop.y:
                deltaY = -(Int(adjustedMovement))
                if invertY { deltaY = -deltaY }
            default:
                break
            }
            
            if naturalScrolling {
                deltaY = -deltaY
            }
            
            if deltaX != 0 || deltaY != 0 {
                DispatchQueue.main.async { [weak self] in
                    // Create and post scroll event
                    if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                               units: .pixel,
                                               wheelCount: 2,
                                               wheel1: Int32(deltaY),
                                               wheel2: Int32(deltaX)) {
                        scrollEvent.post(tap: .cghidEventTap)
                    }
                    
                    // Force cursor position again after scroll
                    self?.enforceCursorPosition()
                }
            }
            return
        }
        
        // Normal mouse movement mode
        let multiplier = 1 // Set to 1 for 1:1 movement
        var deltaX = 0
        var deltaY = 0
        
        switch usage {
        case TPHIDUsage.GenericDesktop.x:
            deltaX = -(Int(movement) * multiplier)
        case TPHIDUsage.GenericDesktop.y:
            deltaY = -(Int(movement) * multiplier)
        default:
            break
        }
        
        if deltaX != 0 || deltaY != 0 {
            stateLock.lock()
            let leftDown = leftButtonDown
            let rightDown = rightButtonDown
            stateLock.unlock()
            
            let buttons: UInt8 = (leftDown ? TPHIDButtonMask.leftButton : 0) |
                                (rightDown ? TPHIDButtonMask.rightButton : 0)
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveMovement?(deltaX: deltaX,
                                                  deltaY: deltaY,
                                                  buttonState: buttons)
            }
        }
    }
    
    private func handleScrollInput(_ value: IOHIDValue) {
        var scrollDelta = IOHIDValueGetIntegerValue(value)
        
        // Apply natural scrolling if enabled
        if TPConfig.shared.naturalScrolling {
            scrollDelta = -scrollDelta
        }
        
        stateLock.lock()
        let isMiddleButtonHeld = middleButtonDown
        stateLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            if isMiddleButtonHeld {
                self?.enforceCursorPosition()
            }
            
            if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                       units: .pixel,
                                       wheelCount: 1,
                                       wheel1: Int32(scrollDelta)) {
                scrollEvent.post(tap: .cghidEventTap)
            }
            
            if isMiddleButtonHeld {
                self?.enforceCursorPosition()
            }
        }
    }
}
