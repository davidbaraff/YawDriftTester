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
            ContentView().edgesIgnoringSafeArea(.all)
        }
    }
}
