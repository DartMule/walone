import AppKit
import Carbon
import UniformTypeIdentifiers

// Использует прежние SensorStream / ImpactEstimator и формат сводки schema 5.
final class SensorExperiment {
    let sensor = SensorStream()
    private let defaults: UserDefaults
    private var calibration: IntensityCalibration?
    private var normalization = ImpactEstimator()
    private var measurements: [[Double]] = [[], [], []]
    private var unmatched = [0, 0, 0]
    private var failureReasons: [[String: Int]] = [[:], [:], [:]]
    private var processingTimes: [Double] = []
    private var streamEnded = false
    private var pending = 0
    private var generation = 0
    private var lastSnapshot = monotonicTime()
    private(set) var useSensor = false
    private(set) var sensitivity = 0.08
    private(set) var stage = 0
    private(set) var collecting = false
    private var intensity = 0.0
    private var processingMS = 0.0
    private var summary = "Измерений пока нет"
    private var comparison = "Для сравнения нужны минимум 20 оценок каждого режима"
    private var calibrationStatus = "Личная калибровка не применена"
    private let calibrationKey = "intensityCalibration.v1"

    init(defaults: UserDefaults = .standard, readStdin: Bool = CommandLine.arguments.contains("--sensor-stdin")) {
        self.defaults = defaults
        let saved = defaults.double(forKey: "sensorFullScale.v1")
        if saved.isFinite, (0.01...0.25).contains(saved) { sensitivity = saved }
        if let data = defaults.data(forKey: calibrationKey) {
            do { try restoreCalibration(data) }
            catch { calibrationStatus = "Сохранённая калибровка повреждена — обычная шкала" }
        }
        useSensor = readStdin
        if readStdin {
            let sensor = self.sensor
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                while let line = readLine() {
                    sensor.ingest(line: line, receivedAt: monotonicTime())
                }
                DispatchQueue.main.async { self?.streamEnded = true; self?.collecting = false }
            }
        }
    }

    func configure(_ arguments: [String: Any]) throws {
        guard let enabled = arguments["enabled"] as? Bool,
              let scale = arguments["sensitivity"] as? Double, scale.isFinite, (0.01...0.25).contains(scale),
              let stage = arguments["stage"] as? Int, (0...2).contains(stage),
              let collecting = arguments["collecting"] as? Bool else { throw CocoaError(.coderReadCorrupt) }
        generation += 1
        useSensor = enabled
        sensitivity = scale
        self.stage = stage
        self.collecting = collecting && enabled && !streamEnded
        defaults.set(scale, forKey: "sensorFullScale.v1")
    }

    func status() -> [String: Any] {
        let now = monotonicTime()
        let snapshot = sensor.snapshot(resetRateCounter: true)
        let fresh = snapshot.lastTime.map { now - $0 < 0.1 } ?? false
        let status = !useSensor ? "Обычный режим — оценка вибрации выключена"
            : streamEnded ? "Сессия датчика завершена — обычный режим"
            : fresh ? String(format: "Поток датчика: %.0f Гц", Double(snapshot.sampleCount) / max(0.01, now - lastSnapshot))
            : "Нет свежего сигнала — обычный режим"
        lastSnapshot = now
        let transport = CalibrationSummary.percentile(snapshot.deliveryDelays, fraction: 0.95)
            .map { String(format: "Доставка датчика P95: %.2f мс", $0) } ?? "Задержка передачи датчика ещё не измерена"
        return ["enabled": useSensor, "sensitivity": sensitivity, "stage": stage,
                "collecting": collecting, "intensity": intensity, "processingMS": processingMS,
                "status": status, "transport": transport, "summary": summary, "comparison": comparison,
                "hasCalibration": calibration != nil, "calibrationStatus": calibrationStatus]
    }

    func key(time: Double, inputAllowed: @escaping () -> Bool = { !IsSecureEventInputEnabled() && CGPreflightListenEventAccess() }, canPlay: @escaping () -> Bool, play: @escaping (Float) -> Void) {
        guard useSensor else { if canPlay() { play(1) }; return }
        guard (canPlay() || collecting), pending < 32 else { return }
        pending += 1
        let request = ImpactRequest(keyTime: time, receivedAt: monotonicTime())
        let currentGeneration = generation
        let measurementStage = collecting ? stage : nil
        func resolve() {
            guard self.generation == currentGeneration, self.useSensor,
                  canPlay() || self.collecting,
                  inputAllowed() else { self.pending -= 1; return }
            let resolution = self.sensor.resolve(request, now: monotonicTime())
            if case .wait = resolution {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001, execute: resolve)
                return
            }
            self.pending -= 1
            let impact: Double?
            let reason: ImpactFailure?
            switch resolution {
            case .value(let value): impact = value; reason = nil
            case .failure(let failure): impact = nil; reason = failure
            case .wait: return
            }
            self.normalization.fullScale = self.sensitivity
            let normalized = impact.map { self.calibration?.normalized($0) ?? self.normalization.normalized($0) } ?? 0.45
            self.intensity = normalized
            if self.collecting, let stage = measurementStage {
                if let impact, self.measurements[stage].count < 1000 { self.measurements[stage].append(impact) }
                else if let reason {
                    self.unmatched[stage] += 1
                    self.failureReasons[stage][reason.rawValue, default: 0] += 1
                }
                self.updateSummary()
            }
            if canPlay() { play(Float(0.2 + 0.8 * normalized)) }
            self.processingMS = max(0, (monotonicTime() - request.keyTime) * 1000)
            if self.processingTimes.count == 1000 { self.processingTimes.removeFirst() }
            self.processingTimes.append(self.processingMS)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ImpactRequest.initialWait, execute: resolve)
    }

    func suspend() {
        generation += 1
        collecting = false
        sensor.reset()
    }

    func reset() {
        generation += 1
        measurements = [[], [], []]; unmatched = [0, 0, 0]; processingTimes = []
        failureReasons = [[:], [:], [:]]
        updateSummary()
    }

    func restoreCalibration(_ data: Data) throws {
        let candidate = try JSONDecoder().decode(IntensityCalibration.self, from: data)
        defaults.set(data, forKey: calibrationKey)
        calibration = candidate
        showCalibration()
    }

    func applyCalibration(report data: Data) throws {
        let candidate = try IntensityCalibration(reportData: data)
        try restoreCalibration(JSONEncoder().encode(candidate))
    }

    func loadCalibration() throws {
        collecting = false
        generation += 1
        let panel = NSOpenPanel()
        panel.title = "Выберите сводку трёх серий одной клавиши без звука"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 256 * 1024 + 1) ?? Data()
        guard data.count <= 256 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        try applyCalibration(report: data)
    }

    private func showCalibration() {
        if let calibration {
            calibrationStatus = String(format: "Личная шкала сохранена: %.5f / %.5f / %.5f g. Это вибрация, не классификатор силы.",
                                       calibration.softG, calibration.normalG, calibration.hardG)
        }
    }

    func removeCalibration() {
        defaults.removeObject(forKey: calibrationKey)
        calibration = nil
        calibrationStatus = "Личная калибровка не применена"
    }

    func exportSummary(soundEnabled: Bool, paused: Bool) throws {
        collecting = false
        generation += 1
        let data = try report(soundEnabled: soundEnabled, paused: paused)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "walone-measurements.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
    }

    private func updateSummary() {
        let labels = ["Мягко", "Обычно", "Сильно"]
        summary = measurements.enumerated().map { i, values in
            guard let median = CalibrationSummary.median(values) else { return "\(labels[i]): 0, без оценки: \(unmatched[i])" }
            let low = CalibrationSummary.percentile(values, fraction: 0.25)!
            let high = CalibrationSummary.percentile(values, fraction: 0.75)!
            return String(format: "%@: %d, медиана %.5f g, P25–P75 %.5f–%.5f\n  без оценки: %d", labels[i], values.count, median, low, high, unmatched[i])
        }.joined(separator: "\n")
        if measurements.contains(where: { $0.count < 20 }) {
            comparison = "Для сравнения нужны минимум 20 оценок каждого режима"
        } else if CalibrationSummary.centralRangesSeparated(measurements) {
            comparison = "Средние диапазоны разделены в этой серии. Повторите проверку: классификатор ещё не подтверждён."
        } else {
            comparison = "Диапазоны перекрываются или порядок интенсивности не подтверждён. Нужна повторная серия."
        }
    }

    func report(soundEnabled: Bool, paused: Bool) throws -> Data {
        let snapshot = sensor.snapshot()
        let groups = measurements.enumerated().map { i, values -> [String: Any] in
            ["label": ["soft", "normal", "hard"][i], "count": values.count,
             "unmatched": unmatched[i],
             "failure_reasons": failureReasons[i],
             "median_g": CalibrationSummary.median(values) as Any? ?? NSNull(),
             "p10_g": CalibrationSummary.percentile(values, fraction: 0.1) as Any? ?? NSNull(),
             "p25_g": CalibrationSummary.percentile(values, fraction: 0.25) as Any? ?? NSNull(),
             "p75_g": CalibrationSummary.percentile(values, fraction: 0.75) as Any? ?? NSNull(),
             "p90_g": CalibrationSummary.percentile(values, fraction: 0.9) as Any? ?? NSNull()]
        }
        let report: [String: Any] = ["schema_version": 5, "groups": groups, "experimental": true,
                "processing_ms_last": processingMS,
                "processing_ms_p50": CalibrationSummary.median(processingTimes) as Any? ?? NSNull(),
                "processing_ms_p95": CalibrationSummary.percentile(processingTimes, fraction: 0.95) as Any? ?? NSNull(),
                "processing_ms_p99": CalibrationSummary.percentile(processingTimes, fraction: 0.99) as Any? ?? NSNull(),
                "processing_observations": processingTimes.count,
                "sensor_wait_budget_ms": ImpactRequest.maximumWait * 1000,
                "pipe_delivery_ms_p50": CalibrationSummary.median(snapshot.deliveryDelays) as Any? ?? NSNull(),
                "pipe_delivery_ms_p95": CalibrationSummary.percentile(snapshot.deliveryDelays, fraction: 0.95) as Any? ?? NSNull(),
                "pipe_delivery_ms_p99": CalibrationSummary.percentile(snapshot.deliveryDelays, fraction: 0.99) as Any? ?? NSNull(),
                "callback_lag_ms_p50": CalibrationSummary.median(snapshot.callbackDelays) as Any? ?? NSNull(),
                "callback_lag_ms_p95": CalibrationSummary.percentile(snapshot.callbackDelays, fraction: 0.95) as Any? ?? NSNull(),
                "callback_lag_ms_p99": CalibrationSummary.percentile(snapshot.callbackDelays, fraction: 0.99) as Any? ?? NSNull(),
                "pipe_transit_ms_p50": CalibrationSummary.median(snapshot.pipeTransitDelays) as Any? ?? NSNull(),
                "pipe_transit_ms_p95": CalibrationSummary.percentile(snapshot.pipeTransitDelays, fraction: 0.95) as Any? ?? NSNull(),
                "pipe_transit_ms_p99": CalibrationSummary.percentile(snapshot.pipeTransitDelays, fraction: 0.99) as Any? ?? NSNull(),
                "callback_transport_observations": snapshot.callbackDelays.count,
                "sensor_processing_off_main": true,
                "sensor_rejected_samples": snapshot.rejectedSamples,
                "transport_observations": snapshot.deliveryDelays.count,
                "central_ranges_separated": CalibrationSummary.centralRangesSeparated(measurements),
                "sound_enabled_at_export": soundEnabled, "sensor_enabled_at_export": useSensor,
                "sound_paused_at_export": paused,
                "calibration_active": calibration != nil,
                "calibration_anchors_g": calibration.map { ["soft": $0.softG, "normal": $0.normalG, "hard": $0.hardG] } as Any? ?? NSNull(),
                "audible_latency_measured": false]
        return try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }
}

private func monotonicTime() -> Double {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return Double(mach_absolute_time()) * Double(info.numer) / Double(info.denom) / 1e9
}
