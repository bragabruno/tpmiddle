import Cocoa
import os.log
import ApplicationServices

public final class TPPermissionManager {
    // MARK: - Properties
    
    public static let shared = TPPermissionManager()
    
    @Published private(set) var waitingForPermissions = false
    @Published private(set) var showingPermissionAlert = false
    
    private let logger = Logger(subsystem: "com.tpmiddle", category: "permissions")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func checkPermissions() -> Error? {
        var missingPermissions: [String] = []
        
        // Check Input Monitoring permission
        if !checkInputMonitoringPermission() {
            missingPermissions.append("Input Monitoring")
        }
        
        // Check Accessibility permission
        if !checkAccessibilityPermission() {
            missingPermissions.append("Accessibility")
        }
        
        // Return appropriate error based on missing permissions
        switch missingPermissions.count {
        case 0:
            return nil
        case 1:
            return missingPermissions[0] == "Input Monitoring" 
                ? TPPermissionError.inputMonitoringDenied
                : TPPermissionError.accessibilityDenied
        default:
            return TPPermissionError.multiplePermissionsDenied
        }
    }
    
    @MainActor
    public func showPermissionError(_ error: Error, completion: @escaping (Bool) -> Void) {
        showingPermissionAlert = true
        
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        
        if let permissionError = error as? TPPermissionError {
            alert.informativeText = """
                TPMiddle requires additional permissions to function properly.
                
                \(permissionError.localizedDescription)
                
                \(permissionError.recoverySuggestion ?? "Please open System Settings and grant the required permissions.")
                """
        } else {
            alert.informativeText = """
                TPMiddle requires additional permissions to function properly.
                
                \(error.localizedDescription)
                
                Please open System Settings and grant the required permissions.
                """
        }
        
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:  // Open System Settings
            if !openSystemPreferences() {
                logger.error("Failed to open System Settings")
                TPErrorHandler.shared.handle(TPPermissionError.systemPreferencesError)
            }
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
    
    private func openSystemPreferences() -> Bool {
        // First try to open the Security & Privacy pane directly
        var url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        
        if !NSWorkspace.shared.open(url) {
            // Fallback to just opening System Settings
            url = URL(string: "x-apple.systempreferences:")!
            return NSWorkspace.shared.open(url)
        }
        
        return true
    }
}

// MARK: - Permission Status Observer

extension TPPermissionManager {
    public func startObservingPermissionStatus() {
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
    public static let permissionsGranted = Notification.Name("TPPermissionsGrantedNotification")
}
