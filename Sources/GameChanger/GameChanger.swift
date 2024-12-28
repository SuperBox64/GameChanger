//
//  LaunchMan.swift
//  Created by Todd Bruss on 3/17/24.
//

import SwiftUI
import GameController
import Carbon.HIToolbox
import AVFoundation

class UIVisibilityState: ObservableObject {
    static let shared = UIVisibilityState()
    
    @Published var isVisible = false {
        didSet {
            print("DEBUG: isVisible changed from \(oldValue) to \(isVisible)")
        }
    }
    
    @Published var isGridVisible = false
    @Published var mouseVisible = false
    @Published var isExecutingPath: Bool = false {
        didSet {
            print("DEBUG: isExecutingPath changed from \(oldValue) to \(isExecutingPath)")
        }
    }
    @Published var isShowingModal = false {
        didSet {
            print("DEBUG: isShowingModal changed from \(oldValue) to \(isShowingModal)")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var cursorHideTimer: Timer?
    var screenshotTimer: Timer?
    @StateObject private var appState = AppState.shared
    
    private func initializeCache() {
        var loadedImages = 0
        var totalImages = 0
        
        // First pass - count total images
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            totalImages += items.count
        }
        
        // Second pass - load images synchronously
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
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
        
        // Verify cache
        print("=== Verifying Cache ===")
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            for item in items {
                if ImageCache.shared.cache[item.systemIcon] == nil {
                    print("WARNING: Missing cache entry for \(item.name)")
                }
            }
        }
        
        // Only set isLoaded after ALL images are confirmed in cache
        if loadedImages == totalImages {
            AppState.shared.isLoaded = true
            print("App state set to loaded")
        } else {
            print("ERROR: Not all images loaded!")
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.hideOtherApplications(nil)

        let presOptions: NSApplication.PresentationOptions = [.hideDock, .hideMenuBar]
        NSApp.presentationOptions = presOptions


        if let window = NSApp.windows.first {
            window.styleMask = [.borderless, .fullSizeContentView]
            window.makeKeyAndOrderFront(nil)
            window.setFrame(NSScreen.main?.frame ?? .zero, display: true)
            window.alphaValue = 0.0
  
            // Prevent window scaling when alerts appear
            NotificationCenter.default.addObserver(
                forName: NSWindow.willBeginSheetNotification,
                object: window,
                queue: .main
            ) { _ in
                window.setContentSize(NSScreen.main?.frame.size ?? .zero)
            }
  
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .linear)
                window.animator().alphaValue = 1.0
            }      
        }
        
        initializeCache()
        
        NotificationCenter.default.post(name: .startupBounce, object: nil)
 
        if UIVisibilityState.shared.mouseVisible {
            NSCursor.unhide()
        } else {
            NSCursor.hide()
        }

        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) { 
                SystemActions.sendAppleEvent(kAEActivate)
            }
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

        if SizingGuide.getCommonSettings().enableScreenshots {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.takeScreenshot()
            }
        }
        
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        //cursorHideTimer?.invalidate()
        screenshotTimer?.invalidate()
        NSCursor.unhide()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.hideOtherApplications(nil)
        SystemActions.sendAppleEvent(kAEActivate)

        // Just trigger the fade in
        UIVisibilityState.shared.isVisible = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func takeScreenshot() {        
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

// Types needed for items
struct Section: RawRepresentable, Codable {
    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    static var allCases: [Section] = {
        return AppDataManager.shared.sections
    }()
}

enum Action: String, Codable {
    case none = ""
    case restart = "restart"
    case sleep = "sleep"
    case logout = "logout"
    case quit = "quit"
    case path = "path"
    case activate = "activate"
    case process = "process"

    private func executeProcess(_ command: String, appName: String? = nil, setFullscreen: Bool = false) {
        guard !UIVisibilityState.shared.isExecutingPath else { return }
        UIVisibilityState.shared.isExecutingPath = true
        
        // Hide UI elements first with shorter fade duration
        UIVisibilityState.shared.isVisible = false
        
        // Launch the process
        DispatchQueue.global(qos: .userInitiated).async {
            let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
            guard let executable = parts.first else {
                DispatchQueue.main.async {
                    print("Invalid command: \(command)")
                    UIVisibilityState.shared.isVisible = true
                    UIVisibilityState.shared.isExecutingPath = false
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            
            // Set up pipes for output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // If there are arguments after the executable
            if parts.count > 1 {
                process.arguments = [parts[1]]
            }
            
            do {
                try process.run()
                if setFullscreen {
                    setFullScreen(for: appName ?? "")
                }
                // Reset executing state after successful launch
                DispatchQueue.main.async {
                    UIVisibilityState.shared.isExecutingPath = false
                }
            } catch {
                print("Failed to execute process: \(error)")
                
                // Ensure UI updates happen on main thread
                DispatchQueue.main.async {
                    
                    showErrorModal(
                        title: "Failed to Execute App",
                        message: "Could not run: \(command)\nError: \(error.localizedDescription)",
                        buttons: ["OK"],
                        defaultButton: "OK"
                    ) { button in
                        switch button {
                        case "OK":
                            UIVisibilityState.shared.isVisible = true
                            UIVisibilityState.shared.isExecutingPath = false
                        default:
                            break
                        }

                        if UIVisibilityState.shared.mouseVisible {
                            NSCursor.unhide()
                        } else {
                            NSCursor.hide()
                        }
                    }
                }
            }
        }
    }
    
   
    func execute(with path: String? = nil, appName: String? = nil, fullscreen: Bool? = nil) {
        print("Executing action: \(self)")
        switch self {
        case .none:
            return
        case .activate:
            SystemActions.sendAppleEvent(kAEActivate)
        case .restart:
            SystemActions.sendAppleEvent(kAERestart)
        case .sleep:
            SystemActions.sendAppleEvent(kAESleep)
        case .logout:
            SystemActions.sendAppleEvent(kAEShutDown)
        case .quit:
            NSApplication.shared.terminate(nil)
        case .process:
            if let command = path {
                executeProcess(command)
            }
        case .path:
            if let command = path {
                executeProcess(command, appName: appName ?? "", setFullscreen: fullscreen ?? false)
            }
        }
    }
}

// Handles fullscreen for applications using Accessibility API
func setFullScreen(for appName: String) {
    sleep(1)
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
        print("Could not find application: \(appName)")
        return
    }
    
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    
    var windowRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRef)
    
    if result == .success,
       let windows = windowRef as? [AXUIElement],
       let window = windows.first {
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, true as CFBoolean)
    } else {
        print("Failed to get window or set fullscreen for: \(appName)")
    }
}

