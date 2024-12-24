//
//  LaunchMan.swift
//  Created by Todd Bruss on 3/17/24.
//

import SwiftUI
import AppKit
import GameController
import Carbon.HIToolbox

// Types needed for items
enum Section: String {
    case box = "Game Changer"
    case arcade = "Arcade"
    case console = "Console"
    case system = "System"
    case computer = "Computer"
    case internet = "Internet"
}

enum Action: String, Codable {
    case none = ""
    case restart = "restart"
    case sleep = "sleep"
    case logout = "logout"
    case quit = "quit"
    
    func execute() {
        print("Executing action: \(self)")  // Debug print
        switch self {
        case .none:
            return
        case .restart:
            SystemActions.sendAppleEvent(kAERestart)
        case .sleep:
            SystemActions.sendAppleEvent(kAESleep)
        case .logout:
            SystemActions.sendAppleEvent(kAELogOut)
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct SystemActions {
    static func sendAppleEvent(_ eventID: UInt32) {
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kSystemProcess))
        let target = NSAppleEventDescriptor(
            descriptorType: typeProcessSerialNumber,
            bytes: &psn,
            length: MemoryLayout.size(ofValue: psn)
        )
        
        let event = NSAppleEventDescriptor(
            eventClass: kCoreEventClass,
            eventID: eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        
        _ = try? event.sendEvent(
            options: [.noReply],
            timeout: TimeInterval(kAEDefaultTimeout)
        )
    }
}

struct AppItem: Codable {
    let name: String
    let systemIcon: String
    let parent: String?
    let action: String?
    
    var sectionEnum: Section {
        return Section(rawValue: name) ?? .box
    }
    
    var parentEnum: Section? {
        guard let parent = parent else { return nil }
        return Section(rawValue: parent)
    }
    
    var actionEnum: Action {
        guard let action = action else { return .none }
        print("Converting action string: \(action)")
        let actionEnum = Action(rawValue: action)
        print("Converted to enum: \(String(describing: actionEnum))")
        return actionEnum ?? .none
    }
}

// Add a new struct to manage app items
struct AppItemManager {
    static let shared = AppItemManager()
    private var items: [String: [AppItem]] = [:]
    
    private init() {
        loadItems()
    }
    
    private mutating func loadItems() {
        print("=== DEBUG JSON LOADING ===")
        print("Bundle URL:", Bundle.main.bundleURL)
        print("All Bundle Resources:", Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil))
        
        if let url = Bundle.main.url(forResource: "app_items", withExtension: "json") {
            print("Found JSON at:", url)
            do {
                let data = try Data(contentsOf: url)
                print("JSON Content:", String(data: data, encoding: .utf8) ?? "Could not read JSON content")
                self.items = try JSONDecoder().decode([String: [AppItem]].self, from: data)
                print("Successfully loaded sections:", self.items.keys)
                print("Items in Game Changer section:", self.items["Game Changer"]?.count ?? 0)
            } catch {
                print("Error loading/decoding JSON:", error)
                print("Error description:", error.localizedDescription)
            }
        } else {
            print("Failed to find app_items.json in bundle")
        }
        print("=== END DEBUG ===")
    }
    
    func getItems(for section: String) -> [AppItem] {
        let items = items[section] ?? []
        print("Getting items for section:", section)
        print("Found items count:", items.count)
        return items
    }
}

extension Notification.Name {
    static let escKeyPressed = Notification.Name("escKeyPressed")
}

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    @Published var currentPage = 0
    @Published var numberOfPages = 1
    @Published var opacity: Double = 1.0
}

struct NavigationOverlayView: View {
    @StateObject private var navigationState = NavigationState.shared
    
