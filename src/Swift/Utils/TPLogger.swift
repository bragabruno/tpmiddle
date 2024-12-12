import Foundation
import os.log

final class TPLogger {
    static let shared = TPLogger()
    
    private let logger: Logger
    private var isLogging = false
    
    private init() {
        self.logger = Logger(subsystem: "com.tpmiddle", category: "general")
    }
    
    func startLogging() {
        isLogging = true
        logMessage("Logging started")
    }
    
    func stopLogging() {
        logMessage("Logging stopped")
        isLogging = false
    }
    
    func logMessage(_ message: String) {
        guard isLogging else { return }
        logger.info("\(message)")
        
        #if DEBUG
        print("TPMiddle: \(message)")
        #endif
    }
}
