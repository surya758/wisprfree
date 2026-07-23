import AppKit

/// Subtle audio cues for recording start/stop, gated by a setting.
enum Sound {
    static func playStart() { play("Pop") }
    static func playStop() { play("Tink") }

    private static func play(_ name: String) {
        guard AppSettings.current.soundEnabled else { return }
        let sound = NSSound(named: name)
        sound?.volume = 0.35
        sound?.play()
    }
}
