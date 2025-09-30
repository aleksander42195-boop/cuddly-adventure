//
//  LifehackWatchAppApp.swift
//  LifehackWatchApp Watch App
//
//  Created by Aleksander Blindheim on 28/09/2025.
//

import SwiftUI

@main
struct LifehackWatchApp_Watch_AppApp: App {
    @StateObject private var vm = WatchChatViewModel(engine: ChatServiceAdapter())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
    }
}
