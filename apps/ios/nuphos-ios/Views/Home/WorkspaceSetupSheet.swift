import SwiftUI

/// First-use setup remains available from the agent picker for existing teams.
struct WorkspaceSetupSheet: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AgentStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = String(localized: "My workspace")
    @State private var discoverable: [Team] = []
    @State private var busy = false
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool { !trimmedName.isEmpty && trimmedName.count <= 80 && !busy }

    var body: some View {
        NavigationStack {
            Form {
                // The name is a field of its own, under a label, so it never reads as one more
                // choice in a list; the action that uses it is the one filled button below.
                Section {
                    TextField("Workspace name", text: $name, prompt: Text("My workspace"))
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { if canCreate { create() } }
                } header: {
                    Text("Workspace name")
                } footer: {
                    Text("Create a workspace for your agents and runtimes, or join one your organization has made available.")
                }
                Section {
                    Button { create() } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView().tint(.white) } else { Text("Create workspace").fontWeight(.semibold) }
                            Spacer()
                        }
                        .frame(minHeight: 30)
                    }
                    .prominentButton()
                    .controlSize(.large)
                    .disabled(!canCreate)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if !discoverable.isEmpty {
                    Section("Available workspaces") {
                        ForEach(discoverable) { team in
                            Button("Join \(team.name)") { join(team) }
                        }
                    }
                }
                Section {
                    Button("Refresh workspaces", systemImage: "arrow.clockwise") {
                        Task { await store.loadTeams(); if store.selectedTeam != nil { dismiss() } }
                    }
                } footer: {
                    Text("Already invited? Accept the invitation from your email, then refresh your workspaces.")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .disabled(busy)
            .navigationTitle("Set up workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
            .task {
                guard let token = auth.token else { return }
                do {
                    let result: WorkspaceAPI.TeamsEnvelope = try await WorkspaceAPI.request("teams/discoverable", token: token)
                    discoverable = result.teams
                } catch { self.error = error.localizedDescription }
            }
        }
    }

    private func create() { enter(path: "teams", body: .object(["name": .string(trimmedName)])) }
    private func join(_ team: Team) { enter(path: "teams/discoverable/\(team.id)/join", body: nil) }
    private func enter(path: String, body: JSONValue?) {
        guard let token = auth.token else { return }
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                let result: WorkspaceAPI.TeamEnvelope = try await WorkspaceAPI.request(path, token: token, method: "POST", body: body)
                await store.loadTeams()
                store.select(team: result.team)
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
}
