import Foundation
import UserNotifications

enum NotificationHelper {
    private static let center = UNUserNotificationCenter.current()
    private static let foregroundDelegate = ForegroundNotificationDelegate()

    static func configureOnLaunch() {
        center.delegate = foregroundDelegate
        Task {
            _ = await ensureAuthorization()
        }
    }

    static func notify(title: String, body: String, artworkURLString: String? = nil) async {
        center.delegate = foregroundDelegate
        guard await ensureAuthorization() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = cleanArtistTitle(title)
        content.body = body
        content.sound = .default
        if let artworkURLString,
           let url = URL(string: artworkURLString),
           let attachment = await downloadAttachment(from: url) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    static func cleanArtistTitle(_ input: String) -> String {
        let pattern = "\\[[^\\]]*\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        let stripped = regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
        let cleaned = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? input : cleaned
    }

    private static func downloadAttachment(from url: URL) async -> UNNotificationAttachment? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard !data.isEmpty else { return nil }
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tracksaver_\(UUID().uuidString).\(ext)")
            try data.write(to: tempURL)
            return try? UNNotificationAttachment(identifier: UUID().uuidString, url: tempURL, options: nil)
        } catch {
            return nil
        }
    }

    private static func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .list, .sound])
        }
    }
}
