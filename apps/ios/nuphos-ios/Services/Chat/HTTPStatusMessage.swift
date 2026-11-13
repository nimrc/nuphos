import Foundation

/// What to say when an error response carries no message of its own. The
/// server's own sentence is English and not part of the app's catalog, so a
/// known status gets an app-side line instead.
enum HTTPStatusMessage {
    static func text(_ status: Int) -> String {
        switch status {
        case 400: String(localized: "That request wasn't understood. Try again.")
        case 401, 403: String(localized: "You don't have permission to do that.")
        case 404: String(localized: "That conversation is no longer available.")
        case 408, 504: String(localized: "Yu AI took too long to answer. Try again.")
        case 429: String(localized: "Too many requests. Try again in a moment.")
        case 500...599: String(localized: "Yu AI is having trouble right now. Try again in a moment.")
        default: String(localized: "Something went wrong. Try again.")
        }
    }
}
