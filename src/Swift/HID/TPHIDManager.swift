import Foundation
import IOKit.hid
import Combine
import AppKit

/// Main class for managing HID devices
@objcMembers
public final class TPHIDManager: NSObject {
    // MARK: - Properties
    
    /// Delegate for receiving HID events
    public weak var delegate: TPHIDManagerDelegate?
    
    /// Currently connected devices
    public private(set) var devices: [TPHIDDevice] = []
    
    /// Whether the manager is currently running
    public private(set) var isRunning = false
    
    /// Whether scroll mode is enabled
    public private(set) var isScrollMode = false
    
    /// Singleton instance
    public static let shared = TPHIDManager()
    
    // MARK: - Private Properties
    
    private var manager: IOHIDManager?
    private var deviceConfigurations: [TPHIDDeviceConfiguration] = []
    private var vendorIDs: Set<UInt32> = []
    private let deviceQueue = DispatchQueue(label: "com.tpmiddle.hidmanager.device", qos: .userInteractive)
    private let delegateQueue = DispatchQueue(label: "com.tpmiddle.hidmanager.delegate", qos: .userInteractive)
    
    private let deviceLock = NSLock()
    private let delegateLock = NSLock()
    
    private var isInitialized = false
    private var waitingForPermissions = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for HID events
    /// - Returns: True if started successfully, false otherwise
    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return true }
        
        if let error = validateConfiguration() {
            notifyError(error)
            return false
        }
        
        if !isInitialized && !setupHIDManager() {
            return false
        }
        
        return isRunning
    }
    
    /// Stop monitoring for HID events
    public func stop() {
        guard isRunning, let manager = manager else { return }
        
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        deviceLock.lock()
        devices.removeAll()
        deviceLock.unlock()
        
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        
        isRunning = false
        isInitialized = false
    }
    
    /// Add a device matching criteria
    /// - Parameters:
    ///   - usagePage: The HID usage page
    ///   - usage: The HID usage
    public func addDeviceMatching(usagePage: UInt32, usage: UInt32) {
        let config = TPHIDDeviceConfiguration(usagePage: usagePage, usage: usage)
        deviceConfigurations.append(config)
        updateDeviceMatching()
    }
    
    /// Add a vendor matching criteria
    /// - Parameter vendorID: The vendor ID to match
    public func addVendorMatching(_ vendorID: UInt32) {
        vendorIDs.insert(vendorID)
        updateDeviceMatching()
    }
    
    /// Get the current device status
    /// - Returns: A string describing the current device status
    public func deviceStatus() -> String {
        var status = "=== HID Manager Device Status ===\n"
        status += "Running: \(isRunning ? "Yes" : "No")\n"
        
        deviceLock.lock()
        status += "Connected Devices: \(devices.count)\n"
        
        for device in devices {
            status += """
            - Device: \(device.productName)
              Vendor ID: \(String(format: "0x%04X", device.vendorID.uint32Value))
              Product ID: \(String(format: "0x%04X", device.productID.uint32Value))
            
            """
        }
        deviceLock.unlock()
        
        status += "===========================\n"
        return status
    }
    
    /// Get the current configuration
    /// - Returns: A string describing the current configuration
    public func currentConfiguration() -> String {
        var config = "=== HID Manager Configuration ===\n"
        config += "Device Configurations:\n"
        
        for deviceConfig in deviceConfigurations {
            config += """
            - Usage Page: \(String(format: "0x%04X", deviceConfig.usagePage))
              Usage: \(String(format: "0x%04X", deviceConfig.usage))
            
            """
        }
        
        if !vendorIDs.isEmpty {
            config += "Vendor IDs:\n"
            for vendorID in vendorIDs {
                config += "- \(String(format: "0x%04X", vendorID))\n"
            }
        }
        
        config += "==============================\n"
        return config
    }
    
    // MARK: - Private Methods
    
    private func setupHIDManager() -> Bool {
        if let error = checkPermissions() {
            if !waitingForPermissions {
                showPermissionAlert(message: error.localizedDescription)
            }
            notifyError(error)
            return false
        }
        
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let manager = manager else {
            notifyError(.initializationFailed)
            return false
        }
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovalCallback, context)
        IOHIDManagerRegisterInputValueCallback(manager, inputValueCallback, context)
        
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            self.manager = nil
            notifyError(.deviceAccessFailed)
            return false
        }
        
        updateDeviceMatching()
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        isInitialized = true
        isRunning = true
        return true
    }
    
    private func updateDeviceMatching() {
        guard let manager = manager else { return }
        
        var matching: [[String: Any]] = []
        
        // Add device configurations
        for config in deviceConfigurations {
            var criteria: [String: Any] = [
                kIOHIDDeviceUsagePageKey: config.usagePage,
                kIOHIDDeviceUsageKey: config.usage
            ]
            if let vendorID = config.vendorID {
                criteria[kIOHIDVendorIDKey] = vendorID
            }
            matching.append(criteria)
        }
        
        // Add vendor IDs
        for vendorID in vendorIDs {
            matching.append([kIOHIDVendorIDKey: vendorID])
        }
        
        let matchingDict = NSDictionary(dictionary: ["DeviceUsagePairs": matching])
        IOHIDManagerSetDeviceMatching(manager, matchingDict)
    }
    
    private func checkPermissions() -> TPHIDManagerError? {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            return .permissionDenied
        }
        
        let testManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard testManager != nil else {
            return .initializationFailed
        }
        
        let result = IOHIDManagerOpen(testManager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnNotPermitted {
            return .permissionDenied
        }
        
        return nil
    }
    
    private func showPermissionAlert(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = NSAlert()
            alert.messageText = "Permissions Required"
            alert.informativeText = message
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Quit")
            
            self.waitingForPermissions = true
            let response = alert.runModal()
            self.waitingForPermissions = false
            
            switch response {
            case .alertFirstButtonReturn:
                let urlString = message.contains("Accessibility")
                    ? "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    : "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.start()
                }
                
            case .alertSecondButtonReturn:
                self.start()
                
            default:
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func validateConfiguration() -> TPHIDManagerError? {
        if deviceConfigurations.isEmpty && vendorIDs.isEmpty {
            return .invalidConfiguration
        }
        return nil
    }
    
    private func notifyError(_ error: TPHIDManagerError) {
        delegateLock.lock()
        let currentDelegate = delegate
        delegateLock.unlock()
        
        let nsError = NSError(domain: TPHIDManagerErrorDomain,
                            code: error.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        
        DispatchQueue.main.async {
            currentDelegate?.didEncounterError?(nsError)
            
            if #available(macOS 10.15, *) {
                NotificationCenter.default.post(name: .TPHIDDeviceError,
                                             object: nsError)
            }
        }
    }
}

