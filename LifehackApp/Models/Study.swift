import Foundation

struct Study: Identifiable, Hashable {
    enum Category: String, CaseIterable, Hashable {
        case training = "Training"
        case breathing = "Breathing/Biofeedback"
        case methodology = "Methodology/Guidelines"
        case general = "General HRV"
    }

    let id = UUID()
    let title: String
    let authors: String
    let journal: String
    let year: String
    let doi: String?
    let url: URL?
    let summary: String
    let takeaways: [String]
    let category: Category
}
