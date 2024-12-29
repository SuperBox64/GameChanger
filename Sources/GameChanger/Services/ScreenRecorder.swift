import Foundation
import ReplayKit
import AVFoundation
import AppKit

@MainActor
class ScreenRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isCameraEnabled = false
    @Published private(set) var isMicrophoneEnabled = false
    
    private let recorder = RPScreenRecorder.shared()
    
    override init() {
        super.init()
        recorder.delegate = self
        recorder.isCameraEnabled = false
        recorder.isMicrophoneEnabled = false
    }
    
    func startRecording() async throws {
        guard !isRecording else { return }
        guard recorder.isAvailable else {
            throw RecordingError.recorderUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startRecording { [weak self] error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self?.isRecording = true
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func stopRecording() async throws {
        guard isRecording else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopRecording { [weak self] previewController, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self?.isRecording = false
                    
                    // Show save panel
                    DispatchQueue.main.async {
                        let savePanel = NSSavePanel()
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                        let timestamp = dateFormatter.string(from: Date())
                        
                        savePanel.nameFieldStringValue = "GameChanger_Recording_\(timestamp).mov"
                        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
                        savePanel.allowedContentTypes = [.mpeg4Movie]
                        savePanel.begin { response in
                            if response == .OK, let url = savePanel.url {
                                print("Recording will be saved to: \(url.path)")
                            }
                        }
                    }
                    
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

// MARK: - RPScreenRecorderDelegate
extension ScreenRecorder: RPScreenRecorderDelegate {
    @objc nonisolated func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        Task { @MainActor in
            print("Screen recorder availability changed: \(screenRecorder.isAvailable)")
        }
    }
    
    @objc nonisolated func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewController: RPPreviewViewController?, error: Error?) {
        Task { @MainActor in
            isRecording = false
            
            if let error = error {
                print("Recording stopped with error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors
extension ScreenRecorder {
    enum RecordingError: LocalizedError {
        case recorderUnavailable
        
        var errorDescription: String? {
            switch self {
            case .recorderUnavailable:
                return "Screen recording is not available on this device"
            }
        }
    }
} 