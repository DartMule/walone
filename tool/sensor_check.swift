import AppKit

// swiftc compiles this check with SensorExperiment and the three shared core files.
@main
struct SensorCheck {
    static func main() throws {
        let suite = "WaloneSensorCheck.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let experiment = SensorExperiment(defaults: defaults, readStdin: false)
        func configure(_ enabled: Bool = true, scale: Double = 0.1, collecting: Bool = true) throws {
            try experiment.configure(["enabled": enabled, "sensitivity": scale, "stage": 0, "collecting": collecting])
        }
        try configure()
        do {
            try configure(scale: .nan)
            fatalError("Invalid scale accepted")
        } catch {}
        assert(experiment.status()["sensitivity"] as? Double == 0.1)
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let time = Double(mach_absolute_time()) * Double(info.numer) / Double(info.denom) / 1e9
        for offset in -10...6 {
            let t = time + Double(offset) / 1000
            experiment.sensor.ingest(MotionSample(time: t, x: offset == 0 ? 0.05 : 0, y: 0, z: 1), receivedAt: time)
        }
        var gains: [Float] = []
        experiment.key(time: time, inputAllowed: { true }, canPlay: { true }, play: { gains.append($0) })
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.025))
        assert(gains.count == 1 && gains[0] > 0.2 && gains[0] < 1)
        let report = try JSONSerialization.jsonObject(with: experiment.report(soundEnabled: false, paused: false)) as! [String: Any]
        assert(report["schema_version"] as? Int == 5)
        let groups = report["groups"] as! [[String: Any]]
        assert(groups[0]["count"] as? Int == 1)
        assert(groups[0]["unmatched"] as? Int == 0)
        let calibrationReport: [String: Any] = [
            "schema_version": 5, "sensor_enabled_at_export": true, "sound_enabled_at_export": false,
            "groups": ["soft", "normal", "hard"].enumerated().map { i, name in
                ["label": name, "count": 20, "unmatched": 0,
                 "median_g": Double(i + 1) * 0.02, "p25_g": Double(i + 1) * 0.02 - 0.001,
                 "p75_g": Double(i + 1) * 0.02 + 0.001] as [String: Any]
            }
        ]
        try experiment.applyCalibration(report: JSONSerialization.data(withJSONObject: calibrationReport))
        assert(experiment.status()["hasCalibration"] as? Bool == true)
        let restored = SensorExperiment(defaults: defaults, readStdin: false)
        assert(restored.status()["hasCalibration"] as? Bool == true)
        assert(restored.status()["enabled"] as? Bool == false)
        do {
            try experiment.applyCalibration(report: Data("{}".utf8))
            fatalError("Invalid calibration accepted")
        } catch {}
        assert(experiment.status()["hasCalibration"] as? Bool == true)
        experiment.removeCalibration()
        assert(defaults.data(forKey: "intensityCalibration.v1") == nil)
        experiment.reset()
        let cleared = try JSONSerialization.jsonObject(with: experiment.report(soundEnabled: false, paused: true)) as! [String: Any]
        assert((cleared["groups"] as! [[String: Any]]).allSatisfy { $0["count"] as? Int == 0 })
        try configure(false)
        assert(experiment.status()["collecting"] as? Bool == false)
        gains = []
        experiment.key(time: time, canPlay: { true }, play: { gains.append($0) })
        assert(gains == [1])
        print("sensor_check=ok (matching, gain, schema 5, validation, persistence, reset, fallback)")
    }
}
