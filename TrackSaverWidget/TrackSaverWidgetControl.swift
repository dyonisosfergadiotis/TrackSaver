//
//  SaveCurrentTrackIntent.swift
//  TrackSaver
//
//  Created by Dyonisos Fergadiotis on 06.02.26.
//


import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct TrackSaverWidgetControl: ControlWidget {
    static let kind = "TrackSaverControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SaveCurrentTrackIntent()) {
                Label {
                    Text("Track speichern")
                } icon: {
                    Image(systemName: "text.append")
                }
            }
        }
        .displayName("Track speichern")
        .description("Speichert den aktuell spielenden Track in die gewählte Playlist.")
    }
}
