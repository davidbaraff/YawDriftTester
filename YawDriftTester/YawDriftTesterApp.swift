//
//  YawDriftTesterApp.swift
//  YawDriftTester
//
//  Created by David Baraff on 6/9/25.
//

import SwiftUI

@main
struct YawDriftTesterApp: App {
    init() {
        _ = AppMC.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    print("Set idle timer disabled on content view")
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
