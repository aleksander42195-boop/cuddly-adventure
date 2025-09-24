import Foundation

struct Device: Identifiable, Hashable {
    let id = UUID()
    let model: String          // e.g. "iPhone 13 Pro Max"
    let capacity: String       // e.g. "1TB"
    let available: Bool
    var displayLine: String {
        "\(model) (\(capacity)) \(available ? "✅ Available" : "❌ Unavailable")"
    }
}

final class DeviceManager: Sendable {
    // Mock store; in real code fetch from persistence / API
    private var stored: [Device] = [
        Device(model: "iPhone 13 Pro Max",   capacity: "1TB",  available: true),
        Device(model: "iPhone 17 Pro Max",   capacity: "2TB",  available: true),
        Device(model: "iPhone 12 mini",      capacity: "256GB", available: false)
    ]

    func findUserDevices() -> [Device] {
        stored
    }

    func refresh() async -> [Device] {
        // Simulate async fetch / filtering
        try? await Task.sleep(nanoseconds: 150_000_000)
        return stored
    }

    // Example mutation (not used yet)
    func add(_ device: Device) {
        stored.append(device)
    }
}
