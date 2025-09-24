import Foundation
import UIKit

enum AppIconManager {
    struct Option: Identifiable, Hashable {
        // key is the CFBundleAlternateIcons key; nil means primary icon
        let key: String?
        let title: String
        var id: String { key ?? "__primary__" }
    }

    // Update names to match your asset/Info.plist keys
    static let options: [Option] = [
        .init(key: nil, title: "Default"),
        .init(key: "Dark", title: "Dark")
    ]

    static func currentKey() -> String? {
        UIApplication.shared.alternateIconName
    }

    static func set(key: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        // If the selected key matches current, skip
        if UIApplication.shared.alternateIconName == key { return }
        UIApplication.shared.setAlternateIconName(key) { error in
            if let error { print("Feil ved bytte av ikon: \(error.localizedDescription)") }
        }
    }
}
