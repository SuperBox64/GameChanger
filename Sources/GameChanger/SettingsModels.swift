import Foundation
import SwiftUI

struct AppItem: Codable {
    let name: String
    let systemIcon: String
    let parent: String?
    let action: String?
    let path: String?
    let fullscreen: Bool?
    
    var sectionEnum: Section {
        return Section(rawValue: name)
    }
    
    var parentEnum: Section? {
        guard let parent = parent else { return nil }
        return Section(rawValue: parent)
    }
    
    var actionEnum: Action {
        guard let action = action else { return .none }
        print("Converting action string: \(action)")
        let actionEnum = Action(rawValue: action)
        print("Converted to enum: \(String(describing: actionEnum))")
        return actionEnum ?? .none
    }
}

struct NavigationDotsCommonSettings: Codable {
    public let size: CGFloat
    public let spacing: CGFloat
    public let bottomPadding: CGFloat
}

public struct ShortcutLayout: Codable {
    public let leadingPadding: CGFloat
    public let bottomPadding: CGFloat
    public let titleSize: CGFloat
    public let subtitleSize: CGFloat
}

public struct LogoLayout: Codable {
    public let topPadding: CGFloat
    public let leadingPadding: CGFloat
}

public struct Section: RawRepresentable, Codable, CaseIterable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static var allCases: [Section] = { return AppDataManager.shared.sections }()
} 