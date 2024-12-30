import SwiftUI

struct SizingGuide {
    static private var settings: GUISettings = {
        guard let url = Bundle.main.url(forResource: "gamechanger-ui", withExtension: "json") else {
            fatalError("gamechanger-ui.json not found in bundle")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(GUISettings.self, from: data)
        } catch {
            fatalError("Failed to decode gamechanger-ui.json: \(error)")
        }
    }()
    
    static func getSettings(for resolution: String) -> InterfaceSizing {
        return settings.GameChangerUI.getResolution(resolution)
    }
    
    static func getCommonSettings() -> CommonSettings {
        return settings.GameChangerUI.common
    }
    
    static func getCurrentSettings() -> InterfaceSizing {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let resolution = getResolutionKey(for: screen.frame.size)
        return getSettings(for: resolution)
    }
    
    static func getSizing(for screenSize: CGSize) -> CarouselSizing {
        let resolution = getResolutionKey(for: screenSize)
        return getSettings(for: resolution).carousel
    }
    
    static func getResolutionKey(for screenSize: CGSize) -> String {
        if screenSize.width >= 5120 {
            return "5120x2880"
        } else if screenSize.width >= 2880 {
            return "2880x1620"
        } else if screenSize.width >= 2560 {
            return "2560x1440"
        } else if screenSize.width >= 2048 {
            return "2048x1152"
        } else if screenSize.width >= 1920 {
            return "1920x1080"
        } else if screenSize.width >= 1600 {
            return "1600x900"
        } else if screenSize.width >= 1440 {
            return "1440x810"
        } else if screenSize.width >= 1366 {
            return "1366x1024"
        }
        return "1280x720"
    }
    
    static func getScreenSize(for resolution: String) -> CGSize {
        switch resolution {
            case "5120x2880":
                return CGSize(width: 5120, height: 2880)
            case "2880x1620":
                return CGSize(width: 2880, height: 1620)
            case "2560x1440":
                return CGSize(width: 2560, height: 1440)
            case "2048x1152":
                return CGSize(width: 2048, height: 1152)
            case "1920x1080":
                return CGSize(width: 1920, height: 1080)
            case "1600x900":
                return CGSize(width: 1600, height: 900)
            case "1440x810":
                return CGSize(width: 1440, height: 810)
            default: // "1280x720"
                return CGSize(width: 1280, height: 720)
        }
    }
}