//
//  ARDelgeate.swift
//  SwiftUIARKit
//
//  Created by Gualtiero Frigerio on 18/05/21.
//

import Foundation
import UIKit
import Debmate
import SwiftUI
import CoreMedia
@preconcurrency import AVFoundation
import Vision
import Synchronization

class CameraMC: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    static let shared = CameraMC()
    let captureSession = AVCaptureSession()
    private let captureSessionQueue = DispatchQueue(label: "com.octoparry.refutageRemote.avCaptureQueue", qos: .userInteractive)
    private let visionSessionQueue = DispatchQueue(label: "com.octoparry.refutageRemote.visionQueue", qos: .userInteractive)
    
    var trackerMC: TrackerMC!
    
    @MainActor
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    private(set) var captureDevice: AVCaptureDevice?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    // var isHidef = false
    // var trackerMC: TrackerMC!
    
    @MainActor
    private var guiAlertWatcher: GUIAlertWatcher { AppMC.shared.guiAlertWatcher }
    
    override private init() {
        super.init()
        
        Task { @MainActor in
            await setupCaptureSession()
            videoPreviewLayer?.connection?.videoRotationAngle = 0
        }
    }
    
    @MainActor
    func restartSession() {
        captureSessionQueue.async { [self] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            
            do {
                try setActiveFormat()
            } catch {
                print("setActiveFormat failed (in session restart): ", error.localizedDescription)
            }
            
            captureSessionQueue.async {
                self.captureSession.startRunning()
            }
        }
    }

    private var authorized = false
        
    @MainActor
    func setupCaptureSession() async {
        guard !authorized else { return }

        if !(await verifyCamera()) {
            await guiAlertWatcher.showWarning("Camera Failure",
                                              details: "You will not be able to use your camera")
            return
        }
        
        do {
            try setupCamera()
            restartSession()
            if let captureDevice = self.captureDevice {
                try! captureDevice.lockForConfiguration()
                captureDevice.ramp(toVideoZoomFactor: 1.0, withRate: 0.1)
                captureDevice.unlockForConfiguration()
            }
            
        } catch {
            await guiAlertWatcher.showWarning("Camera Setup Failed",
                                              details: "Cannot setup camera: \(error.localizedDescription)")
        }
    }
    
    /*
    func captureOutput(_: AVCaptureOutput, didDrop: CMSampleBuffer, from: AVCaptureConnection) {
    }*/
    
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            await trackerMC.track()
        }
    }
    
    /*
    private static func transformOrientation(orientation: UIInterfaceOrientation) -> Double {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        case .portraitUpsideDown:
            return 90
        default:
            return 90
        }
    }*/

    func setActiveFormat() throws {
        guard let captureDevice = captureDevice else { return }
        guard let fmt = findSuitableFormat(captureDevice: captureDevice) else {
            throw GeneralError("Failed to find format for device")
        }
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeFormat = fmt
            let frameRate = 30.0
            captureDevice.activeVideoMinFrameDuration = CMTime(seconds: 1 / frameRate, preferredTimescale: 600)
            captureDevice.activeVideoMaxFrameDuration = CMTime(seconds: 1 / frameRate, preferredTimescale: 600)

        } catch {
            print("Lock for config failed: \(error.localizedDescription)")
        }
    }
    
    func setupCamera() throws {
        guard let captureDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                   mediaType: .video, position: .back).devices.first else {
            throw GeneralError("Unable to find suitable camera device on this phone")
        }

        self.captureDevice = captureDevice
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080

        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            captureSession.commitConfiguration()
            throw GeneralError("Could not create device input.")
        }

        guard captureSession.canAddInput(deviceInput) else {
            throw GeneralError("Could not add device input.")
        }
        
        captureSession.addInput(deviceInput)
        
        try setActiveFormat()
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)

            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA]
            videoDataOutput.setSampleBufferDelegate(self, queue: visionSessionQueue)
        } else {
           captureSession.commitConfiguration()
            throw GeneralError("Could not add video data output to the session")
        }
        
        captureSession.commitConfiguration()
        
        /*
        if let captureConnection = videoDataOutput.connection(with: .video) {
            print("Enable capture connection, is intrinsic matrix delivery enabled")
            captureConnection.isEnabled = true
            captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }*/
        
        /*
        try captureDevice.lockForConfiguration()
        let dimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        print("Dimensions: \(dimensions)")
        captureDevice.unlockForConfiguration()
         */
    }
    
    func verifyCamera() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined: // The user has not yet been asked for camera access.
            if await AVCaptureDevice.requestAccess(for: .video) {
                return true
            }
            else {
                await cameraAccessWarning()
            }
        case .denied: // The user has previously denied access.
            await cameraAccessWarning()
        case .restricted: // The user can't grant access due to restrictions.
            await guiAlertWatcher.showWarning("Camera Access Failure",
                                              details: "Unexpectedly found camera access is 'restricted'")
        @unknown default:
            await guiAlertWatcher.showWarning("Camera Access Failure",
                                              details: "Unknown error checking for camera access")
        }
        return false
    }

    fileprivate func cameraAccessWarning() async {
        await guiAlertWatcher.showWarning("Cannot Access Camera",
                                          details: "TrackerEx requires camera access. " +
                                                   "Go to Settings > Privacy > Camera to enable access.")
    }

    private func findSuitableFormat(captureDevice: AVCaptureDevice) -> AVCaptureDevice.Format? {
        for fmt in captureDevice.formats {
            guard fmt.mediaType == .video else { continue }
            
            guard fmt.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate == 30 }),
                  let photoDimensions = fmt.supportedMaxPhotoDimensions.first,
                  photoDimensions.width == 1920 else {
                continue
            }
            
            return fmt
        }
        return nil
    }
}
