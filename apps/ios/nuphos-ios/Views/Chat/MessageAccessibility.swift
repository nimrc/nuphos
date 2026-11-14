import SwiftUI

/// One spoken line per message: who said it, when, and every word.
/// The whole bubble is a single element, so VoiceOver reads a message in
/// one pass instead of stopping at an empty group.
enum MessageAccessibility {
    static func time(_ date: Date?) -> String {
        guard let date else { return "" }
        return AppLocale.time(date)
    }

    static func label(mine: Bool, date: Date?, text: String) -> Text {
        let time = time(date)
        if mine {
            return time.isEmpty ? Text("You: \(text)") : Text("You, \(time): \(text)")
        }
        return time.isEmpty ? Text("Them: \(text)") : Text("Them, \(time): \(text)")
    }
}

extension ComposerAttachment {
    /// What VoiceOver says for a photo or file: kind, name and size.
    var accessibilityDescription: String {
        switch kind {
        case .image(let data):
            return String(localized: "Image, \(name), \(data.count.formatted(.byteCount(style: .file)))")
        case .file(let url):
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            guard let bytes else { return String(localized: "File, \(name)") }
            return String(localized: "File, \(name), \(bytes.formatted(.byteCount(style: .file)))")
        }
    }
}

extension TransferDownloadGroup.File {
    /// Kind and name; the transfer store does not report a size.
    var accessibilityDescription: String {
        if isImage { return String(localized: "Image, \(fileName)") }
        if isVideo { return String(localized: "Video, \(fileName)") }
        return String(localized: "File, \(fileName)")
    }
}
