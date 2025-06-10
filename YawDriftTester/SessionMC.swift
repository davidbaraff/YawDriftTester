//
//  SessionMC.swift
//  RefutageRemote
//
//  Created by David Baraff on 9/18/24.
//

import Foundation
import ARKit
import Debmate
import Synchronization

@MainActor
@Observable
class SessionMC {
    static let shared = SessionMC()
        
    private var lastScanRequest: Date?
    var cameraMC: CameraMC { CameraMC.shared }
    var currentYaw = 0.0
    let startDate = Date()
    var runningTime = 0
    var nextChangeSeconds = 0
    
    init() {
        Task {
            while true {
                try? await Task.sleep(seconds: 1)
                runningTime = Int(startDate.secondsAgo)
            }
        }
    }
}

