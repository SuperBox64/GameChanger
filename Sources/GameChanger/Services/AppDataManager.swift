import SwiftUI

// Add this class near the top of the file
class AppDataManager {
    static let shared = AppDataManager()
    
    private(set) var sections: [Section] = []
    private var itemsBySection: [String: [AppItem]] = [:]
    
    private init() {
        loadData()
    }
    
    private func loadData() {
        guard let url = Bundle.main.url(forResource: "app_items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sectionsArray = json["sections"] as? [[String: Any]] else {
            print("ERROR: Failed to load app_items.json")
            return
        }
        
        // Sections are now ordered from the JSON array
        sections = sectionsArray.compactMap { section in
            guard let name = section["name"] as? String else { return nil }
            return Section(rawValue: name)
        }
        
        // Parse items for each section
        for section in sectionsArray {
            guard let sectionName = section["name"] as? String,
                  let items = section["items"] as? [[String: Any]] else { continue }
            
            itemsBySection[sectionName] = items.compactMap { itemDict in
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
    
    func items(for section: Section) -> [AppItem] {
        return itemsBySection[section.rawValue] ?? []
    }
}