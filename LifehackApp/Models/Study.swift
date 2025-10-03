import Foundation

struct Study: Identifiable, Hashable, Codable {
    enum Category: String, CaseIterable, Hashable, Codable {
        case training = "Training"
        case breathing = "Breathing/Biofeedback"
        case methodology = "Methodology/Guidelines"
        case general = "General HRV"
    }

    // Stable identity derived from DOI/title via slug; not stored in JSON
    var id: String { slug }
    let title: String
    let authors: String
    let journal: String
    let year: String
    let doi: String?
    let url: URL?
    let summary: String
    let takeaways: [String]
    let category: Category

    // Stable identifier derived from DOI if available, otherwise from title
    var slug: String {
        let base = (doi?.lowercased() ?? title.lowercased())
        let allowed = base.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(allowed))
    }
}
