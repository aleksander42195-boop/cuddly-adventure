import Foundation

/// Fetches a "Study of the Day" from trusted scientific sources (PubMed, Europe PMC) with daily caching.
/// Falls back to local curated studies if remote fetch fails.
@MainActor
final class DailyStudyService {
    static let shared = DailyStudyService()
    private init() {}

    private let cacheDateKey = "remoteStudyOfTheDayDate"
    private let cacheDataKey = "remoteStudyOfTheDayData"
    private let recentStudySlugsKey = "remoteStudyRecentlySeenSlugs"
    private let recentStudyMemoryLimit = 120

    enum Topic: String, CaseIterable {
        case hrv = "heart rate variability"
        case sleep = "sleep health"
        case stress = "stress physiology"
        case nutrition = "nutrition and diet"
        case yoga = "yoga and mindfulness"
        case training = "exercise training"

        var searchPhrase: String {
            switch self {
            case .hrv:
                return "\"heart rate variability\" AND (training OR recovery OR performance OR autonomic)"
            case .sleep:
                return "\"sleep quality\" AND (intervention OR randomized OR recovery)"
            case .stress:
                return "(\"stress management\" OR \"stress physiology\") AND (biofeedback OR mindfulness OR intervention)"
            case .nutrition:
                return "(nutrition OR diet OR dietary) AND (performance OR recovery OR cardiovascular)"
            case .yoga:
                return "(yoga OR \"yogic breathing\" OR \"mindfulness-based yoga\") AND (stress OR HRV OR wellness)"
            case .training:
                return "(exercise OR training OR workout OR \"physical activity\") AND (HRV OR endocrine OR resilience)"
            }
        }

        var category: Study.Category {
            switch self {
            case .training:
                return .training
            case .yoga:
                return .breathing
            case .hrv, .stress, .sleep, .nutrition:
                return .general
            }
        }

        var alternateTopics: [Topic] {
            Topic.allCases.filter { $0 != self }
        }

        static func defaultForToday(_ date: Date = Date()) -> Topic {
            let rotation: [Topic] = [.hrv, .training, .yoga, .stress, .sleep, .nutrition]
            let index = (Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0) % rotation.count
            return rotation[index]
        }
    }

    /// Returns cached study for today if available. Otherwise fetches remotely and caches.
    func studyOfTheDay(preferred topic: Topic = Topic.defaultForToday()) async -> Study? {
        if let cached = loadCachedIfFresh() { return cached }
        if let fetched = await fetchFromRemote(topic: topic, skippingRecent: true) {
            cache(study: fetched)
            return fetched
        }
        return nil
    }

    /// Forces a refresh from remote sources and caches it (ignores cache freshness)
    func forceRefresh(preferred topic: Topic = Topic.defaultForToday()) async -> Study? {
        if let fetched = await fetchFromRemote(topic: topic, skippingRecent: true) {
            cache(study: fetched)
            return fetched
        }
        if let fallback = await fetchFromRemote(topic: topic, skippingRecent: false) {
            cache(study: fallback)
            return fallback
        }
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
        markStudyAsSeen(slug: study.slug)
    }

    // Expose last cached date for UI
    var lastCachedDate: Date? {
        UserDefaults.standard.object(forKey: cacheDateKey) as? Date
    }

    private func markStudyAsSeen(slug: String) {
        guard !slug.isEmpty else { return }
        let defaults = UserDefaults.standard
        var slugs = defaults.stringArray(forKey: recentStudySlugsKey) ?? []
        slugs.removeAll { $0 == slug }
        slugs.insert(slug, at: 0)
        if slugs.count > recentStudyMemoryLimit {
            slugs = Array(slugs.prefix(recentStudyMemoryLimit))
        }
        defaults.set(slugs, forKey: recentStudySlugsKey)
    }

    private func recentlySeenSlugs() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentStudySlugsKey) ?? []
    }

    private func isRecentlySeen(slug: String) -> Bool {
        recentlySeenSlugs().contains(slug)
    }
}

// MARK: - PubMed Integration (JSONSerialization based, robust to dynamic keys)

