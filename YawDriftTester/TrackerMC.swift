//
//  TrackerMC.swift
//  RefutageRemote
//
//  Created by David Baraff on 7/21/24.
//

import Foundation
import Debmate
import DockKit
import Spatial

extension DockAccessory.Limits.Limit {
    init?(_ r: (Double, Double)?) throws {
        guard let r = r else { return nil }
        try self.init(positionRange: r.0 ..< r.1, maximumSpeed: 1)
    }
}

actor TrackerMC {
    let dockManager = DockAccessoryManager.shared
    private var accessory: DockAccessory?

    private var motionStatesTask: Task<Void,Never>?
    private var eventsTask: Task<Void,Never>?
    
    private(set) var autoTrack = true
    private(set) var currentYaw = 0.0
    
    private var currentYawTimeStamp = 0.0
    private var currentPitch = 0.0
    private var currentYawVelocity = 0.0
    private var zeroVelocity = false
    private var stopVelocityTask: Task<Void,Never>?
    private var errorIsLarge = false

    init() {
    }
    
    func startup() {
        Task {
            await watchStateChanges()
        }
    }
    
    private func setAccessory(_ newAccessory: DockAccessory?) async {
        if motionStatesTask != nil {
            motionStatesTask?.cancel()
            eventsTask?.cancel()
        }

        accessory = newAccessory
        guard let accessory = accessory else { return }
        motionStatesTask = Task {
            print("Watching motion states")
            do {
                for await motionState in try accessory.motionStates {
                    if Task.isCancelled {
                        print("Motion state loop: canceled")
                        return
                    }
                    
                    currentYaw = -motionState.angularPositions.y
                    currentPitch = motionState.angularPositions.x
                    currentYawTimeStamp = ProcessInfo.processInfo.systemUptime
                    // print("current yaw = \(currentYaw.asDegrees) at \(currentYawTimeStamp)")

                    let yaw = currentYaw
                    Task { @MainActor in
                        SessionMC.shared.currentYaw = yaw
                    }
                }
                print("In motion state: reached end")
            } catch {
                print("Caught \(error) in motion states")
            }
        }
    }

    func watchStateChanges() async {
        while true {
            do {
                for await stateChange in try dockManager.accessoryStateChanges {
                    if stateChange.state == .docked {
                        do {
                            try await dockManager.setSystemTrackingEnabled(false)
                        } catch {
                            print("Set system tracking enabled failed: \(error)")
                        }
                        
                        await setAccessory(stateChange.accessory)
                    }
                    else {
                        await setAccessory(nil)
                    }
                }
            }
            catch {
                print("set system tracking threw: \(error)")
            }
        }
    }

    func setOrientation(pitch: Double?, yaw: Double?) async {
        guard let accessory = accessory else {
            return
        }

        let newPitch = pitch ?? currentPitch
        let newYaw = yaw ?? currentYaw
        
        let orientation = Vector3D(x: newPitch, y: newYaw, z: 0)
        do {
            _ = try await accessory.setOrientation(orientation, duration: .seconds(1.0))
        }
        catch {
            print("Set orientation failed: \(error.localizedDescription)")
        }
    }
    
    func setOrientation(pitch: Double, yaw: Double, roll: Double, relative: Bool) async {
        guard let accessory = accessory else {
            return
        }

        let orientation = Vector3D(x: pitch, y: yaw, z: roll)
        do {
            _ = try await accessory.setOrientation(orientation, duration: Duration.seconds(0), relative: relative)
        }
        catch {
            print("Set orientation failed: \(error.localizedDescription)")
        }
    }
    
    let yawMin = -35.0.asRadians
    let yawMax = 35.0.asRadians
    
    private func attenuateYawVelocity(_ yawVelocity: Double) -> Double? {
        let rampDelta = min(5.asRadians, (yawMax - yawMin) / 5)
        
        if currentYaw < yawMin {
            return yawVelocity >= 0 ? nil : 0.0
        }
        else if currentYaw - yawMin < rampDelta {
            return yawVelocity >= 0 ? nil : (currentYaw - yawMin) / rampDelta * yawVelocity
        }
        else if currentYaw > yawMax {
            return yawVelocity <= 0 ? nil : 0.0
        }
        else if yawMax - currentYaw < rampDelta {
            return yawVelocity <= 0 ? nil : (yawMax - currentYaw) / rampDelta * yawVelocity
        }
        else {
            return nil
        }
    }
    
    func setVelocity(pitch: Double, yaw yawVelocityIn: Double, roll: Double, stopAfter: Double? = nil) async {
        guard let accessory = accessory else {
            return
        }

        var yawVelocity = max(-0.75, min(yawVelocityIn, 0.75))
        if let attenuatedVelocity = attenuateYawVelocity(yawVelocity) {
            yawVelocity = attenuatedVelocity
        }

        if pitch == 0 && yawVelocity == 0 && roll == 0 {
            stopVelocityTask?.cancel()
            if zeroVelocity {
                return
            }
            zeroVelocity = true
        }
        else {
            zeroVelocity = false
        }

        if !zeroVelocity,
           let stopAfter = stopAfter {

            stopVelocityTask?.cancel()
            stopVelocityTask = Task {
                try? await Task.sleep(seconds: stopAfter)

                if !Task.isCancelled {
                    await setVelocity(pitch: 0, yaw: 0, roll: 0)
                }
            }
        }
        do {
            currentYawVelocity = yawVelocity
            currentYawTimeStamp = ProcessInfo.processInfo.systemUptime

            if yawVelocity == 0 {
                yawVelocity = 1e-6
            }
            print("Set angular velocity to ", -yawVelocity)
            try await accessory.setAngularVelocity(Vector3D(x: pitch, y: -yawVelocity, z: roll))
        }
        catch {
            print("Set angular velocity failed: \(error.localizedDescription)")
        }
    }
    
    enum ReturnLocation {
        case left
        case center
        case right
    }

    var nextReturnLocation = ReturnLocation.left
    var lastChange = Date()
    var timeToWait = 10.0
    
    private func returnToOrientation(targetYaw: Double) async {
        let thetaOffset = currentYaw - targetYaw
        var effectiveThetaOffset = thetaOffset

        if abs(thetaOffset) < 1.0.asRadians {
            effectiveThetaOffset = 0
        }
        else {
            print("Trying to return to \(targetYaw.asDegrees)")
            print("Current offset is: ", thetaOffset.asDegrees)
        }
        await setVelocity(pitch: 0, yaw: -effectiveThetaOffset * 0.85, roll: 0)
    }
    
    private func returnTo(location: ReturnLocation) async {
        switch location {
        case .center:
            return await returnToOrientation(targetYaw: (yawMin + yawMax) / 2)
        case .left:
            return await returnToOrientation(targetYaw: yawMin)
        case .right:
            return await returnToOrientation(targetYaw: yawMax)
        }
    }
    
    var startDate = Date()

    func track() async {
        if lastChange.secondsAgo >= timeToWait {
            lastChange = Date()
            timeToWait = 10.0
            
            if nextReturnLocation == .center {
                nextReturnLocation = .left
            }
            else if nextReturnLocation == .left {
                nextReturnLocation = .right
            }
            else {
                nextReturnLocation = .center
                if startDate.secondsAgo > 300 {
                    timeToWait = 300.0
                }
                else if startDate.secondsAgo > 120 {
                    timeToWait = 30.0
                }
                else {
                    timeToWait = 20.0
                }
            }
        }

        let remaining = (timeToWait - lastChange.secondsAgo).roundedInt
        Task { @MainActor in
            SessionMC.shared.nextChangeSeconds = remaining
        }

        await returnTo(location: nextReturnLocation)
        
        let extra = (yawMax - yawMin) * 0.075
        if currentYaw < yawMin - extra {
            // print("Branch A")
            await setVelocity(pitch: 0, yaw: -(currentYaw - yawMin) * 3, roll: 0)
            return
        }
        else if currentYaw > yawMax + extra {
            // print("Branch B")
            await setVelocity(pitch: 0, yaw: -(currentYaw - yawMax) * 3, roll: 0)
            return
        }
    }
}