    var body: some View {
        VStack {
            Spacer()
            NavigationDotsView(
                currentPage: navigationState.currentPage,
                totalPages: navigationState.numberOfPages
            )
        }
        .opacity(navigationState.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct GameChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()  // Background layer
                
                ClockView()  // Remove the VStack wrapper
                
                ContentView()     // Main content layer
                MouseIndicatorView()  // Mouse indicator overlay
                NavigationOverlayView()  // Navigation dots overlay
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct BackgroundView: View {
    @State private var sizing: CarouselSizing = SizingGuide.getSizing(for: NSScreen.main!.frame.size)
    
    private var logoSize: CGFloat {
        let settings = SizingGuide.getCurrentSettings()
        return settings.title.size * 6.8
    }
    
    var body: some View {
        ZStack {

            // Background image and gradient
            GeometryReader { geometry in
                Group {
                    if let backgroundURL = Bundle.main.url(forResource: "backgroundimage", withExtension: "jpg", subdirectory: "images/jpg"),
                       let backgroundImage = NSImage(contentsOf: backgroundURL) {
                        Image(nsImage: backgroundImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Color.black
                    }
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .edgesIgnoringSafeArea(.all)
            
             // Logo
            if let logoURL = Bundle.main.url(forResource: "superbox64headerlogo", withExtension: "svg", subdirectory: "images/logo"),
               let logoImage = NSImage(contentsOf: logoURL) {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize)
                    .padding(.leading, SizingGuide.getCurrentSettings().layout.logo?.leadingPadding ?? 30)
                    .padding(.top, SizingGuide.getCurrentSettings().layout.logo?.topPadding ?? 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct MainWindowView: View {
    var body: some View {
        ContentView()
    }
}

// Add at top level
class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isLoaded = false
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var cursorHideTimer: Timer?
    @StateObject private var appState = AppState.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // FIRST: Block until all images are loaded
        print("=== Starting Image Loading ===")
        
        // Pre-initialize the cache
        let allSections = ["Game Changer", "Arcade", "Console", "Computer", "Internet", "System"]
        var loadedImages = 0
        var totalImages = 0
        
        // First pass - count total images
        for section in allSections {
            let items = AppItemManager.shared.getItems(for: section)
            totalImages += items.count
        }
        
        print("Total images to load: \(totalImages)")
        
        // Second pass - load images synchronously
        for section in allSections {
            let items = AppItemManager.shared.getItems(for: section)
            for item in items {
                autoreleasepool {
                    if let iconURL = Bundle.main.url(forResource: item.systemIcon, 
                                                   withExtension: "svg", 
                                                   subdirectory: "images/svg") {
                        if let image = NSImage(contentsOf: iconURL) {
                            ImageCache.shared.cache[item.systemIcon] = image
                            loadedImages += 1
                            print("[\(loadedImages)/\(totalImages)] Loaded: \(item.name)")
                        } else {
                            print("Failed to load image for: \(item.name)")
                        }
                    } else {
                        print("Failed to find image URL for: \(item.name)")
                    }
                }
            }
        }
        
        print("=== Image Loading Complete: \(loadedImages)/\(totalImages) ===")
        
        // Verify cache
        print("=== Verifying Cache ===")
        for section in allSections {
            let items = AppItemManager.shared.getItems(for: section)
            for item in items {
                if ImageCache.shared.cache[item.systemIcon] == nil {
                    print("WARNING: Missing cache entry for \(item.name)")
                }
            }
        }
        print("=== Cache Verification Complete ===")
        
        // Only set isLoaded after ALL images are confirmed in cache
        if loadedImages == totalImages {
            AppState.shared.isLoaded = true
            print("App state set to loaded")
        } else {
            print("ERROR: Not all images loaded!")
        }
        
        // Rest of initialization
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard self != nil else { return event }
        
        if event.keyCode == 53 { // ESC key
            NotificationCenter.default.post(name: .escKeyPressed, object: nil)
            return nil
        }
        
        return event
    }

        // Hide cursor and start timer to keep it hidden
        NSCursor.hide()
        cursorHideTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            NSCursor.hide()
        }
        
        // Set up menu bar
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // Add App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Add Quit item
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitMenuItem)
        
    let presOptions: NSApplication.PresentationOptions = [.hideDock]
    NSApp.presentationOptions = presOptions

        // Make window full screen
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.title = ""
                window.toggleFullScreen(nil)
                
                // Take screenshot after a short delay to ensure UI is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.takeScreenshot()
                }
            }
        }
    }
    
    private func preloadAllImages() {
        print("=== DEBUG IMAGE LOADING ===")
        print("Bundle URL:", Bundle.main.bundleURL)
        print("SVG Directory exists:", Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "images/svg") != nil)
        
        // Preload all sections
        let superboxItems = AppItemManager.shared.getItems(for: "Game Changer")
        print("Game Changer items:", superboxItems.map { $0.name })
        ImageCache.shared.preloadImages(from: superboxItems)
        
        let arcadeItems = AppItemManager.shared.getItems(for: "Arcade")
        print("Arcade items:", arcadeItems.map { $0.name })
        ImageCache.shared.preloadImages(from: arcadeItems)
        
        let consoleItems = AppItemManager.shared.getItems(for: "Console")
        ImageCache.shared.preloadImages(from: consoleItems)
        
        let systemItems = AppItemManager.shared.getItems(for: "System")
        ImageCache.shared.preloadImages(from: systemItems)
        
        print("=== END IMAGE LOADING ===")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cursorHideTimer?.invalidate()
        NSCursor.unhide()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func takeScreenshot() {
        guard SizingGuide.getCommonSettings().enableScreenshots else { return }
        
        if let window = NSApp.windows.first,
           let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming]
           ) {
            let image = NSImage(cgImage: cgImage, size: window.frame.size)
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = dateFormatter.string(from: Date())
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fileURL = desktopURL.appendingPathComponent("GameChanger_\(timestamp).png")
                
                try? pngData.write(to: fileURL)
                print("Screenshot saved to: \(fileURL.path)")
            }
        }
    }
}

