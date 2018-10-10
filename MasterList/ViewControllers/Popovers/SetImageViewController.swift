//
//  SetImageViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/14/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import CloudKit
import Flurry_iOS_SDK
import ChameleonFramework
import MBProgressHUD

class SetImageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let privateDatabase = CKContainer.default().privateCloudDatabase
    var currentList: CKRecord?
    let imagePicker = UIImagePickerController()
    let tempURL: URL? = nil
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        
        if let list = currentList {
            if let photo = list["photo"] as? CKAsset {
                imageView.image = UIImage(contentsOfFile: photo.fileURL.path)
            } else {
                imageView.image = #imageLiteral(resourceName: "imagePlaceholder")
            }
        }
    }
    
    @IBAction func selectImageBtnTapped(_ sender: Any) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        present(imagePicker, animated: true, completion: nil)
        
    }
    
    @IBAction func takePhotoBtnTapped(_ sender: UIButton) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = UIImagePickerControllerSourceType.camera
        imagePicker.cameraCaptureMode = .photo
        imagePicker.modalPresentationStyle = .fullScreen
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func cancelBtnTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneBtnTapped(_ sender: Any) {
        
        if let list = currentList {
            let photo = imageView.image
            if let asset = createAsset(from: UIImageJPEGRepresentation(photo!, 1.0)!) {
                list["photo"] = asset as CKRecordValue
            }
    
            privateDatabase.save(list, completionHandler: { (record: CKRecord?, error: Error?) in
                if error == nil {
                    print("photo saved!")
                    Flurry.logEvent("Photo Added")
                    DispatchQueue.main.sync {
                        self.savedAnimation(message: "Image Saved!")
                    }
                    self.dismiss(animated: true, completion: nil)
                } else {
                    print("Error: \(error.debugDescription)")
                    self.showAlert(title: "Unable to save image", message: "Check connection and try again")
                }
            })
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.contentMode = .scaleAspectFit
            imageView.image = pickedImage
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func createAsset(from data: Data) -> CKAsset? {
        var asset: CKAsset? = nil
        let tempStr = ProcessInfo.processInfo.globallyUniqueString
        let fileName = "\(tempStr)_file.bin"
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = baseURL.appendingPathComponent(fileName, isDirectory: false)
        
        do {
            try data.write(to: fileURL, options: .atomicWrite)
            asset = CKAsset(fileURL: fileURL)
            
        } catch {
            print("error creating asset: \(error)")
        }
        return asset
    }
}