private struct SystemActions  {
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
    let path: String?
    let fullscreen: Bool?
    
    var sectionEnum: Section {
        return Section(rawValue: name)
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

extension Notification.Name {
    static let escKeyPressed = Notification.Name("escKeyPressed")
    static let swipeLeft = Notification.Name("swipeLeft")
    static let swipeRight = Notification.Name("swipeRight")
    static let jumpToPage = Notification.Name("jumpToPage")
    static let bounceItems = Notification.Name("bounceItems")
    static let startupBounce = Notification.Name("startupBounce")
}

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    @Published var currentPage = 0
    @Published var numberOfPages = 1
    @Published var opacity: Double = 1.0
}

struct NavigationOverlayView: View {
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var contentState = ContentState.shared
    
    var body: some View {
        VStack {
            Spacer()
            NavigationDotsNSViewRepresentable(
                currentPage: navigationState.currentPage,
                totalPages: navigationState.numberOfPages,
                onPageSelect: { page in
                    contentState.jumpToPage(page)
                }
            )
            .frame(width: 600, height: 100)
            .opacity(navigationState.numberOfPages > 1 ? 1 : 0)  // Hide if only one page
        }
        .opacity(navigationState.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SizePreservingView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .fixedSize()
            .allowsHitTesting(true)
    }
}

class ContentState: ObservableObject {
    static let shared = ContentState()
    @Published var selectedIndex = -1
    @Published var currentSection = "Game Changer"  // Add this
    
    func jumpToPage(_ page: Int) {
        NotificationCenter.default.post(
            name: .jumpToPage,
            object: nil,
            userInfo: ["page": page]
        )
    }
}

@main
struct GameChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowSizeMonitor = WindowSizeMonitor.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()
                .onAppear {
                    SoundPlayer.shared.preloadStartupSound()
                }
                
                Group {
                    LogoView()
                    ClockView()
                    if uiVisibility.isGridVisible {
                        GameGridView()
                    } else {
                        ContentView()
                    }
                    MouseIndicatorView()
                    NavigationOverlayView()
                    ShortcutHintView()
                }
                .opacity(uiVisibility.isVisible ? 1 : 0)
                .animation(
                    .spring(
                        response: 1.2,
                        dampingFraction: 0.8,
                        blendDuration: 1.0
                    ),
                    value: uiVisibility.isVisible
                )
            }
            .background(Color.black)
            .frame(width: .infinity, height: .infinity)
            .environmentObject(windowSizeMonitor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
    }
}

struct BackgroundView: View {
    @StateObject private var sizingManager = SizingManager.shared
    
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
        }
    }
}

struct LogoView: View {
    @StateObject private var sizingManager = SizingManager.shared
    
    private var logoSize: CGFloat {
        let settings = SizingGuide.getCurrentSettings()
        return settings.title.size * 6.8
    }
    
    var body: some View {
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
    let mouseSensitivity: Double
    let enableScreenshots: Bool
    let bounceEnabled: Bool
    let fonts: FontSettings
    let colors: ColorSettings
    let mouseIndicator: MouseIndicatorCommonSettings
    let animations: AnimationSettings
    let opacities: OpacitySettings
    let fontWeights: FontWeightSettings
    let multipliers: MultiplierSettings
    let layout: CommonLayoutSettings
    let navigationDots: NavigationDotsCommonSettings
}

struct CommonLayoutSettings: Codable {
    let shortcut: ShortcutLayout
}

struct MouseIndicatorCommonSettings: Codable {
    let inactivityTimeout: Double
    let distanceFromDots: CGFloat  // Distance between navigation dots and mouse indicator
}

struct ColorSettings: Codable {
    let mouseIndicator: MouseIndicatorColors
    let text: TextColors
}

struct TextColors: Codable {
    let selected: [Double]
    let unselected: [Double]
    