struct GUISettings: Codable {
    let GameChangerUI: GameChangerUISettings
}

struct GameChangerUISettings: Codable {
    let common: CommonSettings
    private let resolutions: [String: InterfaceSizing]
    
    private enum CodingKeys: String, CodingKey {
        case common
        case resolutions
    }
    
    func getResolution(_ key: String) -> InterfaceSizing {
        guard let settings = resolutions[key] else {
            fatalError("Missing settings for resolution: \(key)")
        }
        return settings
    }
}

struct CommonSettings: Codable {
    let multipliers: MultiplierSettings
    let opacities: OpacitySettings
    let fontWeights: FontWeightSettings
    let fonts: FontSettings
    let animations: AnimationSettings
    let colors: ColorSettings
    let mouseIndicator: MouseIndicatorCommonSettings
    let navigation: NavigationCommonSettings
    let enableScreenshots: Bool
    let mouseSensitivity: Double
}

struct MouseIndicatorCommonSettings: Codable {
    let inactivityTimeout: Double
}

struct NavigationCommonSettings: Codable {
    let opacity: Double
}

struct ColorSettings: Codable {
    let mouseIndicator: MouseIndicatorColors
}

struct MouseIndicatorColors: Codable {
    let background: [Double]  // [R, G, B, A]
    let progress: [Double]    // [R, G, B, A]
    
    var backgroundUI: Color {
        Color(.sRGB, 
              red: background[0],
              green: background[1], 
              blue: background[2], 
              opacity: background[3])
    }
    
    var progressUI: Color {
        Color(.sRGB, 
              red: progress[0], 
              green: progress[1], 
              blue: progress[2], 
              opacity: progress[3])
    }
}

struct FontSettings: Codable {
    let title: String
    let label: String
    let clock: String
}

struct InterfaceSizing: Codable {
    let carousel: CarouselSizing
    let mouseIndicator: MouseIndicatorSettings
    let title: TitleSettings
    let label: LabelSettings
    let clock: ClockSettings
    let navigationDots: NavigationSettings
    let layout: LayoutSettings
}

struct SizingGuide {
    static private var settings: GUISettings = {
        guard let url = Bundle.main.url(forResource: "gamechanger-ui", withExtension: "json") else {
            fatalError("gamechanger-ui.json not found in bundle")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(GUISettings.self, from: data)
        } catch {
            fatalError("Failed to decode gamechanger-ui.json: \(error)")
        }
    }()
    
