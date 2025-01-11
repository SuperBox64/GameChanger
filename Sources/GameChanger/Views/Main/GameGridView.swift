import SwiftUI
import Carbon.HIToolbox

struct GameGridView: View {
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @StateObject private var appState = AppState.shared
    @State private var selectedIndex: Int = 0  // Start with first item selected
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    let columns: [GridItem] = Array(repeating: .init(.fixed(180), spacing: 40), count: 7)  // 7 columns
    let sectionName: String
    
    // Show items from the current section
    private var gameItems: [AppItem] {
        guard appState.isLoaded else { return [] }
        
        // Get items from the current section without padding
        return AppDataManager.shared.items(for: Section(rawValue: sectionName))
    }
    
    private func handleGameSelection(_ index: Int) {
        let item = gameItems[index]
        if !item.name.isEmpty {
            // Hide UI but keep grid view state
           // uiVisibility.isVisible = false
            
            item.actionEnum.execute(
                with: item.path,
                appName: item.name,
                fullscreen: item.fullscreen
            )
        }
    }
    
    private func setupKeyMonitorForGameGridView() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                uiVisibility.isGridVisible = false
            case kVK_UpArrow:
                if selectedIndex >= 7 { // Move up one row
                    selectedIndex -= 7
                }
            case kVK_DownArrow:
                let nextRowIndex = selectedIndex + 7
                if nextRowIndex < gameItems.count { // Move down one row if exists
                    selectedIndex = nextRowIndex
                }
            case kVK_LeftArrow:
                if selectedIndex % 7 != 0 { // Not at start of row
                    selectedIndex -= 1
                }
            case kVK_RightArrow:
                if (selectedIndex + 1) % 7 != 0 && // Not at end of row
                   selectedIndex + 1 < gameItems.count { // Next item exists
                    selectedIndex += 1
                }
            case kVK_Return, kVK_Space:
                if selectedIndex >= 0 && selectedIndex < gameItems.count {
                    handleGameSelection(selectedIndex)
                }
            default:
                return nil
            }
            return nil
        }
    }
    
    // private func setupMouseMonitor() {
    //     mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
    //         return nil
    //     }
        
    //     // Left click for selection
    //     NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
    //         return nil
    //     }
        
    //     // Right click for back
    //     NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
    //         if uiVisibility.isGridVisible {
    //             uiVisibility.isGridVisible = false
    //         }
    //         return nil
    //     }
    // }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(sectionName)
                    .font(.custom(
                        SizingGuide.getCommonSettings().fonts.title,
                        size: SizingGuide.getCurrentSettings().title.size
                    ))
                    .foregroundColor(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(0..<gameItems.count, id: \.self) { index in
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
                    .padding(40)
                }
            }
        }
        .onAppear {
            setupKeyMonitorForGameGridView()
            //setupMouseMonitor()
        }
        .onDisappear {
            if let keyMonitor = keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            // if let mouseMonitor = mouseMonitor {
            //     NSEvent.removeMonitor(mouseMonitor)
            // }
        }
    }
}

struct GameGridItemView: View {
    let item: AppItem
    let isSelected: Bool
    let onSelect: () -> Void
    @StateObject private var sizingManager = SizingManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 180, height: 180)
                
                loadIcon()
                    .frame(width: 140, height: 140)
            }
            
            Text(item.name.isEmpty ? "Empty" : item.name)
                .foregroundColor(.white)
                .font(.system(size: 20))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .opacity(item.name.isEmpty ? 0.5 : 1.0)
        }
        .frame(width: 200, height: 240)
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
