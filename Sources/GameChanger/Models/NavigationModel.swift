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
    
    func moveLeft() {
        // Implementation
    }
    
    func moveRight() {
        // Implementation
    }
    
    func back() {
        // Implementation
    }
    
    func handleSelection() {
        // Implementation
    }
} 