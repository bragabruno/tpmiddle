import Cocoa
import Combine

/// Main application class that coordinates all components
@objcMembers
public final class TPApplication: NSObject {
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = TPApplication()
    
    /// Current application state
    public private(set) var state: TPApplicationState = .notInitialized {
        didSet {
            delegate?.applicationDidChangeState?(state)
            if TPConfig.shared.debugMode {
                TPLogger.shared.log("Application state changed to: \(state.description)")
            }
        }
    }
    
    /// Whether the application should continue running
    public var shouldKeepRunning = true
    
    /// Whether we're waiting for permissions
    public private(set) var waitingForPermissions = false
    
    /// Whether we're showing a permission alert
    public private(set) var showingPermissionAlert = false
    
    /// Application delegate
    public weak var delegate: TPApplicationDelegate?
    
    // MARK: - Private Properties
    
    private let stateLock = NSLock()
    private let setupQueue = DispatchQueue(label: "com.tpmiddle.application.setup", qos: .userInteractive)
    
    private var hidManager: TPHIDManager?
    private var buttonManager: TPButtonManager?
    private var statusBarController: TPStatusBarController?
    private var eventWindow: NSWindow?
    private var eventViewController: TPEventViewController?
    
    private let permissionManager = TPPermissionManager.shared
    private let errorHandler = TPErrorHandler.shared
    private let statusReporter = TPStatusReporter.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        // Start logging immediately
        TPLogger.shared.startLogging()
        TPLogger.shared.log("TPApplication initializing...")
        
        // Log system info
        statusReporter.logSystemInfo()
        
        setupObservers()
    }
    
    deinit {
        cleanup()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Start the application
    public func start() {
        stateLock.lock()
        guard state != .running else {
            stateLock.unlock()
            return
        }
        state = .starting
        stateLock.unlock()
        
        do {
            TPLogger.shared.log("Starting application...")
            
            // Check permissions
            state = .checkingPermissions
            if let error = permissionManager.checkPermissions() {
                handlePermissionError(error)
                return
            }
            
            // Initialize components
            try initializeComponents()
            
            // Configure HID device matching
            configureHIDDeviceMatching()
            
            // Start HID monitoring
            guard startHIDMonitoring() else { return }
            
            // Initialize event viewer if in debug mode
            if TPConfig.shared.debugMode {
                setupQueue.async { [weak self] in
                    self?.setupEventViewer()
                    DispatchQueue.main.async {
                        self?.showEventViewer()
                    }
                }
            }
            
            state = .running
            TPLogger.shared.log("TPMiddle application started successfully")
            TPLogger.shared.log(applicationStatus)
            
        } catch {
            errorHandler.handle(error)
            if !waitingForPermissions && !showingPermissionAlert {
                NSApp.terminate(nil)
            }
        }
    }
    
    /// Clean up application resources
    public func cleanup() {
        guard !waitingForPermissions && !showingPermissionAlert else { return }
        
        TPLogger.shared.log("TPApplication cleaning up...")
        state = .stopping
        
        // Clean up UI
        DispatchQueue.main.async { [weak self] in
            self?.hideEventViewer()
            self?.eventWindow = nil
            self?.eventViewController?.stopMonitoring()
            self?.eventViewController = nil
        }
        
        // Clean up managers
        stateLock.lock()
        hidManager?.delegate = nil
        hidManager?.stop()
        hidManager = nil
        
        buttonManager?.delegate = nil
        buttonManager?.reset()
        buttonManager = nil
        
        statusBarController?.delegate = nil
        statusBarController = nil
        stateLock.unlock()
        
        TPLogger.shared.stopLogging()
        state = .stopped
    }
    
    /// Get current application status
    public var applicationStatus: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return """
        TPMiddle Status:
        State: \(state.description)
        Debug Mode: \(TPConfig.shared.debugMode ? "Enabled" : "Disabled")
        HID Manager: \(hidManager != nil ? "Running" : "Stopped")
        """
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe configuration changes
        if #available(macOS 10.15, *) {
            TPConfig.shared.configurationChanged
                .sink { [weak self] in
                    self?.handleConfigurationChange()
                }
                .store(in: &cancellables)
        }
        
        // Observe permission changes
        NotificationCenter.default.publisher(for: .TPPermissionsChanged)
            .sink { [weak self] notification in
                if let granted = notification.object as? Bool {
                    self?.handlePermissionChange(granted)
                }
            }
            .store(in: &cancellables)
    }
    
    private func initializeComponents() throws {
        // Initialize status bar first
        statusBarController = TPStatusBarController.shared
        guard statusBarController != nil else {
            throw TPApplicationError.componentInitializationFailed("Status Bar Controller")
        }
        
        // Initialize managers
        hidManager = TPHIDManager.shared
        guard hidManager != nil else {
            throw TPApplicationError.componentInitializationFailed("HID Manager")
        }
        
        buttonManager = TPButtonManager.shared
        guard buttonManager != nil else {
            throw TPApplicationError.componentInitializationFailed("Button Manager")
        }
        
        // Set up delegates
        setupDelegates()
    }
    
    private func setupDelegates() {
        hidManager?.delegate = self
        buttonManager?.delegate = self
        statusBarController?.delegate = self
    }
    
    private func configureHIDDeviceMatching() {
        hidManager?.addDeviceMatching(usagePage: TPHIDUsage.Page.genericDesktop,
                                    usage: TPHIDUsage.GenericDesktop.mouse)
        hidManager?.addDeviceMatching(usagePage: TPHIDUsage.Page.genericDesktop,
                                    usage: TPHIDUsage.GenericDesktop.pointer)
        
        // Add vendor IDs for broader device support
        hidManager?.addVendorMatching(TPHIDVendorID.lenovo)  // Lenovo
        hidManager?.addVendorMatching(TPHIDVendorID.ibm)     // IBM
        hidManager?.addVendorMatching(TPHIDVendorID.ti)      // Texas Instruments
        hidManager?.addVendorMatching(TPHIDVendorID.logitech) // Logitech
    }
    
    private func startHIDMonitoring() -> Bool {
        guard let hidManager = hidManager else { return false }
        
        if !hidManager.start() {
            if !waitingForPermissions && !showingPermissionAlert {
                TPLogger.shared.log("Failed to start HID manager")
                NSApp.terminate(nil)
            }
            return false
        }
        return true
    }
    
    private func setupEventViewer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                if self.eventViewController == nil {
                    // Load view controller from nib
                    guard let mainBundle = Bundle.main,
                          let nibPath = mainBundle.path(forResource: "TPEventViewController", ofType: "nib") else {
                        throw TPApplicationError.resourceNotFound("TPEventViewController.nib")
                    }
                    
                    let viewController = TPEventViewController(nibName: "TPEventViewController", bundle: mainBundle)
                    viewController.loadView()
                    viewController.startMonitoring()
                    self.eventViewController = viewController
                    TPLogger.shared.log("TPEventViewController loaded from nib")
                }
                
                if self.eventWindow == nil {
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                        styleMask: [.titled, .closable, .resizable],
                        backing: .buffered,
                        defer: false
                    )
                    window.contentViewController = self.eventViewController
                    window.title = "Event Viewer"
                    window.center()
                    self.eventWindow = window
                }
            } catch {
                self.errorHandler.handle(error)
            }
        }
    }
    
    private func showEventViewer() {
        DispatchQueue.main.async { [weak self] in
            self?.eventWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func hideEventViewer() {
        DispatchQueue.main.async { [weak self] in
            self?.eventWindow?.orderOut(nil)
        }
    }
    
    private func handlePermissionError(_ error: Error) {
        state = .waitingForPermissions
        waitingForPermissions = true
        
        permissionManager.showPermissionError(error) { [weak self] shouldRetry in
            guard let self = self else { return }
            
            self.waitingForPermissions = false
            if shouldRetry {
                self.start()
            } else {
                self.shouldKeepRunning = false
                NSApp.terminate(nil)
            }
        }
    }
    
    private func handleConfigurationChange() {
        if TPConfig.shared.debugMode {
            setupQueue.async { [weak self] in
                self?.setupEventViewer()
                DispatchQueue.main.async {
                    self?.showEventViewer()
                }
            }
        } else {
            hideEventViewer()
        }
    }
    
    private func handlePermissionChange(_ granted: Bool) {
        delegate?.applicationDidUpdatePermissions?(granted: granted)
        if granted {
            start()
        }
    }
}

// MARK: - NSApplicationDelegate

extension TPApplication: NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        TPLogger.shared.log("Application did finish launching")
        
        // Process command line arguments
        let arguments = ProcessInfo.processInfo.arguments
        TPConfig.shared.applyCommandLineArguments(arguments)
        
        // Start the application
        start()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        if !waitingForPermissions && !showingPermissionAlert {
            TPLogger.shared.log("Application will terminate")
            cleanup()
        }
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running even when all windows are closed
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !shouldKeepRunning {
            return .terminateNow
        }
        
        if waitingForPermissions || showingPermissionAlert {
            return .terminateCancel
        }
        
        return .terminateNow
    }
}

