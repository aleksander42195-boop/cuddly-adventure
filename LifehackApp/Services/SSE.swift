import Foundation

enum SSE {
    static func parseLines(_ data: Data) -> [String] {
        String(data: data, encoding: .utf8)?
            .split(whereSeparator: \.isNewline)
            .map(String.init) ?? []
    }
}
