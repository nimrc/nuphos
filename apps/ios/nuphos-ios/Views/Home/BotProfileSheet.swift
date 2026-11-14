import SwiftUI

/// Which Bot's profile is open, from a list row or a chat header.
struct BotProfileTarget: Identifiable, Hashable {
    let botId: String
    let teamId: String
    /// The name it is shown with until its profile is read.
    let title: String
    var id: String { botId }
}

/// A Bot's profile: its face, name and personality (standing instructions).
/// The owner edits them and saves once; anyone else in the chat reads them.
struct BotProfileSheet: View {
    let target: BotProfileTarget
    @Environment(AgentStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var saved: BotProfile?
    @State private var loadError: String?
    @State private var name = ""
    @State private var face = ""
    @State private var instructions = ""
    @State private var saving = false
    @State private var failure: String?
    @State private var showTriggers = false
    @State private var leader = false
    @State private var changingLeader = false
    /// What this Bot handed out or was given that is not finished.
    @State private var handoffs: [Handoff] = []

    private let faces = BotAvatars.files.map { $0.replacingOccurrences(of: ".svg", with: "") }
    private var editable: Bool { saved?.editable == true }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedInstructions: String { instructions.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var faceImage: String {
        BotAvatars.asset(named: face) ?? BotAvatars.asset(for: target.botId)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(faceImage).resizable().scaledToFit()
                            .frame(width: 96, height: 96)
                            .accessibilityHidden(true)
                        Text(trimmedName.isEmpty ? target.title : trimmedName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.heading)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if saved == nil {
                    Section {
                        if let loadError {
                            Text(loadError).foregroundStyle(.red)
                            Button("Try again") { Task { await load() } }
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    if editable {
                        Section("Name") {
                            TextField("Name", text: $name)
                                .submitLabel(.done)
                                .accessibilityIdentifier("bot-profile.name")
                        }
                        .listRowBackground(Theme.surface)

                        Section("Avatar") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(faces, id: \.self) { option in
                                    Button { face = option } label: {
                                        Image(BotAvatars.asset(named: option) ?? "").resizable().scaledToFit()
                                            .padding(3)
                                            .overlay(Circle().stroke(option == face ? Theme.heading : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(option)
                                    .accessibilityAddTraits(option == face ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    Section {
                        if editable {
                            TextField("Who this Bot is, how it talks and what it takes care of.", text: $instructions, axis: .vertical)
                                .lineLimit(6...20)
                                .accessibilityIdentifier("bot-profile.personality")
                        } else {
                            Text(instructions.isEmpty ? "No personality yet." : instructions)
                                .foregroundStyle(instructions.isEmpty ? Theme.muted : Theme.heading)
                                .textSelection(.enabled)
                        }
                    } header: {
                        Text("Personality")
                    } footer: {
                        if editable {
                            Text("The Bot follows this in every chat. It also updates it itself when you tell it who to be.")
                        }
                    }
                    .listRowBackground(Theme.surface)

                    if editable {
                        Section {
                            Toggle(isOn: Binding(get: { leader }, set: { setLeader($0) })) {
                                Label("Leader", systemImage: "star")
                            }
                            .disabled(changingLeader)
                            .accessibilityIdentifier("bot-profile.leader")
                        } footer: {
                            Text("The Leader takes on your requests, hands parts to your other Bots, manages them and brings back one answer. One Bot leads at a time.")
                        }
                        .listRowBackground(Theme.surface)
                    } else if leader {
                        Section {
                            Label("Leader", systemImage: "star.fill")
                        } footer: {
                            Text("This Bot hands work to its owner's other Bots and manages them.")
                        }
                        .listRowBackground(Theme.surface)
                    }

                    if editable, !handoffs.isEmpty {
                        Section("Handoffs") {
                            ForEach(handoffs) { handoff in HandoffRow(handoff: handoff, botId: target.botId) }
                        }
                        .listRowBackground(Theme.surface)
                    }

                    Section {
                        Button { showTriggers = true } label: {
                            Label("Triggers", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(editable ? "Edit profile" : "Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(editable ? "Cancel" : "Done") { dismiss() }.disabled(saving)
                }
                if editable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saving ? "Saving…" : "Save") { save() }
                            .disabled(saving || trimmedName.isEmpty || trimmedName.count > 120 || trimmedInstructions.count > 8000)
                    }
                }
            }
            .sheet(isPresented: $showTriggers) {
                ConversationTriggers(teamId: target.teamId, sessionId: target.botId, token: store.token)
                    .presentationDetents([.large])
            }
            .alert("Couldn't save profile", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .task {
                name = target.title
                face = BotFaces.shared.face(for: target.botId) ?? ""
                await load()
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(saving)
    }

    private func load() async {
        loadError = nil
        do {
            let profile = try await NuphosAPI.botProfile(token: store.token, teamId: target.teamId, sessionId: target.botId)
            saved = profile
            name = profile.title
            if let avatar = profile.avatar { face = avatar }
            instructions = profile.instructions
            leader = profile.leader
            if profile.editable { await loadHandoffs() }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadHandoffs() async {
        struct Envelope: Decodable { let handoffs: [Handoff] }
        let envelope: Envelope? = try? await WorkspaceAPI.request(
            "agent/conversations/\(target.botId)/handoffs",
            query: [URLQueryItem(name: "teamId", value: target.teamId)], token: store.token)
        handoffs = envelope?.handoffs ?? []
    }

    /// Applies at once, apart from Save: picking a Leader also takes the role from any other Bot.
    private func setLeader(_ on: Bool) {
        guard !changingLeader else { return }
        leader = on
        changingLeader = true
        Task {
            defer { changingLeader = false }
            do {
                try await store.setBotLeader(on, botId: target.botId, teamId: target.teamId)
            } catch {
                leader = !on
                failure = error.localizedDescription
            }
        }
    }

    /// Sends only what changed, so a face this build doesn't ship is never overwritten unasked.
    private func save() {
        guard let saved else { return }
        let changedName = trimmedName == saved.title ? nil : trimmedName
        let changedFace = face == saved.avatar || face.isEmpty ? nil : face
        let changedInstructions = trimmedInstructions == saved.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            ? nil : trimmedInstructions
        guard changedName != nil || changedFace != nil || changedInstructions != nil else {
            dismiss()
            return
        }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await store.saveBotProfile(
                    botId: target.botId, teamId: target.teamId,
                    name: changedName, avatar: changedFace, instructions: changedInstructions
                )
                dismiss()
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

/// One handoff: the other Bot, the task, and whether it is late or blocked.
private struct HandoffRow: View {
    let handoff: Handoff
    /// The Bot whose profile this is: the other end is the one shown.
    let botId: String
    @Environment(AgentStore.self) private var store

    private var outgoing: Bool { handoff.fromSessionId == botId }
    private var other: String {
        let id = outgoing ? handoff.toSessionId : handoff.fromSessionId
        return store.bots.first { $0.sessionId == id }?.displayTitle ?? String(localized: "Another Bot")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: outgoing ? "arrow.up.right" : "arrow.down.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
                Group { if outgoing { Text("To \(other)") } else { Text("From \(other)") } }
                    .font(Theme.Text.label.weight(.medium))
                    .foregroundStyle(Theme.heading)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if handoff.status == .blocked {
                    Text("Blocked").font(Theme.Text.caption).foregroundStyle(.red)
                } else if handoff.overdue() {
                    Text("Late").font(Theme.Text.caption).foregroundStyle(Theme.warning)
                } else if let due = handoff.dueAt {
                    Text(due, style: .relative).font(Theme.Text.caption).foregroundStyle(Theme.muted)
                }
            }
            Text(handoff.task)
                .font(Theme.Text.label)
                .foregroundStyle(Theme.body)
                .lineLimit(2)
            if let report = handoff.report, !report.isEmpty {
                Text(report)
                    .font(Theme.Text.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bot-profile.handoff")
    }
}
