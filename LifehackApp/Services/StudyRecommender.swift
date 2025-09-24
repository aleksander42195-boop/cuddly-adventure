import Foundation

struct StudyRecommender {
    static let shared = StudyRecommender()
    private init() {}

    private let daySlugKey = "studyOfTheDaySlug"
    private let dayDateKey = "studyOfTheDayDate"

    func loadTodaysStudy() -> Study? {
        let defaults = UserDefaults.standard
        guard let day = defaults.object(forKey: dayDateKey) as? Date,
              Calendar.current.isDateInToday(day),
              let slug = defaults.string(forKey: daySlugKey) else { return nil }
        return HRVStudies.all.first { $0.slug == slug }
    }

    func selectStudy(for snap: TodaySnapshot) -> Study {
        // If already selected today, return it
        if let s = loadTodaysStudy() { return s }

        let lowHRV = snap.hrvSDNNms > 0 && snap.hrvSDNNms < 30
        let highStress = snap.stress >= 0.66

        // Build pool with anti-repeat and priority
        var pool = HRVStudies.all
        let recent = Set(UserDefaults.standard.stringArray(forKey: "lastShownStudySlugs") ?? [])
        pool.sort { (a, b) in
            let aRecent = recent.contains(a.slug)
            let bRecent = recent.contains(b.slug)
            if aRecent == bRecent { return a.title < b.title }
            return !aRecent && bRecent
        }
        if lowHRV || highStress {
            let prioritized = pool.filter { [.breathing, .training].contains($0.category) }
            pool = prioritized.isEmpty ? pool : prioritized + pool
        }
        let chosen = pool.randomElement() ?? HRVStudies.all[0]

        // persist
        let defaults = UserDefaults.standard
        defaults.set(chosen.slug, forKey: daySlugKey)
        defaults.set(Date(), forKey: dayDateKey)

        // update last-shown memory as well
        var mem = Array(Set((defaults.stringArray(forKey: "lastShownStudySlugs") ?? []) + [chosen.slug]))
        if mem.count > 50 { mem = Array(mem.prefix(50)) }
        defaults.set(mem, forKey: "lastShownStudySlugs")

        return chosen
    }
}
