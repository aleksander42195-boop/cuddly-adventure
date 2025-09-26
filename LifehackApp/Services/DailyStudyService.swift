import Foundation

/// Fetches a "Study of the Day" from trusted scientific sources (PubMed) with daily caching.
/// Falls back to local curated studies if remote fetch fails.
@MainActor
final class DailyStudyService {
    static let shared = DailyStudyService()
    private init() {}

    private let cacheDateKey = "remoteStudyOfTheDayDate"
    private let cacheDataKey = "remoteStudyOfTheDayData"

    enum Topic: String { case hrv = "heart rate variability" }

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
}

// MARK: - PubMed Integration (JSONSerialization based, robust to dynamic keys)

private extension DailyStudyService {
    func fetchFromPubMed(topic: Topic) async -> Study? {
        do {
            guard let id = try await pubmedLatestId(for: topic) else { return nil }
            guard let summary = try await pubmedSummary(for: id) else { return nil }
            return map(summary: summary, id: id, topic: topic)
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

    func map(summary: [String: Any], id: String, topic: Topic) -> Study {
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

        return Study(
            title: title,
            authors: authors,
            journal: journ,
            year: year,
            doi: doi,
            url: url,
            summary: "Sourced daily from PubMed based on \(topic.rawValue).",
            takeaways: ["Peer-reviewed source (PubMed)", "Refreshed daily", "Tap Open to read full details"],
            category: .general
        )
    }
}
