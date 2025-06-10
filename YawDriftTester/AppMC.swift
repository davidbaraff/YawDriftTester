//
//  AppMC.swift
//  TrackerEx
//
//  Created by David Baraff on 7/19/24.
//

import Foundation
import Debmate
import UIKit

@MainActor
@Observable
class AppMC {
    static let shared = AppMC()
    let guiAlertWatcher = GUIAlertWatcher(interfaceIdiom: nil)
    let trackerMC = TrackerMC()
    
    init() {
        let cameraMC = CameraMC.shared
        cameraMC.trackerMC = trackerMC
        Task {
            await trackerMC.startup()
        }
    }
}
