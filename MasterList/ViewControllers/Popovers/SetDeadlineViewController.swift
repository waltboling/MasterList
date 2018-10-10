//
//  SetDeadlineViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/14/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import UserNotifications
import CloudKit
import Flurry_iOS_SDK
import MBProgressHUD

class SetDeadlineViewController: UIViewController {
    
    let notificationCenter = UNUserNotificationCenter.current()
    var dateFormatter = DateFormatter()
    var currentList: CKRecord?
    let privateDatabase = CKContainer.default().privateCloudDatabase
    var reminderInterval: Int?
    
    
    //IB Outlets
    @IBOutlet weak var reminderOptions: UISegmentedControl!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var deadlineLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //request notification authorization
        let options: UNAuthorizationOptions = [.alert, .sound, .badge];
        
        notificationCenter.requestAuthorization(options: options) { (granted, error) in
            if granted {
                print("Accepted permission.")
            } else {
                print("Did not accept permission.")
            }
        }
        
        titleLabel.textColor = UIColor.darkGray
        titleLabel.font = UIFont(name:"Quicksand-Regular", size: 36)
        
        //default the value to record value or current time
        if let list = currentList {
            let deadlineDateFormatter = DateFormatter()
            deadlineDateFormatter.dateFormat = "MM/dd/yy, hh:mm a"
            if let deadlineValue = list["deadline"] as? String {
                deadlineLabel.text = deadlineValue
                if let dataDate = deadlineDateFormatter.date(from: deadlineValue) {
                    datePicker.date = dataDate
                }
                if let deadlineIndex = list["deadlineIndex"] as? Int {
                    reminderOptions.selectedSegmentIndex = deadlineIndex
                }
            }
            else {
                deadlineLabel.text = deadlineDateFormatter.string(from: NSDate() as Date)
            }
        }
    }
    
    //IB Actions
    @IBAction func DeadlineWasSet(_ sender: UIDatePicker) {
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        deadlineLabel.text = dateFormatter.string(from: sender.date)
    }
    
    @IBAction func doneBtnWasTapped(_ sender: Any) {
        deleteOldNotification()
        configureNotification()
        
        if let list = currentList {
            list["deadline"] = deadlineLabel.text as CKRecordValue?
            list["deadlineIndex"] = reminderOptions.selectedSegmentIndex as CKRecordValue?
            
            privateDatabase.save(list, completionHandler: { (record: CKRecord?, error: Error?) in
                if error == nil {
                    print("deadline saved!")
                    Flurry.logEvent("Deadline Added")
                    DispatchQueue.main.async {
                        self.savedAnimation(message: "Deadline Saved!")
                    }
                    self.dismiss(animated: true, completion: nil)
                } else {
                    print("Error: \(error.debugDescription)")
                    self.showAlert(title: "Unable to save deadline", message: "Check connection and try again")
                }
            })
        }
    }
    
    @IBAction func cancelBtnWasTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    
    //if there is already a deadline, we need to delete the old one
    func deleteOldNotification(){
        if let existingDeadline = currentList!["deadline"] as? String,
            let currentListValue = currentList!["listName"] as? String {
            print("Checking if notification exists for \(existingDeadline)")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yy, hh:mm a"
            var deadlineDate : Date!
            
            if let dataDate = dateFormatter.date(from: existingDeadline),
                let existingIndex = currentList!["deadlineIndex"] as? Int {
                switch existingIndex{
                case 1:
                    deadlineDate = Calendar.current.date(byAdding: .hour, value: -1, to: dataDate)!
                case 2:
                    deadlineDate = Calendar.current.date(byAdding: .hour, value: -2, to: dataDate)!
                case 3:
                    deadlineDate = Calendar.current.date(byAdding: .day, value: -1, to: dataDate)!
                default:
                    deadlineDate = dataDate
                }
                
                let identifier = "\(currentListValue)_\(dateFormatter.string(from: deadlineDate))"
                print("DELETING REMINDER: \(identifier)")
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
                //printPendingRequests()
            }
        }
    }
    
    //method for troubleshooting and debugging
    func printPendingRequests(){
        notificationCenter.getPendingNotificationRequests(completionHandler: { requests in
            for request in requests {
                print(request)
            }
        })
    }
    
    func configureNotification() {
        let content = UNMutableNotificationContent()
        content.title = "You have tasks due"
        
        content.sound = UNNotificationSound.default()
        
        var reminderDate = Date()
     
        switch reminderOptions.selectedSegmentIndex {
        case 0:
            //print("Remind is set for the deadline date time")
            reminderInterval = 0
        case 1:
            reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: datePicker.date)!
            reminderInterval = 1
        case 2:
            reminderDate = Calendar.current.date(byAdding: .hour, value: -2, to: datePicker.date)!
            reminderInterval = 2
        case 3:
            reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: datePicker.date)!
            reminderInterval = 24
        default:
            print("error setting deadline")
        }
        
        let triggerDate =  Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        
        if reminderInterval! > 1 {
            content.body = "\(currentList!["listName"] as! String) due in \(reminderInterval!) hours"
        } else {
            content.body = "\(currentList!["listName"] as! String) due in \(reminderInterval!) hour"
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        if let currentListValue = currentList!["listName"] as? String {
            dateFormatter.dateFormat = "MM/dd/yy, hh:mm a"
            let identifier = "\(currentListValue)_\(dateFormatter.string(from: reminderDate))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            notificationCenter.add(request, withCompletionHandler: { (error) in
                if error != nil {
                    print("Something went wrong")
                } else {
                    print("NOTIFICATION ADDED :  \(identifier)")
                }
            })
        }
        //printPendingRequests()
    }
}
