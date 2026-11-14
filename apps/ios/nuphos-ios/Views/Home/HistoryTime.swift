import Foundation

/// The desktop's `formatHistoryTime`: `now`, `N min`, `N hr(s)`, `N day(s)`,
/// `N mo(s)`, `N yr(s)`. Each number-and-unit pair is its own key so a
/// translation never has to glue an English unit onto a number.
enum HistoryTime {
    static func format(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return String(localized: "now") }
        if minutes < 60 { return String(localized: "\(minutes) min", comment: "Chat list age, minutes") }
        let hours = minutes / 60
        if hours < 24 { return hours == 1 ? String(localized: "\(hours) hr", comment: "Chat list age, one hour") : String(localized: "\(hours) hrs", comment: "Chat list age, hours") }
        let days = hours / 24
        if days < 30 { return days == 1 ? String(localized: "\(days) day", comment: "Chat list age, one day") : String(localized: "\(days) days", comment: "Chat list age, days") }
        let months = days / 30
        if months < 12 { return months == 1 ? String(localized: "\(months) mo", comment: "Chat list age, one month") : String(localized: "\(months) mos", comment: "Chat list age, months") }
        let years = months / 12
        return years == 1 ? String(localized: "\(years) yr", comment: "Chat list age, one year") : String(localized: "\(years) yrs", comment: "Chat list age, years")
    }
}
