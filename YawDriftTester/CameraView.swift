//
//  CameraView.swift
//  FencingReview
//
//  Copyright © 2024 David Baraff. All rights reserved.
//

import Foundation
import SwiftUI
import Debmate
import AVFoundation
import UIKit

struct CameraView : View {
    var body: some View {
        CameraRepresentable()
    }
}

struct CameraRepresentable : UIViewControllerRepresentable {
    typealias UIViewControllerType = CameraVC
    
    func makeUIViewController(context: Context) -> CameraVC {
        let vc = CameraVC()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraVC, context: Context) {
        // empty
    }
}

class CameraVC: UIViewController {
    let cameraMC = CameraMC.shared
    let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videoPreviewLayer.session = cameraMC.captureSession
        cameraMC.videoPreviewLayer = videoPreviewLayer
        view.layer.addSublayer(videoPreviewLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        videoPreviewLayer.frame = view.frame
        if let connection = videoPreviewLayer.connection {
            connection.videoRotationAngle = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
    }

    override func viewDidLayoutSubviews() {
        videoPreviewLayer.frame = view.layer.frame
    }
}



