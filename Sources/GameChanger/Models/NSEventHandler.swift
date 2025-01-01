import AppKit

@MainActor
class NSEventHandler: ObservableObject {
    static let shared = NSEventHandler()
    
    private var mouseMonitor: Any?
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    func setupMouseEventMonitor(
        onLeftClick: @escaping (NSPoint) -> Void,
        onRightClick: @escaping (NSPoint) -> Void,
        onMiddleClick: @escaping (NSPoint) -> Void
    ) {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
            switch event.type {
            case .leftMouseDown:
                if UIVisibilityState.shared.mouseVisible {
                    onLeftClick(event.locationInWindow)
                }
            case .rightMouseDown:
                onRightClick(event.locationInWindow)
            case .otherMouseDown where event.buttonNumber == 2:
                onMiddleClick(event.locationInWindow)
            default:
                break
            }
            return event
        }
    }
    
    func removeMouseEventMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
} 