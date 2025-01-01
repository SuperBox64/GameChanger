import SwiftUI

struct NavigationBackgroundView: View {
    @StateObject private var navigationModel = NavigationModel.shared
    
    var body: some View {
        BackgroundView(onBack: navigationModel.back)
    }
} 