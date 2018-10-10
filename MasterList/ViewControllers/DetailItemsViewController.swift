//
//  DetailItemsViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/4/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import CloudKit
import ChameleonFramework
import Flurry_iOS_SDK
import GoogleMobileAds
import MBProgressHUD
import UserNotifications

class DetailItemsViewController: UIViewController, UITextFieldDelegate, GADBannerViewDelegate {
    
    var sublist: CKRecord?
    var detailItems = [CKRecord]()
    var longPressGesture = UIGestureRecognizer()
    var bannerView: GADBannerView!
    var refresh = UIRefreshControl()
    let notificationCenter = UNUserNotificationCenter.current()
    var hud = MBProgressHUD()
    
    //IB Outlets
    @IBOutlet weak var detailItemsTableView: UITableView!
    @IBOutlet weak var addItemBtn: UIButton!
    @IBOutlet weak var inputDetailItems: UITextField!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        hud = loadingAnimation()
        
        loadLists()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load Lists")
        refresh.addTarget(self, action: #selector(self.loadLists), for: .valueChanged)
        detailItemsTableView.addSubview(refresh)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureAds()
        inputDetailItems.delegate = self
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(recognizer:)))
        
        addItemBtn.tintColor = UIColor.flatOrangeDark
        detailItemsTableView.addGestureRecognizer(longPressGesture)
    }
    
    @objc func loadLists() {
        if let sublist = sublist {
            self.navigationItem.title = sublist["listName"] as? String
            
            let privateDatabase = CKContainer.default().privateCloudDatabase
            let reference = CKReference(recordID: sublist.recordID, action: .deleteSelf)
            let query = CKQuery(recordType: "detailItems", predicate: NSPredicate(format:"sublist == %@", reference))
            
            //test connection
            if ConnectionManager.shared.testConnection() {
                if ConnectionManager.shared.testCloudKit() {
                    privateDatabase.perform(query, inZoneWith: nil) { (results: [CKRecord]?, error: Error?) in
                        if let items = results {
                            self.detailItems = items
                            DispatchQueue.main.async(execute: {
                                self.detailItemsTableView.reloadData()
                                self.refresh.endRefreshing()
                                self.hud.hide(animated: true)
                            })
                        }
                    }
                } else {
                    hud.hide(animated: true)
                    showAlert(title: "iCloud Not Working", message: "Enable iCloud to Continue")
                }
            } else {
               hud.hide(animated: true)
                showAlert(title: "No Internet Connection Detected", message: "Connect to Internet or try again later")
            }
        }
    }
    
    func configureAds() {
        
        bannerView = GADBannerView(adSize: kGADAdSizeBanner)
        addBannerViewToView(bannerView)
        //real ads
        bannerView.adUnitID = "ca-app-pub-3684839275222485/8331042439"
        bannerView.rootViewController = self
        let request = GADRequest()
        //request.testDevices = [kGADSimulatorID]
        bannerView.load(request)
        bannerView.delegate = self
    }
    
    func addBannerViewToView(_ bannerView: GADBannerView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bannerView)
        self.view.addConstraints(
            [NSLayoutConstraint(item: bannerView,
                                attribute: .bottom,
                                relatedBy: .equal,
                                toItem: self.view.safeAreaLayoutGuide,
                                attribute: .bottom,
                                multiplier: 1,
                                constant: 0),
             NSLayoutConstraint(item: bannerView,
                                attribute: .centerX,
                                relatedBy: .equal,
                                toItem: self.view,
                                attribute: .centerX,
                                multiplier: 1,
                                constant: 0)
            ])
    }
    
    @IBAction func addItemWasTapped(_ sender: Any) {
        inputDetailItems.resignFirstResponder()
        detailItemWasAdded()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        inputDetailItems.resignFirstResponder()
        detailItemWasAdded()
        return true
    }
    
    func detailItemWasAdded() {
        if inputDetailItems.text != "" {
            let newDetailList = CKRecord(recordType: "detailItems")
            newDetailList["listName"] = inputDetailItems.text as CKRecordValue?
            
            if let list = self.sublist {
                let reference = CKReference(recordID: list.recordID, action: .deleteSelf)
                newDetailList.setObject(reference, forKey: "sublist")
                let privateDatabase = CKContainer.default().privateCloudDatabase
                
                privateDatabase.save(newDetailList, completionHandler: { (record: CKRecord?, error: Error?) in
                    if error == nil {
                        print("list saved")
                        DispatchQueue.main.async(execute: {
                            self.detailItemsTableView.beginUpdates()
                            self.detailItems.insert(newDetailList, at: 0)
                            let indexPath = IndexPath(row: 0, section: 0)
                            self.detailItemsTableView.insertRows(at: [indexPath], with: .top)
                            self.detailItemsTableView.endUpdates()
                        })
                    } else {
                        print("Error: \(error.debugDescription)")
                        self.showAlert(title: "Unable to save list", message: "Check connection and try again")
                    }
                })
            }
        } else {
            inputDetailItems.shake()
        }
        
        inputDetailItems.text = ""
    }
    
    @objc func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        if longPressGesture.state == UIGestureRecognizerState.began {
            performSegue(withIdentifier: DataStructs.toDetailMenu, sender: self)
            Flurry.logEvent("Segued to Detail List Reminders")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == DataStructs.toDetailMenu {
            let touchPoint = longPressGesture.location(in: self.detailItemsTableView)
            if let indexPath = self.detailItemsTableView.indexPathForRow(at: touchPoint) {
                let currentDetailItem = detailItems[indexPath.row]
                let controller = (segue.destination as! PopoverMenuTableViewController)
                controller.currentList = currentDetailItem
            } else if let indexPath = self.detailItemsTableView.indexPathForSelectedRow {
                let currentDetailItem = detailItems[indexPath.row]
                let controller = (segue.destination as! PopoverMenuTableViewController)
                controller.currentList = currentDetailItem
            } //for now longpress and select perform same function
        }
    }
}

