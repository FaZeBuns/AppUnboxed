import Foundation
import AudioToolbox
import AVFoundation

public class CSGOAudioPlayer {
    public static let shared = CSGOAudioPlayer()

    private var unboxPlayer: AVAudioPlayer?
    private var winPlayer: AVAudioPlayer?
    // Several copies of the tick so fast back-to-back ticks overlap instead of
    // cutting each other off.
    private var tickPlayers: [AVAudioPlayer] = []
    private var tickIndex = 0

    private init() {
        // Play even with the ring switch on silent, and mix with the user's music.
        // (The old tick was the system keyboard click, which is silent whenever
        // Keyboard Clicks is off in Settings.)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        unboxPlayer = Self.player("unbox", volume: 1.0)
        winPlayer = Self.player("win", volume: 0.9)
        for _ in 0..<8 {
            if let p = Self.player("tick", volume: 0.85) { tickPlayers.append(p) }
        }
    }

    private static func player(_ name: String, volume: Float) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.volume = volume
        p.prepareToPlay()
        return p
    }

    /// The crate sequence soundtrack (thud, rattles, burst-open), cut to match
    /// the animation timeline in CrateStageView.
    public func playUnbox() {
        guard let player = unboxPlayer else { playWhoosh(); return }
        player.currentTime = 0
        player.play()
    }

    /// One reel tick. Called once for every card that passes the marker.
    public func playTick() {
        guard !tickPlayers.isEmpty else { AudioServicesPlaySystemSound(1104); return }
        let p = tickPlayers[tickIndex % tickPlayers.count]
        tickIndex += 1
        p.currentTime = 0
        p.play()
    }

    public func playWin() {
        guard let player = winPlayer else { AudioServicesPlaySystemSound(1025); return }
        player.currentTime = 0
        player.play()
    }

    public func playWhoosh() {
        AudioServicesPlaySystemSound(1108)
    }
}
