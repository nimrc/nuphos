import SwiftUI

/// The fixed strip above the Bots list: every pinned Bot in pin order, as a
/// 44 pt face in a 49 pt slot. The row does not scroll with the list and it is
/// not built at all when nothing is pinned.
struct PinnedBotsRow: View {
    let bots: [PinnedBot]
    /// The Bot whose conversation is open, so its slot carries the brand ring.
    let currentBotId: String?
    let onOpen: (PinnedBot) -> Void
    let onUnpin: (PinnedBot) -> Void
    let onProfile: (PinnedBot) -> Void

    /// The spec's measurements, in one place.
    enum Metrics {
        static let height = PinnedBotsLayout.height
        static let avatar = PinnedBotsLayout.avatar
        /// The current avatar's ring makes a 49 pt footprint; every slot keeps
        /// it, so the ring appearing never moves its neighbours.
        static let slot = PinnedBotsLayout.slot
        static let spacing = PinnedBotsLayout.spacing
        static let inset = PinnedBotsLayout.inset
        static let ring = PinnedBotsLayout.ring
        static let fade = PinnedBotsLayout.fade
        static let hairline = PinnedBotsLayout.hairline
        static let navigationBarClearance = PinnedBotsLayout.navigationBarClearance
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacing) {
                    ForEach(bots) { bot in
                        Button {
                            // The open one has nowhere to go.
                            guard bot.id != currentBotId else { return }
                            onOpen(bot)
                        } label: {
                            PinnedBotAvatar(bot: bot, current: bot.id == currentBotId)
                        }
                        .buttonStyle(PinnedBotPressStyle())
                        .contextMenu {
                            Button {
                                onUnpin(bot)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(Theme.brand)

                            Button {
                                onProfile(bot)
                            } label: {
                                Label("Profile", systemImage: "person.text.rectangle")
                            }
                        }
                        .accessibilityLabel(Text(verbatim: bot.title))
                        .accessibilityHint(Text("Open this Bot"))
                        // The current Bot speaks its state in the value, as the
                        // page picker does, so VoiceOver never says it twice.
                        .accessibilityValue(
                            bot.id == currentBotId ? Text("\(bot.title), selected") : Text(verbatim: "")
                        )
                        .accessibilityRemoveTraits(.isSelected)
                    }
                    // A second layout child keeps the row's accessibility
                    // container alive when exactly one Bot is pinned; with a
                    // single child XCTest/VoiceOver pruned the count label.
                    // It only exists at one, so many pins keep their tree.
                    if bots.count == 1 {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: "\u{200B}"))
                    }
                }
                .padding(.horizontal, Metrics.inset)
                .frame(height: Metrics.height, alignment: .leading)
                // The avatars' HStack is the labelled container at one and
                // many pins, so the count is spoken before the faces.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Pinned Bots, \(bots.count)"))
                .accessibilityIdentifier("pinned-bots-row")
            }
            .frame(height: Metrics.height)
            // A fixed-width fade to the page canvas. A mask here collapsed
            // its flexible rectangle and hid the row on iPad and iPhone.
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [Theme.canvas.opacity(0), Theme.canvas],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: Metrics.fade)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: Metrics.hairline)
        }
    }
}

/// A pinned Bot's face, or its name's initial when it has none.
struct PinnedBotAvatar: View {
    let bot: PinnedBot
    let current: Bool
    @AppStorage(BotAvatars.enabledKey, store: BotAvatars.defaults) private var avatarsEnabled = true

    private var face: String? {
        BotFaces.shared.face(for: bot.id) ?? bot.avatar
    }

    var body: some View {
        ZStack {
            Group {
                if avatarsEnabled, let face {
                    Image(BotAvatars.asset(named: face) ?? BotAvatars.asset(for: bot.id))
                        .resizable()
                        .scaledToFit()
                        .overlay(alignment: .bottomTrailing) {
                            AgentRuntimeBadge(runtime: bot.runtime, size: 12)
                        }
                } else {
                    Circle()
                        .fill(Theme.surface)
                    Text(verbatim: PinnedBot.initial(of: bot.title))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.heading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(4)
                }
            }
            .frame(width: PinnedBotsRow.Metrics.avatar, height: PinnedBotsRow.Metrics.avatar)
            .clipShape(Circle())

            if current {
                Circle()
                    .strokeBorder(Theme.brand, lineWidth: PinnedBotsRow.Metrics.ring)
            }
        }
        .frame(width: PinnedBotsRow.Metrics.slot, height: PinnedBotsRow.Metrics.slot)
        .contentShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Pressing a pinned face scales it, without a background highlight.
private struct PinnedBotPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