    static func getSettings(for resolution: String) -> InterfaceSizing {
        return settings.GameChangerUI.getResolution(resolution)
    }
    
    static func getCommonSettings() -> CommonSettings {
        return settings.GameChangerUI.common
    }
    
    static func getCurrentSettings() -> InterfaceSizing {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let resolution = getResolutionKey(for: screen.frame.size)
        return getSettings(for: resolution)
    }
    
    static func getSizing(for screenSize: CGSize) -> CarouselSizing {
        let resolution = getResolutionKey(for: screenSize)
        return getSettings(for: resolution).carousel
    }
    
    static func getResolutionKey(for screenSize: CGSize) -> String {
        if screenSize.width >= 2560 {
            return "2560x1440"
        } else if screenSize.width >= 1920 {
            return "1920x1080"
        }
        return "1280x720"
    }
}

// Add this at the top level
class ImageCache {
    static let shared = ImageCache()
    var cache: [String: NSImage] = [:]
    
    func preloadImages(from items: [AppItem]) {
        for item in items {
            if let iconURL = Bundle.main.url(forResource: item.systemIcon, withExtension: "svg", subdirectory: "images/svg"),
               let image = NSImage(contentsOf: iconURL) {
                print("Caching image for: \(item.name)")
                cache[item.systemIcon] = image
            }
        }
    }
    
    func getImage(named: String) -> NSImage? {
        return cache[named]
    }
}

struct CarouselView: View {
    let visibleItems: [AppItem]
    let selectedIndex: Int
    let sizing: CarouselSizing
    let currentOffset: CGFloat
    let showingNextItems: Bool
    let nextOffset: CGFloat
    let nextItems: [AppItem]
    
