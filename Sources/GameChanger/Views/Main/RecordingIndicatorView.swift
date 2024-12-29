import SwiftUI

struct RecordingIndicatorView: View {
    @ObservedObject var screenRecorder: ScreenRecorder
    
    var body: some View {
        if screenRecorder.isRecording {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 16, height: 16)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
    }
} 