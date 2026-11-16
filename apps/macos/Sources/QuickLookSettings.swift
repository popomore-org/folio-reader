import AppKit
import SwiftUI

struct QuickLookSettings: View {
    let isSelected: Bool
    private let registry = QuickLookRegistry.embedded()
    @State private var snapshot: QuickLookRegistry.Snapshot?
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Finder Quick Look") {
                Text("Select a file in Finder and press Space to preview it.")
                    .foregroundStyle(.secondary)
                LabeledContent("Registration") {
                    if snapshot == nil, working {
                        ProgressView().controlSize(.small).accessibilityLabel("Checking registration")
                    } else {
                        Text(registration)
                    }
                }
                if let election = snapshot?.election {
                    LabeledContent("macOS selection", value: selection(election))
                }
                if let snapshot, snapshot.duplicateCount > 0 {
                    LabeledContent("Other registered copies", value: String(snapshot.duplicateCount))
                    Button("Remove Other Registrations") { update(.removeDuplicates) }
                        .disabled(working || snapshot.election == nil)
                }
                HStack {
                    if snapshot?.election == nil, snapshot != nil {
                        Button("Register Extension") { update(.register) }.disabled(working)
                    }
                    Button("Open System Settings", action: openSystemSettings)
                    Button("Refresh") { update(.read) }.disabled(working || registry == nil)
                }
                Text(systemSettingsHelp)
                    .font(.footnote).foregroundStyle(.secondary)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: isSelected, initial: true) { _, selected in
            if selected { update(.read) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if isSelected { update(.read) }
        }
    }

    private var registration: String {
        if registry == nil { return "Extension unavailable" }
        guard let snapshot else { return "Status unavailable" }
        return snapshot.election == nil ? "Not registered" : "Registered"
    }

    private func selection(_ election: QuickLookRegistry.Election) -> String {
        switch election {
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        case .automatic: "System default"
        case .superseded: "Another copy is selected"
        case .debugger: "Debugger only"
        case .unknown: "Unknown"
        }
    }

    private func update(_ action: QuickLookRegistry.Action) {
        guard !working, let registry else { return }
        working = true
        error = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try registry.apply(action) }
            }.value
            switch result {
            case let .success(current):
                snapshot = current
                if action == .removeDuplicates, current.duplicateCount > 0 {
                    error = "macOS still lists another copy. Remove the unused app from its current location, then refresh."
                }
            case let .failure(failure):
                snapshot = nil
                error = failure.localizedDescription
            }
            working = false
        }
    }

    private var systemSettingsHelp: String {
        if #available(macOS 15, *) {
            return "In Extensions, choose By Category, open Quick Look, and turn on Folio."
        }
        return "In System Settings, open Quick Look and turn on Folio."
    }

    private func openSystemSettings() {
        let pane: String
        if #available(macOS 15, *) { pane = "com.apple.LoginItems-Settings.extension" }
        else { pane = "com.apple.ExtensionsPreferences" }
        guard let url = URL(string: "x-apple.systempreferences:" + pane),
              NSWorkspace.shared.open(url) else {
            error = "Couldn’t open System Settings. Find Quick Look in Extensions."
            return
        }
    }
}