    var body: some View {
        ZStack {
            // Current items
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: sizing.gridSpacing),
                GridItem(.flexible(), spacing: sizing.gridSpacing),
                GridItem(.flexible(), spacing: sizing.gridSpacing),
                GridItem(.flexible(), spacing: sizing.gridSpacing)
            ], spacing: sizing.gridSpacing) {
                ForEach(0..<visibleItems.count, id: \.self) { index in
                    AppIconView(
                        item: visibleItems[index],
                        isSelected: index == selectedIndex,
                        sizing: sizing
                    )
                }
            }
            .offset(x: currentOffset)
            
            // Next items (if showing)
            if showingNextItems {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                    GridItem(.flexible(), spacing: sizing.gridSpacing)
                ], spacing: sizing.gridSpacing) {
                    ForEach(0..<nextItems.count, id: \.self) { index in
                        AppIconView(
                            item: nextItems[index],
                            isSelected: false,
                            sizing: sizing
                        )
                    }
                }
                .offset(x: nextOffset)
            }
        }
        .padding(sizing.gridSpacing)
    }
}

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @State private var gameController: GCController?
    @State private var accumulatedMouseX: CGFloat = 0
    @State private var accumulatedMouseY: CGFloat = 0
    @State private var isMouseInWindow = false
    @State private var sizing: CarouselSizing = SizingGuide.getSizing(for: NSScreen.main!.frame.size)
    @State private var currentPage = 0
    @State private var currentSlideOffset: CGFloat = 0
    @State private var nextSlideOffset: CGFloat = 0
    @State private var showingNextSet = false
    @State private var windowWidth: CGFloat = 0
    @State private var animationDirection: Int = 0
    @State private var isTransitioning = false
    @State private var opacity: Double = 1
    @State private var titleOpacity: Double = 1
    @State private var currentSection: String = "Game Changer"
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
        min(abs(accumulatedMouseX) / mouseSensitivity, 1.0)
    }
    
    private func handleSelection() {
        let sourceItems = getSourceItems()
        let visibleStartIndex = currentPage * 4
        let actualIndex = visibleStartIndex + selectedIndex
        let selectedItem = sourceItems[actualIndex]
        
        if selectedItem.actionEnum != .none {
            selectedItem.actionEnum.execute()
            return
        }
        
        if let _ = selectedItem.parent, 
           !AppItemManager.shared.getItems(for: selectedItem.name).isEmpty {
            selectedIndex = 0
            currentPage = 0
            currentSection = selectedItem.sectionEnum.rawValue
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
    
    // Update keyboard handling
    private var keyboardHandler: some View {
        Color.clear
            .focusable()
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch Int(event.keyCode) {
                    case kVK_Return:
                        resetMouseState()
                        handleSelection()
                    case kVK_Escape:
                        resetMouseState()
                        back()
                    default:
                        break
                    }
                    return event
                }
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
        
        if abs(accumulatedMouseX) > mouseSensitivity {
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
        let allSections = ["Game Changer", "Arcade", "Console", "Computer", "Internet", "System"]
        for section in allSections {
            let items = AppItemManager.shared.getItems(for: section)
            ImageCache.shared.preloadImages(from: items)
        }
    }
    
    // Update animation access in views
    private var animationSettings: AnimationSettings {
        return SizingGuide.getCommonSettings().animations
    }
    
    var body: some View {
        ZStack {
            // Title at the top
            VStack {
                Text(currentSection)
                    .font(.custom(
                        SizingGuide.getCommonSettings().fonts.title,
                        size: SizingGuide.getCurrentSettings().title.size
                    ))
                    .foregroundColor(.white)
                    .opacity(titleOpacity)
                    .padding(.top, SizingGuide.getCurrentSettings().layout.title.topPadding)
                Spacer()
            }
            
            // Carousel in center
            CarouselView(
                visibleItems: visibleItems,
                selectedIndex: selectedIndex,
                sizing: sizing,
                currentOffset: currentOffset,
                showingNextItems: showingNextItems,
                nextOffset: nextOffset,
                nextItems: nextItems
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyMonitor()
            setupGameController()
            setupMouseMonitor()
            setupMouseTrackingMonitor()
            if let screen = NSScreen.main {
                sizing = SizingGuide.getSizing(for: screen.frame.size)
                windowWidth = screen.frame.width
            }
            updateNavigationState()
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
            }
            NotificationCenter.default.removeObserver(self)
            NSCursor.unhide()  // Make sure cursor is visible when view disappears
        }
        .onChange(of: currentPage) { _ in
            updateNavigationState()
        }
        .onChange(of: currentSection) { _ in
            updateNavigationState()
        }
    }
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53: // Escape
                resetMouseState()
                back()
            case 126: // Up Arrow
                resetMouseState()
                back()
            case 125: // Down Arrow
                resetMouseState()
                handleSelection()
            case 123: // Left Arrow
                resetMouseState()
                moveLeft()
            case 124: // Right Arrow
                resetMouseState()
                moveRight()
            case 36: // Return
                resetMouseState()
                handleSelection()
            case 49: // Space
                resetMouseState()
                handleSelection()
            default: break
            }
            return event
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
            handleMouseMovement(event)
            return event
        }
        
        // Left click and A/B buttons - Select
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            resetMouseState()
            handleSelection()
            return event
        }
        
        // Right click - Back
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            resetMouseState()
            back()
            return event
        }
        
        // Middle click - Quit
        NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            if event.buttonNumber == 2 { // Middle click
                NSApplication.shared.terminate(nil)
            }
            return event
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
            return event
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
        let currentVisibleCount = min(4, sourceItems.count - (currentPage * 4))
        if selectedIndex >= currentVisibleCount {
            selectedIndex = currentVisibleCount - 1
        }
    }
    
    private func moveLeft() {
        if !isAnimating {
            let sourceItems = getSourceItems()
            let totalItems = sourceItems.count
            let itemsPerPage = 4
            
            if selectedIndex == 0 {
                if currentPage > 0 {
                    guard SizingGuide.getCommonSettings().animations.slideEnabled else { return }
                    isAnimating = true
                    showingNextItems = true
                    nextOffset = -windowWidth
                    
                    withAnimation(.carouselSlide(settings: animationSettings)) {
                        currentOffset = windowWidth
                        nextOffset = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                        currentPage -= 1
                        selectedIndex = 3
                        currentOffset = 0
                        nextOffset = 0
                        showingNextItems = false
                        isAnimating = false
                    }
                } else {
                    guard SizingGuide.getCommonSettings().animations.slideEnabled else { return }
                    isAnimating = true
                    showingNextItems = true
                    nextOffset = -windowWidth
                    
                    withAnimation(.carouselSlide(settings: animationSettings)) {
                        currentOffset = windowWidth
                        nextOffset = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                        let lastPage = (totalItems - 1) / itemsPerPage
                        let itemsOnLastPage = totalItems % itemsPerPage == 0 ? itemsPerPage : totalItems % itemsPerPage
                        currentPage = lastPage
                        selectedIndex = itemsOnLastPage - 1
                        currentOffset = 0
                        nextOffset = 0
                        showingNextItems = false
                        isAnimating = false
                    }
                }
            } else {
                selectedIndex -= 1
            }
        }
    }
    
    private func moveRight() {
        if !isAnimating {
            let sourceItems = getSourceItems()
            let totalItems = sourceItems.count
            let itemsPerPage = 4
            let lastPage = (totalItems - 1) / itemsPerPage
            let itemsOnLastPage = totalItems % itemsPerPage == 0 ? itemsPerPage : totalItems % itemsPerPage
            
            if selectedIndex == min(4, sourceItems.count - (currentPage * 4)) - 1 {
                if currentPage < lastPage {
                    guard SizingGuide.getCommonSettings().animations.slideEnabled else { return }
                    isAnimating = true
                    showingNextItems = true
                    nextOffset = windowWidth
                    
                    withAnimation(.carouselSlide(settings: animationSettings)) {
                        currentOffset = -windowWidth
                        nextOffset = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                        currentPage += 1
                        selectedIndex = 0
                        currentOffset = 0
                        nextOffset = 0
                        showingNextItems = false
                        isAnimating = false
                    }
                } else if currentPage == lastPage && selectedIndex == itemsOnLastPage - 1 {
                    guard SizingGuide.getCommonSettings().animations.slideEnabled else { return }
                    isAnimating = true
                    showingNextItems = true
                    nextOffset = windowWidth
                    
                    withAnimation(.carouselSlide(settings: animationSettings)) {
                        currentOffset = -windowWidth
                        nextOffset = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationSettings.slide.duration) {
                        currentPage = 0
                        selectedIndex = 0
                        currentOffset = 0
                        nextOffset = 0
                        showingNextItems = false
                        isAnimating = false
                    }
                }
            } else {
                selectedIndex += 1
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
            currentSection = parentSection.rawValue
            selectedIndex = 0
            currentPage = 0
        }
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppItemManager.shared.getItems(for: currentSection)
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
}

// Helper extension to convert NSPoint to screen coordinates
extension NSPoint {
    var asScreenPoint: NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        return NSPoint(x: x, y: screen.frame.height - y)
    }
}

