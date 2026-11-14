import SwiftUI

enum WorkspaceAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct Appearance: Equatable {
    var workspace: WorkspaceAppearance = .system
    var size = 18.0
    var width = 700.0
    var serif = true

    init() {
        let defaults = UserDefaults.standard
        workspace = WorkspaceAppearance(rawValue: defaults.string(forKey: "workspaceAppearance") ?? "") ?? .system
        size = min(30, max(13, defaults.object(forKey: "textSize") as? Double ?? 18))
        width = defaults.object(forKey: "readerWidth") as? Double ?? 700
        serif = defaults.object(forKey: "serif") as? Bool ?? true
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(workspace.rawValue, forKey: "workspaceAppearance")
        defaults.set(size, forKey: "textSize")
        defaults.set(width, forKey: "readerWidth")
        defaults.set(serif, forKey: "serif")
    }
}

struct ReaderSettings: View {
    @ObservedObject var model: ReaderModel
    @ObservedObject var updates: FolioUpdates

    var body: some View {
        TabView(selection: $updates.settingsPage) {
            appearance.tabItem { Label("Appearance", systemImage: "textformat") }.tag(FolioUpdates.SettingsPage.appearance)
            UpdateSettings(updates: updates)
                .tabItem { Label("Updates", systemImage: "arrow.clockwise") }.tag(FolioUpdates.SettingsPage.updates)
        }
        .frame(width: 500, height: 420)
    }

    private var appearance: some View {
        Form {
            Section("Workspace") {
                Picker("Appearance", selection: $model.appearance.workspace) {
                    ForEach(WorkspaceAppearance.allCases) { mode in Text(mode.rawValue.capitalized).tag(mode) }
                }
            }
            Section("Reading") {
                Picker("Typeface", selection: $model.appearance.serif) {
                    Text("Serif").tag(true)
                    Text("Sans Serif").tag(false)
                }
                Stepper("Text size · \(Int(model.appearance.size)) pt", value: $model.appearance.size, in: 13...30)
                Picker("Reading width", selection: $model.appearance.width) {
                    Text("Narrow").tag(570.0)
                    Text("Standard").tag(700.0)
                    Text("Wide").tag(920.0)
                }
            }
        }
        .formStyle(.grouped)
    }
}


private struct UpdateSettings: View {
    @ObservedObject var updates: FolioUpdates

    var body: some View {
        Form {
            Section("Software Update") {
                LabeledContent("Installed version", value: updates.currentVersion)
                if updates.isConfigured {
                    TimelineView(.periodic(from: .now, by: 0.4)) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(updates.status)
                            if let progress = updates.downloadProgress {
                                ProgressView(value: progress)
                            } else if updates.isWorking {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    if let version = updates.version {
                        LabeledContent("Available version", value: version)
                        ScrollView {
                            Text(updates.notes).frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 100)
                        .accessibilityLabel("Release Notes")
                    }
                    HStack {
                        Button(updates.lastCheckFailed ? "Retry Check" : "Check for Updates", action: updates.check)
                            .disabled(!updates.canCheck)
                        if updates.canDownload { Button("Download", action: updates.download) }
                        if updates.canInstall { Button("Install and Restart", action: updates.install) }
                        if updates.canDefer { Button("Install Later", action: updates.deferInstallation) }
                        if updates.canCancel { Button("Cancel", action: updates.cancel) }
                    }
                } else {
                    Text("This preview is updated by installing a new preview build.").foregroundStyle(.secondary)
                }
            }
            if updates.isConfigured {
                Section("Automatic Updates") {
                    Toggle("Check every 24 hours", isOn: Binding(get: { updates.automaticChecks }, set: updates.setAutomaticChecks))
                    Toggle("Download available updates", isOn: $updates.automaticDownloads)
                    Toggle("Install and restart when Folio is idle", isOn: $updates.automaticInstalls)
                    Text("Automatic download applies to scheduled checks. Installation waits for edits, file opening, and media playback.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
