import SwiftUI
import AVFoundation


class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?
    
    func playStartupSound() {
        guard let soundURL = Bundle.main.url(
            forResource: "StartupTwentiethAnniversaryMac", 
            withExtension: "wav") else {
                print("Could not find sound file")
                return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.75
            audioPlayer?.play()
            
            print("Playing sound...")
        } catch {
            print("Failed to load sound: \(error)")
        }
    }
}
