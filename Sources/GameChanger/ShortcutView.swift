import SwiftUI

struct ShortcutHintView: View {
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(uiVisibility.mouseVisible ? "Hide Mouse" : "Show Mouse")
                .foregroundColor(.white)
                .font(.system(size: SizingGuide.getCurrentSettings().layout.shortcut.titleSize))
            Text("Press esc key")
                .foregroundColor(.gray)
                .font(.system(size: SizingGuide.getCurrentSettings().layout.shortcut.subtitleSize))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, SizingGuide.getCurrentSettings().layout.shortcut.leadingPadding)
        .padding(.bottom, SizingGuide.getCurrentSettings().layout.shortcut.bottomPadding)
    }
}