struct AppIconView: View {
    let item: AppItem
    let isSelected: Bool
    let sizing: CarouselSizing
    
    private func loadIcon() -> some View {
        // Force immediate loading from cache
        let cachedImage = ImageCache.shared.getImage(named: item.systemIcon)
        print("Loading icon for \(item.name): \(cachedImage != nil ? "Found in cache" : "Not found")")
        
        if let image = cachedImage {
            return AnyView(Image(nsImage: image)
                .resizable()
                .frame(width: sizing.iconSize * 2, height: sizing.iconSize * 2)
                .padding(0)
                .cornerRadius(sizing.cornerRadius))
        }
        
        // Fallback - try to load directly if not in cache
        if let iconURL = Bundle.main.url(forResource: item.systemIcon, 
                                       withExtension: "svg", 
                                       subdirectory: "images/svg"),
           let image = NSImage(contentsOf: iconURL) {
            // Add to cache if found
            ImageCache.shared.cache[item.systemIcon] = image
            print("Loaded and cached icon for \(item.name)")
            
            return AnyView(Image(nsImage: image)
                .resizable()
                .frame(width: sizing.iconSize * 2, height: sizing.iconSize * 2)
                .padding(0)
                .cornerRadius(sizing.cornerRadius))
        }
        
        print("Failed to load icon for \(item.name)")
        return AnyView(Color.clear
            .frame(width: sizing.iconSize * 2, height: sizing.iconSize * 2))
    }
    
