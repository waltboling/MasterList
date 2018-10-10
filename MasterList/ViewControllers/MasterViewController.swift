//
//  ViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/3/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//
import UIKit
import CloudKit
import ChameleonFramework
import Flurry_iOS_SDK
import GoogleMobileAds
import MBProgressHUD
import UserNotifications

class MasterViewController: UIViewController, UITextFieldDelegate, GADBannerViewDelegate {
    
    fileprivate var collapseDetailViewController = true
    var masterLists = [CKRecord]()
    var refresh = UIRefreshControl()
    var detailController: SublistViewController?
    var hud = MBProgressHUD()
    var bannerView: GADBannerView!
    let colors: [UIColor] = [
        UIColor.flatTeal,
        UIColor.flatTeal,
        UIColor.flatMintDark
    ]
    let notificationCenter = UNUserNotificationCenter.current()
    
    //IB Outlets
    @IBOutlet weak var masterTableView: UITableView!
    @IBOutlet weak var logOutBtn: UIBarButtonItem!
    @IBOutlet weak var inputNewList: UITextField!
    @IBOutlet weak var addListBtn: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureVisual()
        configureAds()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load Lists")
        refresh.addTarget(self, action: #selector(MasterViewController.loadLists), for: .valueChanged)
        
        masterTableView.addSubview(refresh)
        
        if let indexPath = masterTableView.indexPathForSelectedRow {
            masterTableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hud = loadingAnimation()
        
        splitViewController?.delegate = self
        self.inputNewList.delegate = self
        
        loadLists()
    }
    
    //for AdMob banner
    func configureAds() {
        bannerView = GADBannerView(adSize: kGADAdSizeBanner)
        addBannerViewToView(bannerView)
        bannerView.adUnitID = "ca-app-pub-3684839275222485/8331042439"
        bannerView.rootViewController = self
        let request = GADRequest()
        request.testDevices = [kGADSimulatorID]
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
    
    //IB funcs
    @IBAction func addListWasTapped(_ sender: Any) {
        inputNewList.resignFirstResponder()
        masterListWasEntered()
    }
    
    @IBAction func logOutWasTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func configureVisual() {
        //background
        masterTableView.backgroundColor = .clear
        view.backgroundColor = .white
        
        //navigation bar
        let navBar = self.navigationController?.navigationBar
        navBar?.tintColor = .white
        navBar?.barTintColor = GradientColor(.topToBottom, frame: (view.frame), colors: colors)
        navBar?.titleTextAttributes = [NSAttributedStringKey.font: UIFont(name:"Quicksand-Bold", size: 18)!, .foregroundColor: UIColor.white]
        self.navigationItem.title = "Master Lists"
        
         addListBtn.tintColor = UIColor.flatOrangeDark
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        inputNewList.resignFirstResponder()
        masterListWasEntered()
        return true
    }
    
    func masterListWasEntered() {
        if inputNewList.text != "" {
            let newMaster = CKRecord(recordType: "masterLists")
            newMaster["listName"] = inputNewList.text as CKRecordValue?
            let privateDatabase = CKContainer.default().privateCloudDatabase
            
            privateDatabase.save(newMaster, completionHandler: {(record: CKRecord?, error: Error?) in
                if error == nil {
                    print("list saved")
                    DispatchQueue.main.async(execute: {
                        self.masterTableView.beginUpdates()
                        self.masterLists.insert(newMaster, at: 0)
                        let indexPath = IndexPath(row: 0, section: 0)
                        self.masterTableView.insertRows(at: [indexPath], with: .top)
                        self.masterTableView.endUpdates()
                    })
                } else {
                    print("Error: \(error.debugDescription)")
                    self.showAlert(title: "Unable to save list", message: "Check connection and try again")
                }
            })
        } else {
            inputNewList.shake()
        }
        
        inputNewList.text = ""
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == DataStructs.toSublist {
            if let indexPath = self.masterTableView.indexPathForSelectedRow {
                let currentMasterList = masterLists[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! SublistViewController
                controller.masterList = currentMasterList
            }
        }
    }

    @objc func loadLists() {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "MasterLists", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        //check for internet connection
        if ConnectionManager.shared.testConnection() {
            if ConnectionManager.shared.testCloudKit() {
                privateDatabase.perform(query, inZoneWith: nil) { (results: [CKRecord]?, error: Error?) in
                    if let lists = results {
                        self.masterLists = lists
                        DispatchQueue.main.async(execute: {
                            self.masterTableView.reloadData()
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

extension MasterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: DataStructs.toSublist, sender: self)
    }
}

extension MasterViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return masterLists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let masterCell = tableView.dequeueReusableCell(withIdentifier: DataStructs.masterCell, for: indexPath)
        let masterList = masterLists[indexPath.row]
        
        if let masterListName = masterList["listName"] as? String {
            masterCell.textLabel?.text = masterListName
        }
        
        masterCell.backgroundColor = .clear
        masterCell.textLabel?.font = UIFont(name:"Quicksand-Regular", size: 20)
        masterCell.textLabel?.textColor = GradientColor(.topToBottom, frame: view.frame, colors: colors)
        
        //let chevronGray = UIImage(named: "chevronIconGray")
            // gray would be for future versions in order to show if a list has a sublist or not
        let chevronBlue = UIImage(named: "chevronIconColor")
        masterCell.accessoryView = UIImageView(image: chevronBlue!)
        masterCell.accessoryView?.contentMode = .scaleAspectFit
        
        return masterCell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let list = masterLists[indexPath.row]
            let selectedRecordID = list.recordID
            let privateDatabase = CKContainer.default().privateCloudDatabase
            
            //deleting location notification when list is deleted
            deleteLocReminder(list: list)
            
            //delete deadline when list is deleted
            deleteDeadline(list: list) //not working
            
            deleteChildAlerts(list: list, listType: "sublists")
            
            privateDatabase.delete(withRecordID: selectedRecordID) { (recordID, error) -> Void in
                if error != nil {
                    print(error!)
                } else {
                    OperationQueue.main.addOperation({ () -> Void in
                        self.masterLists.remove(at: indexPath.row)
                        self.masterTableView.reloadData()
                    })
                }
            }
        }
    }
    
    func deleteChildAlerts(list: CKRecord, listType: String){
        let query: CKQuery!
        //test connection
        if ConnectionManager.shared.testConnection() {
            if ConnectionManager.shared.testCloudKit() {
                let privateDatabase = CKContainer.default().privateCloudDatabase
                let reference = CKReference(recordID: list.recordID, action: .deleteSelf)
                if (listType == "sublists"){
                    query = CKQuery(recordType: "sublists", predicate: NSPredicate(format: "masterList == %@", reference))
                }
                else{
                    query = CKQuery(recordType: "detailItems", predicate: NSPredicate(format: "sublist == %@", reference))
                }
                
                privateDatabase.perform(query, inZoneWith: nil) { (results: [CKRecord]?, error: Error?) in
                    if let items = results {
                        for childList in items {
                            self.deleteDeadline(list: childList)
                            self.deleteLocReminder(list: childList)
                            
                            //call it again for the items below this as there are three levels of lists
                            self.deleteChildAlerts(list: childList, listType: "detailItems")
                        }
                    }
                }
            }
        }
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
}

extension MasterViewController: UISplitViewControllerDelegate {
    //so that masterview comes up instead of detail on app load
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return collapseDetailViewController
    }
}


