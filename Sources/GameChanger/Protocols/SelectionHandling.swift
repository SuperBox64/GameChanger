import SwiftUI

@preconcurrency protocol SelectionHandling: AnyObject {
    func handleSelection() async
}

@MainActor
class SelectionHandler {
    private let viewModel: ContentViewModel
    
    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }
    
    func handleSelection() async {
        let sourceItems = getSourceItems()
        guard !sourceItems.isEmpty else { return }
        
        let visibleStartIndex = viewModel.currentPage * 4
        guard visibleStartIndex >= 0 else { return }
        guard viewModel.selectedIndex >= 0 else { return }
        
        let actualIndex = visibleStartIndex + viewModel.selectedIndex
        guard actualIndex < sourceItems.count else { return }
        
        let selectedItem = sourceItems[actualIndex]
        
        if selectedItem.actionEnum != .none {
            viewModel.selectedIndex = -1
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
                    viewModel.opacity = 0.0
                    viewModel.titleOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDuration / 2)) {
                    self.viewModel.selectedIndex = 0
                    self.viewModel.currentPage = 0
                    self.viewModel.currentSection = selectedItem.sectionEnum.rawValue
                    
                    withAnimation(.linear(duration: fadeDuration / 2)) {
                        self.viewModel.opacity = 1.0
                        self.viewModel.titleOpacity = 1.0
                    }
                }
            } else {
                viewModel.selectedIndex = 0
                viewModel.currentPage = 0
                viewModel.currentSection = selectedItem.sectionEnum.rawValue
            }
        }
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppDataManager.shared.items(for: Section(rawValue: viewModel.currentSection))
    }
} 