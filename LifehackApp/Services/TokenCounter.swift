import Foundation

enum TokenCounter {
    static func estimateTokens(_ s: String) -> Int {
        max(1, s.count / 4)
    }
}
