//
//  CameraViewController.swift
//  Custom Camera (Swift)
//
//  Created by Chris Leversuch on 03/07/2016.
//  Copyright © 2016 Brightec. All rights reserved.
//

import UIKit
import AVFoundation
import SnapKit


class CameraViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet var topBarView: UIView!
    @IBOutlet var bottomBarView: UIView!
    @IBOutlet var cameraContainerView: UIView!
    @IBOutlet var flashButton: UIButton!
    @IBOutlet var flashModeContainerView: UIView!
    @IBOutlet var flashAutoButton: UIButton!
    @IBOutlet var flashOnButton: UIButton!
    @IBOutlet var flashOffButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var openPhotoAlbumButton: UIButton!
    @IBOutlet var takePhotoButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var cameraViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var cameraViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var bottomBarHeightConstraint: NSLayoutConstraint!

    // MARK: State
    var blurView: UIVisualEffectView!

    var session: AVCaptureSession!
    var capturePreviewView: UIView!
    var capturePreviewLayer: AVCaptureVideoPreviewLayer!
    var captureQueue: OperationQueue!
    var imageOrientation: UIImage.Orientation!
    var flashMode: AVCaptureDevice.FlashMode! {
        didSet {
            updateFlashButton()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Default to the flash mode buttons being hidden
        flashModeContainerView.alpha = 0.0

        // Initialise the capture queue
        captureQueue = OperationQueue()

        // Initialise the blur effect used when switching between cameras
        let effect = UIBlurEffect(style: .light)
        blurView = UIVisualEffectView(effect: effect)

        // Listen for orientation changes so that we can update the UI
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged(sender:)), name: UIDevice.orientationDidChangeNotification, object: nil)

        // 3.5" and 4" devices have a smaller bottom bar
        if (UIScreen.main.bounds.size.height <= 568.0) {
            bottomBarHeightConstraint.constant = 91.0
            bottomBarView.layoutIfNeeded()
        }

        // 3.5" devices have the top and bottom bars over the camera view
        if (UIScreen.main.bounds.size.height == 480.0) {
            cameraViewTopConstraint.constant = -self.topBarView.frame.size.height
            cameraViewBottomConstraint.constant = -self.bottomBarView.frame.size.height
            cameraContainerView.layoutIfNeeded()
        }
        
        updateOrientation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        enableCapture()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        captureQueue.cancelAllOperations()
        capturePreviewLayer.removeFromSuperlayer()
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        session.stopRunning()
        session = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let capturePreviewLayer = capturePreviewLayer {
            capturePreviewLayer.frame = cameraContainerView.bounds
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }


    // MARK: - UI

    func toggleFlashModeButtons() {
        UIView.animate(withDuration: 0.3) {
            self.flashModeContainerView.alpha = self.flashModeContainerView.alpha == 1.0 ? 0.0 : 1.0
            self.cameraButton.alpha = self.cameraButton.alpha == 1.0 ? 0.0 : 1.0
        }
    }

    func updateFlashButton() {
        switch flashMode! {
        case .auto:
            flashButton.setImage(UIImage(named: "ic_flash_auto_white"), for: [])
            break

        case .on:
            flashButton.setImage(UIImage(named: "ic_flash_on_white"), for: [])
            break

        case .off:
            flashButton.setImage(UIImage(named: "ic_flash_off_white"), for: [])
            break
        }
    }

    func updateOrientation() {
        let deviceOrientation = UIDevice.current.orientation

        let angle: CGFloat
        switch deviceOrientation {
        case .portraitUpsideDown:
            angle = CGFloat(Double.pi)
            break

        case .landscapeLeft:
            angle = CGFloat(Double.pi / 2)
            break

        case .landscapeRight:
            angle = CGFloat(-Double.pi / 2)
            break

        default:
            angle = 0
            break
        }

        UIView.animate(withDuration: 0.3) {
            self.flashButton.transform = CGAffineTransform(rotationAngle: angle)
            self.flashAutoButton.transform = CGAffineTransform(rotationAngle: angle)
            self.flashOnButton.transform = CGAffineTransform(rotationAngle: angle)
            self.flashOffButton.transform = CGAffineTransform(rotationAngle: angle)
            self.cameraButton.transform = CGAffineTransform(rotationAngle: angle)
            self.openPhotoAlbumButton.transform = CGAffineTransform(rotationAngle: angle)
            self.takePhotoButton.transform = CGAffineTransform(rotationAngle: angle)
            self.cancelButton.transform = CGAffineTransform(rotationAngle: angle)
        }
    }


    // MARK: - Helpers

    func enableCapture() {
        if (session != nil) { return }

        self.flashButton.isHidden = true
        self.cameraButton.isHidden = true

        let operation = captureOperation()
        operation.completionBlock = {
            self.operationCompleted()
        }
        operation.queuePriority = .veryHigh
        captureQueue.addOperation(operation)
    }

    func captureOperation() -> BlockOperation {
        let operation = BlockOperation {
            self.session = AVCaptureSession()
            self.session.sessionPreset = AVCaptureSession.Preset.photo
            guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
                return
            }

            let input: AVCaptureDeviceInput?
            do {
                input = try AVCaptureDeviceInput(device: device)
            } catch {
                input = nil
            }

            if (input == nil) { return }

            self.session.addInput(input!)

            // Turn on point autofocus for middle of view
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }

            if (device.isFocusModeSupported(.autoFocus)) {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .continuousAutoFocus
            }

            if (device.isFlashModeSupported(.auto)) {
                device.flashMode = .auto
            } else {
                device.flashMode = .off
            }
            self.flashMode = device.flashMode

            device.unlockForConfiguration()

            self.capturePreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            self.capturePreviewLayer.frame = self.cameraContainerView.bounds
            self.capturePreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

            // Still Image Output
            let stillOutput = AVCaptureStillImageOutput()
            stillOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            self.session.addOutput(stillOutput)
        }

        return operation
    }

    func operationCompleted() {
        DispatchQueue.main.async {
            if (self.session == nil) { return }
            guard let device = self.currentDevice() else { return }

            self.capturePreviewView = UIView(frame: CGRect.zero)
            self.cameraContainerView.addSubview(self.capturePreviewView)
            self.capturePreviewView.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            self.capturePreviewView.layer.addSublayer(self.capturePreviewLayer)
            self.session.startRunning()
            if (device.hasFlash) {
                self.updateFlashlightState()
                self.flashButton.isHidden = false
            }
            if (UIImagePickerController.isCameraDeviceAvailable(.front) && UIImagePickerController.isCameraDeviceAvailable(.rear)) {
                self.cameraButton.isHidden = false
            }
        }
    }

    func updateFlashlightState() {
        guard let device = currentDevice() else { return }

        flashAutoButton.isSelected = flashMode == .auto
        flashOnButton.isSelected = flashMode == .on
        flashOffButton.isSelected = flashMode == .off

        do {
            try device.lockForConfiguration()
            device.flashMode = self.flashMode
            device.unlockForConfiguration()
        } catch {

        }
    }

    func currentDevice() -> AVCaptureDevice? {
        if (session == nil) { return nil }
        guard let inputDevice = session.inputs.first as? AVCaptureDeviceInput else { return nil }
        return inputDevice.device
    }

    func frontCamera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for device in devices {
            if (device.position == .front) {
                return device
            }
        }

        return nil
    }

    func currentImageOrientation() -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        let imageOrientation: UIImage.Orientation

        let input = session.inputs.first as! AVCaptureDeviceInput
        if (input.device.position == .back) {
            switch (deviceOrientation) {
            case .landscapeLeft:
                imageOrientation = .up
                break

            case .landscapeRight:
                imageOrientation = .down
                break

            case .portraitUpsideDown:
                imageOrientation = .left
                break

            default:
                imageOrientation = .right
                break
            }
        } else {
            switch (deviceOrientation) {
            case .landscapeLeft:
                imageOrientation = .downMirrored
                break

            case .landscapeRight:
                imageOrientation = .upMirrored
                break

            case .portraitUpsideDown:
                imageOrientation = .rightMirrored
                break

            default:
                imageOrientation = .leftMirrored
                break
            }
        }
        
        return imageOrientation
    }

    func takePicture() {
        if (!cameraButton.isEnabled) { return }

        let output = session.outputs.last as! AVCaptureStillImageOutput
        guard let videoConnection = output.connections.last else {
            return
        }

        output.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (imageDataSampleBuffer : CMSampleBuffer?, error : Error?) in
            self.cameraButton.isEnabled = true
            
            if (imageDataSampleBuffer == nil || error != nil) { return }
            
            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
            
            let cgImage: CGImage = UIImage(data: imageData!)!.cgImage!
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: self.currentImageOrientation())
            
            self.handleImage(image: image)
        })

        cameraButton.isEnabled = false
    }

    func handleImage(image: UIImage) {
        let navController: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ImageViewerStoryboardIdentifier") as! UINavigationController

        let viewController: ImageViewerViewController = navController.viewControllers.first as! ImageViewerViewController
        viewController.image = image
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneBarButtonWasTouched(sender:)))

        self.present(navController, animated: true, completion: nil)
    }


    // MARK: - Actions

    @IBAction func flashButtonWasTouched(sender: UIButton) {
        toggleFlashModeButtons()
    }

    @IBAction func flashModeButtonWasTouched(sender: UIButton) {
        if (sender == flashAutoButton) {
            flashMode = .auto
        } else if (sender == flashOnButton) {
            flashMode = .on
        } else {
            flashMode = .off
        }

        updateFlashlightState()
        
        toggleFlashModeButtons()
    }

    @IBAction func cameraButtonWasTouched(sender: UIButton) {
        if (session == nil) { return }
        session.stopRunning()

        // Input Switch
        let operation = BlockOperation {
            var input = self.session.inputs.first as! AVCaptureDeviceInput

            let newCamera: AVCaptureDevice

            if (input.device.position == .back) {
                newCamera = self.frontCamera()!
            } else {
                newCamera = AVCaptureDevice.default(for: AVMediaType.video)!
            }

            // Should the flash button still be displayed?
            DispatchQueue.main.async {
                self.flashButton.isHidden = !newCamera.isFlashAvailable
            }

            // Remove previous camera, and add new
            self.session.removeInput(input)

            do {
                try input = AVCaptureDeviceInput(device: newCamera)
            } catch {
                return
            }
            self.session.addInput(input)
        }
        operation.completionBlock = {
            DispatchQueue.main.async {
                if (self.session == nil) { return }
                self.session.startRunning()
                self.blurView.removeFromSuperview()
            }
        }
        operation.queuePriority = .veryHigh

        // disable button to avoid crash if the user spams the button
        self.cameraButton.isEnabled = false

        // Add blur to avoid flickering
        self.blurView.isHidden = false
        self.capturePreviewView.addSubview(self.blurView)
        self.blurView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })

        // Flip Animation
        UIView.transition(with: self.capturePreviewView, duration: 0.5, options: [.transitionFlipFromLeft, .allowAnimatedContent], animations: nil) { (finished) in
            self.cameraButton.isEnabled = true
            self.captureQueue.addOperation(operation)
        }
    }

    @IBAction func openPhotoAlbumButtonWasTouched(sender: UIButton) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self

        present(imagePickerController, animated: true, completion: nil)
    }

    @IBAction func takePhotoButtonWasTouchedz(sender: UIButton) {
        takePicture()
    }

    @IBAction func cancelButtonWasTouched(sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    @objc func orientationChanged(sender: NSNotification) {
        updateOrientation()
    }

    @objc func doneBarButtonWasTouched(sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

}


// MARK: - UIImagePickerControllerDelegate
extension CameraViewController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        
        dismiss(animated: true) {
            self.handleImage(image: image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

}


// MARK: - UINavigationControllerDelegate
extension CameraViewController: UINavigationControllerDelegate {

}

