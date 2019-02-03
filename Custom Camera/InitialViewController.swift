//
//  ViewController.swift
//  Custom Camera (Swift)
//
//  Created by Chris Leversuch on 03/07/2016.
//  Copyright © 2016 Brightec. All rights reserved.
//

import UIKit


class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func showNativeCamera() {
        if (!UIImagePickerController.isSourceTypeAvailable(.camera)) {
            showNoCameraError()
            return
        }

        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .camera
        imagePickerController.delegate = self

        present(imagePickerController, animated: true, completion: nil);
    }

    func showCustomCamera() {
        if (!UIImagePickerController.isSourceTypeAvailable(.camera)) {
            showNoCameraError()
            return
        }

        let cameraViewController: CameraViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraStoryboardIdentifier") as! CameraViewController
        present(cameraViewController, animated: true, completion: nil)
    }

    func showNoCameraError() {
        let alertController = UIAlertController(title: "Error", message: "Your device doesn't have a camera", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    // MARK: - Actions
    @IBAction func showNativeCameraButtonWasTouched(sender: UIButton) {
        showNativeCamera()
    }

    @IBAction func showCustomCameraButtonWasTouched(sender: UIButton) {
        showCustomCamera()
    }

    @objc func doneBarButtonWasTouched(sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

}


// MARK: - UIImagePickerControllerDelegate
extension InitialViewController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image: UIImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage;
        
        dismiss(animated: true) {
            let navController: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ImageViewerStoryboardIdentifier") as! UINavigationController
            
            let viewController: ImageViewerViewController = navController.viewControllers.first as! ImageViewerViewController
            viewController.image = image
            viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneBarButtonWasTouched(sender:)))
            
            self.present(navController, animated: true, completion: nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

}


// MARK: - UINavigationControllerDelegate
extension InitialViewController: UINavigationControllerDelegate {
}

