//
//  ViewController.swift
//  MLImageRecognition
//
//  Created by Adnann Muratovic on 04.02.23.
//

import UIKit
import AVFoundation
import CoreML

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
    
    var mlModel = try! MobileNetV2(configuration: MLModelConfiguration())
    
    var focusPoint = CGPoint(x: 0.5, y: 0.5)

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        configureCaptureSession()
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

// MARK: - Configure VideoPlayer
private extension CameraController {
    /**
     Configures the capture session for video recording.
     - Initializes the video capture device and adds it to the capture session as input.
     - Sets the sample buffer delegate for the video data output and adds it to the capture session.
     - Initializes the video preview layer and adds it as a sublayer to the view's layer.
     - Updates the description label text to "Looking for objects..." and brings it to the front.
     */
    private func configureCaptureSession() {
        // Get the back-facing camera for capturing videos
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get the camera device")
            return
        }

        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)

            // Set the input device on the capture session
            captureSession.addInput(input)

            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "imageRecognition.queue"))
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            captureSession.addOutput(videoDataOutput)
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error.localizedDescription)
            return
        }

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer
        videPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videPreviewLayer!)

        // Bring the label to the front
        descriptionLabel.text = "Looking for objects..."
        view.bringSubviewToFront(descriptionLabel)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        
        // Resize the frame to 224x224
        // This is the required size of the model
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let image = UIImage(ciImage: ciImage)
        
        UIGraphicsBeginImageContext(CGSize(width: 224, height: 224))
        image.draw(in: CGRect(x: 0, y: 0, width: 224, height: 224))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Convert UIImage to CVPixelBuffer
        // The code for the conversion is adapted from this post of StackOverflow
        // https://stackoverflow.com/questions/44462087/how-to-convert-a-uiimage-to-a-cvpixelbuffer

        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(resizedImage.size.width), Int(resizedImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(resizedImage.size.width), height: Int(resizedImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: resizedImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        resizedImage.draw(in: CGRect(x: 0, y: 0, width: resizedImage.size.width, height: resizedImage.size.height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        if let pixelBuffer = pixelBuffer,
            let output = try? mlModel.prediction(image: pixelBuffer) {
            
            DispatchQueue.main.async {
                self.descriptionLabel.text = output.classLabel
                
                for (key, value) in output.classLabelProbs {
                    print("\(key) = \(value)")
                }
            }
        }
    }
    
    // Function to control camera focus and exposure
    func setCameraFocusAndExposure(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .autoExpose
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            device.unlockForConfiguration()
        } catch {
            // Handle errors here
        }
    }

    // Function to set flash mode
    func setFlashMode(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode, photoOutput: AVCapturePhotoOutput) {
        if device.hasFlash && photoOutput.supportedFlashModes.contains(mode) {
            do {
                try device.lockForConfiguration()
                device.flashMode = mode
                device.unlockForConfiguration()
            } catch {
                // Handle errors here
                print(error.localizedDescription)
            }
        } else {
            // Flash is not available or not supported
            print("DEBUG ❌: Flash is not available or not supported")
        }
    }
}
