import SwiftUI
import AppKit

@main
struct TrackSaver_For_MacApp: App {
    @NSApplicationDelegateAdaptor(TrackSaverForMacAppDelegate.self) private var appDelegate

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        CloudAccountSyncService.shared.start()
        NotificationHelper.configureOnLaunch()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
