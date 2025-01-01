import SwiftUI

@MainActor
class NavigationModel: ObservableObject {
    static let shared = NavigationModel()
    
    @Published var selectedIndex = 0
    @Published var currentPage = 0
    @Published var currentSection: String = AppDataManager.shared.sections[0].rawValue
    @Published var currentOffset: CGFloat = 0
    @Published var nextOffset: CGFloat = 0
    @Published var showingNextItems = false
    @Published var windowWidth: CGFloat = 0
    @Published var opacity: Double = 1.0
    @Published var titleOpacity: Double = 1.0
    
    private func getSourceItems() -> [AppItem] {
        return AppDataManager.shared.items(for: Section(rawValue: currentSection))
    }
    
    func moveLeft() {
        let sourceItems = getSourceItems()
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else if currentPage == 0 {
            let itemsOnLastPage = min(4, sourceItems.count - (lastPage * 4))
            currentPage = lastPage
            selectedIndex = itemsOnLastPage - 1
        } else {
            let nextPage = currentPage - 1
            let itemsOnNextPage = min(4, sourceItems.count - (nextPage * 4))
            currentPage = nextPage
            selectedIndex = itemsOnNextPage - 1
        }
    }
    
    func moveRight() {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (currentPage * 4))
        let lastPage = (sourceItems.count - 1) / 4
        
        if selectedIndex < itemsOnCurrentPage - 1 {
            selectedIndex += 1
        } else if currentPage == lastPage {
            currentPage = 0
            selectedIndex = 0
        } else {
            currentPage += 1
            selectedIndex = 0
        }
    }
    
    func handleSelection() {
        let sourceItems = getSourceItems()
        guard !sourceItems.isEmpty else { return }
        
        let visibleStartIndex = currentPage * 4
        guard visibleStartIndex >= 0 else { return }
        guard selectedIndex >= 0 else { return }
        
        let actualIndex = visibleStartIndex + selectedIndex
        guard actualIndex < sourceItems.count else { return }
        
        let selectedItem = sourceItems[actualIndex]
        
        if selectedItem.actionEnum != .none {
            selectedIndex = -1
            selectedItem.actionEnum.execute(
                with: selectedItem.path,
                appName: selectedItem.name,
                fullscreen: selectedItem.fullscreen
            )
            return
        }
        
        if !AppDataManager.shared.items(for: selectedItem.sectionEnum).isEmpty {
            currentSection = selectedItem.sectionEnum.rawValue
            selectedIndex = 0
            currentPage = 0
        }
    }
    
    func back() {
        let sourceItems = getSourceItems()
        if !sourceItems.isEmpty, let parentSection = sourceItems[0].parentEnum {
            if !parentSection.rawValue.isEmpty {
                currentSection = parentSection.rawValue
                selectedIndex = 0
                currentPage = 0
            }
        }
    }
} 