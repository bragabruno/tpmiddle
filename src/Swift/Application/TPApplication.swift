import Cocoa
import IOKit.hid
import Combine

@MainActor
final class TPApplication: NSObject {
    // MARK: - Singleton
    
    static let shared = TPApplication()
    
    // MARK: - Properties
    
    @Published private(set) var isInitialized = false
    @Published private(set) var waitingForPermissions = false
    @Published private(set) var showingPermissionAlert = false
    @Published private(set) var shouldKeepRunning = true
    
    private let stateLock = NSLock()
    private let setupQueue = DispatchQueue(label: "com.tpmiddle.application.setup", qos: .userInitiated)
    
    private var hidManager: TPHIDManager?
    private var buttonManager: TPButtonManager?
    private var statusBarController: TPStatusBarController?
    
    private var eventWindow: NSWindow?
    private var eventViewController: TPEventViewController?
    
    private let permissionManager: TPPermissionManager
    private let errorHandler: TPErrorHandler
    private let statusReporter: TPStatusReporter
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        self.permissionManager = .shared
        self.errorHandler = .shared
        self.statusReporter = .shared
        
        super.init()
        
        // Start logging immediately
        TPLogger.shared.startLogging()
        TPLogger.shared.logMessage("TPApplication initializing...")
        
        // Log system information
        statusReporter.logSystemInfo()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    func start() async {
        guard isInitialized else {
            TPLogger.shared.logMessage("TPApplication not properly initialized")
            NSApp.terminate(nil)
            return
        }
        
        do {
            TPLogger.shared.logMessage("Starting application...")
            
            // Check permissions
            if let error = permissionManager.checkPermissions() {
                await handlePermissionError(error)
                return
            }
            
            try await setupManagers()
            configureHIDDeviceMatching()
            
            // Start HID monitoring
            guard await startHIDManager() else {
                if !waitingForPermissions && !showingPermissionAlert {
                    TPLogger.shared.logMessage("Failed to start HID manager")
                    NSApp.terminate(nil)
                }
                return
            }
            
            // Initialize event viewer if in debug mode
            if TPConfig.shared.debugMode {
                await setupAndShowEventViewer()
            }
            
            TPLogger.shared.logMessage("TPMiddle application started successfully")
            TPLogger.shared.logMessage(applicationStatus)
            
        } catch {
            errorHandler.logError(error)
            if !waitingForPermissions && !showingPermissionAlert {
                NSApp.terminate(nil)
            }
        }
    }
    
    func cleanup() {
        guard !waitingForPermissions && !showingPermissionAlert else { return }
        
        TPLogger.shared.logMessage("TPApplication cleaning up...")
        
        Task { @MainActor in
            hideEventViewer()
            eventWindow = nil
            eventViewController?.stopMonitoring()
            eventViewController = nil
        }
        
        stateLock.lock()
        defer { stateLock.unlock() }
        
        hidManager?.delegate = nil
        hidManager?.stop()
        hidManager = nil
        
        buttonManager?.delegate = nil
        buttonManager?.reset()
        buttonManager = nil
        
        statusBarController?.delegate = nil
        statusBarController = nil
        
        TPLogger.shared.stopLogging()
    }
    