private extension DailyStudyService {
    func fetchFromRemote(topic: Topic, skippingRecent: Bool) async -> Study? {
        var orderedTopics: [Topic] = [topic]
        orderedTopics.append(contentsOf: topic.alternateTopics)

        for candidate in orderedTopics {
            if let pubmed = await fetchFromPubMed(topic: candidate, skippingRecent: skippingRecent) {
                return pubmed
            }
            if let europe = await fetchFromEuropePMC(topic: candidate, skippingRecent: skippingRecent) {
                return europe
            }
        }
        return nil
    }

    func fetchFromPubMed(topic: Topic, skippingRecent: Bool) async -> Study? {
        do {
            guard let ids = try await pubmedRecentIds(for: topic), !ids.isEmpty else { return nil }
            for id in ids {
                guard let summary = try await pubmedSummary(for: id) else { continue }
                let abstract = (try? await pubmedAbstract(for: id)) ?? nil
                let study = map(summary: summary, id: id, topic: topic, abstract: abstract)
                if skippingRecent && isRecentlySeen(slug: study.slug) { continue }
                return study
            }
        } catch {
            print("[DailyStudyService] PubMed fetch error: \(error)")
        }
        return nil
    }

    func pubmedRecentIds(for topic: Topic) async throws -> [String]? {
        let query = "\(topic.searchPhrase) AND english[lang]"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? topic.rawValue
        let retmax = 12
        let retstart = Int.random(in: 0...20)
        let urlStr = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&sort=pub+date&retmax=\(retmax)&retstart=\(retstart)&term=\(encoded)"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let esearch = root?["esearchresult"] as? [String: Any]
        let ids = esearch?["idlist"] as? [String]
        return ids
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

    func fetchFromEuropePMC(topic: Topic, skippingRecent: Bool) async -> Study? {
        do {
            guard let results = try await europePMCResults(for: topic) else { return nil }
            for entry in results {
                guard let study = map(europePMCDictionary: entry, topic: topic) else { continue }
                if skippingRecent && isRecentlySeen(slug: study.slug) { continue }
                return study
            }
        } catch {
            print("[DailyStudyService] EuropePMC fetch error: \(error)")
        }
        return nil
    }

    func europePMCResults(for topic: Topic) async throws -> [[String: Any]]? {
        let query = "\(topic.searchPhrase) AND LANGUAGE:eng AND (PUB_TYPE:journal)"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? topic.rawValue
        let urlStr = "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=\(encoded)&format=json&pageSize=20&sort_date=y"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let resultList = root?["resultList"] as? [String: Any]
        return resultList?["result"] as? [[String: Any]]
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
            category: topic.category
        )
    }

    func map(europePMCDictionary dict: [String: Any], topic: Topic) -> Study? {
        guard let rawTitle = dict["title"] as? String, !rawTitle.isEmpty else { return nil }
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let authors = (dict["authorString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let journal = (dict["journalTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Europe PMC"
        let year = (dict["pubYear"] as? String) ?? ""
        let doi = (dict["doi"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = (dict["source"] as? String)?.lowercased() ?? ""

        var idValue: String = ""
        if let idString = dict["id"] as? String {
            idValue = idString
        } else if let idNumber = dict["id"] as? NSNumber {
            idValue = idNumber.stringValue
        }

        let abstractText = (dict["abstractText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let takeaways = Self.takeaways(from: abstractText) ?? ["European peer-reviewed source", "English language publication", "Tap Open to read full details"]

        let urlString: String
        if let doi, !doi.isEmpty {
            urlString = "https://doi.org/\(doi)"
        } else if !source.isEmpty, !idValue.isEmpty {
            urlString = "https://europepmc.org/article/\(source.uppercased())/\(idValue)"
        } else {
            urlString = "https://www.ebi.ac.uk/europepmc/"
        }

        let url = URL(string: urlString)

        return Study(
            title: title,
            authors: authors,
            journal: journal,
            year: year,
            doi: doi,
            url: url,
            summary: abstractText ?? "English-language research surfaced via Europe PMC for \(topic.rawValue).",
            takeaways: takeaways,
            category: topic.category
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
