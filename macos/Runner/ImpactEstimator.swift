import Foundation

public struct MotionSample: Sendable {
    public let time: Double
    public let x: Double
    public let y: Double
    public let z: Double

    public init(time: Double, x: Double, y: Double, z: Double) {
        self.time = time; self.x = x; self.y = y; self.z = z
    }
}

public enum ImpactFailure: String, Codable {
    case noSamples, staleSignal, incompleteCoverage, windowConsumed, noPeak
    case invalidTimestamp, deadline, sensorDisabled
}

public enum ImpactMatch {
    case value(Double)
    case failure(ImpactFailure)
}

public enum ImpactResolution {
    case wait
    case value(Double)
    case failure(ImpactFailure)
}

/// A bounded request on the same monotonic timeline as the event and sensor.
public struct ImpactRequest {
    public static let initialWait = 0.006
    // Observed HID callback batches can lag ~26 ms. Allow future coverage too;
    // resolve still finishes as soon as data is available, starting at 6 ms.
    public static let maximumWait = 0.035
    public let keyTime: Double
    private let deadline: Double

    public init(keyTime: Double, receivedAt: Double) {
        self.keyTime = keyTime
        deadline = receivedAt + Self.maximumWait
    }

    public func resolve(using estimator: inout ImpactEstimator, now: Double) -> ImpactResolution {
        guard now.isFinite, deadline.isFinite, keyTime.isFinite else { return .failure(.invalidTimestamp) }
        guard now < deadline else { return .failure(.deadline) }
        switch estimator.match(at: keyTime, minimumCoverage: 0.004) {
        case .value(let value): return .value(value)
        case .failure(.incompleteCoverage): return .wait
        case .failure(let reason): return .failure(reason)
        }
    }
}

/// Experimental high-pass filter. Values are chassis vibration in g, not key force.
public struct ImpactEstimator {
    private var baseline: MotionSample?
    private var peaks: [(time: Double, value: Double)] = []
    private var consumedThrough = -Double.infinity
    public private(set) var lastTime: Double?
    public var threshold = 0.002
    public var fullScale = 0.08

    public init() { peaks.reserveCapacity(256) }

    public mutating func ingest(_ sample: MotionSample) {
        guard sample.time.isFinite, sample.x.isFinite, sample.y.isFinite, sample.z.isFinite else { return }
        if let lastTime, sample.time <= lastTime { return }
        let dt = sample.time - (lastTime ?? sample.time)
        lastTime = sample.time
        guard let previous = baseline, dt < 0.2 else {
            baseline = sample
            peaks.removeAll(keepingCapacity: true)
            return
        }
        let alpha = 1 - exp(-dt / 0.03)
        let dx = sample.x - previous.x, dy = sample.y - previous.y, dz = sample.z - previous.z
        baseline = MotionSample(time: sample.time, x: previous.x + alpha * dx,
                                y: previous.y + alpha * dy, z: previous.z + alpha * dz)
        peaks.append((sample.time, sqrt(dx * dx + dy * dy + dz * dz)))
        peaks.removeAll { $0.time < sample.time - 0.12 }
    }

    /// A short look-ahead is provided by the caller. A vibration cannot be reused
    /// for another key; dense chords therefore deliberately have uncertain estimates.
    public mutating func impact(at keyTime: Double, minimumCoverage: Double = 0) -> Double? {
        if case .value(let value) = match(at: keyTime, minimumCoverage: minimumCoverage) { return value }
        return nil
    }

    public mutating func match(at keyTime: Double, minimumCoverage: Double = 0) -> ImpactMatch {
        guard keyTime.isFinite, minimumCoverage.isFinite, minimumCoverage >= 0 else { return .failure(.invalidTimestamp) }
        guard let lastTime else { return .failure(.noSamples) }
        guard abs(lastTime - keyTime) < 0.1 else { return .failure(.staleSignal) }
        guard lastTime - keyTime >= minimumCoverage else { return .failure(.incompleteCoverage) }
        let start = max(keyTime - 0.012, consumedThrough)
        let end = keyTime + 0.006
        guard start < end else { return .failure(.windowConsumed) }
        let peak = peaks.filter { $0.time > start && $0.time <= end }.map(\.value).max()
        consumedThrough = max(consumedThrough, end)
        guard let peak else { return .failure(.noPeak) }
        return .value(peak)
    }

    public func normalized(_ impact: Double) -> Double {
        guard fullScale > threshold else { return 0 }
        return min(1, max(0, (impact - threshold) / (fullScale - threshold)))
    }
}

public struct CalibrationSummary {
    public static func median(_ values: [Double]) -> Double? {
        percentile(values, fraction: 0.5)
    }

    /// Linearly interpolated empirical quantile; no distribution is assumed.
    public static func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard fraction.isFinite, (0...1).contains(fraction) else { return nil }
        let sorted = values.filter { $0.isFinite && $0 >= 0 }.sorted()
        guard !sorted.isEmpty else { return nil }
        let position = Double(sorted.count - 1) * fraction
        let lower = Int(position), upper = min(sorted.count - 1, lower + 1)
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    /// A descriptive check for one series, not a validated typing classifier.
    public static func centralRangesSeparated(_ groups: [[Double]], minimumCount: Int = 20) -> Bool {
        guard groups.count == 3, groups.allSatisfy({ $0.filter { $0.isFinite && $0 >= 0 }.count >= minimumCount }) else { return false }
        guard let softUpper = percentile(groups[0], fraction: 0.75),
              let normalLower = percentile(groups[1], fraction: 0.25),
              let normalUpper = percentile(groups[1], fraction: 0.75),
              let hardLower = percentile(groups[2], fraction: 0.25) else { return false }
        return softUpper < normalLower && normalUpper < hardLower
    }
}