    private var labelFontSize: CGFloat {
        SizingGuide.getCurrentSettings().label.size
    }
    
    var body: some View {
        let multipliers = SizingGuide.getCommonSettings().multipliers
        VStack(spacing: sizing.gridSpacing * multipliers.gridSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: sizing.cornerRadius * multipliers.cornerRadius)
                    .fill(Color.clear)
                    .frame(
                        width: sizing.iconSize * multipliers.iconSize + sizing.selectionPadding,
                        height: sizing.iconSize * multipliers.iconSize + sizing.selectionPadding
                    )
                
                if isSelected {
                    RoundedRectangle(cornerRadius: sizing.cornerRadius * multipliers.cornerRadius)
                        .fill(Color.white.opacity(SizingGuide.getCommonSettings().opacities.selectionHighlight))
                        .frame(
                            width: sizing.iconSize * multipliers.iconSize + sizing.selectionPadding,
                            height: sizing.iconSize * multipliers.iconSize + sizing.selectionPadding
                        )
                }
                
                loadIcon()
            }
            
            Text(item.name)
                .font(.custom(
                    SizingGuide.getCommonSettings().fonts.label,
                    size: labelFontSize
                ))
                .foregroundColor(isSelected ? .white : .blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClockView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
    
    private var clockFontSize: CGFloat {
        SizingGuide.getCurrentSettings().clock.timeSize
    }
    
    private var dateFontSize: CGFloat {
        SizingGuide.getCurrentSettings().clock.dateSize
    }
    
    private var clockSettings: ClockSettings {
        SizingGuide.getCurrentSettings().clock
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) { 
            Text(timeFormatter.string(from: currentTime))
                .font(.custom(
                    SizingGuide.getCommonSettings().fonts.clock,
                    size: clockSettings.timeSize
                ))
                .foregroundColor(.white)
                .padding(0)
            Text(dateFormatter.string(from: currentTime))
                .font(.custom(
                    SizingGuide.getCommonSettings().fonts.clock,
                    size: clockSettings.dateSize
                ))
                .padding(.top, SizingGuide.getCurrentSettings().clock.spacing)
                .foregroundColor(.white.opacity(SizingGuide.getCommonSettings().opacities.clockDateText))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, SizingGuide.getCurrentSettings().layout.clock.trailingPadding)
        .padding(.top, SizingGuide.getCurrentSettings().layout.clock.topPadding)
        .onReceive(timer) { input in
            currentTime = input
        }
    }
}

// Update MouseProgressView to use settings
struct MouseProgressView: View {
    let progress: CGFloat
    let direction: Int
    
    private var settings: MouseIndicatorSettings {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let resolution = screenWidth >= 2560 ? "2560x1440" :
                        screenWidth >= 1920 ? "1920x1080" : "1280x720"
        
        return SizingGuide.getSettings(for: resolution).mouseIndicator
    }
    
