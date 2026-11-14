import SwiftUI

/// One Cloud agent's own page, like Desktop's Settings → Agent: rename it,
/// see its usage, sign it in again, disable it, and rebuild a cloud runtime
/// or remove a connected one.
struct AgentDetailView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AgentStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let team: Team
    let runtime: RuntimeInstance
    @State private var name: String
    @State private var busy = false
    @State private var confirmRemoval = false
    @State private var error: String?

    init(team: Team, runtime: RuntimeInstance) {
        self.team = team
        self.runtime = runtime
        _name = State(initialValue: runtime.label)
    }

    /// The list's copy, so a rename or a disable shows as soon as it lands.
    private var current: RuntimeInstance { store.runtimes.first { $0.id == runtime.id } ?? runtime }
    private var quota: RuntimeQuota? { store.quotas[runtime.id] }
    private var path: String { "teams/\(team.id)/agent-runtimes/\(runtime.id)" }
    /// A cloud runtime is only rebuilt: once it is deleted the server gives the team a fresh one.
    private var rebuilds: Bool { current.kind == "managed" }
    // Typed so each branch is looked up in the catalog; a bare ternary would pass a String.
    private var actionTitle: LocalizedStringKey { rebuilds ? "Rebuild Runtime" : "Remove Runtime" }
    private var confirmTitle: LocalizedStringKey { rebuilds ? "Rebuild \(current.label)?" : "Remove \(current.label)?" }
    private var confirmMessage: LocalizedStringKey {
        rebuilds
            ? "This deletes the runtime's files and sign-in and starts a fresh one in a moment. Your agents' history stays in Yu AI."
            : "This disconnects the runtime. Your agents stay in Yu AI."
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Runtime name", text: $name)
                    .submitLabel(.done)
                    .onSubmit {
                        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !label.isEmpty, label != current.label { update(["label": .string(label)]) }
                    }
            }
            Section("Usage") {
                if let quota, quota.available {
                    ForEach(quota.windows, id: \.label) { window in
                        LabeledContent(window.label) {
                            HStack(spacing: 8) {
                                QuotaGauge(window: window).frame(width: 60)
                                Text("\(window.leftPercent)% left")
                                    .monospacedDigit()
                                    .foregroundStyle(window.labelTint ?? .secondary)
                            }
                        }
                    }
                } else {
                    Text(quotaReason(quota?.reason)).foregroundStyle(.secondary)
                }
            }
            Section {
                // omp is bound to Yu AI and has no sign-in of its own, so it offers none.
                if current.status == .active,
                   RuntimeInstance.Provider.supportsSignIn(current.provider.rawValue) {
                    NavigationLink(quota?.needsSignIn == true ? "Sign In" : "Sign In Again") {
                        AgentSetupView(team: team, runtime: current)
                    }
                }
                Toggle("Enabled", isOn: Binding(
                    get: { current.status == .active },
                    set: { update(["status": .string($0 ? "active" : "disabled")]) }
                ))
            }
            Section {
                Button(actionTitle, role: .destructive) { confirmRemoval = true }
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.footnote) }
            }
        }
        .disabled(busy)
        .navigationTitle(current.label)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(confirmTitle, isPresented: $confirmRemoval, titleVisibility: .visible) {
            Button(actionTitle, role: .destructive) { remove() }
        } message: {
            Text(confirmMessage)
        }
    }

    /// The server explains why there are no figures, in English. The one
    /// reason this build knows by name is translated; anything else is shown
    /// as the server wrote it.
    private func quotaReason(_ reason: String?) -> String {
        guard let reason else { return String(localized: "Unavailable") }
        if reason == "omp does not report usage" { return String(localized: "omp does not report usage") }
        return reason
    }

    private func update(_ patch: [String: JSONValue]) {
        guard let token = auth.token else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                let _: RuntimeInstance = try await WorkspaceAPI.request(path, token: token, method: "PATCH", body: .object(patch))
                await store.loadRuntimes(force: true)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func remove() {
        guard let token = auth.token else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                _ = try await AgentChatAPI.send("DELETE", path, token: token, body: nil as JSONValue?)
                await store.loadRuntimes(force: true)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
