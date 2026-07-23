import AppKit

/// Subtle audio cues for recording start/stop, gated by a setting.
enum Sound {
    /// NSSound.play() is async; without a strong reference the sound is
    /// deallocated before it finishes and never plays. Keep recent ones alive.
    private static var players: [NSSound] = []

    static func playStart() { play("Pop") }
    static func playStop() { play("Tink") }

    private static func play(_ name: String) {
        guard AppSettings.current.soundEnabled, let sound = NSSound(named: name) else { return }
        sound.volume = 0.4
        players.append(sound)
        if players.count > 4 { players.removeFirst(players.count - 4) }
        sound.play()
    }
}
