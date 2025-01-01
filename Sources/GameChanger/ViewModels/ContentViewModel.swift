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
        setupMouseEventMonitor()
    }
    
    func resetMouseState() async {
        await mouseHandler.resetMouseState()
    }
    
    private func setupGameController() {
        // Game controller setup implementation
    }
    
    private func setupMouseEventMonitor() {
        NSEventHandler.shared.setupMouseEventMonitor(
            onLeftClick: { [weak self] location in
                if let index = self?.getItemIndexAtLocation(location) {
                    self?.navigationModel.selectedIndex = index
                    self?.navigationModel.handleSelection()
                }
            },
            onRightClick: { [weak self] location in
                if self?.getItemIndexAtLocation(location) != nil {
                    self?.navigationModel.back()
                }
            },
            onMiddleClick: { [weak self] location in
                if self?.getItemIndexAtLocation(location) != nil {
                    self?.navigationModel.back()
                }
            }
        )
    }
    
    private func getItemIndexAtLocation(_ location: NSPoint) -> Int? {
        guard NSApp.windows.first != nil else { return nil }
        let sizing = sizingManager.sizing
        let gridWidth = sizing.iconSize + sizing.gridSpacing
        let gridHeight = sizing.iconSize + sizing.gridSpacing
        
        let sourceItems = AppDataManager.shared.items(for: Section(rawValue: navigationModel.currentSection))
        let startIndex = navigationModel.currentPage * 4
        let endIndex = min(startIndex + 4, sourceItems.count)
        
        for index in startIndex..<endIndex {
            let relativeIndex = index - startIndex
            let row = relativeIndex / 4
            let col = relativeIndex % 4
            
            let itemX = CGFloat(col) * gridWidth + sizing.gridSpacing
            let itemY = CGFloat(row) * gridHeight + sizing.gridSpacing
            
            let itemFrame = CGRect(x: itemX, y: itemY,
                                 width: sizing.iconSize,
                                 height: sizing.iconSize)
            
            if itemFrame.contains(location) {
                return relativeIndex
            }
        }
        return nil
    }
} 