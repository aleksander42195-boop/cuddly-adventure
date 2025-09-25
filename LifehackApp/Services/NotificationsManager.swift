import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

final class NotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationsManager()
    private override init() { super.init() }

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "hrv.study."
    private let lastShownKey = "lastShownStudySlugs"
    private let lastScheduleKey = "lastStudyNotificationDate"
    private let dailyCap = 3
    private let quietHours = 22...6 // 22:00 to 06:59

    func configure() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        // Set up notification categories first
        let studyCategory = UNNotificationCategory(
            identifier: "STUDY_NOTIFICATION",
            actions: [
                UNNotificationAction(identifier: "READ_NOW", title: "Read Now", options: .foreground),
                UNNotificationAction(identifier: "BOOKMARK", title: "Bookmark", options: [])
            ],
            intentIdentifiers: []
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "HEALTH_REMINDER",
            actions: [
                UNNotificationAction(identifier: "OPEN_APP", title: "Open App", options: .foreground),
                UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [])
            ],
            intentIdentifiers: []
        )
        
        center.setNotificationCategories([studyCategory, reminderCategory])
        
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus != .authorized else { return }
            self.center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    func scheduleStudySuggestions(basedOn snap: TodaySnapshot) {
        // Respect user preference from SettingsView
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard enabled else { cancelAllStudySuggestions(); return }

        // Compute priority condition
        let lowHRV = snap.hrvSDNNms > 0 && snap.hrvSDNNms < 30
        let highStress = snap.stress >= 0.66
        var count = (lowHRV || highStress) ? 3 : 1

        // Enforce daily cap based on what was already scheduled today
        let scheduledToday = scheduledCountToday()
        count = max(0, min(count, dailyCap - scheduledToday))
        guard count > 0 else { return }

        // Pick studies with simple weighted preference
        let picks = pickStudies(count: count, lowHRV: lowHRV, highStress: highStress)

        // Schedule at next 24h windows (09:00, 15:00, 19:00)
        var times: [(hour: Int, minute: Int)] = [(9,0)]
        if count >= 2 { times.append((15,0)) }
        if count >= 3 { times.append((19,0)) }

        center.getPendingNotificationRequests { pending in
            // Remove old study notifications
            let removeIds = pending.filter { $0.identifier.hasPrefix(self.idPrefix) }.map { $0.identifier }
            if !removeIds.isEmpty { self.center.removePendingNotificationRequests(withIdentifiers: removeIds) }

            for (idx, study) in picks.enumerated() {
                var fireDate = self.nextFireDate(hour: times[idx].hour, minute: times[idx].minute)
                // Skip quiet hours: if computed time falls within quiet hours, push to 07:30 next morning
                let hour = Calendar.current.component(.hour, from: fireDate)
                if self.isQuietHour(hour: hour) {
                    fireDate = self.nextFireDate(hour: 7, minute: 30)
                }
                let content = UNMutableNotificationContent()
                content.title = "HRV study: \(study.title)"
                if let first = study.takeaways.first {
                    content.body = first
                } else {
                    content.body = study.summary
                }
                if let url = study.url { content.userInfo["studyURL"] = url.absoluteString }
                content.userInfo["studySlug"] = study.slug
                content.sound = .default
                content.categoryIdentifier = "STUDY_SUGGESTION"

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(identifier: self.idPrefix + study.slug, content: content, trigger: trigger)
                self.center.add(req, withCompletionHandler: nil)
            }

            // persist schedule day for capping
            UserDefaults.standard.set(Date(), forKey: self.lastScheduleKey)
            // remember shown slugs for anti-repeat
            let existing = Set(self.lastShownSlugs())
            let new = existing.union(picks.map { $0.slug })
            UserDefaults.standard.set(Array(new.prefix(50)), forKey: self.lastShownKey)
        }
    }

    private func nextFireDate(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        let today = cal.date(from: comps) ?? now
        if today > now { return today }
        return cal.date(byAdding: .day, value: 1, to: today) ?? now
    }

    private func pickStudies(count: Int, lowHRV: Bool, highStress: Bool) -> [Study] {
        var pool = HRVStudies.all
        // Anti-repeat: deprioritize recently shown ones
        let recent = Set(lastShownSlugs())
        pool.sort { (a, b) in
            let aRecent = recent.contains(a.slug)
            let bRecent = recent.contains(b.slug)
            if aRecent == bRecent { return a.title < b.title }
            return !aRecent && bRecent
        }
        if lowHRV || highStress {
            // prioritize breathing and training
            let prioritized = pool.filter { [.breathing, .training].contains($0.category) }
            pool = prioritized.isEmpty ? pool : prioritized + pool
        }
        var result: [Study] = []
        var used = Set<Study>()
        for _ in 0..<count {
            if let s = pool.randomElement(), !used.contains(s) {
                result.append(s); used.insert(s)
            }
        }
        if result.isEmpty, let any = HRVStudies.all.randomElement() { result = [any] }
        return result
    }

    private func cancelAllStudySuggestions() {
        center.getPendingNotificationRequests { pending in
            let ids = pending.filter { $0.identifier.hasPrefix(self.idPrefix) }.map { $0.identifier }
            if !ids.isEmpty { self.center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    // Optional: Present while foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Save action handled here
        handleAction(response: response)
        // Open URL on any tap if present
        if let urlString = response.notification.request.content.userInfo["studyURL"] as? String,
           let url = URL(string: urlString) {
            #if canImport(UIKit)
            DispatchQueue.main.async { UIApplication.shared.open(url) }
            #endif
        }
        completionHandler()
    }

    // Actions: Read now or Save for later
    func registerCategories() {
        let read = UNNotificationAction(identifier: "READ_NOW", title: "Read now", options: [.foreground])
        let save = UNNotificationAction(identifier: "SAVE_FOR_LATER", title: "Save", options: [])
        let cat = UNNotificationCategory(identifier: "STUDY_SUGGESTION", actions: [read, save], intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
    }

    func handleAction(response: UNNotificationResponse) {
        let info = response.notification.request.content.userInfo
        if response.actionIdentifier == "SAVE_FOR_LATER" {
            if let slug = info["studySlug"] as? String {
                BookmarkStore.shared.toggle(slug: slug)
            }
        }
    }

    // Helpers
    private func lastShownSlugs() -> [String] {
        UserDefaults.standard.stringArray(forKey: lastShownKey) ?? []
    }

    private func scheduledCountToday() -> Int {
        let cal = Calendar.current
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: lastScheduleKey) as? Date,
           cal.isDate(last, inSameDayAs: now) {
            // Count pending with our prefix
            let sema = DispatchSemaphore(value: 0)
            var count = 0
            center.getPendingNotificationRequests { pending in
                count = pending.filter { $0.identifier.hasPrefix(self.idPrefix) }.count
                sema.signal()
            }
            sema.wait()
            return count
        }
        return 0
    }

    private func isQuietHour(hour: Int) -> Bool {
        if quietHours.contains(hour) { return true }
        // handle wrap-around for 22...6 range
        return hour >= 22 || hour <= 6
    }
}
