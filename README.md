# TrackSaver

TrackSaver is an iOS app that saves your currently playing Spotify track to a selected playlist with one tap.

It includes:
- a SwiftUI app UI
- App Intents for Siri/Shortcuts
- a Control Widget button
- local history of saved tracks

## Features

- Spotify OAuth login using PKCE (no client secret in app)
- Save currently playing track to a playlist
- Duplicate check before adding a track
- Playlist picker with default playlist persistence
- Shift-based shortcut playlists (3 slots)
- Local save history per Spotify account
- Local notifications (optionally with artwork)
- App Intent support for shortcuts and automation

## Tech Stack

- Swift 5
- SwiftUI
- AppIntents
- WidgetKit
- URLSession for Spotify Web API
- Keychain for token storage
- App Group `UserDefaults` for shared settings/history

## Requirements

- Xcode 26+ (project is currently configured with iOS deployment target `26.2`)
- iOS device or simulator
- Spotify account with active playback when saving tracks
- A Spotify Developer app

## Setup

1. Create a Spotify app in the Spotify Developer Dashboard.
2. Add a redirect URI (example: `tracksaver://callback`) in the Spotify app settings.
3. Update `TrackSaver/Spotify/SpotifyConfig.swift`:
   - `clientId`
   - `redirectURI`
4. In Xcode, add a URL Type to the TrackSaver app target:
   - URL Schemes: `tracksaver` (or your chosen scheme)
5. Verify capabilities/entitlements for app and widget targets:
   - App Group: `group.dyonisosfergadiotis.tracksaver`
   - Keychain Access Group: `8W4U9DBYVS.group.dyonisosfergadiotis.tracksaver`
6. If you fork or change Team ID / bundle setup, update:
   - `TrackSaver/Storage/SharedDefaults.swift` (`suiteName`)
   - `TrackSaver/Storage/KeychainStore.swift` (`accessGroup`)
   - `TrackSaver/TrackSaver.entitlements`
   - `TrackSaverWidget/TrackSaverWidget.entitlements`

## Run Locally

1. Open `TrackSaver.xcodeproj` in Xcode.
2. Select the `TrackSaver` scheme.
3. Build and run.
4. Complete Spotify login on first launch.
5. Choose a default playlist.
6. Use save action from app UI, Shortcuts, or widget.

## Shortcuts and Widget

- Intents are defined in `TrackSaver/Intents/`.
- Available shortcut actions:
  - Save current track
  - Save for Shift 1
  - Save for Shift 2
  - Save for Shift 3
- Shift time windows:
  - Shift 1: 06:00-13:59
  - Shift 2: 14:00-21:59
  - Shift 3: 22:00-05:59
- Widget extension lives in `TrackSaverWidget/`.

## Project Structure

```text
TrackSaver/
  App/              # App entry + root flow
  Spotify/          # Auth + Spotify API client
  Storage/          # Shared defaults + keychain storage
  UI/               # Views, styling, sheets
  Intents/          # AppIntents / Shortcuts actions
  Notifications/    # Local notification helper
TrackSaverWidget/   # Control Widget extension
TrackSaver.xcodeproj
```

## Troubleshooting

- Login fails after Spotify auth:
  - Check redirect URI in Spotify dashboard and `SpotifyConfig.redirectURI`
  - Check URL scheme in Xcode target settings
- `401 Unauthorized` from Spotify:
  - Log out and log in again
  - Verify client ID and redirect URI
- "No current track":
  - Start playback in Spotify first
- Widget/Shortcut save fails:
  - Ensure a default playlist (or shift playlist) is configured
- Entitlement/keychain issues:
  - Ensure App Group and Keychain Access Group match your signing team setup

## Security Notes

- Spotify `clientId` is public by design.
- Access and refresh tokens are stored in Keychain.
- Shared settings/history are stored in App Group `UserDefaults`.

## Status

Current repo has no automated test target yet. Manual validation is recommended after changes to auth, intents, or widget flows.
