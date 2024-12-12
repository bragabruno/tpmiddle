import Cocoa
import os.log
import ApplicationServices

final class TPPermissionManager {
    static let shared = TPPermissionManager()
    
    // MARK: - Properties
    
    @Published private(set) var waitingForPermissions = false
    @Published private(set) var showingPermissionAlert = false
    
    private let logger = Logger(subsystem: "com.tpmiddle", category: "permissions")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    func checkPermissions() -> Error? {
        // Check Input Monitoring permission
        if !checkInputMonitoringPermission() {
            return TPError.permissionDenied("Input Monitoring permission is required")
        }
        
        // Check Accessibility permission
        if !checkAccessibilityPermission() {
            return TPError.permissionDenied("Accessibility permission is required")
        }
        
        return nil
    }
    
    @MainActor
    func showPermissionError(_ error: Error, completion: @escaping (Bool) -> Void) {
        showingPermissionAlert = true
        
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = """
            TPMiddle requires additional permissions to function properly.
            
            \(error.localizedDescription)
            
            Please open System Preferences and grant the required permissions.
            """
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:  // Open System Preferences
            openSystemPreferences()
            waitingForPermissions = true
            showingPermissionAlert = false
            completion(true)
            
        case .alertSecondButtonReturn:  // Retry
            showingPermissionAlert = false
            completion(true)
            
        default:  // Quit
            showingPermissionAlert = false
            completion(false)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkInputMonitoringPermission() -> Bool {
        let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [trusted: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options = NSDictionary(object: kCFBooleanTrue!, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func openSystemPreferences() {
        // First try to open the Security & Privacy pane directly
        var url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        
        if !NSWorkspace.shared.open(url) {
            // Fallback to just opening System Preferences
            url = URL(string: "x-apple.systempreferences:")!
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Status Observer

extension TPPermissionManager {
    func startObservingPermissionStatus() {
        // Create a timer to check permission status periodically when waiting
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self,
                  self.waitingForPermissions else {
                timer.invalidate()
                return
            }
            
            // Check if permissions have been granted
            if self.checkInputMonitoringPermission() && self.checkAccessibilityPermission() {
                self.waitingForPermissions = false
                timer.invalidate()
                
                // Post notification that permissions have been granted
                NotificationCenter.default.post(
                    name: .permissionsGranted,
                    object: nil
                )
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let permissionsGranted = Notification.Name("TPPermissionsGrantedNotification")
}

// MARK: - Error Types

enum TPError: LocalizedError {
    case permissionDenied(String)
    case deviceNotFound(String)
    case configurationError(String)
    case hidError(String)
    case resourceNotFound(String)
    case managerInitializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .deviceNotFound(let message):
            return "Device not found: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .hidError(let message):
            return "HID error: \(message)"
        case .resourceNotFound(let message):
            return "Resource not found: \(message)"
        case .managerInitializationFailed(let message):
            return "Manager initialization failed: \(message)"
        }
    }
}
