import AppIntents

struct RecenterIntent: AppIntent {
    static let title: LocalizedStringResource = "Recenter Screen"
    static let description = IntentDescription("Puts the Stage screen back in front of you.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            StageModel.shared.recenter()
        }
        return .result()
    }
}

struct StageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecenterIntent(),
            phrases: [
                "Recenter \(.applicationName)",
                "Center \(.applicationName)",
            ],
            shortTitle: "Recenter",
            systemImageName: "arrow.counterclockwise"
        )
    }
}
