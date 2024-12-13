import Cocoa
import Combine

/// View controller for displaying input events
public final class TPEventViewController: NSViewController {
    // MARK: - Types
    
    private struct Constants {
        static let indicatorSize: CGFloat = 8.0
        static let indicatorRadius: CGFloat = 4.0
        static let baseScale: CGFloat = 1.0
        static let magnitudeScale: CGFloat = 0.05
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet private weak var movementView: NSView!
    @IBOutlet private weak var deltaLabel: NSTextField!
    @IBOutlet private weak var leftButton: NSButton!
    @IBOutlet private weak var middleButton: NSButton!
    @IBOutlet private weak var rightButton: NSButton!
    @IBOutlet private weak var scrollLabel: NSTextField!
    
    // MARK: - Properties
    
    /// Delegate for receiving event viewer updates
    public weak var delegate: TPEventViewControllerDelegate?
    
    // MARK: - Private Properties
    
    private var centerIndicator: NSView!
    private var lastPoint: NSPoint = .zero
    private var accumulatedScrollX: CGFloat = 0
    private var accumulatedScrollY: CGFloat = 0
    private var isMonitoring = false
    
    private weak var hidManager = TPHIDManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        TPLogger.shared.log("TPEventViewController initialized with nib")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        TPLogger.shared.log("TPEventViewController initialized from coder")
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        TPLogger.shared.log("TPEventViewController viewDidLoad")
        
        setupUI()
        setupNotifications()
    }
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        centerIndicator()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring input events
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        TPLogger.shared.log("TPEventViewController startMonitoring")
        isMonitoring = true
        
        // Reset the view
        centerIndicator()
        accumulatedScrollX = 0
        accumulatedScrollY = 0
        deltaLabel.stringValue = "X: 0, Y: 0"
        scrollLabel.stringValue = "Scroll: 0, 0"
        leftButton.state = .off
        middleButton.state = .off
        rightButton.state = .off
        
