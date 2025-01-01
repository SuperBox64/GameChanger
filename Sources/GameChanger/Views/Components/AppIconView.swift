import SwiftUI

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
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHighlighted = hovering
                    if hovering && UIVisibilityState.shared.mouseVisible {
                        onHighlight()
                    }
                }
                .onTapGesture {
                    if UIVisibilityState.shared.mouseVisible {
                        onSelect()
                    }
                }
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
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHighlighted = hovering
                    if hovering && UIVisibilityState.shared.mouseVisible {
                        onHighlight()
                    }
                }
                .onTapGesture {
                    if UIVisibilityState.shared.mouseVisible {
                        onSelect()
                    }
                }
        }
        .frame(
            width: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding,
            height: sizingManager.sizing.iconSize * multipliers.iconSize + sizingManager.sizing.selectionPadding + 40
        )
        .onChange(of: UIVisibilityState.shared.mouseVisible) { newValue in
            if !newValue {
                isHighlighted = false
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
