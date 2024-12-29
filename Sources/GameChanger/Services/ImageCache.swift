import SwiftUI

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