// MARK: - TPHIDManagerDelegate

extension TPApplication: TPHIDManagerDelegate {
    public func didDetectDeviceAttached(_ deviceInfo: String) {
        TPLogger.shared.log("Device attached: \(deviceInfo)")
        delegate?.applicationDidUpdateDeviceConnectivity?(connected: true)
    }
    
    public func didDetectDeviceDetached(_ deviceInfo: String) {
        TPLogger.shared.log("Device detached: \(deviceInfo)")
        delegate?.applicationDidUpdateDeviceConnectivity?(connected: false)
    }
    
    public func didEncounterError(_ error: Error) {
        errorHandler.handle(error)
    }
    
    public func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool) {
        buttonManager?.updateButtonStates(leftDown: left, right: right, middle: middle)
    }
    
    public func didReceiveMovement(deltaX: Int, deltaY: Int, withButtonState buttons: UInt8) {
        buttonManager?.handleMovement(deltaX: deltaX, deltaY: deltaY, withButtonState: buttons)
    }
}

// MARK: - TPButtonManagerDelegate

extension TPApplication: TPButtonManagerDelegate {
    public func middleButtonStateChanged(_ isPressed: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.eventViewController?.startMonitoring()
        }
    }
}

// MARK: - TPStatusBarControllerDelegate

extension TPApplication: TPStatusBarControllerDelegate {
    public func statusBarControllerDidToggleEventViewer(_ show: Bool) {
        if show {
            setupQueue.async { [weak self] in
                self?.setupEventViewer()
                DispatchQueue.main.async {
                    self?.showEventViewer()
                }
            }
        } else {
            hideEventViewer()
        }
        statusBarController?.updateEventViewerState(show)
    }
    
    public func statusBarControllerWillQuit() {
        shouldKeepRunning = false
    }
}

// MARK: - Errors

enum TPApplicationError: LocalizedError {
    case componentInitializationFailed(String)
    case resourceNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .componentInitializationFailed(let component):
            return "Failed to initialize \(component)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let TPPermissionsChanged = Notification.Name("TPPermissionsChanged")
}
