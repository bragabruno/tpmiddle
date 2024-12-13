import Cocoa
import os.log

public final class TPApplication {
    // MARK: - Properties
    
    public static let shared = TPApplication()
    
    private let logger = Logger(subsystem: "com.tpmiddle", category: "application")
    private let errorHandler = TPErrorHandler.shared
    private let permissionManager = TPPermissionManager.shared
    
    private var statusBarController: TPStatusBarController?
    private var hidManager: TPHIDManager?
    private var buttonManager: TPButtonManager?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func start() {
        do {
            // Check permissions first
            if let error = permissionManager.checkPermissions() {
                permissionManager.showPermissionError(error) { shouldRetry in
                    if shouldRetry {
                        self.permissionManager.startObservingPermissionStatus()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
                return
            }
            
            // Initialize components
            try initializeComponents()
            
            // Start HID manager
            do {
                try hidManager?.start()
            } catch {
                logger.error("Failed to start HID Manager: \(error.localizedDescription)")
                errorHandler.handle(error)
            }
            
        } catch {
            errorHandler.handle(error)
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeComponents() throws {
        // Initialize status bar first
        statusBarController = TPStatusBarController()
        guard statusBarController != nil else {
            throw TPApplicationError.componentInitializationFailed("Status Bar Controller")
        }
        
        // Initialize HID manager
        hidManager = TPHIDManager()
        guard hidManager != nil else {
            throw TPApplicationError.componentInitializationFailed("HID Manager")
        }
        
        // Initialize button manager
        buttonManager = TPButtonManager()
        guard buttonManager != nil else {
            throw TPApplicationError.componentInitializationFailed("Button Manager")
        }
        
        // Load event view controller
        if let mainBundle = Bundle.main,
           let nibPath = mainBundle.path(forResource: "TPEventViewController", ofType: "nib") {
            if !FileManager.default.fileExists(atPath: nibPath) {
                throw TPApplicationError.resourceNotFound("TPEventViewController.nib")
            }
        }
        
        // Setup component relationships
        setupComponentRelationships()
    }
    
    private func setupComponentRelationships() {
        // Set up any necessary delegates or relationships between components
        hidManager?.delegate = buttonManager
        buttonManager?.delegate = statusBarController
    }
}

// MARK: - Notification Handling

extension TPApplication {
    @objc private func handlePermissionsGranted(_ notification: Notification) {
        start()
    }
}
