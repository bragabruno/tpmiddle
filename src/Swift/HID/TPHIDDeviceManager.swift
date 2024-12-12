import Foundation
import IOKit.hid
import os.log

final class TPHIDDeviceManager {
    // MARK: - Properties
    
    private weak var delegate: TPHIDManagerDelegate?
    private let manager: IOHIDManager
    private let logger = Logger(subsystem: "com.tpmiddle", category: "hid.device")
    private var devices = Set<TPHIDDevice>()
    private let deviceQueue = DispatchQueue(label: "com.tpmiddle.hid.device", qos: .userInteractive)
    private let inputHandler: TPHIDInputHandler
    
    // MARK: - Initialization
    
    init(delegate: TPHIDManagerDelegate?) {
        self.delegate = delegate
        self.manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.inputHandler = TPHIDInputHandler(delegate: delegate)
        
        // Set up manager
        IOHIDManagerSetDeviceMatching(manager, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        // Register callbacks
        setupCallbacks()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    func start() -> Bool {
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            logger.error("Failed to open HID Manager: \(result)")
            delegate?.didEncounterError(TPHIDError.hidError("Failed to open HID Manager"))
            return false
        }
        
        logger.info("HID Device Manager started successfully")
        return true
    }
    
    func stop() {
        deviceQueue.sync {
            devices.forEach { $0.close() }
            devices.removeAll()
        }
        
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        logger.info("HID Device Manager stopped")
    }
    
    func addDeviceMatching(_ matching: [String: Any]) {
        let matchingDict = matching as CFDictionary
        IOHIDManagerSetDeviceMatching(manager, matchingDict)
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() {
        // Device matching callback
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let manager = Unmanaged<TPHIDDeviceManager>.fromOpaque(context!).takeUnretainedValue()
            manager.handleDeviceMatched(device)
        }
        
        // Device removal callback
        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let manager = Unmanaged<TPHIDDeviceManager>.fromOpaque(context!).takeUnretainedValue()
            manager.handleDeviceRemoved(device)
        }
        
        // Register callbacks
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            matchingCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            removalCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    private func handleDeviceMatched(_ device: IOHIDDevice) {
        guard let hidDevice = TPHIDDevice(device: device) else {
            logger.error("Failed to create TPHIDDevice")
            return
        }
        
        deviceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add device to set
            self.devices.insert(hidDevice)
            
            // Open device
            guard hidDevice.open() else {
                self.logger.error("Failed to open device: \(hidDevice.description)")
                return
            }
            
            // Set up device callbacks
            self.setupDeviceCallbacks(hidDevice)
            
            // Notify delegate
            DispatchQueue.main.async {
                self.delegate?.didDetectDeviceAttached(hidDevice.description)
            }
            
            self.logger.info("Device attached: \(hidDevice.description)")
        }
    }
    
    private func handleDeviceRemoved(_ device: IOHIDDevice) {
        deviceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Find and remove device
            if let index = self.devices.firstIndex(where: { $0.device == device }) {
                let hidDevice = self.devices.remove(at: index)
                hidDevice.close()
                
                // Notify delegate
                DispatchQueue.main.async {
                    self.delegate?.didDetectDeviceDetached(hidDevice.description)
                }
                
                self.logger.info("Device detached: \(hidDevice.description)")
            }
        }
    }
    
    private func setupDeviceCallbacks(_ device: TPHIDDevice) {
        // Input value callback
        let inputCallback: IOHIDValueCallback = { context, result, sender, value in
            guard let context = context else { return }
            let manager = Unmanaged<TPHIDDeviceManager>.fromOpaque(context).takeUnretainedValue()
            manager.inputHandler.handleInput(value)
        }
        
        // Set callbacks
        device.setInputValueCallback(inputCallback)
    }
}
