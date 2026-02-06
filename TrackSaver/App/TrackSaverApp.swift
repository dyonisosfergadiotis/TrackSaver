import SwiftUI

@main
struct TrackSaverApp: App {
    @AppStorage("TrackSaverAccentIndex") private var accentIndex = 0
    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(StyleKit.accent)
        }
    }
}
