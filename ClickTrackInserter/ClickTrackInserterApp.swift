//
//  ClickTrackInserterApp.swift
//  ClickTrackInserter
//
//  Created by 한희 on 6/25/26.
//

import SwiftUI

@main
struct ClickTrackInserterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
