import SwiftUI

@main
struct TrackSaverApp: App {
    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        NotificationHelper.configureOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(StyleKit.accent)
        }
    }
}
