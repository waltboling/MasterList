//
//  PopoverMenuTableViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/13/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import CloudKit
import Flurry_iOS_SDK
import ChameleonFramework
import MBProgressHUD

class PopoverMenuTableViewController: UITableViewController, UITextViewDelegate {
    
    var currentList: CKRecord?
    let privateDatabase = CKContainer.default().privateCloudDatabase
    let notePlaceholderText = "Click to add note here..."

    //IB Outlets
    @IBOutlet weak var photoLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var locationDetailLabel: UILabel!
    @IBOutlet weak var displayNotesTextView: UITextView!{
        didSet {
            displayNotesTextView.addDoneCancelToolbar()
        }
    }
    @IBOutlet weak var notesTextView: UITextView! {
        didSet {
            notesTextView.addDoneCancelToolbar()
        }
    }
    
    @IBOutlet weak var noteSavedLabel: UILabel!
    @IBOutlet weak var deadlineLabel: UILabel!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var saveNoteButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        animateTable()
        self.navigationItem.title = "Reminders"
        notesTextView.delegate = self
        noteSavedLabel.alpha = 0
        
        if let list = currentList {
            if let note = list["note"] as? String {
                self.notesTextView.text = note
            } else {
                self.notesTextView?.text = notePlaceholderText
                self.notesTextView?.textColor = .gray
            }
        }
        
        notesTextView.addDoneCancelToolbar(onDone: (target: self, action: #selector(saveNote)), onCancel: (target: self, action: #selector(cancelNote)))
        
        saveNoteButton.backgroundColor = .flatTeal
        noteSavedLabel.textColor = .flatTeal
    }
   
    override func viewWillAppear(_ animated: Bool) {
        if let list = currentList {
            let listName = list["listName"] as? String
            if let note = list["note"] as? String {
                 self.notesTextView.text = note
            } else {
                self.notesTextView?.text = notePlaceholderText
                self.notesTextView?.textColor = .gray
            }
            
            if let deadline = list["deadline"] as? String {
            self.deadlineLabel.text = deadline
            } else {
                self.deadlineLabel.text = "Click to add deadline"
                self.deadlineLabel.textColor = .gray
            }
            
            if let location = list["location"] as? String {
            self.locationLabel.text = location
                self.locationDetailLabel.text = list["locationDetailLabel"] as? String
                self.locationDetailLabel.textColor = .flatMintDark
            } else {
                self.locationLabel.text = "Click pin to add location"
                self.locationLabel.textColor = .gray
                self.locationDetailLabel.text = ""
            }
            
            if let photo = list["photo"] as? CKAsset {
                self.photoButton.titleLabel?.isHidden = true
                self.photoButton.setBackgroundImage(UIImage(contentsOfFile: (photo.fileURL.path)), for: .normal)
                self.photoButton.layoutIfNeeded()
                self.photoButton.subviews.first?.contentMode = .scaleAspectFill
                self.photoLabel.text = listName! + "_img"
            } else {
                self.photoButton.setBackgroundImage(#imageLiteral(resourceName: "imagePlaceholder"), for: .normal)
                self.photoLabel.textColor = .gray
            }
        }
    }

    //next two methods create a placeholder text for textview
    func textViewDidBeginEditing(_ textView: UITextView) {
        tableView.setContentOffset(CGPoint(x: 0, y: 180), animated: true)
        if notesTextView.text == notePlaceholderText {
            notesTextView.text = ""
            notesTextView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        tableView.setContentOffset(CGPoint(x: 0, y: -80), animated: true)
        if notesTextView.text.isEmpty {
            notesTextView.text = notePlaceholderText
            notesTextView.textColor = UIColor.gray
        }
        
    }
    
    @IBAction func saveNoteWasTapped(_ sender: Any) {
        saveNote()
    }
    
    @objc func saveNote() {
        if let list = currentList {
            if notesTextView.text != nil {
                list["note"] = notesTextView.text as CKRecordValue?
                privateDatabase.save(list, completionHandler: { (record: CKRecord?, error: Error?) in
                    if error == nil {
                        print("note saved!")
                        
                        DispatchQueue.main.sync {
                            self.notesTextView.resignFirstResponder()
                            self.savedAnimation(message: "Note Saved!")
                        }
                    } else {
                        print("Error: \(error.debugDescription)")
                        self.showAlert(title: "Unable to save note", message: "Check connection and try again")
                    }
                })
            }
        }
    }
    
    @objc func cancelNote() {
        notesTextView.resignFirstResponder()
    }
    
    //animation functions
    
    /*func savedAnimation() {
        notesTextView.resignFirstResponder()
        let window = UIApplication.shared.keyWindow
        let hud = MBProgressHUD.showAdded(to: window!, animated: true)
        hud.mode = .customView
        hud.customView = UIImageView(image: UIImage(named: "checkmarkIcon"))
        hud.label.text = "Note Saved!"
        hud.hide(animated: true, afterDelay: 1.0)
    }*/
    
    func animateTable() {
        tableView.reloadData()
        let cells = tableView.visibleCells
        let tableViewHeight = tableView.bounds.size.height
        
        
        for cell in cells {
            cell.transform = CGAffineTransform(translationX: 0, y: tableViewHeight)
        }
        
        var delayCounter = 0.0
        for cell in cells {
            UIView.animate(withDuration: 1.20, delay: delayCounter * 0.05, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
                cell.transform = CGAffineTransform.identity
            }, completion: nil)
            delayCounter += 1
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case DataStructs.toPhotoPicker:
            let controller = segue.destination as! SetImageViewController
            controller.currentList = currentList
            controller.transitioningDelegate = self
        case DataStructs.toLocation:
            let controller = segue.destination as! UINavigationController
            let target = controller.topViewController as! LocationReminderViewController
            target.currentList = currentList
            controller.transitioningDelegate = self
        case DataStructs.toDeadline:
            let controller = segue.destination as! SetDeadlineViewController
            controller.currentList = currentList
            controller.transitioningDelegate = self
        default:
            print("could not find segue identifier")
        }
    }
}

// MARK: - Table view data source (static cells currently set in storyboard)

//MARK: - custom transition extension

extension PopoverMenuTableViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentAnimator()
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissAnimator()
    }
}