    var selectedUI: Color {
        Color(.sRGB, 
              red: selected[0],
              green: selected[1], 
              blue: selected[2], 
              opacity: selected[3])
    }
    
    var unselectedUI: Color {
        Color(.sRGB, 
              red: unselected[0],
              green: unselected[1], 
              blue: unselected[2], 
              opacity: unselected[3])
    }
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
        if screenSize.width >= 5120 {
            return "5120x2880"
        } else if screenSize.width >= 2880 {
            return "2880x1620"
        } else if screenSize.width >= 2560 {
            return "2560x1440"
        } else if screenSize.width >= 2048 {
            return "2048x1152"
        } else if screenSize.width >= 1920 {
            return "1920x1080"
        } else if screenSize.width >= 1600 {
            return "1600x900"
        } else if screenSize.width >= 1440 {
            return "1440x810"
        }
        return "1280x720"
    }
    
    static func getScreenSize(for resolution: String) -> CGSize {
        switch resolution {
            case "5120x2880":
                return CGSize(width: 5120, height: 2880)
            case "2880x1620":
                return CGSize(width: 2880, height: 1620)
            case "2560x1440":
                return CGSize(width: 2560, height: 1440)
            case "2048x1152":
                return CGSize(width: 2048, height: 1152)
            case "1920x1080":
                return CGSize(width: 1920, height: 1080)
            case "1600x900":
                return CGSize(width: 1600, height: 900)
            case "1440x810":
                return CGSize(width: 1440, height: 810)
            default: // "1280x720"
                return CGSize(width: 1280, height: 720)
        }
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
    let onHighlight: (Int) -> Void
    let onSelect: (Int) -> Void
    let onBack: (Int) -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    var body: some View {
        ZStack {
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
                        onHighlight: { onHighlight(index) },
                        onSelect: { onSelect(index) },
                        onBack: { onBack(index) },
                        itemIndex: index
                    )
                }
            }
            .offset(x: currentOffset)
            
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
                            onHighlight: { },
                            onSelect: { },
                            onBack: { },
                            itemIndex: index
                        )
                    }
                }
                .offset(x: nextOffset)
            }
        }
        .padding(sizing.gridSpacing)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if abs(value.translation.width) > 50 { // Minimum swipe distance
                        if value.translation.width < 0 {
                            onSwipeLeft()
                        } else {
                            onSwipeRight()
                        }
                    }
                }
        )
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
    @State private var currentSection: String = Section.allCases.first?.rawValue ?? "Game Changer"
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
        min(abs(accumulatedMouseX) / SizingGuide.getCommonSettings().mouseSensitivity, 1.0)
    }
    
    private func handleSelection() {
        let sourceItems = getSourceItems()
        let visibleStartIndex = currentPage * 4
        let actualIndex = visibleStartIndex + selectedIndex
        let selectedItem = sourceItems[actualIndex]
        
        if selectedItem.actionEnum != .none {
            // Pass the required parameters for path action
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
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    
            // Then handle other keys
                    switch Int(event.keyCode) {
                  // Handle mouse visibility
            case kVK_ANSI_G:
                UIVisibilityState.shared.isGridVisible.toggle()
            case kVK_ANSI_Q:
                NSApplication.shared.terminate(nil)
                return nil
            case kVK_Escape:
                UIVisibilityState.shared.mouseVisible.toggle()
                if UIVisibilityState.shared.mouseVisible {
                    SystemActions.sendAppleEvent(kAEActivate)
                    NSCursor.unhide()
                } else {
                    NSCursor.hide()
                    SystemActions.sendAppleEvent(kAEActivate)
                }
            case kVK_UpArrow:
                resetMouseState()
                back()
            case kVK_DownArrow:
                resetMouseState()
                handleSelection()
            case kVK_LeftArrow:
                resetMouseState()
                moveLeft()
            case kVK_RightArrow:
                resetMouseState()
                moveRight()
                    case kVK_Return:
                        resetMouseState()
                        handleSelection()
            case kVK_Space:
                        resetMouseState()
                handleSelection()
            default: break
                    }
            return nil
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
                selectedIndex: UIVisibilityState.shared.mouseVisible ? -1 : selectedIndex,  // No selection when mouse is visible
                sizing: sizingManager.sizing,
                currentOffset: currentOffset,
                showingNextItems: showingNextItems,
                nextOffset: nextOffset,
                nextItems: nextItems,
                onHighlight: { index in
                    if UIVisibilityState.shared.mouseVisible {
                        selectedIndex = index
                    }
                },
                onSelect: { index in
                    selectedIndex = index
                    resetMouseState()
                    handleSelection()
                },
                onBack: { index in
                    selectedIndex = index
                    resetMouseState()
                    back()
                },
                onSwipeLeft: {
                    if UIVisibilityState.shared.mouseVisible {
                        resetMouseState()
                        moveRight()  // Swipe left moves to next page
                    }
                },
                onSwipeRight: {
                    if UIVisibilityState.shared.mouseVisible {
                        resetMouseState()
                        moveLeft()   // Swipe right moves to previous page
                    }
                }
            )
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //     if UIVisibilityState.shared.mouseVisible {
            //         NSCursor.unhide()
            //     } else {
            //         NSCursor.hide()
            //     }
            // }
            setupKeyMonitor()
            setupGameController()
            setupMouseMonitor()
            setupMouseTrackingMonitor()
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
                        //First fade out current items
                            currentPage = page
                            selectedIndex = 0
                            
                        // Only trigger bounce if enabled
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
            // if let monitor = keyMonitor {
            //     NSEvent.removeMonitor(monitor)
            // }
            NotificationCenter.default.removeObserver(self)
            NSCursor.unhide()  // Make sure cursor is visible when view disappears
        }
        .onChange(of: currentPage) { _ in
            updateNavigationState()
        }
        .onChange(of: currentSection) { _ in
            updateNavigationState()
        }
        .onChange(of: UIVisibilityState.shared.isVisible) { isVisible in
            if isVisible {
                // When becoming visible, only set visual selection
                let sourceItems = getSourceItems()
                let startIndex = currentPage * 4
                let endIndex = min(startIndex + 4, sourceItems.count)
                
                // Make sure selectedIndex is valid for current page
                if startIndex + selectedIndex < endIndex {
                resetMouseState()
                    // Don't call handleSelection() - just reset state
                    ContentState.shared.selectedIndex = selectedIndex
                    ContentState.shared.currentSection = "Game Changer"
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
            return event
        }
        
        // Left click and A/B buttons - Select
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if !UIVisibilityState.shared.mouseVisible {
                resetMouseState()
                handleSelection()
            }
            return event
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

// Helper extension to convert NSPoint to screen coordinates
extension NSPoint {
    var asScreenPoint: NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        return NSPoint(x: x, y: screen.frame.height - y)
    }
}

struct AppIconView: View {
    @EnvironmentObject private var windowSizeMonitor: WindowSizeMonitor
    @StateObject private var uiVisibility = UIVisibilityState.shared
    let item: AppItem
    let isSelected: Bool
    @State private var isHighlighted = false
    let onHighlight: () -> Void
    let onSelect: () -> Void
    let onBack: () -> Void
    @State private var bounceOffset: CGFloat = 0
    let itemIndex: Int
    
    @StateObject private var sizingManager = SizingManager.shared
    
    var body: some View {
        let multipliers = SizingGuide.getCommonSettings().multipliers
        VStack(spacing: multipliers.gridSpacing * multipliers.gridSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: sizingManager.sizing.cornerRadius * 1.334)
                    .fill(Color.clear)
                    .frame(
                        width: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding,
                        height: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding
                    )
                
                if isSelected || (isHighlighted && UIVisibilityState.shared.mouseVisible) {
                    RoundedRectangle(cornerRadius: sizingManager.sizing.cornerRadius * multipliers.cornerRadius)
                        .fill(Color.white.opacity(SizingGuide.getCommonSettings().opacities.selectionHighlight))
                        .frame(
                            width: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding,
                            height: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding
                        )
                        .animation(.carouselSlide(settings: SizingGuide.getCommonSettings().animations), value: isSelected)
                }
                
                loadIcon()
            }
            .offset(y: bounceOffset)
            
            Text(item.name)
                .font(.custom(
                    SizingGuide.getCommonSettings().fonts.label,
                    size: sizingManager.sizing.labelSize
                ))
                .foregroundColor(isSelected || (isHighlighted && UIVisibilityState.shared.mouseVisible) ? 
                    SizingGuide.getCommonSettings().colors.text.selectedUI : 
                    SizingGuide.getCommonSettings().colors.text.unselectedUI)
                .offset(y: bounceOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering in
            isHighlighted = hovering  // Always update highlight state
            if hovering && UIVisibilityState.shared.mouseVisible {  // Only trigger highlight action in mouse mode
                    onHighlight()
                }
            }
        .onChange(of: UIVisibilityState.shared.mouseVisible) { newValue in
            if !newValue {
                isHighlighted = false
            }
        }
        .onTapGesture {
            if UIVisibilityState.shared.mouseVisible {
                onSelect()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bounceItems)) { _ in
            bounceItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startupBounce)) { _ in
            startupBounce()
        }
    }
    
    private func startupBounce() {
        if SizingGuide.getCommonSettings().animations.bounceEnabled {
            let randomDelay = Double.random(in: 0.1...0.2)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
                    let randomBounce = Double.random(in: -75 ... -25)
                    bounceOffset = randomBounce
                
                withAnimation(
                    .spring(
                        response: 1.75,
                        dampingFraction: 0.5,
                        blendDuration: 0.25
                    )
                ) {
                    bounceOffset = 0
                    }
                }
        }
    }
    
    private func bounceItems() {
        if SizingGuide.getCommonSettings().animations.bounceEnabled {
              if SizingGuide.getCommonSettings().animations.bounceEnabled {
                let randomDelay = Double.random(in: 0...0.1)
                let baseDelay = Double(itemIndex) * 0.05
                
                DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + randomDelay) {
                    let randomBounce = Double.random(in: (-45)...(-35))
                    bounceOffset = randomBounce
                    
                    withAnimation(
                        .spring(
                            response: 1.0,
                            dampingFraction: 0.55,
                            blendDuration: 0
                        )
                    ) {
                        bounceOffset = 0
                    }
                }
            }
        }
    }
    
    private func loadIcon() -> some View {
        let cachedImage = ImageCache.shared.getImage(named: item.systemIcon)
        
        if let image = cachedImage {
            return AnyView(Image(nsImage: image)
                .resizable()
                .frame(width: sizingManager.sizing.iconSize * 2, height: sizingManager.sizing.iconSize * 2)
                .padding(0)
                .cornerRadius(sizingManager.sizing.cornerRadius))
        }
        
        if let iconURL = Bundle.main.url(forResource: item.systemIcon, 
                                       withExtension: "svg", 
                                       subdirectory: "images/svg"),
           let image = NSImage(contentsOf: iconURL) {
            ImageCache.shared.cache[item.systemIcon] = image
            
            return AnyView(Image(nsImage: image)
                .resizable()
                .frame(width: sizingManager.sizing.iconSize * 2, height: sizingManager.sizing.iconSize * 2)
                .padding(0)
                .cornerRadius(sizingManager.sizing.cornerRadius))
        }
        
        return AnyView(Color.clear
            .frame(width: sizingManager.sizing.iconSize * 2, height: sizingManager.sizing.iconSize * 2))
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

// // Update MouseProgressView to use settings
// struct MouseProgressView: View {
//     @EnvironmentObject private var windowSizeMonitor: WindowSizeMonitor
//     let progress: CGFloat
//     let direction: Int
    
//     private var settings: MouseIndicatorSettings {
//         let resolution = windowSizeMonitor.currentResolution
//         return SizingGuide.getSettings(for: resolution).mouseIndicator
//     }
    
//     var body: some View {
//         let commonSettings = SizingGuide.getCommonSettings()
        
//         ZStack {
//             Group {
//                 Circle()
//                 .stroke(
//                     commonSettings.colors.mouseIndicator.backgroundUI,
//                     style: StrokeStyle(
//                         lineWidth: settings.strokeWidth,
//                         lineCap: .round
//                     )
//                 )
//                 .frame(width: settings.size, height: settings.size)
            
//                 Circle()
//                 .trim(from: 0, to: progress)
//                 .stroke(
//                     commonSettings.colors.mouseIndicator.progressUI,
//                     style: StrokeStyle(
//                         lineWidth: settings.strokeWidth,
//                         lineCap: .round
//                     )
//                 )
//                 .rotationEffect(
//                     direction == -1 ?
//                         .degrees(Double(-90) - (Double(progress) * 360)) :
//                         .degrees(-90)
//                 )
//             }

//             Image(systemName: direction == -1 ? "chevron.left" :
//                             direction == 1 ? "chevron.right" : "")
//                 .font(.system(
//                     size: settings.size * SizingGuide.getCommonSettings().multipliers.mouseIndicatorIconSize,
//                     weight: .semibold
//                 ))
//                 .foregroundColor(SizingGuide.getCommonSettings().colors.mouseIndicator.progressUI)
//         }
//         .padding(.bottom, SizingGuide.getCurrentSettings().layout.mouseIndicator.bottomPadding)
//         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        
//     }
// }

class NavigationDotsNSView: NSView {
    var currentPage: Int = 0 {
        didSet {
            needsDisplay = true
            animatePageChange(from: oldValue, to: currentPage)
        }
    }
    var totalPages: Int = 0
    var onPageSelect: ((Int) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        let bottomPadding: CGFloat = settings.bottomPadding
        let maxDotsPerRow = 12
        let rows = (totalPages + maxDotsPerRow - 1) / maxDotsPerRow
        let dotsInLastRow = totalPages % maxDotsPerRow == 0 ? maxDotsPerRow : totalPages % maxDotsPerRow
        
        for row in 0..<rows {
            let dotsInThisRow = row == rows - 1 ? dotsInLastRow : maxDotsPerRow
            let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
            let startX = (bounds.width - totalWidth) / 2
            let y = bottomPadding 
            
            for col in 0..<dotsInThisRow {
                let index = row * maxDotsPerRow + col
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                let path = NSBezierPath(ovalIn: dotRect)
                
                if index == currentPage {
                    NSColor.white.setFill()
                } else {
                    NSColor.white.withAlphaComponent(0.3).setFill()
                }
                path.fill()
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        let bottomPadding = settings.bottomPadding
        let maxDotsPerRow = 12
        let rows = (totalPages + maxDotsPerRow - 1) / maxDotsPerRow
        
        for row in 0..<rows {
            let dotsInThisRow = row == rows - 1 ? (totalPages % maxDotsPerRow == 0 ? maxDotsPerRow : totalPages % maxDotsPerRow) : maxDotsPerRow
            let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
            let startX = (bounds.width - totalWidth) / 2
            let y = bounds.height - bottomPadding - CGFloat(row) * (dotSize + spacing) - dotSize
            
            for col in 0..<dotsInThisRow {
                let index = row * maxDotsPerRow + col
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                if dotRect.contains(point) {
                    onPageSelect?(index)
                    break
                }
            }
        }
    }
    
    private func animatePageChange(from: Int, to: Int) {
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        let bottomPadding = settings.bottomPadding
        
        let oldDotRect = getDotRect(for: from, dotSize: dotSize, spacing: spacing, bottomPadding: bottomPadding)
        let newDotRect = getDotRect(for: to, dotSize: dotSize, spacing: spacing, bottomPadding: bottomPadding)
        
        // Animate the moving dot
        let animLayer = CALayer()
        animLayer.frame = oldDotRect
        animLayer.backgroundColor = NSColor.white.cgColor
        animLayer.cornerRadius = dotSize / 2
        layer?.addSublayer(animLayer)
        
        // Create path for arc movement
        let path = CGMutablePath()
        path.move(to: CGPoint(x: oldDotRect.midX, y: oldDotRect.midY))
        
        // Calculate control point for arc (higher for longer distances)
        let distance = abs(newDotRect.midX - oldDotRect.midX)
        let arcHeight = min(distance * 1.0, 100)  // Increased height by 50%
        let midX = (oldDotRect.midX + newDotRect.midX) / 2
        let controlPoint = CGPoint(x: midX, y: oldDotRect.midY + arcHeight)
        
        path.addQuadCurve(to: CGPoint(x: newDotRect.midX, y: newDotRect.midY),
                         control: controlPoint)
        
        let anim = CAKeyframeAnimation(keyPath: "position")
        anim.path = path
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.duration = 0.2
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.3
        fadeAnim.duration = 0.2
        fadeAnim.beginTime = 0.0
        
        let group = CAAnimationGroup()
        group.animations = [anim, fadeAnim]
        group.duration = 0.2
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        animLayer.add(group, forKey: "transition")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animLayer.removeFromSuperlayer()
        }
    }
    
    private func getDotRect(for index: Int, dotSize: CGFloat, spacing: CGFloat, bottomPadding: CGFloat) -> NSRect {
        let maxDotsPerRow = 12
        let row = index / maxDotsPerRow
        let col = index % maxDotsPerRow
        let dotsInThisRow = min(maxDotsPerRow, totalPages - (row * maxDotsPerRow))
        let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
        let startX = (bounds.width - totalWidth) / 2
        let y = bottomPadding 
        let x = startX + CGFloat(col) * (dotSize + spacing)
        return NSRect(x: x, y: y, width: dotSize, height: dotSize)
    }
}

struct NavigationDotsNSViewRepresentable: NSViewRepresentable {
    var currentPage: Int
    var totalPages: Int
    var onPageSelect: (Int) -> Void
    
    func makeNSView(context: Context) -> NavigationDotsNSView {
        let view = NavigationDotsNSView(frame: .zero)
        view.currentPage = currentPage
        view.totalPages = totalPages
        view.onPageSelect = onPageSelect
        return view
    }
    
    func updateNSView(_ nsView: NavigationDotsNSView, context: Context) {
        nsView.currentPage = currentPage
        nsView.totalPages = totalPages
        nsView.onPageSelect = onPageSelect
        nsView.needsDisplay = true
    }
}

class MouseIndicatorState: ObservableObject {
    static let shared = MouseIndicatorState()
    @Published var showingProgress = false
    @Published var mouseProgress: CGFloat = 0
    @Published var mouseDirection: Int = 0
}

class MouseIndicatorNSView: NSView {
    var progress: CGFloat = 0
    var direction: Int = 0
    private let settings = SizingGuide.getSettings(for: WindowSizeMonitor.shared.currentResolution).mouseIndicator
    private let commonSettings = SizingGuide.getCommonSettings()
    
    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = settings.size / 2
        
        // If moving right, flip the context
        if direction == 1 {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
        }
        
        // Background circle
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor(commonSettings.colors.mouseIndicator.backgroundUI).setStroke()
        bgPath.lineWidth = settings.strokeWidth
        bgPath.stroke()
        
        // Progress circle
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        let startAngle: CGFloat = 93    
   
        let endAngle = startAngle + (359.5 * progress)
        
        path.appendArc(withCenter: center, radius: radius, 
                      startAngle: startAngle, endAngle: endAngle)
        NSColor(commonSettings.colors.mouseIndicator.progressUI).setStroke()
        path.lineWidth = settings.strokeWidth
        path.stroke()
        
        // Chevron
        let chevron = "chevron.left" 
        let baseConfig = NSImage.SymbolConfiguration(paletteColors: [
            NSColor(commonSettings.colors.mouseIndicator.progressUI)
        ])

        // 2) Then apply another configuration for point size, weight, and scale.
        let finalConfig = baseConfig.applying(
            NSImage.SymbolConfiguration(pointSize: settings.size * commonSettings.multipliers.mouseIndicatorIconSize, weight: .bold)
        )       

        if let image = NSImage(systemSymbolName: chevron, accessibilityDescription: nil)?
            .withSymbolConfiguration(finalConfig) {
            image.isTemplate = true
            let imageSize: NSSize = image.size
            image.draw(in: NSRect(
                x: center.x - imageSize.width / 2,
                y: center.y - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            ), from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
}

struct MouseIndicatorNSViewRepresentable: NSViewRepresentable {
    let progress: CGFloat
    let direction: Int
    
    func makeNSView(context: Context) -> MouseIndicatorNSView {
        let view = MouseIndicatorNSView()
        view.progress = progress
        view.direction = direction
        return view
    }
    
    func updateNSView(_ nsView: MouseIndicatorNSView, context: Context) {
        nsView.progress = progress
        nsView.direction = direction
        nsView.needsDisplay = true
    }
}

struct MouseIndicatorView: View {
    @StateObject private var mouseState = MouseIndicatorState.shared
    @StateObject private var uiVisibilityState = UIVisibilityState.shared
    
    var body: some View {
        let settings = SizingGuide.getSettings(for: WindowSizeMonitor.shared.currentResolution).mouseIndicator
        VStack {
            Spacer()
            MouseIndicatorNSViewRepresentable(
                progress: mouseState.mouseProgress,
                direction: mouseState.mouseDirection
            )
            .frame(width: settings.size,
                   height: settings.size)
            .padding(.bottom, settings.bottomPadding)  // Get bottomPadding from mouseIndicator settings
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(mouseState.showingProgress && !uiVisibilityState.mouseVisible ? 1 : 0)
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
    let bounceEnabled: Bool
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



// Add LayoutSettings struct
struct LayoutSettings: Codable {
    let title: TitleLayout
    let clock: ClockLayout
    let logo: LogoLayout?  // Add back the logo property
    let shortcut: ShortcutLayout
}

struct TitleLayout: Codable {
    let topPadding: CGFloat
}

struct ClockLayout: Codable {
    let topPadding: CGFloat
    let trailingPadding: CGFloat
}

struct MouseIndicatorLayout: Codable {
    // Remove this line since it's now in MouseIndicatorSettings
    // let bottomPadding: CGFloat
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
    let bottomPadding: CGFloat
}

class WindowSizeMonitor: ObservableObject {
    static let shared = WindowSizeMonitor()
    @Published var currentResolution: String
    private var observers: [NSObjectProtocol] = []
    
    init() {
        // Set default resolution based on main screen
        if let screen = NSScreen.main {
            self.currentResolution = SizingGuide.getResolutionKey(for: screen.frame.size)
        } else {
            self.currentResolution = "1920x1080"  // Safe default
        }
        
        // Observe window resize notifications
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

// Add this class near the top of the file
class AppDataManager {
    static let shared = AppDataManager()
    
    private(set) var sections: [Section] = []
    private(set) var itemsBySection: [String: [AppItem]] = [:]
    
    private init() {
        loadData()
    }
    
    private func loadData() {
        guard let url = Bundle.main.url(forResource: "app_items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("ERROR: Failed to load app_items.json")
            return
        }
        
        // Parse sections, ensuring "Game Changer" is first
        var allSections = json.keys.map { Section(rawValue: $0) }
        if let gcIndex = allSections.firstIndex(where: { $0.rawValue == "Game Changer" }) {
            let gc = allSections.remove(at: gcIndex)
            allSections.insert(gc, at: 0)
        }
        sections = allSections
        
        // Parse items for each section
        for (sectionKey, itemsArray) in json {
            if let items = itemsArray as? [[String: Any]] {
                itemsBySection[sectionKey] = items.compactMap { itemDict in
                    guard let name = itemDict["name"] as? String else { return nil }
                    
                    return AppItem(
                        name: name,
                        systemIcon: (itemDict["systemIcon"] as? String) ?? "",
                        parent: (itemDict["parent"] as? String) ?? "",
                        action: (itemDict["action"] as? String) ?? "",
                        path: (itemDict["path"] as? String) ?? "",
                        fullscreen: itemDict["fullscreen"] as? Bool
                    )
                }
            }
        }
    }
    
    func items(for section: Section) -> [AppItem] {
        return itemsBySection[section.rawValue] ?? []
    }
}

// Add this class at the top level of the file
class SizingManager: ObservableObject {
    @Published private(set) var sizing: CarouselSizing
    
    static let shared = SizingManager()
    
    private init() {
        // Initialize with safe default values first
        let defaultSize = CGSize(width: 1920, height: 1080)
        self.sizing = SizingGuide.getSizing(for: defaultSize)
        
        // Then update with actual screen size if available
        if let screen = NSScreen.main {
            self.updateSizing(for: screen.frame.size)
        }
    }
    
    func updateSizing(for size: CGSize) {
        // Ensure we're not trying to access settings during initialization
        DispatchQueue.main.async {
            self.sizing = SizingGuide.getSizing(for: size)
        }
    }
}

// First create the new view
struct ShortcutHintView: View {
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(uiVisibility.mouseVisible ? "Hide Mouse" : "Show Mouse")
                .foregroundColor(.white)
                .font(.system(size: SizingGuide.getCurrentSettings().layout.shortcut.titleSize))
            Text("Press esc key")
                .foregroundColor(.gray)
                .font(.system(size: SizingGuide.getCurrentSettings().layout.shortcut.subtitleSize))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, SizingGuide.getCurrentSettings().layout.shortcut.leadingPadding)
        .padding(.bottom, SizingGuide.getCurrentSettings().layout.shortcut.bottomPadding)
    }
}

struct GameGridView: View {
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @StateObject private var appState = AppState.shared
    @State private var selectedIndex: Int = -1
    let columns: [GridItem] = Array(repeating: .init(.fixed(160), spacing: 26), count: 5)
    
    // Use items from all sections, limit to 20
    private var gameItems: [AppItem] {
        guard appState.isLoaded else { return [] }
        
        // Collect items from all sections
        var allItems: [AppItem] = []
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: section)
            allItems.append(contentsOf: items)
        }
        
        // Take first 20 items or pad to 20
        let emptyItem = AppItem(name: "", systemIcon: "", parent: nil, action: nil, path: nil, fullscreen: nil)
        if allItems.count >= 20 {
            return Array(allItems.prefix(20))
        } else {
            return allItems + Array(repeating: emptyItem, count: 20 - allItems.count)
        }
    }
    
    // Add back the handleGameSelection function
    private func handleGameSelection(_ index: Int) {
        let item = gameItems[index]
        if !item.name.isEmpty {
            item.actionEnum.execute(
                with: item.path,
                appName: item.name,
                fullscreen: item.fullscreen
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if appState.isLoaded {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<20, id: \.self) { index in
                            GameGridItemView(
                                item: gameItems[index],
                                isSelected: selectedIndex == index,
                                onSelect: {
                                    selectedIndex = index
                                    handleGameSelection(index)
                                }
                            )
                        }
                    }
                    .padding(32)
                    .frame(
                        minHeight: max(0, geometry.size.height),
                        alignment: .center
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    // ... rest of implementation
}

struct GameGridItemView: View {
    let item: AppItem
    let isSelected: Bool
    let onSelect: () -> Void
    @StateObject private var sizingManager = SizingManager.shared
    
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 144, height: 144)
                
                loadIcon()
                    .frame(width: 112, height: 112)
            }
            
            Text(item.name.isEmpty ? "Empty" : item.name)
                .foregroundColor(.white)
                .font(.system(size: 18))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .opacity(item.name.isEmpty ? 0.5 : 1.0)
        }
        .frame(width: 160, height: 192)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private func loadIcon() -> some View {
        if let image = ImageCache.shared.getImage(named: item.systemIcon) {
            return AnyView(
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
        }
        return AnyView(
            Image(systemName: "square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
        )
    }
}

// Add this extension to safely access array elements
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?
    
    func preloadStartupSound() {
        guard let soundURL = Bundle.main.url(
            forResource: "StartupTwentiethAnniversaryMac", 
            withExtension: "wav") else {
                print("Could not find sound file")
                return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.75
            audioPlayer?.play()
            
            print("Playing sound...")
        } catch {
            print("Failed to load sound: \(error)")
        }
    }
}



func showErrorModal(
    title: String,
    message: String,
    buttons: [String] = ["OK"],
    defaultButton: String = "OK",
    completion: ((String) -> Void)? = nil
) {
    if !Thread.isMainThread {
        print("Not on main thread")
        return
    }
    
    print("Before alert - MouseIndicator showing: \(MouseIndicatorState.shared.showingProgress)")
    
    NSCursor.unhide()  // Show cursor before creating alert
    
    // Create a hidden window for alerts
    let alertWindow = NSWindow(
        contentRect: .zero,
        styleMask: [.titled],
        backing: .buffered,
        defer: true
    )
    alertWindow.isReleasedWhenClosed = true
    alertWindow.orderOut(nil)
    
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    
    for buttonTitle in buttons {
        let button = alert.addButton(withTitle: buttonTitle)
        if buttonTitle == defaultButton {
            button.keyEquivalent = "\r"
        }
    }
    
    alert.window.level = .floating  // Make alert float above main window
    let response = alert.runModal()
    
    print("After alert - MouseIndicator showing: \(MouseIndicatorState.shared.showingProgress)")
    
    let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    let clickedButton = buttons[Int(buttonIndex)]
    
    completion?(clickedButton)
}

struct NavigationDotsCommonSettings: Codable {
    let size: CGFloat
    let spacing: CGFloat
    let bottomPadding: CGFloat
}

struct ShortcutLayout: Codable {
    let leadingPadding: CGFloat
    let bottomPadding: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat
}

// 1. First add back LogoLayout since it's needed by LogoView
struct LogoLayout: Codable {
    let topPadding: CGFloat
    let leadingPadding: CGFloat
}

// 2. Add the missing NavigationSettings struct
struct NavigationSettings: Codable {
    let size: CGFloat
    let spacing: CGFloat
    let bottomPadding: CGFloat
}

private let defaultNavigationSettings = NavigationSettings(
    size: 12.0,
    spacing: 24.0,
    bottomPadding: 30.0
)


