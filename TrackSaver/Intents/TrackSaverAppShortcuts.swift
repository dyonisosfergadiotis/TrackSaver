import AppIntents

struct TrackSaverAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveCurrentTrackIntent(),
            phrases: [
                "${applicationName} speichern",
                "Track in ${applicationName} speichern",
                "Song in ${applicationName} sichern"
            ],
            shortTitle: "Track speichern",
            systemImageName: "plus.app.fill"
        )
        AppShortcut(
            intent: SaveCurrentTrackShift1Intent(),
            phrases: [
                "${applicationName} Schicht 1 speichern",
                "Schicht 1 Track in ${applicationName} sichern"
            ],
            shortTitle: "Schicht 1",
            systemImageName: "1.circle.fill"
        )
        AppShortcut(
            intent: SaveCurrentTrackShift2Intent(),
            phrases: [
                "${applicationName} Schicht 2 speichern",
                "Schicht 2 Track in ${applicationName} sichern"
            ],
            shortTitle: "Schicht 2",
            systemImageName: "2.circle.fill"
        )
        AppShortcut(
            intent: SaveCurrentTrackShift3Intent(),
            phrases: [
                "${applicationName} Schicht 3 speichern",
                "Schicht 3 Track in ${applicationName} sichern"
            ],
            shortTitle: "Schicht 3",
            systemImageName: "3.circle.fill"
        )
    }
}
