import SwiftUI

struct AccentColorOption: Identifiable {
    let id: Int
    let label: String
    let color: Color
}

struct AccentPalette {
    static let options: [AccentColorOption] = [
        .init(id: 0, label: "Azur", color: Color(red: 0.18, green: 0.48, blue: 0.89)),
        .init(id: 1, label: "Mint", color: Color(red: 0.45, green: 0.81, blue: 0.67)),
        .init(id: 2, label: "Lavendel", color: Color(red: 0.65, green: 0.52, blue: 0.84)),
        .init(id: 3, label: "Peach", color: Color(red: 0.98, green: 0.72, blue: 0.58)),
        .init(id: 4, label: "Rose", color: Color(red: 0.91, green: 0.45, blue: 0.59)),
        .init(id: 5, label: "Sunrise", color: Color(red: 1.00, green: 0.76, blue: 0.42)),
        .init(id: 6, label: "Ocean", color: Color(red: 0.16, green: 0.60, blue: 0.76)),
        .init(id: 7, label: "Spring", color: Color(red: 0.52, green: 0.85, blue: 0.62)),
        .init(id: 8, label: "Coral", color: Color(red: 0.96, green: 0.49, blue: 0.58)),
        .init(id: 9, label: "Lemon", color: Color(red: 0.97, green: 0.90, blue: 0.55)),
        .init(id: 10, label: "Sky", color: Color(red: 0.44, green: 0.68, blue: 0.95)),
        .init(id: 11, label: "Petal", color: Color(red: 0.84, green: 0.67, blue: 0.85))
    ]

    static func color(at index: Int) -> Color {
        options[safe: index]?.color ?? options.first!.color
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
