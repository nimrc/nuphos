import Foundation

/// The date copy must follow the language the app actually loaded, not only
/// the device's. A per-app language can make the interface Chinese while
/// `Locale.current` is still English.
enum AppLocaleTests {
    static func run() {
        let english = Locale(identifier: "en_US")
        let chinese = Locale(identifier: "zh_CN")

        let appChinese = AppLocale.current(preferred: ["zh-Hans", "en"], system: english)
        precondition(appChinese.language.languageCode == "zh", "the app's Chinese wins over an English device")
        precondition(appChinese.language.script?.identifier == "Hans")

        let appEnglish = AppLocale.current(preferred: ["en"], system: chinese)
        precondition(appEnglish.language.languageCode == "en", "the app's English wins over a Chinese device")

        // Same language: keep the device locale, including its region settings.
        let same = AppLocale.current(preferred: ["en-GB"], system: Locale(identifier: "en_GB"))
        precondition(same.region == Locale.Region("GB"), "a matching device locale keeps its region")

        // A catalogue with no usable language falls back to the device.
        let fallback = AppLocale.current(preferred: ["Base"], system: english)
        precondition(fallback == english)

        let date = Date(timeIntervalSince1970: 1_794_572_100) // 2026-11-13 12:15 UTC
        let zh = date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(appChinese))
        precondition(zh.contains("2026年11月13日"), "Chinese date order, got \(zh)")
        precondition(zh.contains("12:15"), "Chinese 24-hour time, got \(zh)")
        precondition(!zh.contains("AM") && !zh.contains("PM"), "Chinese time is 24-hour, got \(zh)")

        let en = date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(appEnglish))
        precondition(en.contains("Nov 13, 2026"), "English date order, got \(en)")
        precondition(en.contains("12:15"), "English time, got \(en)")
    }
}
