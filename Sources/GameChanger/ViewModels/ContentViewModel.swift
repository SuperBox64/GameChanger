import SwiftUI
import GameController
import Carbon.HIToolbox

@MainActor
class ContentViewModel: ObservableObject {
    static let shared = ContentViewModel()
    
    // Core state objects
    let appState = AppState.shared
    let sizingManager = SizingManager.shared
    let navigationModel = NavigationModel.shared
    let mouseState = MouseIndicatorState.shared
    let uiVisibility = UIVisibilityState.shared
    
    private lazy var mouseHandler: MouseHandler = {
        let handler = MouseHandler(mouseState: mouseState, uiVisibility: uiVisibility)
        handler.setMoveLeftHandler { [weak self] in
            Task { @MainActor in
                await self?.resetMouseState()
                self?.navigationModel.moveLeft()
            }
        }
        handler.setMoveRightHandler { [weak self] in
            Task { @MainActor in
                await self?.resetMouseState()
                self?.navigationModel.moveRight()
            }
        }
        return handler
    }()
    
    func setupMonitors() async {
        InputModel.shared.setupKeyMonitor()
        setupGameController()
        await mouseHandler.setupMouseMonitor()
        await mouseHandler.setupMouseTrackingMonitor()
    }
    
    func resetMouseState() async {
        await mouseHandler.resetMouseState()
    }
    
    private func setupGameController() {
        // Game controller setup implementation
    }
} 