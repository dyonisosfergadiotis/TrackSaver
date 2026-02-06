import AppIntents

struct TrackSaverAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            // Use the new pure logic intent that doesn't open the app
            intent: SaveCurrentTrackIntent(),
            phrases: [
                "${applicationName} speichern",
                "Track in ${applicationName} speichern",
                "Song in ${applicationName} sichern"
            ],
            shortTitle: "Track speichern",
            systemImageName: "plus.app.fill"
        )
    }
}

