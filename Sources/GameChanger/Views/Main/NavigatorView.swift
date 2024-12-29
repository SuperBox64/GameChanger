import SwiftUI

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

class NavigationDotsNSView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        // Enable mouse tracking
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        let maxDotsPerRow = 12
        
        for row in 0..<((totalPages + maxDotsPerRow - 1) / maxDotsPerRow) {
            let dotsInThisRow = row == (totalPages + maxDotsPerRow - 1) / maxDotsPerRow - 1 ? 
                               totalPages % maxDotsPerRow == 0 ? maxDotsPerRow : totalPages % maxDotsPerRow : 
                               maxDotsPerRow
            
            let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
            let startX = (bounds.width - totalWidth) / 2
            
            for col in 0..<dotsInThisRow {
                let index = row * maxDotsPerRow + col
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let y = bounds.height - settings.bottomPadding - dotSize
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                
                if dotRect.contains(point) {
                    onPageSelect?(index)
                    return
                }
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        let maxDotsPerRow = 12
        let rows = (totalPages + maxDotsPerRow - 1) / maxDotsPerRow
        let dotsInLastRow = totalPages % maxDotsPerRow == 0 ? maxDotsPerRow : totalPages % maxDotsPerRow
        
        for row in 0..<rows {
            let dotsInThisRow = row == rows - 1 ? dotsInLastRow : maxDotsPerRow
            let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
            let startX = (bounds.width - totalWidth) / 2
            
            for col in 0..<dotsInThisRow {
                let index = row * maxDotsPerRow + col
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let y = bounds.height - settings.bottomPadding - dotSize
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
    
    var currentPage: Int = 0 {
        didSet {
            needsDisplay = true
            animatePageChange(from: oldValue, to: currentPage)
        }
    }
    var totalPages: Int = 0
    var onPageSelect: ((Int) -> Void)?
    
    private func animatePageChange(from: Int, to: Int) {
        let settings = SizingGuide.getCommonSettings().navigationDots
        let dotSize: CGFloat = settings.size
        let spacing: CGFloat = settings.spacing
        
        let oldDotRect = getDotRect(for: from, dotSize: dotSize, spacing: spacing)
        let newDotRect = getDotRect(for: to, dotSize: dotSize, spacing: spacing)
        
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
    
    private func getDotRect(for index: Int, dotSize: CGFloat, spacing: CGFloat) -> NSRect {
        let maxDotsPerRow = 12
        let row = index / maxDotsPerRow
        let col = index % maxDotsPerRow
        let dotsInThisRow = min(maxDotsPerRow, totalPages - (row * maxDotsPerRow))
        let totalWidth = CGFloat(dotsInThisRow) * (dotSize + spacing) - spacing
        let startX = (bounds.width - totalWidth) / 2
        let settings = SizingGuide.getCommonSettings().navigationDots  // Add this line
        let y = bounds.height - settings.bottomPadding - dotSize
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