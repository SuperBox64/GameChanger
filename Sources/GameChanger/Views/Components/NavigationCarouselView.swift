import SwiftUI

struct NavigationCarouselView: View {
    @StateObject private var navigationModel = NavigationModel.shared
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
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
        CarouselView(
            visibleItems: visibleItems,
            selectedIndex: uiVisibility.mouseVisible ? -1 : navigationModel.selectedIndex,
            sizing: sizingManager.sizing,
            currentOffset: navigationModel.currentOffset,
            showingNextItems: navigationModel.showingNextItems,
            nextOffset: navigationModel.nextOffset,
            nextItems: nextItems,
            onHighlight: { index in
                if uiVisibility.mouseVisible {
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
                if uiVisibility.mouseVisible {
                    navigationModel.moveRight()
                }
            },
            onSwipeRight: {
                if uiVisibility.mouseVisible {
                    navigationModel.moveLeft()
                }
            }
        )
        .opacity(navigationModel.opacity)
    }
} 