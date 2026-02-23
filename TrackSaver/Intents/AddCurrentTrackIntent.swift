import AppIntents

struct AddCurrentTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Aktuellen Song speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Legacy-Alias für den TrackSaver-Save-Intent.")
    }

    func perform() async throws -> some IntentResult {
        return .result(value: await SaveTrackIntentRunner.perform(shortcutSlot: nil))
    }
}
