import SwiftUI
import GameController
import Carbon.HIToolbox

@MainActor
class ContentViewModel: ObservableObject {
    static let shared = ContentViewModel()
    
    // Core state objects
    let appState = AppState.shared
    let sizingManager = SizingManager.shared
    let navigationState = NavigationState.shared
    let mouseState = MouseIndicatorState.shared
    let screenRecorder = ScreenRecorder()
    let uiVisibility = UIVisibilityState.shared
    
    // Mouse handling
    private lazy var mouseHandler: MouseHandler = {
        let handler = MouseHandler(mouseState: mouseState, uiVisibility: uiVisibility)
        handler.setMoveLeftHandler { [weak self] in
            Task { @MainActor in
                await self?.resetMouseState()
                self?.moveLeft()
            }
        }
        handler.setMoveRightHandler { [weak self] in
            Task { @MainActor in
                await self?.resetMouseState()
                self?.moveRight()
            }
        }
        return handler
    }()
    
    // Published state
    @Published var selectedIndex = 0
    @Published var currentPage = 0
    @Published var opacity: Double = 1.0
    @Published var titleOpacity: Double = 1.0
    @Published var currentSection: String = AppDataManager.shared.sections[0].rawValue
    @Published var currentOffset: CGFloat = 0
    @Published var nextOffset: CGFloat = 0
    @Published var showingNextItems = false
    
    // Other state
    var keyMonitor: Any?
    var gameController: GCController?
    var windowWidth: CGFloat = 0
    

    func setupMonitors() async {
        InputModel.shared.setupKeyMonitor()
        setupGameController()
        await mouseHandler.setupMouseMonitor()
        await mouseHandler.setupMouseTrackingMonitor()
    }
    
    func resetMouseState() async {
        await mouseHandler.resetMouseState()
    }

    // MARK: - Navigation Methods
    
    func moveLeft() {
        let sourceItems = getSourceItems()
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else if currentPage == 0 {
            let itemsOnLastPage = min(4, sourceItems.count - (lastPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage = lastPage      
                selectedIndex = itemsOnLastPage - 1  
                nextOffset = 0             
                currentOffset = -windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    nextOffset = windowWidth    
                    currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                currentPage = lastPage
                selectedIndex = itemsOnLastPage - 1
            }
        } else {
            let nextPage = currentPage - 1
            let itemsOnNextPage = min(4, sourceItems.count - (nextPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage -= 1           
                selectedIndex = itemsOnNextPage - 1  
                nextOffset = 0             
                currentOffset = -windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    nextOffset = windowWidth    
                    currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                currentPage -= 1
                selectedIndex = itemsOnNextPage - 1
            }
        }
    }
    
    func moveRight() {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (currentPage * 4))
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex < itemsOnCurrentPage - 1 {
            selectedIndex += 1
        } else if currentPage == lastPage {
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage = 0            
                selectedIndex = 0          
                nextOffset = 0             
                currentOffset = windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    nextOffset = -windowWidth   
                    currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                currentPage = 0
                selectedIndex = 0
            }
        } else {
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage += 1           
                selectedIndex = 0          
                nextOffset = 0             
                currentOffset = windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    nextOffset = -windowWidth   
                    currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                currentPage += 1
                selectedIndex = 0
            }
        }
    }

    private func getSourceItems() -> [AppItem] {
        // Implementation needed
        return []
    }



    private func setupGameController() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidConnect),
            name: .GCControllerDidBecomeCurrent,
            object: nil
        )
        
        if let controller = GCController.current {
            gameController = controller
            configureGameController(controller)
        }
    }

    @objc private func handleControllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            gameController = controller
            configureGameController(controller)
        }
    }

    private func configureGameController(_ controller: GCController) {
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, _ in
            if xValue < -0.5 {
                self?.moveLeft()
            } else if xValue > 0.5 {
                self?.moveRight()
            }
        }
        
        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] _, xValue, _ in
            if xValue < -0.5 {
                self?.moveLeft()
            } else if xValue > 0.5 {
                self?.moveRight()
            }
        }
    }
} 