//
//  ViewController.swift
//  MLImageRecognition
//
//  Created by Adnann Muratovic on 04.02.23.
//

import UIKit
import AVFoundation

class CameraController: UIViewController {
    
    // MARK: - Properties
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.backgroundColor = .lightGray
        label.textAlignment = .center
        return label
    }()
    
    var captureSession = AVCaptureSession()
    var videPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        configure()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        /// Start video capture
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // Dispose of any resources that can be recreated.
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        /// Dispose of any resources that can be recreated.
    }
}

// MARK: - Configure VideoPlayer
private extension CameraController {
    private func configure() {
        /// Get the bac-facing camera for capturing videos
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            /// Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            /// Set the input device on the capture session
            captureSession.addInput(input)
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "imageRecognition.qeueu"))
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            captureSession.addOutput(videoDataOutput)
        }
        catch {
            /// If any error occurs, simply print it out and don't continuie any more.
            print(error.localizedDescription)
            return
        }
        
        /// Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer
        videPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videPreviewLayer!)
        
        /// Bring the label to the front
        descriptionLabel.text = "Looking for objects..."
        view.bringSubviewToFront(descriptionLabel)
    }
}

// MARK: - Layout
private extension CameraController {
    private func layout() {
        view.addSubview(descriptionLabel)
        
        let descriptionLabelConstraints = [
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            descriptionLabel.heightAnchor.constraint(equalToConstant: 50)
        ]
        
        NSLayoutConstraint.activate(descriptionLabelConstraints)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
}
