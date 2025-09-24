import Foundation

final class BookmarkStore {
    static let shared = BookmarkStore()
    private init() {}

    private let key = "bookmarkedStudySlugs"

    private var defaults: UserDefaults { .standard }

    func allSlugs() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func isBookmarked(slug: String) -> Bool {
        allSlugs().contains(slug)
    }

    func toggle(slug: String) {
        var arr = allSlugs()
        if let idx = arr.firstIndex(of: slug) {
            arr.remove(at: idx)
        } else {
            arr.insert(slug, at: 0)
        }
        defaults.set(arr, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    func allStudies() -> [Study] {
        let set = Set(allSlugs())
        return HRVStudies.all.filter { set.contains($0.slug) }
    }
}
