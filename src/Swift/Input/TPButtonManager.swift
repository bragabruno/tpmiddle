import Foundation
import CoreGraphics
import AppKit

/// Main class for managing button states and emulating middle button functionality
@objcMembers
public final class TPButtonManager: NSObject {
    // MARK: - Constants
    
    private struct Constants {
        static let minMovementThreshold: CGFloat = 1.0  // Minimum movement to trigger scroll
        static let maxScrollSpeed: CGFloat = 1.0       // Maximum scroll speed cap
    }
    
    // MARK: - Properties
    
    /// Delegate for receiving button manager events
    public weak var delegate: TPButtonManagerDelegate?
    
    /// Whether the middle button is currently emulated
    public private(set) var isMiddleButtonEmulated: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return middleEmulated
        }
    }
    
    /// Whether the middle button is currently pressed
    public private(set) var isMiddleButtonPressed: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return middlePressed
        }
    }
    
    /// Shared instance
    public static let shared = TPButtonManager()
    
    // MARK: - Private Properties
    
    private var leftDown = false
    private var rightDown = false
    private var middleEmulated = false
    private var middlePressed = false
    
    private var leftDownTime: Date?
    private var rightDownTime: Date?
    private var lastLocation = CGPoint.zero
    
    // Scroll state
    private var accumulatedDeltaX: CGFloat = 0
    private var accumulatedDeltaY: CGFloat = 0
    private var lastScrollTime: TimeInterval = 0
    
    // Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Thread safety
    private let stateLock = NSLock()
    private let delegateLock = NSLock()
    private let eventQueue = DispatchQueue(label: "com.tpmiddle.buttonManager.event", qos: .userInteractive)
    private let delegateQueue = DispatchQueue(label: "com.tpmiddle.buttonManager.delegate", qos: .userInteractive)
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        reset()
        setupEventTap()
    }
    
    deinit {
        teardownEventTap()
    }
    
    // MARK: - Public Methods
    
    /// Update the state of all buttons
    /// - Parameters:
    ///   - leftDown: Whether the left button is down
    ///   - rightDown: Whether the right button is down
    ///   - middleDown: Whether the middle button is down
    public func updateButtonStates(leftDown: Bool, right rightDown: Bool, middle middleDown: Bool) {
        stateLock.lock()
        
        // Log button state
        TPLogger.shared.logButtonEvent(left: leftDown, right: rightDown, middle: middleDown)
        
        // Handle middle button state for scroll mode only
        if middleDown != middlePressed {
            middlePressed = middleDown
            if !middlePressed {
                // Reset scroll state when middle button is released
                accumulatedDeltaX = 0
                accumulatedDeltaY = 0
                lastLocation = .zero
            } else {
                // Get initial cursor position when middle button is pressed
                if let event = CGEvent(source: nil) {
                    lastLocation = event.location
                }
            }
            // Notify delegate of state change without generating click events
            notifyDelegateOfMiddleButtonState(middleDown)
        }
        
        if middleDown {
            middleEmulated = true
            stateLock.unlock()
            return
        }
        
        // Handle left button state change
        if leftDown != self.leftDown {
            self.leftDown = leftDown
            if leftDown {
                leftDownTime = Date()
            }
        }
        
        // Handle right button state change
        if rightDown != self.rightDown {
            self.rightDown = rightDown
            if rightDown {
                rightDownTime = Date()
            }
        }
        
        // Check for middle button emulation
        if leftDown && rightDown && !middleEmulated,
           let leftTime = leftDownTime,
           let rightTime = rightDownTime {
            let timeDiff = abs(leftTime.timeIntervalSince(rightTime))
            if timeDiff <= TPConfig.shared.middleButtonDelay {
                middleEmulated = true
                middlePressed = true
                notifyDelegateOfMiddleButtonState(true)
            }
        }
        
        // Release emulated middle button when both buttons are released
        if !leftDown && !rightDown && middleEmulated {
            middleEmulated = false
            middlePressed = false
            notifyDelegateOfMiddleButtonState(false)
            
            // Reset scroll state
            accumulatedDeltaX = 0
            accumulatedDeltaY = 0
            lastLocation = .zero
        }
        
        stateLock.unlock()
    }
    
    /// Handle movement with button state
    /// - Parameters:
    ///   - deltaX: X-axis movement
    ///   - deltaY: Y-axis movement
    ///   - buttons: Button state mask
    public func handleMovement(deltaX: Int, deltaY: Int, withButtonState buttons: UInt8) {
        stateLock.lock()
        let shouldHandle = middlePressed || middleEmulated
        stateLock.unlock()
        
        guard shouldHandle else { return }
        
        let config = TPConfig.shared
        
        // Calculate time since last scroll for acceleration
        let currentTime = Date().timeIntervalSinceReferenceDate
        var timeDelta = currentTime - lastScrollTime
        if timeDelta > 0.1 { timeDelta = 0.1 } // Cap the time delta
        
        // Apply acceleration based on movement speed
        let speed = sqrt(Double(deltaX * deltaX + deltaY * deltaY))
        let accelerationFactor = 0.0 + (speed * config.scrollAcceleration * timeDelta)
        
        // Use raw movement values
        let adjustedDeltaX = CGFloat(deltaX)
        let adjustedDeltaY = CGFloat(deltaY)
        
        stateLock.lock()
        // Accumulate movement with acceleration and speed multiplier
        accumulatedDeltaX += adjustedDeltaX * config.scrollSpeedMultiplier * accelerationFactor
        accumulatedDeltaY += adjustedDeltaY * config.scrollSpeedMultiplier * accelerationFactor
        
        // Only scroll if accumulated movement exceeds threshold
        if abs(accumulatedDeltaX) >= Constants.minMovementThreshold ||
           abs(accumulatedDeltaY) >= Constants.minMovementThreshold {
            
            // Cap scroll speed
            let scrollX = min(max(accumulatedDeltaX, -Constants.maxScrollSpeed), Constants.maxScrollSpeed)
            let scrollY = min(max(accumulatedDeltaY, -Constants.maxScrollSpeed), Constants.maxScrollSpeed)
            
            // Reset accumulated deltas
            accumulatedDeltaX = 0
            accumulatedDeltaY = 0
            lastScrollTime = currentTime
            
            stateLock.unlock()
            
            // Post scroll event
            postScrollEvent(deltaY: scrollY, deltaX: scrollX)
        } else {
            stateLock.unlock()
        }
    }
    
    /// Reset all button states
    public func reset() {
        stateLock.lock()
        leftDown = false
        rightDown = false
        middleEmulated = false
        middlePressed = false
        leftDownTime = nil
        rightDownTime = nil
        lastLocation = .zero
        
        // Reset scroll state
        accumulatedDeltaX = 0
        accumulatedDeltaY = 0
        lastScrollTime = Date().timeIntervalSinceReferenceDate
        stateLock.unlock()
        
        // Notify delegate of reset
        notifyDelegateOfMiddleButtonState(false)
    }
    
    // MARK: - Private Methods
    
    private func setupEventTap() {
        // Create event tap
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.leftMouseUp.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseUp.rawValue) |
                       (1 << CGEventType.otherMouseDown.rawValue) |
                       (1 << CGEventType.otherMouseUp.rawValue) |
                       (1 << CGEventType.scrollWheel.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            
            let manager = Unmanaged<TPButtonManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEventTapEvent(type: type, event: event)
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: context
        )
        
        guard let eventTap = eventTap else {
            TPLogger.shared.log("Failed to create event tap - Input Monitoring permission may be required")
            return
        }
        
        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            TPLogger.shared.log("Failed to create run loop source")
            self.eventTap = nil
            return
        }
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        TPLogger.shared.log("Event tap setup successfully")
    }
    
    private func teardownEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }
    
    private func handleEventTapEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        switch type {
        case .mouseMoved:
            if middlePressed || middleEmulated {
                let currentLocation = event.location
                
                if lastLocation == .zero {
                    lastLocation = currentLocation
                    return nil
                }
                
                // Calculate movement delta
                let deltaX = Int(currentLocation.x - lastLocation.x)
                let deltaY = Int(lastLocation.y - currentLocation.y) // Flip Y for natural scrolling
                
                lastLocation = currentLocation
                
                if deltaX != 0 || deltaY != 0 {
                    handleMovement(deltaX: deltaX, deltaY: deltaY, withButtonState: 0)
                    return nil // Consume the event
                }
            }
            
        case .leftMouseDown:
            leftDown = true
            leftDownTime = Date()
            
        case .leftMouseUp:
            leftDown = false
            
        case .rightMouseDown:
            rightDown = true
            rightDownTime = Date()
            
        case .rightMouseUp:
            rightDown = false
            
        case .otherMouseDown, .otherMouseUp:
            // Consume middle button events to prevent clicks
            if event.getIntegerValueField(.mouseEventButtonNumber) == CGMouseButton.center.rawValue {
                return nil
            }
            
        case .scrollWheel:
            // Let system handle regular scroll events
            break
            
        default:
            break
        }
        
        return event
    }
    
    private func notifyDelegateOfMiddleButtonState(_ isDown: Bool) {
        delegateLock.lock()
        let currentDelegate = delegate
        delegateLock.unlock()
        
        guard let currentDelegate = currentDelegate else { return }
        
        delegateQueue.async {
            currentDelegate.middleButtonStateChanged?(isDown)
        }
    }
    
    private func postScrollEvent(deltaY: CGFloat, deltaX: CGFloat) {
        eventQueue.async {
            // Create scroll event with simple configuration
            guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                          units: .pixel,
                                          wheelCount: 2,
                                          wheel1: Int32(deltaY),
                                          wheel2: Int32(deltaX)) else {
                TPLogger.shared.log("Failed to create scroll event")
                return
            }
            
            // Set continuous flag
            scrollEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            
            // Post the event
            scrollEvent.post(tap: .cghidEventTap)
            
            // Log scroll event
            TPLogger.shared.logScrollEvent(deltaX: Double(deltaX), deltaY: Double(deltaY))
            
            if TPConfig.shared.debugMode {
                TPLogger.shared.log("Posted scroll event - deltaX: \(deltaX), deltaY: \(deltaY)")
            }
        }
    }
}
