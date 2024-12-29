import Foundation
import ReplayKit
import AVFoundation
import AppKit

@MainActor
class ScreenRecorder: NSObject, ObservableObject, RPPreviewViewControllerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isCameraEnabled = false
    @Published private(set) var isMicrophoneEnabled = false
    
    private let recorder = RPScreenRecorder.shared()
    private var previewWindow: NSWindow?
    
    override init() {
        super.init()
        recorder.delegate = self
        
        // Initialize default settings
        recorder.isCameraEnabled = false
        recorder.isMicrophoneEnabled = false
    }
    
    // MARK: - Recording Controls
    
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
                    if let previewController = previewController {
                        self?.presentPreview(previewController)
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Camera and Microphone Controls
    
    func toggleCamera() {
        recorder.isCameraEnabled.toggle()
        isCameraEnabled = recorder.isCameraEnabled
        
        if isCameraEnabled, let cameraView = recorder.cameraPreviewView {
            setupCameraPreview(cameraView)
        } else {
            removeCameraPreview()
        }
    }
    
    func toggleMicrophone() {
        recorder.isMicrophoneEnabled.toggle()
        isMicrophoneEnabled = recorder.isMicrophoneEnabled
    }
    
    // MARK: - Camera Preview Setup
    
    private func setupCameraPreview(_ cameraView: NSView) {
        guard let window = NSApp.windows.first else { return }
        
        // Configure camera preview
        cameraView.frame = NSRect(x: 0, y: window.frame.height - 150,
                                width: 200, height: 150)
        cameraView.wantsLayer = true
        
        window.contentView?.addSubview(cameraView)
    }
    
    private func removeCameraPreview() {
        recorder.cameraPreviewView?.removeFromSuperview()
    }
    
    // MARK: - Preview Handling
    
    private func presentPreview(_ previewController: RPPreviewViewController) {
        guard let window = NSApp.windows.first else { return }
        
        // Show mouse cursor when presenting preview
        UIVisibilityState.shared.mouseVisible = true
        NSCursor.unhide()
        
        previewController.previewControllerDelegate = self
        
        // Create and configure preview window
        let previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        previewWindow.contentViewController = previewController
        
        previewWindow.title = "Recording Preview"
        previewWindow.center()
        
        self.previewWindow = previewWindow
        
        // Present as sheet
        window.beginSheet(previewWindow)
    }
    
    // MARK: - RPPreviewViewControllerDelegate
    
    @objc nonisolated func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        Task { @MainActor in
            guard let window = NSApp.windows.first,
                  let previewWindow = self.previewWindow else { return }
            
            window.endSheet(previewWindow)
            self.previewWindow = nil
        }
    }
}

// MARK: - RPScreenRecorderDelegate
@MainActor
extension ScreenRecorder: RPScreenRecorderDelegate {
    @objc func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        // Update UI if recorder availability changes
        print("Screen recorder availability changed: \(screenRecorder.isAvailable)")
    }
    
    @objc func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewController: RPPreviewViewController?, error: Error?) {
        Task { @MainActor in
            isRecording = false
            
            if let error = error {
                print("Recording stopped with error: \(error.localizedDescription)")
                return
            }
            
            if let previewController = previewController {
                presentPreview(previewController)
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