import SwiftUI

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
    
    private func checkMouseHover() {
        if let window = NSApp.windows.first {
            let mouseLocation = window.mouseLocationOutsideOfEventStream  // Remove optional binding
            // Get the grid layout
            let gridWidth = sizing.iconSize + sizing.gridSpacing
            let gridHeight = sizing.iconSize + sizing.gridSpacing
            
            // Check each visible item
            for index in 0..<visibleItems.count {
                let row = index / 4
                let col = index % 4
                
                let itemX = CGFloat(col) * gridWidth + sizing.gridSpacing
                let itemY = CGFloat(row) * gridHeight + sizing.gridSpacing
                
                let itemFrame = CGRect(x: itemX, y: itemY, 
                                     width: sizing.iconSize, 
                                     height: sizing.iconSize)
                
                if itemFrame.contains(mouseLocation) {
                    onHighlight(index)
                    break
                }
            }
        }
    }
    
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
                            onBack: { 
                                onBack(index)
                                DispatchQueue.main.async {
                                    checkMouseHover()
                                }
                            },
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