extension DetailItemsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: DataStructs.toDetailMenu, sender: self)
    }
    
}

extension DetailItemsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detailItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let detailCell = tableView.dequeueReusableCell(withIdentifier: DataStructs.detailCell, for: indexPath)
        let detailItem = detailItems[indexPath.row]
        
        if let itemName = detailItem["listName"] as? String {
            detailCell.textLabel?.text = itemName
            detailCell.backgroundColor = .clear
            detailCell.textLabel?.textColor = UIColor.flatTeal
            detailCell.textLabel?.font = UIFont(name: "Quicksand-Regular", size: 16)
        }
        
        detailCell.detailTextLabel?.text = ""
        if detailItem["photo"] != nil {
            detailCell.detailTextLabel?.text = "Image"
        }
        if detailItem["deadline"] != nil {
            if let strText = detailCell.detailTextLabel?.text {
                if (strText != "") {
                    detailCell.detailTextLabel?.text = strText + " | "
                }
            }
            detailCell.detailTextLabel?.text! += "Deadline"
        }
        if detailItem["location"] != nil {
            if let strText = detailCell.detailTextLabel?.text {
                if (strText != "") {
                    detailCell.detailTextLabel?.text = strText + " | "
                }
            }
            detailCell.detailTextLabel?.text! += "Location"
        }
        if detailItem["note"] != nil {
            if let strText = detailCell.detailTextLabel?.text {
                if (strText != "") {
                    detailCell.detailTextLabel?.text = strText + " | "
                }
            }
            detailCell.detailTextLabel?.text! += "Note"
        }
        
        return detailCell
    }
    
    func deleteLocReminder(list: CKRecord) {
        if let existingListName = list["listName"] as? String {
            if let existingLocation = list["location"] as? String {
                
                print("Checking if notification exists for \(existingLocation)")
                
                let identifier = "\(existingListName)_\(existingLocation)"
                print("DELETING REMINDER: \(identifier)")
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        }
    }
    
    func deleteDeadline(list: CKRecord) {
        if let existingDeadline = list["deadline"] as? String,
            let currentListValue = list["listName"] as? String {
            print("Checking if notification exists for \(existingDeadline)")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yy, hh:mm a"
            var deadlineDate : Date!
            
            if let dataDate = dateFormatter.date(from: existingDeadline),
                let existingIndex = list["deadlineIndex"] as? Int {
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
            }
        }
    }
    
    //deleting a cell
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let list = detailItems[indexPath.row]
            let selectedRecordID = list.recordID
            
            //deleting location notification when list is deleted
            deleteLocReminder(list: list)
            
            //delete deadline when list is deleted
            deleteDeadline(list: list) //not working
            
            let privateDatabase = CKContainer.default().privateCloudDatabase
            
            privateDatabase.delete(withRecordID: selectedRecordID) { (recordID, error) -> Void in
                if error != nil {
                    print(error!)
                } else {
                    OperationQueue.main.addOperation({ () -> Void in
                        self.detailItems.remove(at: indexPath.row)
                        self.detailItemsTableView.reloadData()
                    })
                }
            }
        }
    }
    
    /// Tells the delegate an ad request loaded an ad.
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("adViewDidReceiveAd")
    }
    
    /// Tells the delegate an ad request failed.
    func adView(_ bannerView: GADBannerView,
                didFailToReceiveAdWithError error: GADRequestError) {
        print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
    }
    
    /// Tells the delegate that a full-screen view will be presented in response
    /// to the user clicking on an ad.
    func adViewWillPresentScreen(_ bannerView: GADBannerView) {
        print("adViewWillPresentScreen")
    }
    
    /// Tells the delegate that the full-screen view will be dismissed.
    func adViewWillDismissScreen(_ bannerView: GADBannerView) {
        print("adViewWillDismissScreen")
    }
    
    /// Tells the delegate that the full-screen view has been dismissed.
    func adViewDidDismissScreen(_ bannerView: GADBannerView) {
        print("adViewDidDismissScreen")
    }
    
    /// Tells the delegate that a user click will open another app (such as
    /// the App Store), backgrounding the current app.
    func adViewWillLeaveApplication(_ bannerView: GADBannerView) {
        print("adViewWillLeaveApplication")
    }
}
