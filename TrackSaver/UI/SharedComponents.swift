import SwiftUI

struct SaveButton: View {
    let isLoading: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.white)
                    .tint(.green)
            }
        }
        .tint(StyleKit.accent)
        .disabled(!enabled || isLoading)
    }
}
