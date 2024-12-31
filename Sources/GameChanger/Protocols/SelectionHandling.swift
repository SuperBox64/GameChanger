import SwiftUI

@preconcurrency protocol SelectionHandling: AnyObject {
    // Core navigation methods
    func moveLeft() async
    func moveRight() async
    func select(at index: Int) async
}

@MainActor
class SelectionHandler: SelectionHandling {
    // State
    @Published private(set) var selectedIndex = 0
    @Published private(set) var currentPage = 0
    @Published private(set) var showingNextItems = false
    @Published private(set) var currentOffset: CGFloat = 0
    @Published private(set) var nextOffset: CGFloat = 0
    
    // Configuration
    var windowWidth: CGFloat = 0
    
    // Dependencies
    private weak var navigationState = NavigationState.shared
    private weak var appDataManager = AppDataManager.shared
    private var currentSection: String = AppDataManager.shared.sections[0].rawValue
    
    init() {
        // Use shared instances
    }
    
    func moveLeft() async {
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
    
    func moveRight() async {
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
    
    func select(at index: Int) async {
        selectedIndex = index
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppDataManager.shared.items(for: Section(rawValue: currentSection))
    }
} 