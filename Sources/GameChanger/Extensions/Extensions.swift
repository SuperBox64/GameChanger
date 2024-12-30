import SwiftUI

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

// Add this extension to safely access array elements
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension NSAlert {
    static func darkModeAlert(
        title: String,
        message: String,
        buttonTitles: [String] = ["OK"]
    ) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        
        // Force dark appearance by setting window appearance
        alert.window.appearance = NSAppearance(named: .darkAqua)
        
        // Add buttons in order
        buttonTitles.forEach { title in
            alert.addButton(withTitle: title)
        }
        
        return alert
    }
}

extension NSWindow {
    func forceDarkMode() {
        self.appearance = NSAppearance(named: .darkAqua)
    }
}