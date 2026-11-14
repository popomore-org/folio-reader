import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case system, light, paper, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Appearance: Equatable {
    var theme: Theme = .system
    var size = 18.0
    var width = 700.0
    var serif = true

    init() {
        let defaults = UserDefaults.standard
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        size = min(30, max(13, defaults.object(forKey: "textSize") as? Double ?? 18))
        width = defaults.object(forKey: "readerWidth") as? Double ?? 700
        serif = defaults.object(forKey: "serif") as? Bool ?? true
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(size, forKey: "textSize")
        defaults.set(width, forKey: "readerWidth")
        defaults.set(serif, forKey: "serif")
    }
}

struct ReaderSettings: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        Form {
            Section("Reading Appearance") {
                Picker("Theme", selection: $model.appearance.theme) {
                    ForEach(Theme.allCases) { theme in Text(theme.label).tag(theme) }
                }
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
        .frame(width: 450, height: 245)
    }
}
