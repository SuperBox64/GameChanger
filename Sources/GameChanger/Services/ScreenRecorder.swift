import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import AppKit

@MainActor
class ScreenRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    // Capture state
    private var captureState = CaptureState()
    
    private struct CaptureState {
        var isWriting = false
        var shouldWrite = false
    }
    
    override init() {
        super.init()
    }
    
    func start() async throws {
        print("\n=== ScreenRecorder.start() ===")
        guard !isRecording else { 
            print("Already recording - ignoring start request")
            return 
        }
        
        // Get screen content
        let content = try await SCShareableContent.current
        print("Got screen content")
        guard let display = content.displays.first else {
            print("No display found")
            throw RecordingError.noPermission
        }
        print("Found display: \(display.width)x\(display.height)")
        
        // Configure stream
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        
        // Setup recording file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "GameChanger-\(timestamp).mp4"
        let outputURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        
        print("Will save to: \(outputURL.path)")
        
        do {
            writer = try AVAssetWriter(url: outputURL, fileType: .mp4)
            print("Created AVAssetWriter")
        } catch {
            print("Failed to create writer: \(error)")
            throw error
        }
        
        // Video settings
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height
        ])
        videoInput?.expectsMediaDataInRealTime = true
        
        // Audio settings
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2
        ])
        audioInput?.expectsMediaDataInRealTime = true
        
        if let videoInput = videoInput, let audioInput = audioInput {
            writer?.add(videoInput)
            writer?.add(audioInput)
        }
        
        // Create and start stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
        try await stream?.startCapture()
        
        writer?.startWriting()
        writer?.startSession(atSourceTime: .zero)
        captureState.shouldWrite = true
        isRecording = true
        UIVisibilityState.shared.isRecording = true
    }
    
    func stop() async throws {
        guard isRecording else { return }
        captureState.shouldWrite = false
        isRecording = false
        UIVisibilityState.shared.isRecording = false
        
        if let stream = stream {
            try await stream.stopCapture()
            self.stream = nil
        }
        
        writer?.finishWriting {
            print("Recording saved")
        }
    }
    
    enum RecordingError: LocalizedError {
        case noDisplay
        case cannotCreateWriter
        case noPermission
        
        var errorDescription: String? {
            switch self {
            case .noDisplay:
                return "No display found to record"
            case .cannotCreateWriter:
                return "Failed to create video writer"
            case .noPermission:
                return "Screen recording permission not granted"
            }
        }
    }
}

// MARK: - Stream Delegate & Output
extension ScreenRecorder: SCStreamDelegate, SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            isRecording = false
        }
    }
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { 
            print("Buffer not ready")
            return 
        }
        
        Task { @MainActor in
            guard captureState.shouldWrite else { 
                print("Not writing - captureState.shouldWrite is false")
                return 
            }
            
            switch type {
            case .screen:
                videoInput?.append(sampleBuffer)
                print("Wrote video frame")
            case .audio:
                audioInput?.append(sampleBuffer)
                print("Wrote audio frame")
            default:
                break
            }
        }
    }
} 