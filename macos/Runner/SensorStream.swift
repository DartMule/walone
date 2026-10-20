import Foundation

/// The pipe reader owns ingestion; the UI only takes snapshots or matches keys.
/// No UI dispatch is required to keep the sensor timeline current.
public final class SensorStream: @unchecked Sendable {
    private let lock = NSLock()
    private var estimator = ImpactEstimator()
    private var deliveryDelays: [Double] = []
    private var callbackDelays: [Double] = []
    private var pipeTransitDelays: [Double] = []
    private var sampleCount = 0
    private var rejectedSamples = 0

    public struct Snapshot {
        public let lastTime: Double?
        public let sampleCount: Int
        public let rejectedSamples: Int
        public let deliveryDelays: [Double]
        public let callbackDelays: [Double]
        public let pipeTransitDelays: [Double]
    }

    public init() {
        deliveryDelays.reserveCapacity(1000)
        callbackDelays.reserveCapacity(1000)
        pipeTransitDelays.reserveCapacity(1000)
    }

    /// Four fields support the old probe; the fifth timestamps callback entry.
    public func ingest(line: String, receivedAt: Double) {
        let parts = line.split(separator: ",", omittingEmptySubsequences: false)
        let fields = parts.compactMap { Double($0) }
        guard (parts.count == 4 || parts.count == 5), fields.count == parts.count,
              fields.allSatisfy(\.isFinite) else {
            lock.lock(); rejectedSamples += 1; lock.unlock()
            return
        }
        ingest(MotionSample(time: fields[0], x: fields[1], y: fields[2], z: fields[3]),
               receivedAt: receivedAt, callbackAt: fields.count == 5 ? fields[4] : nil)
    }

    public func ingest(_ sample: MotionSample, receivedAt: Double, callbackAt: Double? = nil) {
        lock.lock(); defer { lock.unlock() }
        guard receivedAt.isFinite, sample.time.isFinite,
              sample.x.isFinite, sample.y.isFinite, sample.z.isFinite,
              abs(sample.time - receivedAt) < 0.2,
              estimator.lastTime.map({ sample.time > $0 }) ?? true else {
            rejectedSamples += 1
            return
        }
        if let callbackAt {
            guard callbackAt.isFinite, callbackAt >= sample.time - 0.000001,
                  callbackAt <= receivedAt + 0.000001 else {
                rejectedSamples += 1
                return
            }
        }
        estimator.ingest(sample)
        sampleCount += 1
        if deliveryDelays.count == 1000 { deliveryDelays.removeFirst() }
        deliveryDelays.append(max(0, (receivedAt - sample.time) * 1000))
        if let callbackAt {
            if callbackDelays.count == 1000 {
                callbackDelays.removeFirst(); pipeTransitDelays.removeFirst()
            }
            callbackDelays.append(max(0, (callbackAt - sample.time) * 1000))
            pipeTransitDelays.append(max(0, (receivedAt - callbackAt) * 1000))
        }
    }

    public func resolve(_ request: ImpactRequest, now: Double) -> ImpactResolution {
        lock.lock(); defer { lock.unlock() }
        return request.resolve(using: &estimator, now: now)
    }

    public func snapshot(resetRateCounter: Bool = false) -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        let snapshot = Snapshot(lastTime: estimator.lastTime, sampleCount: sampleCount,
                                rejectedSamples: rejectedSamples, deliveryDelays: deliveryDelays,
                                callbackDelays: callbackDelays, pipeTransitDelays: pipeTransitDelays)
        if resetRateCounter { sampleCount = 0 }
        return snapshot
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        estimator = ImpactEstimator()
        sampleCount = 0; rejectedSamples = 0
        deliveryDelays.removeAll(keepingCapacity: true)
        callbackDelays.removeAll(keepingCapacity: true)
        pipeTransitDelays.removeAll(keepingCapacity: true)
    }
}
