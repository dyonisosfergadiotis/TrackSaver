import AppIntents

struct AddCurrentTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Aktuellen Song speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Legacy-Alias für den TrackSaver-Save-Intent.")
    }

    func perform() async throws -> some IntentResult {
        let output = await SaveTrackIntentRunner.perform(shortcutSlot: nil)
        return .result(value: output, dialog: SaveTrackIntentRunner.intentDialog(for: output))
    }
}
