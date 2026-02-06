import SwiftUI

struct WalkthroughView: View {
    @Binding var isComplete: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 10) {
                            Text("TrackSaver")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Speichere den aktuell spielenden Song mit einem einzigen Tap.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Playlists auswählen")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                HStack(spacing: 12) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Aktuellen Track übernehmen")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Historie lokal behalten")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        Button {
                            isComplete = true
                        } label: {
                            Text("Weiter zum Login")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StyleKit.accent)
                        .foregroundStyle(.black)

                        Text("Du kannst dich später jederzeit abmelden.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
