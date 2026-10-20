import Foundation

/// A personal continuous vibration scale, not a classifier of physical force.
public struct IntensityCalibration: Codable {
    public let softG: Double
    public let normalG: Double
    public let hardG: Double
    private let version: Int

    public enum Failure: LocalizedError {
        case unsupportedReport, incompleteMeasurements, overlappingRanges, invalidAnchors

        public var errorDescription: String? {
            switch self {
            case .unsupportedReport: return "Нужна сводка schema 5 с включённым датчиком и выключенным звуком."
            case .incompleteMeasurements: return "Нужны три серии минимум по 20 оценок без пропусков, одной клавишей и пальцем."
            case .overlappingRanges: return "Центральные диапазоны перекрываются. Калибровка не применена."
            case .invalidAnchors: return "Некорректные или неупорядоченные значения калибровки."
            }
        }
    }

    private init(softG: Double, normalG: Double, hardG: Double) throws {
        guard softG.isFinite, normalG.isFinite, hardG.isFinite,
              softG > 0, softG < normalG, normalG < hardG,
              (hardG * 1.2).isFinite else { throw Failure.invalidAnchors }
        self.softG = softG; self.normalG = normalG; self.hardG = hardG
        version = 1
    }

    public init(reportData: Data) throws {
        let report = try JSONDecoder().decode(Report.self, from: reportData)
        guard report.schema_version == 5, report.sensor_enabled_at_export,
              !report.sound_enabled_at_export else { throw Failure.unsupportedReport }
        guard report.groups.count == 3 else { throw Failure.incompleteMeasurements }
        let ordered = ["soft", "normal", "hard"].compactMap { label in
            report.groups.first { $0.label == label }
        }
        guard ordered.count == 3, Set(report.groups.map(\.label)).count == 3,
              ordered.allSatisfy({ $0.count >= 20 && $0.unmatched == 0 }) else {
            throw Failure.incompleteMeasurements
        }
        guard ordered.allSatisfy({ group in
            [group.median_g, group.p25_g, group.p75_g].allSatisfy { $0.isFinite && $0 >= 0 }
                && group.p25_g <= group.median_g && group.median_g <= group.p75_g
        }) else { throw Failure.invalidAnchors }
        guard ordered[0].p75_g < ordered[1].p25_g,
              ordered[1].p75_g < ordered[2].p25_g else { throw Failure.overlappingRanges }
        try self.init(softG: ordered[0].median_g, normalG: ordered[1].median_g,
                      hardG: ordered[2].median_g)
    }

    /// Linear interpolation at 0 / soft / normal / hard / 1.2×hard anchors.
    /// No allocation or I/O occurs when processing a key.
    public func normalized(_ impact: Double) -> Double {
        guard impact.isFinite, impact > 0 else { return 0 }
        if impact <= softG { return 0.2 * impact / softG }
        if impact <= normalG { return 0.2 + 0.3 * (impact - softG) / (normalG - softG) }
        if impact <= hardG { return 0.5 + 0.35 * (impact - normalG) / (hardG - normalG) }
        return min(1, 0.85 + 0.15 * (impact - hardG) / (hardG * 0.2))
    }

    private enum CodingKeys: String, CodingKey { case version, softG, normalG, hardG }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .version) == 1 else { throw Failure.invalidAnchors }
        try self.init(softG: values.decode(Double.self, forKey: .softG),
                      normalG: values.decode(Double.self, forKey: .normalG),
                      hardG: values.decode(Double.self, forKey: .hardG))
    }

    private struct Report: Decodable {
        let schema_version: Int
        let sensor_enabled_at_export: Bool
        let sound_enabled_at_export: Bool
        let groups: [Group]
    }

    private struct Group: Decodable {
        let label: String
        let count: Int
        let unmatched: Int
        let median_g: Double
        let p25_g: Double
        let p75_g: Double
    }
}