    var body: some View {
        let commonSettings = SizingGuide.getCommonSettings()
        
        ZStack {
            Circle()
                .stroke(
                    commonSettings.colors.mouseIndicator.backgroundUI,
                    style: StrokeStyle(
                        lineWidth: settings.strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: settings.size, height: settings.size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    commonSettings.colors.mouseIndicator.progressUI,
                    style: StrokeStyle(
                        lineWidth: settings.strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: settings.size, height: settings.size)
                .rotationEffect(
                    direction == -1 ?
                        .degrees(Double(-90) - (Double(progress) * 360)) :
                        .degrees(-90)
                )
            
            Image(systemName: direction == -1 ? "chevron.left" :
                            direction == 1 ? "chevron.right" : "")
                .font(.system(
                    size: settings.size * SizingGuide.getCommonSettings().multipliers.mouseIndicatorIconSize,
                    weight: .semibold
                ))
                .foregroundColor(SizingGuide.getCommonSettings().colors.mouseIndicator.progressUI)
        }
        .padding(.bottom, SizingGuide.getCurrentSettings().layout.mouseIndicator.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

struct NavigationDotsView: View {
    let currentPage: Int
    let totalPages: Int
    
    private var dotSize: CGFloat {
        SizingGuide.getCurrentSettings().navigationDots.size
    }
    
    private var dotSpacing: CGFloat {
        SizingGuide.getCurrentSettings().navigationDots.spacing
    }
    
    private var dotOpacity: CGFloat {
        SizingGuide.getCommonSettings().navigation.opacity
    }
    
    private var bottomPadding: CGFloat {
        SizingGuide.getCurrentSettings().navigationDots.bottomPadding
    }
    
    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(index == currentPage ? 1 : dotOpacity)
            }
        }
        .padding(.bottom, bottomPadding)
    }
}

class MouseIndicatorState: ObservableObject {
    static let shared = MouseIndicatorState()
    @Published var showingProgress = false
    @Published var mouseProgress: CGFloat = 0
    @Published var mouseDirection: Int = 0
}

struct MouseIndicatorView: View {
    @StateObject private var mouseState = MouseIndicatorState.shared
    
    var body: some View {
        ZStack {
            if mouseState.showingProgress {
                MouseProgressView(
                    progress: mouseState.mouseProgress,
                    direction: mouseState.mouseDirection
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Add this at the top level with other animation-related properties
extension Animation {
    static func carouselSlide(settings: AnimationSettings) -> Animation {
        let curve = settings.slide.curve
        return .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, 
                           duration: settings.slide.duration)
    }
    
    static func carouselFade(settings: AnimationSettings) -> Animation {
        return .easeInOut(duration: settings.fade.duration)
    }
}

// Add new animation settings structs
struct AnimationSettings: Codable {
    let slideEnabled: Bool
    let fadeEnabled: Bool
    let slide: SlideAnimation
    let fade: FadeAnimation
}

struct SlideAnimation: Codable {
    let duration: Double
    let curve: CubicCurve
}

struct CubicCurve: Codable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
}

struct FadeAnimation: Codable {
    let duration: Double
}

private let defaultNavigationSettings = NavigationSettings(
    size: 12.0,
    spacing: 24.0,
    bottomPadding: 40.0
) 

// Add these constants at the top level
private let mouseSensitivity: CGFloat = 100.0
private let enableScreenshots = true 

// Add LayoutSettings struct
struct LayoutSettings: Codable {
    let title: TitleLayout
    let clock: ClockLayout
    let logo: LogoLayout?
    let mouseIndicator: MouseIndicatorLayout
}

struct TitleLayout: Codable {
    let topPadding: CGFloat
}

struct ClockLayout: Codable {
    let topPadding: CGFloat
    let trailingPadding: CGFloat
}

struct LogoLayout: Codable {
    let topPadding: CGFloat
    let leadingPadding: CGFloat
}

struct MouseIndicatorLayout: Codable {
    let bottomPadding: CGFloat
}

struct MultiplierSettings: Codable {
    let iconSize: Double
    let cornerRadius: Double
    let gridSpacing: Double
    let mouseIndicatorIconSize: Double
}

struct OpacitySettings: Codable {
    let selectionHighlight: Double
    let clockDateText: Double
}

struct FontWeightSettings: Codable {
    let mouseIndicatorIcon: String
}

struct CarouselSizing: Codable {
    let iconSize: CGFloat
    let iconPadding: CGFloat
    let cornerRadius: CGFloat
    let gridSpacing: CGFloat
    let titleSize: CGFloat
    let labelSize: CGFloat
    let selectionPadding: CGFloat
}

struct TitleSettings: Codable {
    let size: CGFloat
}

struct LabelSettings: Codable {
    let size: CGFloat
}

struct ClockSettings: Codable {
    let timeSize: CGFloat
    let dateSize: CGFloat
    let spacing: CGFloat
}

struct MouseIndicatorSettings: Codable {
    let size: CGFloat
    let strokeWidth: CGFloat
}

struct NavigationSettings: Codable {
    let size: CGFloat
    let spacing: CGFloat
    let bottomPadding: CGFloat
} 