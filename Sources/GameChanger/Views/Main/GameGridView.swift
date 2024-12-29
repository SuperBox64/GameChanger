import SwiftUI

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
