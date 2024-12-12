import Cocoa

// Import local modules
@_exported import struct Foundation.Notification
@_exported import class Foundation.UserDefaults
@_exported import class Foundation.NotificationCenter

// MARK: - Configuration Keys
private enum ConfigKeys {
    static let debugMode = "debugMode"
    static let scrollSpeed = "scrollSpeed"
    static let naturalScrolling = "naturalScrolling"
    static let accelerationEnabled = "accelerationEnabled"
}

// MARK: - Default Values
private enum Defaults {
    static let debugMode = false
    static let scrollSpeed = 1.0
    static let naturalScrolling = true
    static let accelerationEnabled = true
}

// MARK: - Notification Names
extension Notification.Name {
    static let configurationChanged = Notification.Name("TPConfigurationChangedNotification")
}

@MainActor
final class TPConfig {
    static let shared = TPConfig()
    
    // MARK: - Properties
    
    @Published private(set) var debugMode: Bool
    @Published private(set) var scrollSpeed: Double
    @Published private(set) var naturalScrolling: Bool
    @Published private(set) var accelerationEnabled: Bool
    
    private let defaults = UserDefaults.standard
    private let configQueue = DispatchQueue(label: "com.tpmiddle.config", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        // Load from UserDefaults with default values
        self.debugMode = defaults.bool(forKey: ConfigKeys.debugMode) ?? Defaults.debugMode
        self.scrollSpeed = defaults.double(forKey: ConfigKeys.scrollSpeed) ?? Defaults.scrollSpeed
        self.naturalScrolling = defaults.bool(forKey: ConfigKeys.naturalScrolling) ?? Defaults.naturalScrolling
        self.accelerationEnabled = defaults.bool(forKey: ConfigKeys.accelerationEnabled) ?? Defaults.accelerationEnabled
        
        // Setup notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func applyCommandLineArguments(_ arguments: [String]) {
        for (index, arg) in arguments.enumerated() {
            switch arg {
            case "--debug":
                debugMode = true
            case "--scroll-speed":
                if index + 1 < arguments.count,
                   let speed = Double(arguments[index + 1]) {
                    scrollSpeed = speed
                }
            case "--natural-scrolling":
                if index + 1 < arguments.count {
                    naturalScrolling = arguments[index + 1].lowercased() == "true"
                }
            case "--acceleration":
                if index + 1 < arguments.count {
                    accelerationEnabled = arguments[index + 1].lowercased() == "true"
                }
            default:
                continue
            }
        }
        
        saveConfiguration()
    }
    
    func updateConfiguration(
        debugMode: Bool? = nil,
        scrollSpeed: Double? = nil,
        naturalScrolling: Bool? = nil,
        accelerationEnabled: Bool? = nil
    ) {
        if let debugMode = debugMode {
            self.debugMode = debugMode
        }
        
        if let scrollSpeed = scrollSpeed {
            self.scrollSpeed = scrollSpeed
        }
        
        if let naturalScrolling = naturalScrolling {
            self.naturalScrolling = naturalScrolling
        }
        
        if let accelerationEnabled = accelerationEnabled {
            self.accelerationEnabled = accelerationEnabled
        }
        
        saveConfiguration()
        
        NotificationCenter.default.post(
            name: .configurationChanged,
            object: self
        )
    }
    
    // MARK: - Private Methods
    
    private func saveConfiguration() {
        configQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.defaults.set(self.debugMode, forKey: ConfigKeys.debugMode)
            self.defaults.set(self.scrollSpeed, forKey: ConfigKeys.scrollSpeed)
            self.defaults.set(self.naturalScrolling, forKey: ConfigKeys.naturalScrolling)
            self.defaults.set(self.accelerationEnabled, forKey: ConfigKeys.accelerationEnabled)
            
            self.defaults.synchronize()
        }
    }
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        saveConfiguration()
    }
}

// MARK: - CustomStringConvertible

extension TPConfig: CustomStringConvertible {
    var description: String {
        """
        TPConfig:
        - Debug Mode: \(debugMode)
        - Scroll Speed: \(scrollSpeed)
        - Natural Scrolling: \(naturalScrolling)
        - Acceleration Enabled: \(accelerationEnabled)
        """
    }
}
