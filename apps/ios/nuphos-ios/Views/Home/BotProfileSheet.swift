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
        } catch {
            loadError = error.localizedDescription
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
