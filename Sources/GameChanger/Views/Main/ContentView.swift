import SwiftUI
import GameController
import Carbon.HIToolbox
import AVFoundation

struct ContentView: View {
    // Existing state objects
    @StateObject private var appState = AppState.shared
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var mouseState = MouseIndicatorState.shared
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @StateObject private var navigationModel = NavigationModel.shared
    
    private var visibleItems: [AppItem] {
        let sourceItems = AppDataManager.shared.items(for: Section(rawValue: navigationModel.currentSection))
        let startIndex = navigationModel.currentPage * 4
        guard startIndex >= 0 && startIndex < sourceItems.count else { return [] }
        let endIndex = min(startIndex + 4, sourceItems.count)
        return Array(sourceItems[startIndex..<endIndex])
    }
    
    private var nextItems: [AppItem] {
        let sourceItems = AppDataManager.shared.items(for: Section(rawValue: navigationModel.currentSection))
        let totalItems = sourceItems.count
        let lastPage = (totalItems - 1) / 4
        
        if navigationModel.currentPage == lastPage {
            let endIndex = min(4, sourceItems.count)
            return Array(sourceItems[0..<endIndex])
        } else {
            let startIndex = (navigationModel.currentPage + 1) * 4
            let endIndex = min(startIndex + 4, sourceItems.count)
            return Array(sourceItems[startIndex..<endIndex])
        }
    }
    
    var body: some View {
        ZStack {
           
            
            VStack {
                Text(navigationModel.currentSection)
                    .font(.custom(
                        SizingGuide.getCommonSettings().fonts.title,
                        size: SizingGuide.getCurrentSettings().title.size
                    ))
                    .foregroundColor(.white)
                    .opacity(navigationModel.titleOpacity)
                    .padding(.top, SizingGuide.getCurrentSettings().title.topPadding)
                Spacer()
            }
            .opacity(uiVisibility.isVisible ? 1 : 0)

            CarouselView(
                visibleItems: visibleItems,
                selectedIndex: UIVisibilityState.shared.mouseVisible ? -1 : navigationModel.selectedIndex,
                sizing: sizingManager.sizing,
                currentOffset: navigationModel.currentOffset,
                showingNextItems: navigationModel.showingNextItems,
                nextOffset: navigationModel.nextOffset,
                nextItems: nextItems,
                onHighlight: { index in
                    if UIVisibilityState.shared.mouseVisible {
                        navigationModel.selectedIndex = index
                    }
                },
                onSelect: { index in
                    navigationModel.selectedIndex = index
                    navigationModel.handleSelection()
                },
                onBack: { index in
                    navigationModel.selectedIndex = index
                    navigationModel.back()
                },
                onSwipeLeft: {
                    if UIVisibilityState.shared.mouseVisible {
                        navigationModel.moveRight()
                    }
                },
                onSwipeRight: {
                    if UIVisibilityState.shared.mouseVisible {
                        navigationModel.moveLeft()
                    }
                }
            )
            .opacity(navigationModel.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await ContentViewModel.shared.setupMonitors()
            }
            if let screen = NSScreen.main {
                sizingManager.updateSizing(for: screen.frame.size)
                navigationModel.windowWidth = screen.frame.width
            }
        }
    }
}