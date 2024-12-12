import Foundation
import IOKit.hid
import os.log

/// Main HID manager class that coordinates device management and input handling
final class TPHIDManager {
    // MARK: - Properties
    
    static let shared = TPHIDManager()
    
    weak var delegate: TPHIDManagerDelegate? {
        didSet {
            deviceManager = TPHIDDeviceManager(delegate: delegate)
        }
    }
    
    private let logger = Logger(subsystem: "com.tpmiddle", category: "hid")
    private var deviceManager: TPHIDDeviceManager?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    func start() -> Bool {
        guard let deviceManager = deviceManager else {
            logger.error("Device manager not initialized. Set delegate first.")
            delegate?.didEncounterError(TPHIDError.hidError("Device manager not initialized"))
            return false
        }
        
        return deviceManager.start()
    }
    
    func stop() {
        deviceManager?.stop()
    }
    
    func addDeviceMatching(usagePage: UInt32, usage: UInt32) {
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: NSNumber(value: usagePage),
            kIOHIDDeviceUsageKey: NSNumber(value: usage)
        ]
        
        addDeviceMatching(matching)
    }
    
    func addVendorMatching(vendorID: UInt32) {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: NSNumber(value: vendorID)
        ]
        
        addDeviceMatching(matching)
    }
    
    // MARK: - Private Methods
    
    private func addDeviceMatching(_ matching: [String: Any]) {
        deviceManager?.addDeviceMatching(matching)
    }
}
