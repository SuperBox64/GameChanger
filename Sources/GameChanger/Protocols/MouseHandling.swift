import AppKit

@preconcurrency protocol MouseHandling: AnyObject {
    @MainActor var mouseState: MouseIndicatorState? { get }
    @MainActor var uiVisibility: UIVisibilityState? { get }
    
    func handleMouseMovement(deltaX: CGFloat) async
    func setupMouseMonitor() async
    func setupMouseTrackingMonitor() async
    func resetMouseState() async
}

@MainActor
class MouseHandler: MouseHandling {
    weak var mouseState: MouseIndicatorState?
    weak var uiVisibility: UIVisibilityState?
    
    // Private state
    private var mouseMonitor: Any?
    private var mouseTimer: Timer?
    private var accumulatedMouseX: CGFloat = 0
    private var mouseProgress: CGFloat = 0
    private var mouseDirection: Int = 0
    private var isMouseInWindow: Bool = false
    
    // Thread-safe callbacks
    private let callbackQueue = DispatchQueue(label: "com.gamechanger.mouse.callbacks")
    private var onMoveLeft: (() -> Void)?
    private var onMoveRight: (() -> Void)?
    
    nonisolated func setMoveLeftHandler(_ handler: @escaping () -> Void) {
        Task { @MainActor in
            self.onMoveLeft = handler
        }
    }
    
    nonisolated func setMoveRightHandler(_ handler: @escaping () -> Void) {
        Task { @MainActor in
            self.onMoveRight = handler
        }
    }
    
    private func executeCallback(_ callback: (() -> Void)?) {
        callbackQueue.async {
            callback?()
        }
    }
    
    init(mouseState: MouseIndicatorState, uiVisibility: UIVisibilityState) {
        self.mouseState = mouseState
        self.uiVisibility = uiVisibility
    }
    
    func setupMouseMonitor() async {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in 
                await self?.handleMouseMovement(deltaX: event.deltaX)
            }
            return event
        }
    }
    
    func setupMouseTrackingMonitor() async {
        NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited]) { [weak self] event in
            if event.type == .mouseEntered {
                self?.isMouseInWindow = true
            } else {
                self?.isMouseInWindow = false
            }
            return event
        }
    }
    
    func handleMouseMovement(deltaX: CGFloat) async {
        guard let uiVisibility = uiVisibility else { return }
        
        if !uiVisibility.mouseVisible {
            let deltaX = deltaX
            
            mouseTimer?.invalidate()
            mouseTimer = Timer.scheduledTimer(
                withTimeInterval: SizingGuide.getCommonSettings().mouseIndicator.inactivityTimeout,
                repeats: false
            ) { [weak self] _ in
                Task {
                    await self?.resetMouseState()
                }
            }
            
            handleMouseDelta(deltaX)
        } else {
            await resetMouseState()
        }
    }
    
    private func handleMouseDelta(_ deltaX: CGFloat) {
        if deltaX != 0 {
            let newDirection = deltaX < 0 ? -1 : 1
            
            if newDirection != mouseDirection {
                accumulatedMouseX = 0
                mouseProgress = 0
                mouseState?.showingProgress = true
            }
            
            mouseDirection = newDirection
        }
        
        accumulatedMouseX += deltaX
        mouseProgress = min(abs(accumulatedMouseX) / SizingGuide.getCommonSettings().mouseSensitivity, 1.0)
        
        if abs(accumulatedMouseX) > SizingGuide.getCommonSettings().mouseSensitivity {
            if accumulatedMouseX < 0 {
                Task { @MainActor in
                    onMoveLeft?()
                }
            } else {
                Task { @MainActor in
                    onMoveRight?()
                }
            }
            accumulatedMouseX = 0
            mouseDirection = 0
            mouseProgress = 0
            mouseState?.showingProgress = false
        }
        
        updateMouseState()
    }
    
    private func updateMouseState() {
        mouseState?.showingProgress = mouseState?.showingProgress ?? false
        mouseState?.mouseProgress = mouseProgress
        mouseState?.mouseDirection = mouseDirection
    }
    
    func resetMouseState() async {
        mouseTimer?.invalidate()
        mouseTimer = nil
        accumulatedMouseX = 0
        mouseProgress = 0
        mouseDirection = 0
        mouseState?.showingProgress = false
        mouseState?.mouseProgress = 0
        mouseState?.mouseDirection = 0
    }
} 