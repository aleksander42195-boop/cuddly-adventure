import Foundation

/// Fetches a "Study of the Day" from trusted scientific sources (PubMed) with daily caching.
/// Falls back to local curated studies if remote fetch fails.
@MainActor
final class DailyStudyService {
    static let shared = DailyStudyService()
    private init() {}

    private let cacheDateKey = "remoteStudyOfTheDayDate"
    private let cacheDataKey = "remoteStudyOfTheDayData"

    enum Topic: String {
        case hrv = "heart rate variability"
        case sleep = "sleep health"
        case stress = "stress physiology"
        case nutrition = "nutrition health"
    }

    /// Returns cached study for today if available. Otherwise fetches from PubMed and caches.
    func studyOfTheDay(preferred topic: Topic = .hrv) async -> Study? {
        if let cached = loadCachedIfFresh() { return cached }
        if let fetched = await fetchFromPubMed(topic: topic) { cache(study: fetched); return fetched }
        return nil
    }

    /// Forces a refresh from PubMed and caches it (ignores cache freshness)
    func forceRefresh(preferred topic: Topic = .hrv) async -> Study? {
        if let fetched = await fetchFromPubMed(topic: topic) { cache(study: fetched); return fetched }
        return nil
    }

    private func loadCachedIfFresh() -> Study? {
        let defaults = UserDefaults.standard
        guard let day = defaults.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDateInToday(day),
              let data = defaults.data(forKey: cacheDataKey) else { return nil }
        return try? JSONDecoder().decode(Study.self, from: data)
    }

    private func cache(study: Study) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(study) {
            defaults.set(Date(), forKey: cacheDateKey)
            defaults.set(data, forKey: cacheDataKey)
        }
    }

    // Expose last cached date for UI
    var lastCachedDate: Date? {
        UserDefaults.standard.object(forKey: cacheDateKey) as? Date
    }
}

// MARK: - PubMed Integration (JSONSerialization based, robust to dynamic keys)

private extension DailyStudyService {
    func fetchFromPubMed(topic: Topic) async -> Study? {
        do {
            guard let id = try await pubmedLatestId(for: topic) else { return nil }
            guard let summary = try await pubmedSummary(for: id) else { return nil }
            let abstract = try await pubmedAbstract(for: id)
            return map(summary: summary, id: id, topic: topic, abstract: abstract)
        } catch {
            print("[DailyStudyService] PubMed fetch error: \(error)")
            return nil
        }
    }

    func pubmedLatestId(for topic: Topic) async throws -> String? {
        let q = topic.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "hrv"
        let urlStr = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&sort=pub+date&retmax=1&term=\(q)"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let esearch = root?["esearchresult"] as? [String: Any]
        let ids = esearch?["idlist"] as? [String]
        return ids?.first
    }

    func pubmedSummary(for id: String) async throws -> [String: Any]? {
        let urlStr = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=json&id=\(id)"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = root?["result"] as? [String: Any]
        return result?[id] as? [String: Any]
    }

    // Fetch abstract via efetch (XML), parse <AbstractText>
    func pubmedAbstract(for id: String) async throws -> String? {
        let urlStr = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=\(id)&retmode=xml"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = PubMedXMLParser()
        return parser.parseAbstract(data: data)
    }

    func map(summary: [String: Any], id: String, topic: Topic, abstract: String?) -> Study {
        let title = (summary["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Latest PubMed Study"
        let journ = (summary["fulljournalname"] as? String) ?? "PubMed"
        let pubdate = (summary["pubdate"] as? String) ?? ""
        let year = String(pubdate.prefix(4))
        let authorsArr = (summary["authors"] as? [[String: Any]]) ?? []
        let authorsNames = authorsArr.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
        let authors = authorsNames.isEmpty ? (summary["sortfirstauthor"] as? String ?? "Unknown") : authorsNames.joined(separator: ", ")
        let articleids = (summary["articleids"] as? [[String: Any]]) ?? []
        let doi = articleids.first(where: { ( ($0["idtype"] as? String)?.lowercased() == "doi" ) })?["value"] as? String
        let url = URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(id)/")

        let abstractText = abstract?.trimmingCharacters(in: .whitespacesAndNewlines)
        let takeaways = Self.takeaways(from: abstractText) ?? ["Peer-reviewed source (PubMed)", "Refreshed daily", "Tap Open to read full details"]

        return Study(
            title: title,
            authors: authors,
            journal: journ,
            year: year,
            doi: doi,
            url: url,
            summary: abstractText ?? "Sourced daily from PubMed based on \(topic.rawValue).",
            takeaways: takeaways,
            category: .general
        )
    }

    static func takeaways(from abstract: String?) -> [String]? {
        guard let text = abstract, !text.isEmpty else { return nil }
        // Split by sentence and pick up to 3 informative lines
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.isEmpty { return nil }
        let keywords = ["increase", "decrease", "associated", "improved", "reduced", "risk", "conclusion", "objective", "results"]
        let scored = sentences.map { s -> (String, Int) in
            let score = keywords.reduce(0) { $0 + (s.lowercased().contains($1) ? 1 : 0) }
            return (s, score)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
        return top.isEmpty ? Array(sentences.prefix(3)) : top
    }
}

// MARK: - Simple XML Parser for PubMed Abstract

private final class PubMedXMLParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var buffer = ""
    private var isInAbstract = false

    func parseAbstract(data: Data) -> String? {
        buffer = ""
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return buffer.isEmpty ? nil : buffer
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "Abstract" || elementName == "AbstractText" { isInAbstract = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInAbstract else { return }
        buffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Abstract" || elementName == "AbstractText" { isInAbstract = false }
    }
}
