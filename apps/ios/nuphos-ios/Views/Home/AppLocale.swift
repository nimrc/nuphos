import Foundation

/// The locale that every date and time in the app formats with.
///
/// `Locale.current` follows the *device's* language. An app can run in a
/// different language — Settings › Yu Bot › Language, or a launch override —
/// and then the interface is Chinese while `Locale.current` still formats
/// "Nov 13, 2026 at 12:15 PM". `Bundle.main.preferredLocalizations` is the
/// catalogue the app actually loaded, so its language is the one the visible
/// copy is in. When it already matches the device, the device locale wins so
/// the region (hour cycle, day order) is kept.
enum AppLocale {
    /// Re-read on every call: changing language must not leave a formatter
    /// holding the locale it was created with.
    static var current: Locale {
        current(preferred: Bundle.main.preferredLocalizations, system: .autoupdatingCurrent)
    }

    /// The app's locale for the catalogue it loaded. When the app's language
    /// and the device's agree, the device locale wins so its region (hour
    /// cycle, day order) is kept; otherwise the app's language wins.
    static func current(preferred: [String], system: Locale) -> Locale {
        guard let identifier = preferred.first, identifier != "Base",
              let language = Locale(identifier: identifier).language.languageCode,
              language != system.language.languageCode
        else { return system }
        return Locale(identifier: identifier)
    }

    /// A message's clock time, in the app's locale (24- or 12-hour as it does).
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(current))
    }

    /// An absolute date and time, in the app's locale.
    static func dateTime(_ date: Date, date dateStyle: Date.FormatStyle.DateStyle = .abbreviated,
                         time timeStyle: Date.FormatStyle.TimeStyle = .shortened) -> String {
        date.formatted(Date.FormatStyle(date: dateStyle, time: timeStyle).locale(current))
    }
}
