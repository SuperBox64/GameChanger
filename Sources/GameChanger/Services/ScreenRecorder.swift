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
    private var cameraView: NSView?
    
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
                    // Set up camera view after recording starts
                    DispatchQueue.main.async {
                        self?.setupCameraView()
                    }
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
                    // Remove camera view when recording stops
                    self?.removeCameraPreview()
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
        // First toggle camera state
        if isCameraEnabled {
            recorder.isCameraEnabled = false
            isCameraEnabled = false
            removeCameraPreview()
        } else {
            recorder.isCameraEnabled = true
            isCameraEnabled = true
            // Set up camera view after enabling
            DispatchQueue.main.async { [weak self] in
                self?.setupCameraView()
            }
        }
    }
    
    func toggleMicrophone() {
        recorder.isMicrophoneEnabled.toggle()
        isMicrophoneEnabled = recorder.isMicrophoneEnabled
    }
    
    // MARK: - Camera Preview Setup
    
    private func setupCameraView() {
        // Validate that the camera preview view and camera are in enabled state
        if (recorder.cameraPreviewView != nil) && recorder.isCameraEnabled {
            guard let cameraView = recorder.cameraPreviewView else {
                print("Unable to retrieve cameraPreviewView. Returning.")
                return
            }
            guard let window = NSApp.windows.first else { return }
            
            // Camera dimensions - half of 640x480
            let width: CGFloat = 320
            let height: CGFloat = 240
            let padding: CGFloat = 20
            
            // Position in BOTTOM right corner - using contentView coordinates
            if let contentView = window.contentView {
                let frame = NSRect(
                    x: contentView.bounds.width - width - (padding * 4),
                    y: contentView.bounds.height - height - padding,  // FIXED: This will place it at the bottom
                    width: width,
                    height: height
                )
                
                cameraView.frame = frame
                cameraView.wantsLayer = true
                contentView.addSubview(cameraView)
                self.cameraView = cameraView
            }
        }
    }
    
    private func removeCameraPreview() {
        DispatchQueue.main.async { [weak self] in
            // Remove the camera view from the main view when tearing down the camera
            self?.cameraView?.removeFromSuperview()
            self?.cameraView = nil
        }
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
    @objc nonisolated func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        Task { @MainActor in
            // Update UI if recorder availability changes
            print("Screen recorder availability changed: \(screenRecorder.isAvailable)")
        }
    }
    
    @objc nonisolated func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewController: RPPreviewViewController?, error: Error?) {
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