import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("AccountUserId", store: SharedDefaults.store) private var accountUserId: String = ""
    @AppStorage("AccountDisplayName", store: SharedDefaults.store) private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL", store: SharedDefaults.store) private var accountAvatarURL: String = ""

    @State private var isLoading = true
    @State private var isReloadingCloud = false
    @State private var userId: String = "—"
    @State private var displayName: String = "—"
    @State private var errorMessage: String?
    @State private var didClearHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        accountCard
                        sessionCard

                        if didClearHistory {
                            GlassCard(style: .compact) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(StyleKit.accent)
                                    Text("Historie wurde gelöscht.")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(StyleKit.textSecondary)
                                }
                            }
                            .overlay {
                                settingsCardContrastOverlay(style: .compact)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let errorMessage {
                            GlassCard(style: .compact) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(StyleKit.accentWarm)
                                    Text(errorMessage)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(StyleKit.textSecondary)
                                }
                            }
                            .overlay {
                                settingsCardContrastOverlay(style: .compact)
                            }
                        }

                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Einstellungen")
            .settingsInlineNavigationBarTitleDisplayMode()
        }
        .task { await loadAccountInfo() }
    }

    private var accountCard: some View {
        GlassCard(style: .compact) {
            HStack(spacing: 14) {
                avatarView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)

                    Text(userId)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(StyleKit.textPrimary)
                }
            }
        }
        .overlay {
            settingsCardContrastOverlay(style: .compact)
        }
    }

    private var sessionCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Sitzung & Daten")

                VStack(spacing: 0) {
                    Button {
                        Task {
                            await reloadFromICloud()
                        }
                    } label: {
                        actionRow(
                            title: "Spotify-Daten neu laden",
                            subtitle: "Account und Historie erneut aus iCloud abrufen",
                            systemImage: "arrow.clockwise.icloud",
                            tint: StyleKit.accent,
                            showsProgress: isReloadingCloud
                        )
                    }
                    .disabled(isReloadingCloud)

                    Divider()
                        .overlay(StyleKit.strokeSoft)
                        .padding(.leading, 34)

                    Button(role: .destructive) {
                        CloudAccountSyncService.shared.logout()
                        dismiss()
                    } label: {
                        actionRow(
                            title: "Spotify abmelden",
                            systemImage: "person.crop.circle.badge.xmark",
                            tint: StyleKit.accentWarm
                        )
                    }

                    Divider()
                        .overlay(StyleKit.strokeSoft)
                        .padding(.leading, 34)

                    Button(role: .destructive) {
                        Task {
                            await clearHistory()
                        }
                    } label: {
                        actionRow(
                            title: "Historie löschen",
                            subtitle: "Alle lokal gespeicherten Einträge entfernen",
                            systemImage: "trash",
                            tint: StyleKit.accentWarm
                        )
                    }
                }
            }
        }
        .overlay {
            settingsCardContrastOverlay(style: .standard)
        }
    }

    private var infoCard: some View {
        GlassCard(style: .compact) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Info")
                infoRow(
                    title: "Version",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                )
            }
        }
        .overlay {
            settingsCardContrastOverlay(style: .compact)
        }
    }

    @ViewBuilder
    private func settingsCardContrastOverlay(style: GlassCardStyle) -> some View {
        if colorScheme != .dark {
            RoundedRectangle(cornerRadius: settingsCardCornerRadius(style), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(style == .standard ? 0.16 : 0.18),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: settingsCardCornerRadius(style), style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            StyleKit.strokeStrong.opacity(style == .standard ? 0.30 : 0.34),
                            StyleKit.stroke.opacity(style == .standard ? 0.18 : 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func settingsCardCornerRadius(_ style: GlassCardStyle) -> CGFloat {
        switch style {
        case .hero:
            return StyleKit.Radius.hero
        case .standard:
            return StyleKit.Radius.card
        case .compact:
            return StyleKit.Radius.compact
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(StyleKit.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(StyleKit.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func actionRow(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        showsProgress: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textMuted)
                        .lineLimit(2)
                }
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StyleKit.textMuted)
            }
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = URL(string: accountAvatarURL), !accountAvatarURL.isEmpty {
            RemoteImage(url: url) { avatarFallback }
                .scaledToFill()
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StyleKit.surfaceStrong)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    private func loadAccountInfo() async {
        isLoading = true
        defer { isLoading = false }

        if !accountDisplayName.isEmpty || !accountUserId.isEmpty {
            displayName = accountDisplayName.isEmpty ? "—" : accountDisplayName
            userId = accountUserId.isEmpty ? "—" : accountUserId
        }

        do {
            let me = try await SpotifyAPI.shared.fetchMe()
            CloudAccountSyncService.shared.updateLoggedInAccount(
                userId: me.id,
                displayName: me.display_name ?? "",
                avatarURL: me.images?.first?.url ?? ""
            )
            displayName = me.display_name?.isEmpty == false ? (me.display_name ?? "") : "—"
            userId = me.id.isEmpty ? "—" : me.id
            errorMessage = nil
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                CloudAccountSyncService.shared.logout()
                dismiss()
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func reloadFromICloud() async {
        guard !isReloadingCloud else { return }
        isReloadingCloud = true
        errorMessage = nil
        defer { isReloadingCloud = false }

        CloudAccountSyncService.shared.refreshFromCloud()
        await waitForSyncedTokensIfNeeded()

        let effectiveUserId = SharedDefaults.accountUserId()
        if !effectiveUserId.isEmpty {
            _ = await CloudHistorySyncService.shared.syncHistory(for: effectiveUserId)
        }
        SharedDefaults.requestHistoryRefresh()

        displayName = accountDisplayName.isEmpty ? "—" : accountDisplayName
        userId = effectiveUserId.isEmpty ? "—" : effectiveUserId

        if KeychainStore().hasAuthTokens(authenticationUI: .fail) {
            await loadAccountInfo()
        }
    }

    private func waitForSyncedTokensIfNeeded() async {
        let keychain = KeychainStore()
        guard SharedDefaults.isSpotifyLoggedIn(),
              !keychain.hasAuthTokens(authenticationUI: .fail) else { return }

        for _ in 0..<12 {
            if keychain.hasAuthTokens(authenticationUI: .fail) {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    @MainActor
    private func clearHistory() async {
        guard !accountUserId.isEmpty else { return }
        SharedDefaults.stageClearHistory(for: accountUserId)
        withAnimation(.easeInOut(duration: 0.22)) {
            didClearHistory = true
        }
        _ = await CloudHistorySyncService.shared.syncHistory(for: accountUserId)
        try? await Task.sleep(for: .seconds(2.2))
        withAnimation(.easeInOut(duration: 0.2)) {
            didClearHistory = false
        }
    }
}

private extension View {
    @ViewBuilder
    func settingsInlineNavigationBarTitleDisplayMode() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
