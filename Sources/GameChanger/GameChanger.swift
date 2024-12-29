//
//  LaunchMan.swift
//  Created by Todd Bruss on 3/17/24.
//

import SwiftUI
import GameController
import Carbon.HIToolbox
import AVFoundation

@main
struct GameChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowSizeMonitor = WindowSizeMonitor.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @State var startupSound = false
    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()
                .onAppear {
                    if !startupSound {
                        startupSound.toggle()
                    SoundPlayer.shared.playStartupSound()
                    }
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

// Helper extension to convert NSPoint to screen coordinates
extension NSPoint {
    var asScreenPoint: NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        return NSPoint(x: x, y: screen.frame.height - y)
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
    
    func playStartupSound() {
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

    // Play system alert sound
    DispatchQueue.global(qos: .background).async {
        NSSound.beep()
    }

    if !Thread.isMainThread {
        print("Not on main thread")
        return
    }
    
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
    
    // Move cursor to center of screen, adjusted up and right
    if let screen = NSScreen.main {
        let centerX = screen.frame.origin.x + screen.frame.width / 2 + 57.5  // 115/2 pixels right
        let centerY = screen.frame.origin.y + screen.frame.height / 2 - 115   // 115 pixels up (subtract to move up)
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
    }
    
    let response = alert.runModal()
    
    print("After alert - MouseIndicator showing: \(MouseIndicatorState.shared.showingProgress)")
    
    let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    let clickedButton = buttons[Int(buttonIndex)]
    
    completion?(clickedButton)
}

