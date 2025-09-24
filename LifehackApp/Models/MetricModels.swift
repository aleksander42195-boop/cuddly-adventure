import SwiftUI

struct Metric: Identifiable, Hashable {
    enum MetricType: String, CaseIterable, Hashable, Codable {
        case steps, calories, mindfulness, sleep, activeMinutes

        var title: String { rawValue.capitalized.replacingOccurrences(of: "Minutes", with: " Minutes") }
        var systemImage: String {
            switch self {
            case .steps: return "figure.walk"
            case .calories: return "flame"
            case .mindfulness: return "brain.head.profile"
            case .sleep: return "bed.double"
            case .activeMinutes: return "hare"
            }
        }
        var color: Color {
            switch self {
            case .steps: return .blue
            case .calories: return .orange
            case .mindfulness: return .purple
            case .sleep: return .indigo
            case .activeMinutes: return .pink
            }
        }
        var goalDefault: Double {
            switch self {
            case .steps: return 10_000
            case .calories: return 600
            case .mindfulness: return 15
            case .sleep: return 8
            case .activeMinutes: return 30
            }
        }
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .calories: return "kcal"
            case .mindfulness: return "min"
            case .sleep: return "h"
            case .activeMinutes: return "min"
            }
        }
    }

    let id = UUID()
    let type: MetricType
    var value: Double
    var goal: Double

    var progress: Double { goal == 0 ? 0 : min(value / goal, 1) }
    var title: String { type.title }
    var color: Color { type.color }

    var formattedValue: String {
        switch type {
        case .sleep:
            return String(format: "%.1f %@", value, type.unit)
        default:
            return "\(Int(value)) \(type.unit)"
        }
    }
}

struct TodaySnapshot: Sendable {
    var stress: Double
    var energy: Double
    var battery: Double
    var hrvSDNNms: Double
    var restingHR: Double
    var steps: Int

    // Computed percentage ints (0...100)
    var stressPercent: Int { Int(stress.clamped01 * 100) }
    var energyPercent: Int { Int(energy.clamped01 * 100) }
    var batteryPercent: Int { Int(battery.clamped01 * 100) }

    // Category labels (simple thresholding; adjust later)
    var stressCategory: String {
        switch stress {
        case ..<0.33: return "Low"
        case ..<0.66: return "Moderate"
        default: return "High"
        }
    }
    var energyCategory: String {
        switch energy {
        case ..<0.33: return "Low"
        case ..<0.66: return "OK"
        default: return "High"
        }
    }
    var batteryCategory: String {
        switch battery {
        case ..<0.2: return "Critical"
        case ..<0.5: return "Low"
        case ..<0.8: return "Good"
        default: return "Full"
        }
    }

    // UI-ready formatted strings
    var hrvLabel: String { String(format: "%.0f ms", hrvSDNNms) }
    var restingHRLabel: String { String(format: "%.0f bpm", restingHR) }
    var stepsLabel: String { "\(steps)" }
    var batteryLabel: String { "\(batteryPercent)%" }

    // Builder for selective updates
    func withUpdated(
        stress: Double? = nil,
        energy: Double? = nil,
        battery: Double? = nil,
        hrvSDNNms: Double? = nil,
        restingHR: Double? = nil,
        steps: Int? = nil
    ) -> TodaySnapshot {
        TodaySnapshot(
            stress: (stress ?? self.stress).clamped01,
            energy: (energy ?? self.energy).clamped01,
            battery: (battery ?? self.battery).clamped01,
            hrvSDNNms: hrvSDNNms ?? self.hrvSDNNms,
            restingHR: restingHR ?? self.restingHR,
            steps: steps ?? self.steps
        )
    }

    // Empty baseline (all zeros)
    static let empty = TodaySnapshot(
        stress: 0, energy: 0, battery: 0,
        hrvSDNNms: 0, restingHR: 0, steps: 0
    )
}

private extension Double {
    var clamped01: Double { min(max(self, 0), 1) }
}