// MARK: - HID Callbacks

private func deviceMatchingCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    guard result == kIOReturnSuccess,
          let context = context else { return }
    
    let manager = Unmanaged<TPHIDManager>.fromOpaque(context).takeUnretainedValue()
    let hidDevice = TPHIDDevice(device: device)
    
    manager.deviceQueue.async {
        manager.deviceLock.lock()
        if !manager.devices.contains(where: { $0.isEqual(to: device) }) {
            manager.devices.append(hidDevice)
            manager.deviceLock.unlock()
            
            manager.delegateLock.lock()
            let currentDelegate = manager.delegate
            manager.delegateLock.unlock()
            
            DispatchQueue.main.async {
                currentDelegate?.didDetectDeviceAttached?(hidDevice.productName)
                
                if #available(macOS 10.15, *) {
                    NotificationCenter.default.post(name: .TPHIDDeviceAttached,
                                                 object: hidDevice.productName)
                }
            }
        } else {
            manager.deviceLock.unlock()
        }
    }
}

private func deviceRemovalCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    guard result == kIOReturnSuccess,
          let context = context else { return }
    
    let manager = Unmanaged<TPHIDManager>.fromOpaque(context).takeUnretainedValue()
    
    manager.deviceQueue.async {
        manager.deviceLock.lock()
        if let index = manager.devices.firstIndex(where: { $0.isEqual(to: device) }) {
            let hidDevice = manager.devices[index]
            manager.devices.remove(at: index)
            manager.deviceLock.unlock()
            
            manager.delegateLock.lock()
            let currentDelegate = manager.delegate
            manager.delegateLock.unlock()
            
            DispatchQueue.main.async {
                currentDelegate?.didDetectDeviceDetached?(hidDevice.productName)
                
                if #available(macOS 10.15, *) {
                    NotificationCenter.default.post(name: .TPHIDDeviceDetached,
                                                 object: hidDevice.productName)
                }
            }
        } else {
            manager.deviceLock.unlock()
        }
    }
}

private func inputValueCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {
    guard result == kIOReturnSuccess,
          let context = context else { return }
    
    let manager = Unmanaged<TPHIDManager>.fromOpaque(context).takeUnretainedValue()
    let element = IOHIDValueGetElement(value)
    let intValue = IOHIDValueGetIntegerValue(value)
    
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    
    var state = TPHIDDeviceState()
    
    switch (usagePage, usage) {
    case (TPHIDUsage.Page.genericDesktop, TPHIDUsage.GenericDesktop.x):
        state.deltaX = Int(intValue)
    case (TPHIDUsage.Page.genericDesktop, TPHIDUsage.GenericDesktop.y):
        state.deltaY = Int(intValue)
    case (TPHIDUsage.Page.button, _):
        let buttonIndex = usage - 1
        if intValue == 1 {
            state.buttonState |= (1 << buttonIndex)
        }
    default:
        break
    }
    
    if state.deltaX != 0 || state.deltaY != 0 || state.buttonState != 0 {
        manager.delegateLock.lock()
        let currentDelegate = manager.delegate
        manager.delegateLock.unlock()
        
        DispatchQueue.main.async {
            currentDelegate?.didReceiveMovement?(deltaX: state.deltaX,
                                               deltaY: state.deltaY,
                                               buttonState: state.buttonState)
            
            currentDelegate?.didReceiveButtonPress?(left: state.isLeftButtonPressed,
                                                  right: state.isRightButtonPressed,
                                                  middle: state.isMiddleButtonPressed)
            
            if #available(macOS 10.15, *) {
                NotificationCenter.default.post(name: .TPHIDDeviceStateChanged,
                                             object: state)
            }
        }
    }
    
    // Forward raw value to delegate if needed
    manager.delegateLock.lock()
    let currentDelegate = manager.delegate
    manager.delegateLock.unlock()
    
    if currentDelegate?.responds(to: #selector(TPHIDManagerDelegate.didReceiveHIDValue(_:))) == true {
        DispatchQueue.main.async {
            currentDelegate?.didReceiveHIDValue?(value)
        }
    }
}
