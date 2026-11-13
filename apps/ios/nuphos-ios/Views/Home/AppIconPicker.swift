#if os(iOS)
import SwiftUI
import UIKit

/// The Home Screen icon. "Default" is the primary AppIcon (the Yu Bot mark, AppIcon.icon);
/// every other one, rendered by apps/desktop/scripts/render-app-icons.mjs, is the alternate
/// icon set `AppIcon-<id>`.
struct AppIconPicker: View {
    private static let characters = ["Napoleon", "Pearl Earring", "Van Gogh", "The Scream", "Son of Man"]
    private static let layouts = ["Classic", "Bleed", "Peek"]
    static let icons: [(id: String, name: String)] = [("Default", "Yu Bot")]
        + zip("BCDEF", characters).flatMap { letter, character in
            layouts.enumerated().map { ("\(letter)\($0.offset + 1)", "\(character), \($0.element)") }
        }

    static var current: String {
        #if NUPHOS_SHARE_EXTENSION
        return "Default"
        #else
        return UIApplication.shared.alternateIconName.map { String($0.dropFirst("AppIcon-".count)) } ?? "Default"
        #endif
    }

    @State private var selected = Self.current

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 16)], spacing: 16) {
                ForEach(Self.icons, id: \.id) { icon in
                    Button {
                        selected = icon.id
                        #if !NUPHOS_SHARE_EXTENSION
                        UIApplication.shared.setAlternateIconName(icon.id == "Default" ? nil : "AppIcon-\(icon.id)") { error in
                            if error != nil { selected = Self.current }
                        }
                        #endif
                    } label: {
                        Image("AppIconPreview-\(icon.id)")
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(3)
                            .overlay {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(selected == icon.id ? Color.accentColor : .clear, lineWidth: 2.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.name)
                    .accessibilityAddTraits(selected == icon.id ? .isSelected : [])
                }
            }
            .padding()
        }
        .background(Theme.canvas)
        .navigationTitle("App icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
