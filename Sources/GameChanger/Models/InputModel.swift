import SwiftUI
import GameController
import Carbon.HIToolbox

@MainActor
class InputModel: ObservableObject {
    static let shared = InputModel()
    
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var gameController: GCController?
    
    @Published var accumulatedMouseX: CGFloat = 0
    @Published var mouseProgress: CGFloat = 0
    @Published var mouseDirection: Int = 0
    @Published var showingProgress = false
    private var mouseTimer: Timer?
    
    func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_ANSI_R where event.modifierFlags.contains(.command):
                Task {
                    if ScreenRecorder().isRecording {
                        try await ScreenRecorder().stopRecording()
                    } else {
                        try await ScreenRecorder().startRecording()
                    }
                }
            case kVK_ANSI_C where event.modifierFlags.contains(.command):
                ScreenRecorder().toggleCamera()
            case kVK_ANSI_M where event.modifierFlags.contains(.command):
                ScreenRecorder().toggleMicrophone()
            case kVK_ANSI_G:
                UIVisibilityState.shared.isGridVisible.toggle()
            case kVK_ANSI_Q:
                NSApplication.shared.terminate(nil)
            case kVK_Escape:
                UIVisibilityState.shared.mouseVisible.toggle()
                if UIVisibilityState.shared.mouseVisible {
                    NSCursor.unhide()
                } else {
                    NSCursor.hide()
                }
            case kVK_UpArrow:
                NavigationModel.shared.back()
            case kVK_DownArrow:
                NavigationModel.shared.handleSelection()
            case kVK_LeftArrow:
                NavigationModel.shared.moveLeft()
            case kVK_RightArrow:
                NavigationModel.shared.moveRight()
            case kVK_Return, kVK_Space:
                NavigationModel.shared.handleSelection()
            default:
                break
            }
            return nil
        }
    }
} 