import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var sizingManager = SizingManager.shared
    @StateObject private var navigationModel = NavigationModel.shared
    @StateObject private var mouseState = MouseIndicatorState.shared
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var uiVisibility = UIVisibilityState.shared
    
    var body: some View {
        ZStack {
            NavigationBackgroundView()
            
            VStack {
                Text(navigationModel.currentSection)
                    .font(.custom(
                        SizingGuide.getCommonSettings().fonts.title,
                        size: SizingGuide.getCurrentSettings().title.size
                    ))
                    .foregroundColor(.white)
                    .opacity(navigationModel.titleOpacity)
                    .padding(.top, SizingGuide.getCurrentSettings().title.topPadding)
                Spacer()
            }
            .opacity(uiVisibility.isVisible ? 1 : 0)

            NavigationCarouselView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await ContentViewModel.shared.setupMonitors()
            }
            if let screen = NSScreen.main {
                sizingManager.updateSizing(for: screen.frame.size)
                navigationModel.windowWidth = screen.frame.width
            }
        }
    }
}