import Foundation

/// Protocol for receiving HID manager events
@objc public protocol TPHIDManagerDelegate: AnyObject {
    /// Called when a new HID device is attached
    @objc optional func didDetectDeviceAttached(_ deviceInfo: String)
    
    /// Called when a HID device is detached
    @objc optional func didDetectDeviceDetached(_ deviceInfo: String)
    
    /// Called when an error occurs during HID operations
    @objc optional func didEncounterError(_ error: Error)
    
    /// Called when a button press is detected
    @objc optional func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
    
    /// Called when movement is detected
    @objc optional func didReceiveMovement(deltaX: Int, deltaY: Int, buttonState: UInt8)
    
    /// Called when a raw HID value is received (internal use)
    @objc optional func didReceiveHIDValue(_ value: Any)
}

/// Extended delegate methods with modern Swift features
public protocol TPHIDManagerDelegateExtended: TPHIDManagerDelegate {
    /// Called when device state changes
    func didUpdateDeviceState(_ state: TPHIDDeviceState)
    
    /// Called when device configuration changes
    func didUpdateConfiguration(_ configuration: TPHIDDeviceConfiguration)
    
    /// Called when scroll mode changes
    func didChangeScrollMode(_ isEnabled: Bool)
}

/// Default implementations for TPHIDManagerDelegateExtended
public extension TPHIDManagerDelegateExtended {
    func didUpdateDeviceState(_ state: TPHIDDeviceState) {
        // Convert state to legacy delegate calls
        didReceiveMovement?(deltaX: state.deltaX, deltaY: state.deltaY, buttonState: state.buttonState)
        didReceiveButtonPress?(
            left: state.isLeftButtonPressed,
            right: state.isRightButtonPressed,
            middle: state.isMiddleButtonPressed
        )
    }
    
    func didUpdateConfiguration(_ configuration: TPHIDDeviceConfiguration) {
        // Default empty implementation
    }
    
    func didChangeScrollMode(_ isEnabled: Bool) {
        // Default empty implementation
    }
}

/// Combine support for HID events
#if canImport(Combine)
import Combine

@available(macOS 10.15, *)
public extension TPHIDManagerDelegate {
    /// Publisher for device attachment events
    var deviceAttachmentPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: .TPHIDDeviceAttached)
            .compactMap { $0.object as? String }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for device detachment events
    var deviceDetachmentPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: .TPHIDDeviceDetached)
            .compactMap { $0.object as? String }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for device state updates
    var deviceStatePublisher: AnyPublisher<TPHIDDeviceState, Never> {
        NotificationCenter.default
            .publisher(for: .TPHIDDeviceStateChanged)
            .compactMap { $0.object as? TPHIDDeviceState }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for errors
    var errorPublisher: AnyPublisher<Error, Never> {
        NotificationCenter.default
            .publisher(for: .TPHIDDeviceError)
            .compactMap { $0.object as? Error }
            .eraseToAnyPublisher()
    }
}

// Notification names
public extension Notification.Name {
    static let TPHIDDeviceAttached = Notification.Name("TPHIDDeviceAttached")
    static let TPHIDDeviceDetached = Notification.Name("TPHIDDeviceDetached")
    static let TPHIDDeviceStateChanged = Notification.Name("TPHIDDeviceStateChanged")
    static let TPHIDDeviceError = Notification.Name("TPHIDDeviceError")
}
#endif
