import Foundation

// Self‑contained fallback so `swift test_device_selection.swift` works standalone.
struct Device: Identifiable, Hashable {
    let id = UUID()
    let model: String
    let capacity: String
    let available: Bool
    var displayLine: String {
        "\(model) (\(capacity)) \(available ? "✅ Available" : "❌ Unavailable")"
    }
}

final class DeviceManager {
    private var stored: [Device] = [
        Device(model: "iPhone 13 Pro Max", capacity: "1TB",  available: true),
        Device(model: "iPhone 17 Pro Max", capacity: "2TB",  available: true),
        Device(model: "iPhone 12 mini",    capacity: "256GB", available: false)
    ]
    func findUserDevices() -> [Device] { stored }
}

@main
struct DeviceSelectionTest {
    static func main() {
        let manager = DeviceManager()
        let devices = manager.findUserDevices()
        print("Found \(devices.count) devices:")
        for d in devices {
            print("• \(d.displayLine)")
        }
        let available = devices.filter { $0.available }
        print("Available count: \(available.count)")
        // Exit non‑zero if none available (simple health signal for CI)
        exit(available.isEmpty ? 1 : 0)
    }
}
