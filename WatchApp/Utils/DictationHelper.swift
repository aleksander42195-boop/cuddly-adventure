import Foundation
import WatchKit

enum DictationHelper {
    /// Viser systemets diktering/skrible/emoji-input på watchOS.
    static func present(
        suggestions: [String] = [],
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.main.async {
            guard let vc = WKExtension.shared().visibleInterfaceController else {
                completion(nil)
                return
            }
            vc.presentTextInputController(
                withSuggestions: suggestions,
                allowedInputMode: .plain
            ) { result in
                // result er [Any]? hvor elementer vanligvis er String
                let text = (result?.first as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(text?.isEmpty == false ? text : nil)
            }
        }
    }
}
