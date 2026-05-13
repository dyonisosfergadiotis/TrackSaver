import Foundation

struct Item: Identifiable {
    let id = UUID()
    let timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
