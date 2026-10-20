import AVFoundation

/// Recorded switches, decoded once. Playback and recovery are confined to the main thread.
enum KeyboardSoundPack: String, CaseIterable, Identifiable {
    case brown, red
    case apex = "apex-pro-tkl-v2"
    case logitech = "logitech-g915-tkl-brown"
    case ibm = "ibm-model-m"
    case hhkb = "hhkb-hybrid"
    case whitefox
    case keychron = "keychron-k10"
    case dell = "dell-d510"
    case razerUltimate = "razer-ultimate"
    case razer2013 = "razer-2013"
    case razerTournament = "razer-tournament"
    case corsairK70 = "corsair-k70"
    case corsairK95Red = "corsair-k95-red"
    case corsairK95Brown = "corsair-k95-brown"
    case ducky = "ducky-miya"
    case appleIIe = "apple-iie"
    case applePro = "apple-pro"
    case appleAluminum = "apple-aluminum"
    case microsoft

    var id: String { rawValue }
    var isKeyboardModel: Bool { self != .brown && self != .red }
    var keyCount: Int {
        switch self {
        case .apex: return 3
        case .logitech: return 5
        case .razer2013: return 2
        default: return 6
        }
    }
    var title: String { description.title }
    var detail: String { description.detail }

    private var description: (title: String, detail: String, author: String) {
        switch self {
        case .brown: return ("Cherry MX Brown", "Тактильный · плотный и сдержанный", "Mechvibes")
        case .red: return ("Cherry MX Red", "Линейный · лёгкий и звонкий", "Mechvibes")
        case .apex: return ("SteelSeries Apex Pro TKL", "Apex Pro TKL v2 · короткий и отчётливый", "Akira")
        case .logitech: return ("Logitech G915 TKL", "Brown · низкопрофильный, тактильный", "Keyboard Sounds")
        case .ibm: return ("IBM Model M Space Saver", "Buckling spring · винтажная механика", "Ico Doornekamp")
        case .hhkb: return ("HHKB Professional Hybrid", "Topre 45 g · без модификаций", "grcekh")
        case .whitefox: return ("WhiteFox", "Hako Violet · механическая клавиатура", "grcekh")
        case .keychron: return ("Keychron K10", "Линейные переключатели · AZERTY", "Sadiquecat")
        case .dell: return ("Dell Latitude D510", "Клавиатура ноутбука · медленная печать", "justamudkip")
        case .razerUltimate: return ("Razer BlackWidow Ultimate", "Механическая клавиатура · запись Rode NT1", "yottasounds")
        case .razer2013: return ("Razer BlackWidow (2013)", "Две отдельные записи нажатия", "newagesoup")
        case .razerTournament: return ("Razer BlackWidow Tournament Edition", "Щёлкающие переключатели · запись 2015 года", "WaveAdventurer")
        case .corsairK70: return ("Corsair K70 (2016)", "Механическая клавиатура · запись печати", "luutoo")
        case .corsairK95Red: return ("Corsair K95", "Cherry MX Red · линейные переключатели", "handygaber")
        case .corsairK95Brown: return ("Corsair K95 RGB Platinum", "Cherry MX Brown · тактильные переключатели", "NickTHH")
        case .ducky: return ("Ducky × Varmilo Miya", "Brown · тактильные переключатели", "eclectic-kitty")
        case .appleIIe: return ("Apple IIe", "Винтажный компьютер · запись Zoom H6", "makenoisemusic")
        case .applePro: return ("Apple Pro Keyboard", "Настольная клавиатура · запись печати", "BrodieSound")
        case .appleAluminum: return ("Apple Aluminum Keyboard", "Алюминиевая клавиатура · запись Rode NT5", "Tomlija")
        case .microsoft: return ("Microsoft Internet Keyboard Pro", "RT9420 · запись Tascam TM-80", "PanosA")
        }
    }

    var recordingNote: String {
        switch self {
        case .apex: return "Запись Akira · 3 варианта букв, Пробел и Enter. Для ⌫ — звук обычной клавиши."
        case .logitech: return "Запись Keyboard Sounds · 5 вариантов букв, Пробел и Enter. Для ⌫ — звук Enter."
        case .brown, .red: return "Запись Mechvibes · PBT-клавиши. Модель клавиатуры не указана."
        case .ibm: return "Запись Ico Doornekamp · 6 букв, отдельные Пробел, Enter и ⌫."
        case .keychron: return "Запись Sadiquecat · 6 нажатий и отдельный Пробел. Для Enter и ⌫ — обычная клавиша."
        default: return "Запись \(description.author) · \(keyCount) фрагментов нажатий. Для Пробела, Enter и ⌫ — обычные клавиши."
        }
    }
}

final class KeyboardAudio {
    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var available: [Bool] = []
    private var tokens: [UInt64] = []
    private var nextVoice = 0
    private var variation = 0
    private var sounds: [AVAudioPCMBuffer] = []
    private var selectedPack: KeyboardSoundPack?
    private var configurationObserver: NSObjectProtocol?
    private let resourcesURL: URL
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    init(engine: AVAudioEngine? = nil, resourcesURL: URL) {
        self.engine = engine
        self.resourcesURL = resourcesURL
    }

    private func prepareEngine() -> AVAudioEngine {
        if let engine, !players.isEmpty { return engine }
        let engine = self.engine ?? AVAudioEngine()
        self.engine = engine
        for _ in 0..<24 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player); available.append(true); tokens.append(0)
        }
        engine.prepare()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            // CoreAudio posts from its own queue. Never tear down the engine there.
            DispatchQueue.main.async { self?.stop() }
        }
        return engine
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
    }

    func prepare() {
        _ = prepareEngine()
    }

    func selectPack(_ pack: KeyboardSoundPack) throws {
        guard selectedPack != pack else { return }
        let names = (0..<pack.keyCount).map { "key\($0)" } + ["space", "enter", "backspace"]
        let loaded = try names.map { name -> AVAudioPCMBuffer in
            let url = resourcesURL.appendingPathComponent("\(pack.rawValue)/\(name).wav")
            let file = try AVAudioFile(forReading: url)
            guard file.processingFormat == format, file.length > 0, file.length <= 48_000,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try file.read(into: buffer)
            return buffer
        }
        // Keep the previous pack intact if any new recording failed to load.
        sounds = loaded; selectedPack = pack; variation = 0
    }

    func play(group: Int, volume: Float) throws {
        if sounds.isEmpty { try selectPack(.brown) }
        let engine = prepareEngine()
        if !engine.isRunning {
            stop()
            try engine.start()
        }
        // A stopped node cannot consume its buffers, even when the engine is running.
        let index = available.firstIndex(of: true) ?? nextVoice
        nextVoice = (index + 1) % players.count
        tokens[index] &+= 1
        let token = tokens[index]
        if !available[index] { players[index].stop() }
        available[index] = false
        let keyCount = sounds.count - 3
        let soundIndex = group == 0 ? variation % keyCount : keyCount - 1 + min(3, max(1, group))
        variation = (variation + 1) % keyCount
        players[index].volume = min(1, max(0, volume))
        players[index].scheduleBuffer(sounds[soundIndex], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.tokens[index] == token else { return }
                self.available[index] = true
            }
        }
        if !players[index].isPlaying { players[index].play() }
    }

    func stop() {
        // Invalidate callbacks before stop() flushes scheduled buffers.
        for index in players.indices { tokens[index] &+= 1 }
        players.forEach { $0.stop() }
        engine?.stop()
        available = Array(repeating: true, count: players.count)
        nextVoice = 0
    }
}
