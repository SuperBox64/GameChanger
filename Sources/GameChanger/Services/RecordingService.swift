import Foundation
import ScreenCaptureKit
import AVFoundation

@MainActor
class RecordingService: ObservableObject {
    static let shared = RecordingService()
    @Published private(set) var isRecording = false
    private let screenRecorder = ScreenRecorder()
    
    func toggleRecording() {
        Task {
            do {
                if screenRecorder.isRecording {
                    try await screenRecorder.stop()
                } else {
                    try await screenRecorder.start()
                }
            } catch {
                print("Recording error: \(error.localizedDescription)")
            }
        }
    }
} 