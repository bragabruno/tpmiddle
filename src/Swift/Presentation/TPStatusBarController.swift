import Cocoa
import Combine

/// Controls the status bar menu and UI
@objcMembers
public final class TPStatusBarController: NSObject {
    // MARK: - Types
    
    private enum MenuItemIdentifier: String {
        case defaultMode = "Default Mode"
        case normalMode = "Normal Mode"
        case eventViewer = "Show Event Viewer"
        case debugMode = "Debug Mode"
        case quit = "Quit"
    }
    
    // MARK: - Properties
    
    /// Delegate for receiving status bar events
    public weak var delegate: TPStatusBarControllerDelegate?
    
    /// Shared instance
    public static let shared = TPStatusBarController()
    
    /// Status item in the menu bar
    private var statusItem: NSStatusItem?
    
    /// Status menu
    private var statusMenu: NSMenu?
    
    /// Whether the event viewer is visible
    private var eventViewerVisible = false
    
    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupStatusBar()
        setupConfigurationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Update the mode display in the status bar
    public func updateModeDisplay() {
        let title = TPConfig.shared.operationMode == .normal ? "●" : "○"
        statusItem?.button?.title = title
    }
    
    /// Update the debug state in the menu
    public func updateDebugState() {
        updateMenuStates()
    }
    
    /// Update the event viewer state in the menu
    /// - Parameter isVisible: Whether the event viewer is visible
    public func updateEventViewerState(_ isVisible: Bool) {
        eventViewerVisible = isVisible
        
        if let item = statusMenu?.item(withTitle: MenuItemIdentifier.eventViewer.rawValue) {
            item.title = isVisible ? "Hide Event Viewer" : "Show Event Viewer"
            item.state = isVisible ? .on : .off
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStatusBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem?.button else {
            TPLogger.shared.log("Failed to create status item button")
            return
        }
        
        // Set initial title
        updateModeDisplay()
        
        // Create menu
        statusMenu = createStatusMenu()
        statusItem?.menu = statusMenu
        
        TPLogger.shared.log("Status bar setup completed - title: \(button.title)")
    }
    
    private func createStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Mode selection
        let defaultModeItem = NSMenuItem(
            title: MenuItemIdentifier.defaultMode.rawValue,
            action: #selector(setDefaultMode(_:)),
            keyEquivalent: ""
        )
        defaultModeItem.target = self
        menu.addItem(defaultModeItem)
        
        let normalModeItem = NSMenuItem(
            title: MenuItemIdentifier.normalMode.rawValue,
            action: #selector(setNormalMode(_:)),
            keyEquivalent: ""
        )
        normalModeItem.target = self
        menu.addItem(normalModeItem)
        
        menu.addItem(.separator())
        
        // Event Viewer
        let eventViewerItem = NSMenuItem(
            title: MenuItemIdentifier.eventViewer.rawValue,
            action: #selector(toggleEventViewer(_:)),
            keyEquivalent: "e"
        )
        eventViewerItem.target = self
        menu.addItem(eventViewerItem)
        
        menu.addItem(.separator())
        
        // Debug mode
        let debugItem = NSMenuItem(
            title: MenuItemIdentifier.debugMode.rawValue,
            action: #selector(toggleDebugMode(_:)),
            keyEquivalent: ""
        )
        debugItem.target = self
        menu.addItem(debugItem)
        
        menu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: MenuItemIdentifier.quit.rawValue,
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Update initial states
        updateMenuStates()
        
        return menu
    }
    
    private func setupConfigurationObservers() {
        guard #available(macOS 10.15, *) else { return }
        
        // Observe operation mode changes
        TPConfig.shared.publisher(for: \.operationMode)
            .sink { [weak self] _ in
                self?.updateModeDisplay()
                self?.updateMenuStates()
            }
            .store(in: &cancellables)
        
        // Observe debug mode changes
        TPConfig.shared.publisher(for: \.debugMode)
            .sink { [weak self] _ in
                self?.updateMenuStates()
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuStates() {
        guard let menu = statusMenu else { return }
        
        let config = TPConfig.shared
        let isNormalMode = config.operationMode == .normal
        
        // Update mode checkmarks
        if let defaultModeItem = menu.item(withTitle: MenuItemIdentifier.defaultMode.rawValue),
           let normalModeItem = menu.item(withTitle: MenuItemIdentifier.normalMode.rawValue) {
            defaultModeItem.state = isNormalMode ? .off : .on
            normalModeItem.state = isNormalMode ? .on : .off
        }
        
        // Update event viewer state
        let eventViewerTitle = eventViewerVisible ? "Hide Event Viewer" : "Show Event Viewer"
        if let eventViewerItem = menu.item(withTitle: MenuItemIdentifier.eventViewer.rawValue) {
            eventViewerItem.title = eventViewerTitle
            eventViewerItem.state = eventViewerVisible ? .on : .off
        }
        
        // Update debug mode
        if let debugItem = menu.item(withTitle: MenuItemIdentifier.debugMode.rawValue) {
            debugItem.state = config.debugMode ? .on : .off
        }
    }
    
    // MARK: - Menu Actions
    
    @objc private func setDefaultMode(_ sender: Any?) {
        setMode(.default)
    }
    
    @objc private func setNormalMode(_ sender: Any?) {
        setMode(.normal)
    }
    
    private func setMode(_ mode: TPOperationMode) {
        TPConfig.shared.operationMode = mode
        updateModeDisplay()
        updateMenuStates()
        
        if TPConfig.shared.debugMode {
            TPLogger.shared.log("Switched to \(mode == .normal ? "Normal" : "Default") mode")
        }
    }
    
    @objc private func toggleEventViewer(_ sender: Any?) {
        delegate?.statusBarControllerDidToggleEventViewer?(!eventViewerVisible)
    }
    
    @objc private func toggleDebugMode(_ sender: Any?) {
        TPConfig.shared.debugMode.toggle()
        updateMenuStates()
        
        TPLogger.shared.log("Debug mode \(TPConfig.shared.debugMode ? "enabled" : "disabled")")
    }
    
    @objc private func quit(_ sender: Any?) {
        delegate?.statusBarControllerWillQuit?()
        NSApp.terminate(nil)
    }
}

// MARK: - CustomStringConvertible

extension TPStatusBarController: CustomStringConvertible {
    public var description: String {
        return """
        TPStatusBarController(
            eventViewerVisible: \(eventViewerVisible),
            operationMode: \(TPConfig.shared.operationMode.description),
            debugMode: \(TPConfig.shared.debugMode)
        )
        """
    }
}
