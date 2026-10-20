import AVFoundation

@main
enum KeyboardAudioCheck {
    static func main() throws {
        let engine = AVAudioEngine()
        let audio = KeyboardAudio(engine: engine, resourcesURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        func voices() -> Int {
            engine.attachedNodes.filter { $0 is AVAudioPlayerNode }.count
        }
        assert(voices() == 0, "Idle keyboard must not allocate playback voices")
        audio.stop()
        try audio.selectPack(.brown)
        assert(voices() == 0, "Selecting recordings must not prepare the engine")
        audio.prepare()
        assert(!engine.isRunning && voices() == 24)
        try audio.play(group: 0, volume: 0)
        assert(engine.isRunning && voices() == 24)
        audio.stop()
        assert(!engine.isRunning)
        try audio.play(group: 1, volume: 0)
        assert(engine.isRunning && voices() == 24)
        audio.stop()
        print("Keyboard audio: lazy voices, first playback and restart passed")
    }
}
