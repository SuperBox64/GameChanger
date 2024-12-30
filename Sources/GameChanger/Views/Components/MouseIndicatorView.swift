import SwiftUI

class MouseIndicatorNSView: NSView {
    var progress: CGFloat = 0
    var direction: Int = 0
    private let settings = SizingGuide.getSettings(for: WindowSizeMonitor.shared.currentResolution).mouseIndicator
    private let commonSettings = SizingGuide.getCommonSettings()
    
    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY - settings.bottomPadding * )
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
        ZStack {
            Spacer()
            MouseIndicatorNSViewRepresentable(
                progress: mouseState.mouseProgress,
                direction: mouseState.mouseDirection
            )
            .frame(width: settings.size * 1.5,
                   height: settings.size * 1.5)
        }
        .opacity(mouseState.showingProgress && !uiVisibilityState.mouseVisible ? 1 : 0)
    }
}