        delegate?.eventViewerDidStartMonitoring?()
    }
    
    /// Stop monitoring input events
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        TPLogger.shared.log("TPEventViewController stopMonitoring")
        isMonitoring = false
        
        delegate?.eventViewerDidStopMonitoring?()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        // Setup main view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Log outlet connections
        TPLogger.shared.log("""
        Checking outlet connections:
        movementView: \(String(describing: movementView))
        deltaLabel: \(String(describing: deltaLabel))
        scrollLabel: \(String(describing: scrollLabel))
        leftButton: \(String(describing: leftButton))
        middleButton: \(String(describing: middleButton))
        rightButton: \(String(describing: rightButton))
        """)
        
        guard movementView != nil else {
            TPLogger.shared.log("Error: movementView outlet not connected!")
            return
        }
        
        // Setup movement view
        movementView.wantsLayer = true
        movementView.layer?.backgroundColor = NSColor.gridColor.cgColor
        movementView.layer?.cornerRadius = 4.0
        
        // Create center point indicator
        centerIndicator = NSView(frame: NSRect(x: 0, y: 0, width: Constants.indicatorSize, height: Constants.indicatorSize))
        centerIndicator.wantsLayer = true
        centerIndicator.layer?.backgroundColor = NSColor.systemBlue.cgColor
        centerIndicator.layer?.cornerRadius = Constants.indicatorRadius
        movementView.addSubview(centerIndicator)
        
        // Center the indicator
        centerIndicator()
        
        // Initialize labels
        deltaLabel.stringValue = "X: 0, Y: 0"
        scrollLabel.stringValue = "Scroll: 0, 0"
        
        // Setup buttons
        leftButton.state = .off
        middleButton.state = .off
        rightButton.state = .off
    }
    
    private func setupNotifications() {
        // Movement notifications
        NotificationCenter.default.publisher(for: .TPMovement)
            .compactMap { $0.userInfo }
            .sink { [weak self] info in
                self?.handleMovement(
                    deltaX: info["deltaX"] as? Int ?? 0,
                    deltaY: info["deltaY"] as? Int ?? 0,
                    buttons: info["buttons"] as? UInt8 ?? 0
                )
            }
            .store(in: &cancellables)
        
        // Button notifications
        NotificationCenter.default.publisher(for: .TPButton)
            .compactMap { $0.userInfo }
            .sink { [weak self] info in
                self?.handleButtons(
                    left: info["left"] as? Bool ?? false,
                    right: info["right"] as? Bool ?? false,
                    middle: info["middle"] as? Bool ?? false
                )
            }
            .store(in: &cancellables)
    }
    
    private func centerIndicator() {
        guard let movementView = movementView else { return }
        
        let bounds = movementView.bounds
        let x = NSMidX(bounds) - Constants.indicatorRadius
        let y = NSMidY(bounds) - Constants.indicatorRadius
        
        centerIndicator.frame = NSRect(
            x: x,
            y: y,
            width: Constants.indicatorSize,
            height: Constants.indicatorSize
        )
        lastPoint = NSPoint(x: NSMidX(bounds), y: NSMidY(bounds))
    }
    
    private func handleMovement(deltaX: Int, deltaY: Int, buttons: UInt8) {
        guard isMonitoring else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update delta label
            self.deltaLabel.stringValue = "X: \(deltaX), Y: \(deltaY)"
            
            // Move indicator
            guard let movementView = self.movementView else { return }
            
            let bounds = movementView.bounds
            
            // Calculate movement magnitude for diagonal scaling
            let magnitude = sqrt(Double(deltaX * deltaX + deltaY * deltaY))
            let scaleFactor = Constants.baseScale * (1.0 + magnitude * Constants.magnitudeScale)
            
            // Apply scaling uniformly to maintain direction
            let scaledDeltaX = CGFloat(deltaX) * scaleFactor
            let scaledDeltaY = CGFloat(deltaY) * scaleFactor
            
            // Apply inversion if configured
            let config = TPConfig.shared
            let finalDeltaX = config.invertScrollX ? -scaledDeltaX : scaledDeltaX
            let finalDeltaY = config.invertScrollY ? -scaledDeltaY : scaledDeltaY
            
            // Calculate new position with unified scaling
            var newX = self.lastPoint.x - finalDeltaX
            var newY = self.lastPoint.y - finalDeltaY
            
            // Ensure the center of the indicator stays within bounds
            newX = min(max(Constants.indicatorRadius, newX), bounds.width - Constants.indicatorRadius)
            newY = min(max(Constants.indicatorRadius, newY), bounds.height - Constants.indicatorRadius)
            
            self.lastPoint = NSPoint(x: newX, y: newY)
            
            // Update indicator position
            self.centerIndicator.frame = NSRect(
                x: newX - Constants.indicatorRadius,
                y: newY - Constants.indicatorRadius,
                width: Constants.indicatorSize,
                height: Constants.indicatorSize
            )
            
            // Update scroll accumulation if needed
            if (buttons & 0x04 != 0) || self.hidManager?.isScrollMode == true {
                self.accumulatedScrollX += CGFloat(deltaX)
                self.accumulatedScrollY += CGFloat(deltaY)
                self.scrollLabel.stringValue = "Scroll: \(Int(self.accumulatedScrollX)), \(Int(self.accumulatedScrollY))"
            }
            
            self.delegate?.eventViewerDidReceiveMovement?(deltaX: deltaX, deltaY: deltaY, buttons: buttons)
        }
    }
    
    private func handleButtons(left: Bool, right: Bool, middle: Bool) {
        guard isMonitoring else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.leftButton.state = left ? .on : .off
            self.rightButton.state = right ? .on : .off
            self.middleButton.state = middle ? .on : .off
            
            self.delegate?.eventViewerDidReceiveButtonPress?(left: left, right: right, middle: middle)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let TPMovement = Notification.Name("TPMovementNotification")
    static let TPButton = Notification.Name("TPButtonNotification")
}
