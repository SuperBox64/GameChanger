import SwiftUI
import GameController
import Carbon.HIToolbox
import AVFoundation

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @State private var gameController: GCController?
    @State private var accumulatedMouseX: CGFloat = 0
    @State private var accumulatedMouseY: CGFloat = 0
    @State private var isMouseInWindow = false
    @StateObject private var sizingManager = SizingManager.shared
    @State private var currentPage = 0
    @State private var currentSlideOffset: CGFloat = 0
    @State private var nextSlideOffset: CGFloat = 0
    @State private var showingNextSet = false
    @State private var windowWidth: CGFloat = 0
    @State private var animationDirection: Int = 0
    @State private var isTransitioning = false
    @State private var opacity: Double = 1.0
    @State private var titleOpacity: Double = 1
    @State private var currentSection: String = AppDataManager.shared.sections[0].rawValue
    @State private var mouseProgress: CGFloat = 0
    @State private var mouseDirection: Int = 0
    @State private var showingProgress = false
    @State private var mouseTimer: Timer?
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var mouseState = MouseIndicatorState.shared
    @State private var currentOffset: CGFloat = 0
    @State private var nextOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showingNextItems = false
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
    private var visibleItems: [AppItem] {
        let sourceItems = getSourceItems()
        let startIndex = currentPage * 4
        
        // Add bounds checking
        guard startIndex >= 0 && startIndex < sourceItems.count else {
            return []
        }
        
        let endIndex = min(startIndex + 4, sourceItems.count)
        return Array(sourceItems[startIndex..<endIndex])
    }
    
    private var numberOfPages: Int {
        let sourceItems = getSourceItems()
        return (sourceItems.count + 3) / 4
    }
    
    private var normalizedMouseProgress: CGFloat {
        min(abs(accumulatedMouseX) / SizingGuide.getCommonSettings().mouseSensitivity, 1.0)
    }
    
    private func handleSelection() {
        // print("handleSelection() called from:")
        // Thread.callStackSymbols.forEach { print($0) }
        // exit(0)
        
        let sourceItems = getSourceItems()
        
        // Guard against empty source items
        guard !sourceItems.isEmpty else { return }
        
        let visibleStartIndex = currentPage * 4
        
        // Guard against invalid page
        guard visibleStartIndex >= 0 else { return }
        
        // Guard against invalid selection
        guard selectedIndex >= 0 else { return }
        
        let actualIndex = visibleStartIndex + selectedIndex
        
        // Guard against out of bounds
        guard actualIndex < sourceItems.count else { return }
        
        let selectedItem = sourceItems[actualIndex]
        
        if selectedItem.actionEnum == .grid {
            uiVisibility.isGridVisible = true
            uiVisibility.currentGridSection = selectedItem.name
            return
        }
        
        if selectedItem.actionEnum != .none {
            selectedIndex = -1  // Deselect before executing action
            selectedItem.actionEnum.execute(
                with: selectedItem.path,
                appName: selectedItem.name,
                fullscreen: selectedItem.fullscreen
            )
            return
        }
        
        if let _ = selectedItem.parent,
           !AppDataManager.shared.items(for: selectedItem.sectionEnum).isEmpty {
            let fadeEnabled = SizingGuide.getCommonSettings().animations.fadeEnabled
            
            if fadeEnabled {
                let fadeDuration = SizingGuide.getCommonSettings().animations.fade.duration
                
                withAnimation(.linear(duration: fadeDuration / 2)) {  // Half duration for each phase
                    opacity = 0.0
                    titleOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDuration / 2)) {
                    selectedIndex = 0  // Reset selection
                    currentPage = 0    // Reset to first page
                    currentSection = selectedItem.sectionEnum.rawValue
                    
                    withAnimation(.linear(duration: fadeDuration / 2)) {
                        opacity = 1.0
                        titleOpacity = 1.0
                    }
                }
            } else {
                selectedIndex = 0  // Reset selection
                currentPage = 0    // Reset to first page
                currentSection = selectedItem.sectionEnum.rawValue
            }
        }
    }
    
    private func resetMouseState() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        accumulatedMouseX = 0
        mouseProgress = 0
        mouseDirection = 0
        mouseState.showingProgress = false
        mouseState.mouseProgress = 0
        mouseState.mouseDirection = 0
    }
    
    private func setupKeyMonitorForContentView() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle screen recording shortcuts
            switch Int(event.keyCode) {
            case kVK_ANSI_R: // Cmd + R for recording
                Task {
                    do {
                        if screenRecorder.isRecording {
                            try await screenRecorder.stopRecording()
                        } else {
                            try await screenRecorder.startRecording()
                        }
                    } catch {
                        print("Recording error: \(error.localizedDescription)")
                    }
                }
            case kVK_ANSI_C: // Cmd + C for camera toggle
                screenRecorder.toggleCamera()
            case kVK_ANSI_M: // Cmd + M for microphone toggle
                screenRecorder.toggleMicrophone()
            case kVK_ANSI_Q:
                NSApplication.shared.terminate(nil)
            case kVK_Escape:
                UIVisibilityState.shared.mouseVisible.toggle()
                if UIVisibilityState.shared.mouseVisible {
                    SystemActions.sendAppleEvent(kAEActivate)
                    NSCursor.unhide()
                } else {
                    NSCursor.hide()
                    SystemActions.sendAppleEvent(kAEActivate)
                }
            // case kVK_UpArrow:
            //     resetMouseState()
            //     back()
            // case kVK_DownArrow:
            //     resetMouseState()
            //     handleSelection()
            // case kVK_LeftArrow:
            //     resetMouseState()
            //     moveLeft()
            // case kVK_RightArrow:
            //     resetMouseState()
            //     moveRight()
            // case kVK_Return:
            //     resetMouseState()
            //     handleSelection()
            // case kVK_Space:
            //     resetMouseState()
            //     handleSelection()
            default: break
            }
            return event
        }
    }
    
    private var titleFontSize: CGFloat {
        SizingGuide.getCurrentSettings().title.size
    }
    
    private func updateNavigationState() {
        let sourceItems = getSourceItems()
        navigationState.numberOfPages = (sourceItems.count + 3) / 4  // Calculate total pages
        navigationState.currentPage = currentPage
        navigationState.opacity = titleOpacity
    }
    
    private func updateMouseState() {
        mouseState.showingProgress = showingProgress
        mouseState.mouseProgress = mouseProgress
        mouseState.mouseDirection = mouseDirection
    }
    
    // Update where mouse state changes:
    private func handleMouseMovement(_ event: NSEvent) {
        let deltaX = event.deltaX
        
        // Reset and restart inactivity timer
        mouseTimer?.invalidate()
        mouseTimer = Timer.scheduledTimer(
            withTimeInterval: SizingGuide.getCommonSettings().mouseIndicator.inactivityTimeout,
            repeats: false
        ) { _ in
            self.resetMouseState()
        }
        
        // Check for direction change
        if deltaX != 0 {
            let newDirection = deltaX < 0 ? -1 : 1
            
            if newDirection != mouseDirection {
                accumulatedMouseX = 0
                mouseProgress = 0
                showingProgress = true
            }
            
            mouseDirection = newDirection
        }
        
        accumulatedMouseX += deltaX
        mouseProgress = normalizedMouseProgress
        
        if abs(accumulatedMouseX) > SizingGuide.getCommonSettings().mouseSensitivity {
            if accumulatedMouseX < 0 {
                moveLeft()
            } else {
                moveRight()
            }
            accumulatedMouseX = 0
            mouseDirection = 0
            mouseProgress = 0
            showingProgress = false
        }
        
        mouseState.showingProgress = showingProgress
        mouseState.mouseProgress = mouseProgress
        mouseState.mouseDirection = mouseDirection
    }
    
    private func preloadImages() {
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            ImageCache.shared.preloadImages(from: items)
        }
    }
    
    // Update animation access in views
    private var animationSettings: AnimationSettings {
        return SizingGuide.getCommonSettings().animations
    }
    
    var body: some View {
        ZStack {
            BackgroundView(onBack: back)
            
            if uiVisibility.isGridVisible {
                GameGridView(sectionName: uiVisibility.currentGridSection)
            } else {
                GameTimeView(
                    currentSection: $currentSection,
                    selectedIndex: $selectedIndex,
                    titleOpacity: $titleOpacity,
                    opacity: $opacity,
                    back: back,
                    handleSelection: handleSelection,
                    moveLeft: moveLeft,
                    moveRight: moveRight,
                    resetMouseState: resetMouseState,
                    visibleItems: visibleItems,
                    showingNextItems: showingNextItems,
                    nextItems: nextItems,
                    currentOffset: currentOffset,
                    nextOffset: nextOffset,
                    sizingManager: sizingManager
                )
                .onAppear {
                    // setupKeyMonitorForContentView()
                    if let screen = NSScreen.main {
                        sizingManager.updateSizing(for: screen.frame.size)
                        windowWidth = screen.frame.width
                    }
                    updateNavigationState()
                    
                    // Add observer for page jumps
                    NotificationCenter.default.addObserver(
                        forName: .jumpToPage,
                        object: nil,
                        queue: .main) { notification in
                            if let page = notification.userInfo?["page"] as? Int {
                                currentPage = page
                                selectedIndex = 0
                                
                                if SizingGuide.getCommonSettings().animations.bounceEnabled {
                                    opacity = 0
                                    withAnimation(.easeOut(duration: 1.0)) {
                                        opacity = 1
                                    }
                                    NotificationCenter.default.post(name: .bounceItems, object: nil)
                                } else {
                                    opacity = 1
                                }
                            }
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self)
                }
                .onChange(of: currentPage) { _ in
                    updateNavigationState()
                }
                .onChange(of: currentSection) { _ in
                    updateNavigationState()
                }
                .onChange(of: UIVisibilityState.shared.isVisible) { isVisible in
                    if isVisible {
                        let sourceItems = getSourceItems()
                        let startIndex = currentPage * 4
                        let endIndex = min(startIndex + 4, sourceItems.count)
                        
                        if startIndex + selectedIndex < endIndex {
                            resetMouseState()
                            ContentState.shared.selectedIndex = selectedIndex
                            ContentState.shared.currentSection = "Game Changer"
                        }
                    }
                }
            }
        }
    }
    
    private func setupGameController() {
        // Watch for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main) { notification in
                if let controller = notification.object as? GCController {
                    connectController(controller)
                }
        }
        
        // Watch for controller disconnections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main) { _ in
                gameController = nil
        }
        
        // Connect to any already-connected controller
        if let controller = GCController.controllers().first {
            connectController(controller)
        }
    }
    
    private func connectController(_ controller: GCController) {
        gameController = controller
        
        if let gamepad = controller.extendedGamepad {
            // D-pad
            gamepad.dpad.valueChangedHandler = { (_, xValue, yValue) in
                DispatchQueue.main.async {
                    resetMouseState()
                    if yValue == 1 {  // Up
                        back()
                    } else if yValue == -1 {  // Down
                        self.handleSelection()
                    }
                    
                    if xValue == -1 {  // Left
                        self.moveLeft()
                    } else if xValue == 1 {  // Right
                        self.moveRight()
                    }
                }
            }
            
            // A and B buttons both select
            gamepad.buttonA.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.handleSelection()
                    }
                }
            }
            
            gamepad.buttonB.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.handleSelection()
                    }
                }
            }
            
            // X and Y buttons go back
            gamepad.buttonX.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.back()
                    }
                }
            }
            
            gamepad.buttonY.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.back()
                    }
                }
            }
        }
    }
    
    private func setupMouseMonitor() {
        // Mouse movement
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            if !UIVisibilityState.shared.mouseVisible {
                handleMouseMovement(event)
            } else {
                resetMouseState()
            }
            return nil
        }
        
        // Left click and A/B buttons - Select
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if !UIVisibilityState.shared.mouseVisible {
                resetMouseState()
                handleSelection()
            }
            return nil
        }
        
        // Right click - Back
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            if !UIVisibilityState.shared.mouseVisible {
                resetMouseState()
                back()
            } else {
                resetMouseState()
                back()
            }
            return nil
        }
        
        // Middle click - Quit
        NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            if event.buttonNumber == 2 { // Middle click
                NSApplication.shared.terminate(nil)
            }
            return nil
        }
    }
    
    private func setupMouseTrackingMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited]) { event in
            switch event.type {
            case .mouseEntered:
                isMouseInWindow = true
            case .mouseExited:
                isMouseInWindow = false
            default:
                break
            }
            return nil
        }
        
        // Initial state check
        if let window = NSApp.windows.first,
           let mouseLocation = NSEvent.mouseLocation.asScreenPoint,
           window.frame.contains(mouseLocation) {
            isMouseInWindow = true
        }
    }
    
    private func enforceSelectionRules() {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (currentPage * 4))
        if selectedIndex >= itemsOnCurrentPage {
            selectedIndex = itemsOnCurrentPage - 1
        }
    }
    
    private func moveLeft() {
        let sourceItems = getSourceItems()
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex > 0 {
            // Move left within current page
            selectedIndex -= 1
        } else if currentPage == 0 {
            // Loop to last page
            let itemsOnLastPage = min(4, sourceItems.count - (lastPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage = lastPage      // First update page to show new items
                selectedIndex = itemsOnLastPage - 1  // Select last item BEFORE animation
                nextOffset = 0             // Start OLD items at center
                currentOffset = -windowWidth // Start NEW items off left edge
                
                withAnimation(.carouselSlide(settings: animationSettings)) {
                    nextOffset = windowWidth    // OLD items slide right and out
                    currentOffset = 0          // NEW items slide right and in
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                    currentOffset = 0
                    showingNextItems = false
                }
            } else {
                currentPage = lastPage
                selectedIndex = itemsOnLastPage - 1
            }
        } else {
            // Normal previous page behavior
            let nextPage = currentPage - 1
            let itemsOnNextPage = min(4, sourceItems.count - (nextPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage -= 1           // First update page to show new items
                selectedIndex = itemsOnNextPage - 1  // Select last item BEFORE animation
                nextOffset = 0             // Start OLD items at center
                currentOffset = -windowWidth // Start NEW items off left edge
                
                withAnimation(.carouselSlide(settings: animationSettings)) {
                    nextOffset = windowWidth    // OLD items slide right and out
                    currentOffset = 0          // NEW items slide right and in
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                    currentOffset = 0
                    showingNextItems = false
                }
            } else {
                currentPage -= 1
                selectedIndex = itemsOnNextPage - 1
            }
        }
    }
    
    private func moveRight() {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (currentPage * 4))
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex < itemsOnCurrentPage - 1 {
            // Move right within current page
            selectedIndex += 1
        } else if currentPage == lastPage {
            // Loop to first page
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage = 0            // First update page to show new items
                selectedIndex = 0          // Select first item BEFORE animation
                nextOffset = 0             // Start OLD items at center
                currentOffset = windowWidth // Start NEW items off right edge
                
                withAnimation(.carouselSlide(settings: animationSettings)) {
                    nextOffset = -windowWidth   // OLD items slide left and out
                    currentOffset = 0          // NEW items slide left and in
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                    currentOffset = 0
                    showingNextItems = false
                }
            } else {
                currentPage = 0
                selectedIndex = 0
            }
        } else {
            // Normal next page behavior
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                currentPage += 1           // First update page to show new items
                selectedIndex = 0          // Select first item BEFORE animation
                nextOffset = 0             // Start OLD items at center
                currentOffset = windowWidth // Start NEW items off right edge
                
                withAnimation(.carouselSlide(settings: animationSettings)) {
                    nextOffset = -windowWidth   // OLD items slide left and out
                    currentOffset = 0          // NEW items slide left and in
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                    currentOffset = 0
                    showingNextItems = false
                }
            } else {
                currentPage += 1
                selectedIndex = 0
            }
        }
    }
    
    private func moveUp() {
        let sourceItems = getSourceItems()
        if selectedIndex < 4 {
            let bottomRowStart = (sourceItems.count - 1) / 4 * 4
            selectedIndex = min(bottomRowStart + (selectedIndex % 4), sourceItems.count - 1)
        } else {
            selectedIndex -= 4
        }
    }
    
    private func moveDown() {
        let sourceItems = getSourceItems()
        if selectedIndex + 4 >= sourceItems.count {
            selectedIndex = selectedIndex % 4
        } else {
            selectedIndex += 4
        }
    }
    
    public func back() {
        let sourceItems = getSourceItems()
        if !sourceItems.isEmpty, let parentSection = sourceItems[0].parentEnum {
            // Only go back if the parent exists and isn't empty
            if !parentSection.rawValue.isEmpty {
                let fadeEnabled = SizingGuide.getCommonSettings().animations.fadeEnabled
                
                if fadeEnabled {
                    let fadeDuration = SizingGuide.getCommonSettings().animations.fade.duration
                    
                    withAnimation(.linear(duration: fadeDuration / 2)) {  // Half duration for each phase
                        opacity = 0.0
                        titleOpacity = 0.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDuration / 2)) {
                        currentSection = parentSection.rawValue
                        selectedIndex = 0
                        currentPage = 0
                        
                        withAnimation(.linear(duration: fadeDuration / 2)) {
                            opacity = 1.0
                            titleOpacity = 1.0
                        }
                    }
                } else {
                    currentSection = parentSection.rawValue
                    selectedIndex = 0
                    currentPage = 0
                }
            }
        }
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppDataManager.shared.items(for: Section(rawValue: currentSection))
    }
    
    private var nextItems: [AppItem] {
        let sourceItems = getSourceItems()
        let totalItems = sourceItems.count
        let itemsPerPage = 4
        let lastPage = (totalItems - 1) / itemsPerPage
        
        // If we're on the last page, get items from first page
        if currentPage == lastPage {
            let startIndex = 0
            let endIndex = min(4, sourceItems.count)
            return Array(sourceItems[startIndex..<endIndex])
        } else {
            // Get items from next page
            let startIndex = (currentPage + 1) * 4
            let endIndex = min(startIndex + 4, sourceItems.count)
            return Array(sourceItems[startIndex..<endIndex])
        }
    }
    
    // Add this function to handle left selection
    private func moveSelection(left: Bool) {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (currentPage * 4))
        
        if left {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
        } else {
            if selectedIndex < itemsOnCurrentPage - 1 {
                selectedIndex += 1
            }
        }
    }
    
    private func getSelectedItem() -> AppItem? {
        let sourceItems = getSourceItems()
        let startIndex = currentPage * 4
        let endIndex = min(startIndex + 4, sourceItems.count)
        
        // Make sure selectedIndex is valid for current page
        guard startIndex + selectedIndex < endIndex else {
            return nil
        }
        
        return sourceItems[startIndex + selectedIndex]
    }
}