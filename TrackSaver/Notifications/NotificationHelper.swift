import Foundation
import UserNotifications

enum NotificationHelper {
    static func notify(title: String, body: String, artworkURLString: String? = nil) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
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
}