    var applicationStatus: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return """
            TPMiddle Status:
            Initialized: \(isInitialized ? "Yes" : "No")
            Debug Mode: \(TPConfig.shared.debugMode ? "Enabled" : "Disabled")
            HID Manager: \(hidManager != nil ? "Running" : "Stopped")
            """
    }
    
    // MARK: - Private Methods
    
    private func setupManagers() async throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        hidManager = TPHIDManager.shared
        guard hidManager != nil else {
            throw TPError.managerInitializationFailed("Failed to create HID manager")
        }
        hidManager?.delegate = self
        
        buttonManager = TPButtonManager.shared
        guard buttonManager != nil else {
            throw TPError.managerInitializationFailed("Failed to create button manager")
        }
        buttonManager?.delegate = self
    }
    
    private func configureHIDDeviceMatching() {
        hidManager?.addDeviceMatching(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Mouse)
        hidManager?.addDeviceMatching(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Pointer)
        
        // Add multiple vendor IDs for broader device support
        hidManager?.addVendorMatching(vendorID: kVendorIDLenovo)  // Lenovo
        hidManager?.addVendorMatching(vendorID: 0x04B3)  // IBM
        hidManager?.addVendorMatching(vendorID: 0x0451)  // Texas Instruments
        hidManager?.addVendorMatching(vendorID: 0x046D)  // Logitech
    }
    
    private func startHIDManager() async -> Bool {
        await hidManager?.start() ?? false
    }
    
    private func handlePermissionError(_ error: Error) async {
        await permissionManager.showPermissionError(error) { [weak self] shouldRetry in
            guard let self = self else { return }
            
            Task {
                if shouldRetry {
                    await self.start()
                } else {
                    self.shouldKeepRunning = false
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    @MainActor
    private func setupAndShowEventViewer() {
        setupQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                do {
                    try await self.setupEventViewer()
                    self.showEventViewer()
                } catch {
                    self.errorHandler.logError(error)
                }
            }
        }
    }
    
    @MainActor
    private func setupEventViewer() async throws {
        guard eventViewController == nil else { return }
        
        // Load view controller from NIB
        guard let mainBundle = Bundle.main.path(forResource: "TPEventViewController", ofType: "nib") else {
            TPLogger.shared.logMessage("Failed to find TPEventViewController.nib")
            throw TPError.resourceNotFound("TPEventViewController.nib not found")
        }
        
        let viewController = TPEventViewController(nibName: "TPEventViewController", bundle: .main)
        viewController.loadView()
        viewController.startMonitoring()
        
        eventViewController = viewController
        TPLogger.shared.logMessage("TPEventViewController loaded from nib")
        
        if eventWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = viewController
            window.title = "Event Viewer"
            window.center()
            eventWindow = window
        }
    }
    
    @MainActor
    private func showEventViewer() {
        eventWindow?.makeKeyAndOrderFront(nil)
    }
    
    @MainActor
    private func hideEventViewer() {
        eventWindow?.orderOut(nil)
    }
}

// MARK: - NSApplicationDelegate

extension TPApplication: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        TPLogger.shared.logMessage("Application did finish launching")
        
        // Process command line arguments
        TPConfig.shared.applyCommandLineArguments(CommandLine.arguments)
        
        // Initialize status bar first
        Task { @MainActor in
            guard let controller = TPStatusBarController.shared else {
                TPLogger.shared.logMessage("Failed to create status bar controller")
                NSApp.terminate(nil)
                return
            }
            
            statusBarController = controller
            statusBarController?.delegate = self
            statusBarController?.setupStatusBar()
            
            isInitialized = true
            TPLogger.shared.logMessage("Application initialization complete")
            
            // Check permissions before starting HID manager
            if let error = permissionManager.checkPermissions() {
                await handlePermissionError(error)
                return
            }
            
            await start()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        guard !waitingForPermissions && !showingPermissionAlert else { return }
        TPLogger.shared.logMessage("Application will terminate")
        cleanup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running even when all windows are closed
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
    func didDetectDeviceAttached(_ deviceInfo: String) {
        TPLogger.shared.logMessage("Device attached: \(deviceInfo)")
    }
    
    func didDetectDeviceDetached(_ deviceInfo: String) {
        TPLogger.shared.logMessage("Device detached: \(deviceInfo)")
    }
    
    func didEncounterError(_ error: Error) {
        errorHandler.showError(error)
        errorHandler.logError(error)
    }
    
    func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool) {
        buttonManager?.updateButtonStates(left: left, right: right, middle: middle)
    }
    
    func didReceiveMovement(deltaX: Int, deltaY: Int, buttonState: UInt8) {
        buttonManager?.handleMovement(deltaX: deltaX, deltaY: deltaY, buttonState: buttonState)
    }
}

// MARK: - TPButtonManagerDelegate

extension TPApplication: TPButtonManagerDelegate {
    func middleButtonStateChanged(_ pressed: Bool) {
        Task { @MainActor in
            eventViewController?.startMonitoring()
        }
    }
}

// MARK: - TPStatusBarControllerDelegate

extension TPApplication: TPStatusBarControllerDelegate {
    func statusBarControllerDidToggleEventViewer(_ show: Bool) {
        if show {
            setupQueue.async { [weak self] in
                guard let self = self else { return }
                
                Task { @MainActor in
                    try? await self.setupEventViewer()
                    self.showEventViewer()
                }
            }
        } else {
            hideEventViewer()
        }
        statusBarController?.updateEventViewerState(show)
    }
    
    func statusBarControllerWillQuit() {
        shouldKeepRunning = false
    }
}

// MARK: - Error Types

enum TPError: LocalizedError {
    case managerInitializationFailed(String)
    case resourceNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .managerInitializationFailed(let message):
            return "Manager initialization failed: \(message)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        }
    }
}
