import SwiftUI

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    @Published var currentPage = 0
    @Published var numberOfPages = 1
    @Published var opacity: Double = 1.0
    @Published var currentSection = AppDataManager.shared.sections[0].rawValue
}

class ContentState: ObservableObject {
    static let shared = ContentState()
    @Published var selectedIndex = -1
    @Published var currentSection = "Game Changer"
    
    func jumpToPage(_ page: Int) {
        NotificationCenter.default.post(
            name: .jumpToPage,
            object: nil,
            userInfo: ["page": page]
        )
    }
}

class WindowSizeMonitor: ObservableObject {
    static let shared = WindowSizeMonitor()
    @Published var currentResolution: String
    private var observers: [NSObjectProtocol] = []
    
    init() {
        if let screen = NSScreen.main {
            self.currentResolution = SizingGuide.getResolutionKey(for: screen.frame.size)
        } else {
            self.currentResolution = "1920x1080"
        }
        
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.updateResolution(for: window.frame.size)
        })
    }
    
    private func updateResolution(for size: CGSize) {
        let newResolution = SizingGuide.getResolutionKey(for: size)
        if newResolution != currentResolution {
            currentResolution = newResolution
            objectWillChange.send()
        }
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isLoaded = false
}

class UIVisibilityState: ObservableObject {
    static let shared = UIVisibilityState()
    @Published var isVisible = false {
        didSet { print("DEBUG: isVisible changed from \(oldValue) to \(isVisible)") }
    }
    @Published var isGridVisible = false
    @Published var mouseVisible = false
    @Published var currentGridSection: String = ""
    @Published var isExecutingPath: Bool = false {
        didSet { print("DEBUG: isExecutingPath changed from \(oldValue) to \(isExecutingPath)") }
    }
    @Published var isShowingModal = false {
        didSet { print("DEBUG: isShowingModal changed from \(oldValue) to \(isShowingModal)") }
    }
}

class SizingManager: ObservableObject {
    @Published private(set) var sizing: CarouselSizing
    static let shared = SizingManager()
    
    private init() {
        let defaultSize = CGSize(width: 1920, height: 1080)
        self.sizing = SizingGuide.getSizing(for: defaultSize)
        if let screen = NSScreen.main {
            self.updateSizing(for: screen.frame.size)
        }
    }
    
    func updateSizing(for size: CGSize) {
        DispatchQueue.main.async {
            self.sizing = SizingGuide.getSizing(for: size)
        }
    }
}

class MouseIndicatorState: ObservableObject {
    static let shared = MouseIndicatorState()
    @Published var mouseProgress: CGFloat = 0
    @Published var mouseDirection: Int = 0
    @Published var showingProgress = false
} 