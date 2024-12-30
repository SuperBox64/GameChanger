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


struct GUISettings: Codable {
    let GameChangerUI: GameChangerUISettings
}

struct GameChangerUISettings: Codable {
    let common: CommonSettings
    private let resolutions: [String: InterfaceSizing]
    
    private enum CodingKeys: String, CodingKey {
        case common
        case resolutions
    }
    
    func getResolution(_ key: String) -> InterfaceSizing {
        guard let settings = resolutions[key] else {
            fatalError("Missing settings for resolution: \(key)")
        }
        return settings
    }
}

struct CommonSettings: Codable {
    let mouseSensitivity: Double
    let enableScreenshots: Bool
    let bounceEnabled: Bool
    let fonts: FontSettings
    let colors: ColorSettings
    let mouseIndicator: MouseIndicatorCommonSettings
    let animations: AnimationSettings
    let opacities: OpacitySettings
    let fontWeights: FontWeightSettings
    let multipliers: MultiplierSettings
    let layout: CommonLayoutSettings
    let navigationDots: NavigationDotsCommonSettings
}

struct CommonLayoutSettings: Codable {
    let shortcut: ShortcutLayout
}

struct MouseIndicatorCommonSettings: Codable {
    let inactivityTimeout: Double
    let distanceFromDots: CGFloat  // Distance between navigation dots and mouse indicator
}

struct ColorSettings: Codable {
    let mouseIndicator: MouseIndicatorColors
    let text: TextColors
}

struct TextColors: Codable {
    let selected: [Double]
    let unselected: [Double]
    
    var selectedUI: Color {
        Color(.sRGB, 
              red: selected[0],
              green: selected[1], 
              blue: selected[2], 
              opacity: selected[3])
    }
    
    var unselectedUI: Color {
        Color(.sRGB, 
              red: unselected[0],
              green: unselected[1], 
              blue: unselected[2], 
              opacity: unselected[3])
    }
}

struct MouseIndicatorColors: Codable {
    let background: [Double]  // [R, G, B, A]
    let progress: [Double]    // [R, G, B, A]
    
    var backgroundUI: Color {
        Color(.sRGB, 
              red: background[0],
              green: background[1], 
              blue: background[2], 
              opacity: background[3])
    }
    
    var progressUI: Color {
        Color(.sRGB, 
              red: progress[0], 
              green: progress[1], 
              blue: progress[2], 
              opacity: progress[3])
    }
}

struct FontSettings: Codable {
    let title: String
    let label: String
    let clock: String
}

struct InterfaceSizing: Codable {
    let carousel: CarouselSizing
    let mouseIndicator: MouseIndicatorSettings
    let title: TitleSettings
    let clock: ClockSettings
    let layout: LayoutSettings
}


// Add new animation settings structs
struct AnimationSettings: Codable {
    let slideEnabled: Bool
    let fadeEnabled: Bool
    let bounceEnabled: Bool
    let slide: SlideAnimation
    let fade: FadeAnimation
}

struct SlideAnimation: Codable {
    let duration: Double
    let curve: CubicCurve
}

struct CubicCurve: Codable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
}

struct FadeAnimation: Codable {
    let duration: Double
}



// Add LayoutSettings struct
struct LayoutSettings: Codable {
    let title: TitleLayout
    let clock: ClockLayout
    let logo: LogoLayout?  // Add back the logo property
    let shortcut: ShortcutLayout
}

struct TitleLayout: Codable {
    let topPadding: CGFloat
}

struct ClockLayout: Codable {
    let topPadding: CGFloat
    let trailingPadding: CGFloat
}

struct MouseIndicatorLayout: Codable {
    // Remove this line since it's now in MouseIndicatorSettings
    // let bottomPadding: CGFloat
}

struct MultiplierSettings: Codable {
    let iconSize: Double
    let cornerRadius: Double
    let gridSpacing: Double
    let mouseIndicatorIconSize: Double
}

struct OpacitySettings: Codable {
    let selectionHighlight: Double
    let clockDateText: Double
}

struct FontWeightSettings: Codable {
    let mouseIndicatorIcon: String
}

struct CarouselSizing: Codable {
    let iconSize: CGFloat
    let iconPadding: CGFloat
    let cornerRadius: CGFloat
    let gridSpacing: CGFloat
    let titleSize: CGFloat
    let labelSize: CGFloat
    let selectionPadding: CGFloat
}

struct TitleSettings: Codable {
    let size: CGFloat
}

struct ClockSettings: Codable {
    let timeSize: CGFloat
    let dateSize: CGFloat
    let spacing: CGFloat
}

struct MouseIndicatorSettings: Codable {
    let size: CGFloat
    let strokeWidth: CGFloat
    let bottomPadding: CGFloat
}
