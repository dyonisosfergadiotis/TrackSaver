import SwiftUI
import AppKit

@MainActor
final class TrackSaverForMacAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        configureAgentMode()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureAgentMode()
        menuBarController = MenuBarController()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBarController?.openHistoryWindow()
        return false
    }

    private func configureAgentMode() {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
final class MenuBarController: NSObject {
    private enum StatusAppearance {
        case idle
        case saving
        case success
        case failure
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let historyPopover = NSPopover()
    private var popoverContentController: NSHostingController<AnyView>?
    private var saveTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?

    override init() {
        super.init()
        configurePopover()
        configureStatusItem()
    }

    func openHistoryWindow() {
        showHistoryPopover()
    }

    private func toggleHistoryPopover() {
        if historyPopover.isShown {
            historyPopover.performClose(nil)
        } else {
            showHistoryPopover()
        }
    }

    private func showHistoryPopover() {
        guard let button = statusItem.button else { return }
        ensurePopoverContentController()
        SharedDefaults.requestHistoryRefresh()
        NSApp.activate(ignoringOtherApps: true)
        historyPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            saveCurrentTrackFromMenuBar()
        default:
            toggleHistoryPopover()
        }
    }

    private func configurePopover() {
        historyPopover.behavior = .transient
        historyPopover.animates = true
        historyPopover.contentSize = TrackSaverForMacLayout.popoverSize(for: .checking)
    }

    private func ensurePopoverContentController() {
        guard popoverContentController == nil else { return }
        let controller = NSHostingController(rootView: makePopoverContent())
        popoverContentController = controller
        historyPopover.contentViewController = controller
    }

    private func makePopoverContent() -> AnyView {
        AnyView(
            ContentView { [weak self] size in
                self?.updatePopoverSize(size)
            }
                .tint(StyleKit.accent)
        )
    }

    private func updatePopoverSize(_ size: CGSize) {
        guard historyPopover.contentSize != size else { return }
        historyPopover.contentSize = size
        historyPopover.contentViewController?.view.window?.setContentSize(size)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.toolTip = "TrackSaver"
        updateStatusAppearance(.idle)
    }

    private func saveCurrentTrackFromMenuBar() {
        guard saveTask == nil else { return }

        saveTask = Task { [weak self] in
            guard let self else { return }
            updateStatusAppearance(.saving)
            defer {
                saveTask = nil
                scheduleRestoreToIdle()
            }

            let bootstrapSnapshot = SharedDefaults.loadIOSBootstrapSnapshot()
            guard bootstrapSnapshot.iosAppLaunched else {
                CloudAccountSyncService.shared.requestIOSLaunchFromMac()
                await NotificationHelper.notify(
                    title: "TrackSaver auf dem iPhone starten",
                    body: "Öffne die iPhone-App einmal, damit Account und Playlist per iCloud auf den Mac synchronisiert werden."
                )
                updateStatusAppearance(.failure)
                openHistoryWindow()
                return
            }

            guard SharedDefaults.isSpotifyLoggedIn() else {
                await NotificationHelper.notify(
                    title: "Spotify auf dem iPhone verbinden",
                    body: "Öffne TrackSaver auf deinem iPhone und stelle sicher, dass Spotify dort angemeldet ist."
                )
                updateStatusAppearance(.failure)
                openHistoryWindow()
                return
            }

            let playlistId = resolveTargetPlaylistId()
            let targetPlaylistName = SharedDefaults.playlistName(for: playlistId)
            guard !playlistId.isEmpty else {
                await NotificationHelper.notify(
                    title: "Playlist auf dem iPhone wählen",
                    body: "Die Ziel-Playlist wird aus iOS synchronisiert. Wähle sie zuerst in TrackSaver auf deinem iPhone aus."
                )
                updateStatusAppearance(.failure)
                openHistoryWindow()
                return
            }

            do {
                let result = try await TrackSaveService.saveCurrentTrack(
                    playlistId: playlistId,
                    playlistName: targetPlaylistName
                )
                await NotificationHelper.notify(
                    title: "\(result.response.trackName) von \(result.response.artistName)",
                    body: TrackSaveService.successMessage(for: result.playlistName),
                    artworkURLString: result.response.artworkURL
                )
                updateStatusAppearance(.success)
            } catch {
                if let apiError = error as? SpotifyAPIError {
                    switch apiError {
                    case .unauthorized:
                        await NotificationHelper.notify(
                            title: "Anmeldung abgelaufen",
                            body: "Öffne TrackSaver auf deinem iPhone und prüfe dort die Spotify-Anmeldung."
                        )
                        updateStatusAppearance(.failure)
                        openHistoryWindow()
                        return
                    case .noCurrentTrack:
                        await NotificationHelper.notify(
                            title: "Kein Track",
                            body: "Es läuft gerade kein Song"
                        )
                        updateStatusAppearance(.failure)
                        return
                    case .duplicateTrack(let trackName, let artistName, let artworkURL):
                        let playlistName = SharedDefaults.playlistName(for: playlistId) ?? targetPlaylistName
                        await NotificationHelper.notify(
                            title: "\(trackName) von \(artistName)",
                            body: TrackSaveService.duplicateMessage(for: playlistName),
                            artworkURLString: artworkURL
                        )
                        updateStatusAppearance(.failure)
                        return
                    default:
                        break
                    }
                }

                await NotificationHelper.notify(
                    title: "Speichern fehlgeschlagen",
                    body: error.localizedDescription
                )
                updateStatusAppearance(.failure)
            }
        }
    }

    private func resolveTargetPlaylistId() -> String {
        SharedDefaults.defaultPlaylistId().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateStatusAppearance(_ appearance: StatusAppearance) {
        guard let button = statusItem.button else { return }

        let configuration: (symbol: String, tint: NSColor?) = switch appearance {
        case .idle:
            ("music.note.list", nil)
        case .saving:
            ("arrow.down.circle.fill", NSColor.systemOrange)
        case .success:
            ("checkmark.circle.fill", NSColor.systemGreen)
        case .failure:
            ("exclamationmark.triangle.fill", NSColor.systemRed)
        }

        let image = NSImage(systemSymbolName: configuration.symbol, accessibilityDescription: "TrackSaver")
        image?.isTemplate = configuration.tint == nil
        button.image = image
        button.contentTintColor = configuration.tint
    }

    private func scheduleRestoreToIdle() {
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.updateStatusAppearance(.idle)
        }
    }
}
