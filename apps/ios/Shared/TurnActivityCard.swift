import SwiftUI

/// The Live Activity's Lock Screen card: every running conversation, the
/// newest first. A row opens its conversation; the widget links the rest of
/// the card to the conversation list.
struct TurnCard: View {
    let card: TurnActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                TurnCardMark(size: 16)
                Text(String(localized: "Yu Bot", table: "TurnActivity")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                TurnCardStatus(card: card).font(.subheadline.weight(.medium))
            }
            TurnCardRows(card: card)
        }
        .foregroundStyle(.white)
        .padding(16)
        // The card is always black, so its grays are the dark ones.
        .environment(\.colorScheme, .dark)
    }
}

struct TurnCardRows: View {
    let card: TurnActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(card.sessions) { session in
                Link(destination: SessionLink.url(teamId: session.teamId, sessionId: session.id) ?? SessionLink.conversations) {
                    HStack(spacing: 8) {
                        TurnPhaseIcon(phase: session.phase)
                        Text(session.title.isEmpty ? String(localized: "Untitled", table: "TurnActivity") : session.title).font(.headline).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(session.phase.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(session.phase.tint)
                    }
                }
            }
            if card.more > 0 {
                Text(String(localized: "+\(card.more) more", table: "TurnActivity")).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct TurnCardMark: View {
    let size: CGFloat

    var body: some View {
        // The Yu Bot avatar (Vermeer); NuphosMark holds a copy so the widget extension has it too.
        Image("NuphosMark").resizable().renderingMode(.original).scaledToFit().frame(width: size, height: size)
            .background(Color(red: 243 / 255, green: 238 / 255, blue: 228 / 255)).clipShape(Circle())
    }
}

/// "2 running", or a check once every row finished.
struct TurnCardStatus: View {
    let card: TurnActivityAttributes.ContentState

    var body: some View {
        if card.active > 0 {
            Text(String(localized: "\(card.active) running", table: "TurnActivity")).foregroundStyle(.secondary)
        } else if card.finished {
            TurnPhaseIcon(phase: .done)
        }
    }
}

/// The running count alone, for the Dynamic Island.
struct TurnCardCount: View {
    let card: TurnActivityAttributes.ContentState

    var body: some View {
        if card.active > 0 {
            Text("\(card.active)").font(.caption.monospacedDigit().weight(.semibold))
        } else if card.finished {
            TurnPhaseIcon(phase: .done)
        }
    }
}

struct TurnPhaseIcon: View {
    let phase: TurnActivityAttributes.Phase

    var body: some View {
        Image(systemName: phase.symbol).foregroundStyle(phase.tint)
    }
}

extension TurnActivityAttributes.Phase {
    var title: String {
        switch self {
        case .running: String(localized: "Running", table: "TurnActivity")
        case .approval: String(localized: "Needs approval", table: "TurnActivity")
        case .done: String(localized: "Done", table: "TurnActivity")
        case .stopped: String(localized: "Stopped", table: "TurnActivity")
        case .unavailable: String(localized: "Unavailable", table: "TurnActivity")
        }
    }

    var symbol: String {
        switch self {
        case .running: "circle.dotted"
        case .approval: "hand.raised.fill"
        case .done: "checkmark.circle.fill"
        case .stopped: "stop.circle.fill"
        case .unavailable: "wifi.slash"
        }
    }

    var tint: Color {
        switch self {
        case .running: .secondary
        case .approval: .orange
        case .done: .green
        case .stopped: .secondary
        case .unavailable: .secondary
        }
    }
}
