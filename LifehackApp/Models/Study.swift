import Foundation

struct Study: Identifiable, Hashable, Codable {
    enum Category: String, CaseIterable, Hashable, Codable {
        case training = "Training"
        case breathing = "Breathing/Biofeedback"
        case methodology = "Methodology/Guidelines"
        case general = "General HRV"
    }

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
    var id: String {
        let base = (doi?.lowercased() ?? title.lowercased())
        let allowed = base.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(allowed))
    }
    
    // Stable identifier derived from DOI if available, otherwise from title  
    var slug: String {
        return id
    }
}

extension Study {
    var sourceDescription: String {
        if let host = url?.host?.lowercased() {
            if host.contains("pubmed") { return "PubMed" }
            if host.contains("europepmc") || host.contains("ebi.ac.uk") { return "Europe PMC" }
            if host.contains("frontiers") { return "Frontiers" }
            if host.contains("mdpi") { return "MDPI Journals" }
        }
        if !journal.isEmpty { return journal }
        if let doi, !doi.isEmpty { return "DOI \(doi)" }
        return "Peer-reviewed research"
    }

    var sourceBadgeLabel: String {
        let descriptor = sourceDescription
        let lower = descriptor.lowercased()
        if lower.contains("pubmed") { return "PubMed Verified" }
        if lower.contains("europe pmc") { return "Europe PMC Verified" }
        if lower.contains("frontiers") { return "Frontiers Journal" }
        if lower.contains("mdpi") { return "MDPI Journal" }
        if lower.contains("journal") { return "Journal Verified" }
        return "Peer-reviewed"
    }
}
