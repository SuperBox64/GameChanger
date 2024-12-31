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
        
        if let _ = selectedItem.parent,
           !AppDataManager.shared.items(for: selectedItem.sectionEnum).isEmpty {
            let fadeEnabled = SizingGuide.getCommonSettings().animations.fadeEnabled
            
            if fadeEnabled {
                let fadeDuration = SizingGuide.getCommonSettings().animations.fade.duration
                
                withAnimation(.linear(duration: fadeDuration / 2)) {
                    opacity = 0.0
                    titleOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDuration / 2)) {
                    self.selectedIndex = 0
                    self.currentPage = 0
                    self.currentSection = selectedItem.sectionEnum.rawValue
                    
                    withAnimation(.linear(duration: fadeDuration / 2)) {
                        self.opacity = 1.0
                        self.titleOpacity = 1.0
                    }
                }
            } else {
                selectedIndex = 0
                currentPage = 0
                currentSection = selectedItem.sectionEnum.rawValue
            }
        }
    }
    
    func moveLeft() {
        let sourceItems = getSourceItems()
        let lastPage = (sourceItems.count - 1) / 4
        
        if self.selectedIndex > 0 {
            self.selectedIndex -= 1
        } else if self.currentPage == 0 {
            let itemsOnLastPage = min(4, sourceItems.count - (lastPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                self.currentPage = lastPage      
                self.selectedIndex = itemsOnLastPage - 1  
                self.nextOffset = 0             
                self.currentOffset = -windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    self.nextOffset = windowWidth    
                    self.currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                self.currentPage = lastPage
                self.selectedIndex = itemsOnLastPage - 1
            }
        } else {
            let nextPage = self.currentPage - 1
            let itemsOnNextPage = min(4, sourceItems.count - (nextPage * 4))
            
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                self.currentPage -= 1           
                self.selectedIndex = itemsOnNextPage - 1  
                self.nextOffset = 0             
                self.currentOffset = -windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    self.nextOffset = windowWidth    
                    self.currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                self.currentPage -= 1
                self.selectedIndex = itemsOnNextPage - 1
            }
        }
    }
    
    func moveRight() {
        let sourceItems = getSourceItems()
        let itemsOnCurrentPage = min(4, sourceItems.count - (self.currentPage * 4))
        let lastPage = (sourceItems.count - 1) / 4
        
        if self.selectedIndex < itemsOnCurrentPage - 1 {
            self.selectedIndex += 1
        } else if self.currentPage == lastPage {
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                self.currentPage = 0            
                self.selectedIndex = 0          
                self.nextOffset = 0             
                self.currentOffset = windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    self.nextOffset = -windowWidth   
                    self.currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                self.currentPage = 0
                self.selectedIndex = 0
            }
        } else {
            if SizingGuide.getCommonSettings().animations.slideEnabled {
                showingNextItems = true
                self.currentPage += 1           
                self.selectedIndex = 0          
                self.nextOffset = 0             
                self.currentOffset = windowWidth 
                
                withAnimation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations)) {
                    self.nextOffset = -windowWidth   
                    self.currentOffset = 0          
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + SizingGuide.getCommonSettings().animations.slide.duration) {
                    self.currentOffset = 0
                    self.showingNextItems = false
                }
            } else {
                self.currentPage += 1
                self.selectedIndex = 0
            }
        }
    }

    func back() {
        let sourceItems = getSourceItems()
        if !sourceItems.isEmpty, let parentSection = sourceItems[0].parentEnum {
            if !parentSection.rawValue.isEmpty {
                let fadeEnabled = SizingGuide.getCommonSettings().animations.fadeEnabled
                
                if fadeEnabled {
                    let fadeDuration = SizingGuide.getCommonSettings().animations.fade.duration
                    
                    withAnimation(.linear(duration: fadeDuration / 2)) {
                        opacity = 0.0
                        titleOpacity = 0.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDuration / 2)) {
                        self.currentSection = parentSection.rawValue
                        self.selectedIndex = 0
                        self.currentPage = 0
                        
                        withAnimation(.linear(duration: fadeDuration / 2)) {
                            self.opacity = 1.0
                            self.titleOpacity = 1.0
                        }
                    }
                } else {
                    self.currentSection = parentSection.rawValue
                    self.selectedIndex = 0
                    self.currentPage = 0
                }
            }
        }
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppDataManager.shared.items(for: Section(rawValue: self.currentSection))
    }
} 