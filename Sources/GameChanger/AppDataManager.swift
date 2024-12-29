import SwiftUI

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