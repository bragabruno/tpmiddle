import Foundation
import Combine

/// Main configuration class for the application
@objcMembers
public final class TPConfig: NSObject {
    // MARK: - Constants
    
    private struct Keys {
        static let normalMode = "NormalMode"
        static let debugMode = "DebugMode"
        static let middleButtonDelay = "MiddleButtonDelay"
        static let scrollSpeedMultiplier = "ScrollSpeedMultiplier"
        static let scrollAcceleration = "ScrollAcceleration"
        static let naturalScrolling = "NaturalScrolling"
        static let invertScrollX = "InvertScrollX"
        static let invertScrollY = "InvertScrollY"
    }
    
    private struct Defaults {
        static let middleButtonDelay: TimeInterval = 0.3
        static let scrollSpeedMultiplier: CGFloat = 1.0
        static let scrollAcceleration: CGFloat = 1.2
    }
    
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = TPConfig()
    
    /// Publisher for configuration changes
    @available(macOS 10.15, *)
    public let configurationChanged = PassthroughSubject<Void, Never>()
    
    // MARK: - Basic Settings
    
    /// Current operation mode
    @UserDefaultsStorage(key: Keys.normalMode, defaultValue: false)
    public var isNormalMode: Bool {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Whether debug mode is enabled
    @UserDefaultsStorage(key: Keys.debugMode, defaultValue: false)
    public var debugMode: Bool {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Delay for middle button emulation
    @UserDefaultsStorage(key: Keys.middleButtonDelay, defaultValue: Defaults.middleButtonDelay)
    public var middleButtonDelay: TimeInterval {
        didSet { notifyConfigurationChanged() }
    }
    
    // MARK: - Scroll Settings
    
    /// Multiplier for scroll speed
    @UserDefaultsStorage(key: Keys.scrollSpeedMultiplier, defaultValue: Defaults.scrollSpeedMultiplier)
    public var scrollSpeedMultiplier: CGFloat {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Acceleration factor for scrolling
    @UserDefaultsStorage(key: Keys.scrollAcceleration, defaultValue: Defaults.scrollAcceleration)
    public var scrollAcceleration: CGFloat {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Whether natural scrolling is enabled
    @UserDefaultsStorage(key: Keys.naturalScrolling, defaultValue: true)
    public var naturalScrolling: Bool {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Whether to invert X-axis scrolling
    @UserDefaultsStorage(key: Keys.invertScrollX, defaultValue: false)
    public var invertScrollX: Bool {
        didSet { notifyConfigurationChanged() }
    }
    
    /// Whether to invert Y-axis scrolling
    @UserDefaultsStorage(key: Keys.invertScrollY, defaultValue: false)
    public var invertScrollY: Bool {
        didSet { notifyConfigurationChanged() }
    }
    
    // MARK: - Computed Properties
    
    /// Current operation mode
    public var operationMode: TPOperationMode {
        get { isNormalMode ? .normal : .default }
        set { isNormalMode = newValue == .normal }
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to their default values
    public func resetToDefaults() {
        _isNormalMode.reset()
        _debugMode.reset()
        _middleButtonDelay.reset()
        _scrollSpeedMultiplier.reset()
        _scrollAcceleration.reset()
        _naturalScrolling.reset()
        _invertScrollX.reset()
        _invertScrollY.reset()
        
        notifyConfigurationChanged()
    }
    
    /// Apply command line arguments to configuration
    /// - Parameter arguments: Array of command line arguments
    public func applyCommandLineArguments(_ arguments: [String]) {
        for arg in arguments {
            switch arg {
            case "-n", "--normal":
                operationMode = .normal
                TPLogger.shared.log("Normal mode enabled via command line")
                
            case "-r", "--reset":
                operationMode = .default
                TPLogger.shared.log("Reset to default mode via command line")
                
            case "-d", "--debug":
                debugMode = true
                TPLogger.shared.log("Debug mode enabled via command line")
                
            case "--natural-scroll":
                naturalScrolling = true
                TPLogger.shared.log("Natural scrolling enabled via command line")
                
            case "--reverse-scroll":
                naturalScrolling = false
                TPLogger.shared.log("Natural scrolling disabled via command line")
                
            default:
                break
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func notifyConfigurationChanged() {
        if #available(macOS 10.15, *) {
            configurationChanged.send()
        }
        
        if debugMode {
            TPLogger.shared.log("""
            Configuration changed:
            - Operation Mode: \(operationMode.description)
            - Debug Mode: \(debugMode)
            - Middle Button Delay: \(middleButtonDelay)
            - Scroll Speed Multiplier: \(scrollSpeedMultiplier)
            - Scroll Acceleration: \(scrollAcceleration)
            - Natural Scrolling: \(naturalScrolling)
            - Invert Scroll X: \(invertScrollX)
            - Invert Scroll Y: \(invertScrollY)
            """)
        }
    }
}

// MARK: - CustomStringConvertible

extension TPConfig: CustomStringConvertible {
    public var description: String {
        return """
        TPConfig(
            operationMode: \(operationMode.description)
            debugMode: \(debugMode)
            middleButtonDelay: \(middleButtonDelay)
            scrollSpeedMultiplier: \(scrollSpeedMultiplier)
            scrollAcceleration: \(scrollAcceleration)
            naturalScrolling: \(naturalScrolling)
            invertScrollX: \(invertScrollX)
            invertScrollY: \(invertScrollY)
        )
        """
    }
}

// MARK: - Combine Support

@available(macOS 10.15, *)
extension TPConfig {
    /// Publisher for specific configuration value changes
    /// - Parameter keyPath: KeyPath to the configuration value to observe
    /// - Returns: Publisher that emits the new value when it changes
    public func publisher<T>(for keyPath: KeyPath<TPConfig, T>) -> AnyPublisher<T, Never> {
        configurationChanged
            .map { [weak self] _ in self?[keyPath: keyPath] }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
