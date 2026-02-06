//
//  TrackSaverWidgetBundle.swift
//  TrackSaver
//
//  Created by Dyonisos Fergadiotis on 06.02.26.
//


import WidgetKit
import SwiftUI

@main
struct TrackSaverWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Hier wird das Control Widget registriert
        if #available(iOSApplicationExtension 26, *) {
            TrackSaverWidgetControl()
        }
    }
}
