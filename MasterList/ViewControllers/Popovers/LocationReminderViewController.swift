//
//  LocationReminderViewController.swift
//  MasterList
//
//  Created by Jon Boling on 8/13/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import MapKit
import UserNotifications
import CloudKit
import Flurry_iOS_SDK
import ChameleonFramework
import CoreLocation
import MBProgressHUD

protocol HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark)
}

class LocationReminderViewController: UIViewController, UITextFieldDelegate, UISearchBarDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    var currentList: CKRecord?
    var locationManager = CLLocationManager()
    var userLocation: CLLocationCoordinate2D?
    var myAnnotation = MKPointAnnotation()
    var coordinate: CLLocationCoordinate2D?
    var selectedRadius = 0
    let userDefaults = UserDefaults.standard
    let privateDatabase = CKContainer.default().privateCloudDatabase
    var resultSearchController:UISearchController? = nil
    var selectedPin: MKPlacemark? = nil
    let notificationCenter = UNUserNotificationCenter.current()
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var radiusControl: UISegmentedControl!
    @IBOutlet weak var notificationControl: UISegmentedControl!
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationsTable") as! LocationsTableViewController
        resultSearchController = UISearchController(searchResultsController: locationSearchTable)
        resultSearchController?.searchResultsUpdater = locationSearchTable
        
        let searchBar = resultSearchController!.searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = "Search for places"
        navigationItem.titleView = resultSearchController?.searchBar
        let navBar = navigationController?.navigationBar
        navBar?.tintColor = .white
        navBar?.barTintColor = .flatTeal
    
        resultSearchController?.hidesNavigationBarDuringPresentation = false
        resultSearchController?.dimsBackgroundDuringPresentation = true
        definesPresentationContext = true
        
        locationSearchTable.mapView = mapView
        locationSearchTable.handleMapSearchDelegate = self
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge];
        notificationCenter.requestAuthorization(options: options) { (granted, error) in
            if granted {
                print("Accepted permission.")
            } else {
                print("Did not accept permission.")
            }
        }
        
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            if let list = currentList {
                if let radiusIndex = list["radiusIndex"] as! Int? {
                    radiusControl.selectedSegmentIndex = radiusIndex
                }
                if let notifyIndex = list["notifyIndex"] as! Int? {
                    notificationControl.selectedSegmentIndex = notifyIndex
                }
                if let lastLocation = list["location"] as! String? {
                    searchBar.placeholder = lastLocation
                }
                if let coordinateLat = list["coordinateLat"] as! CLLocationDegrees?,
                    let coordinateLong = list["coordinateLong"] as! CLLocationDegrees?{
                    let setLocation = CLLocation(latitude: coordinateLat, longitude: coordinateLong)
                    let tmpRegion = MKCoordinateRegionMake(setLocation.coordinate, MKCoordinateSpanMake(0.03, 0.03))
                    mapView.setRegion(tmpRegion, animated: true)
                    myAnnotation = MKPointAnnotation()
                    myAnnotation.coordinate = setLocation.coordinate
                    myAnnotation.title = searchBar.placeholder
                    mapView.addAnnotation(myAnnotation)
                } else {
                    locationManager.delegate = self
                    locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager.startUpdatingLocation()
                    locationManager.stopUpdatingLocation()
                    mapView.showsUserLocation = true
                }
            }
        }
        addMapTrackingButton()
    }
    
    //if there is already a location reminder, we need to delete the old one
    func deleteOldNotification(){
        if let list = currentList,
            let existingLocation = list["location"] as? String,
            let existingListName = list["listName"] as? String {
            
            print("Checking if notification exists for \(existingLocation)")
            
            let identifier = "\(existingListName)_\(existingLocation)"
            print("DELETING REMINDER: \(identifier)")
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
    
    //update user location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation = locations.last
        let span = MKCoordinateSpanMake(0.1, 0.1)
        let viewRegion = MKCoordinateRegionMake((userLocation?.coordinate)!, span)
        self.mapView.setRegion(viewRegion, animated: true)
        locationManager.stopUpdatingLocation()
    }
    
    //IBActions
    @IBAction func cancelWasTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneButtonWasTapped(_ sender: Any) {
        deleteOldNotification()
        
        let notifyIndex = notificationControl.selectedSegmentIndex
        let notifyOnEntry = (notifyIndex == 0 || notifyIndex == 2)
        let notifyOnExit = (notifyIndex == 1 || notifyIndex == 2)
        let radiusIndex = radiusControl.selectedSegmentIndex
        if radiusIndex == 0 {
            selectedRadius = 100
        } else if radiusIndex == 1 {
            selectedRadius = 200
        } else if radiusIndex == 2 {
            selectedRadius = 500
        } else if radiusIndex == 3 {
            selectedRadius = 1000
        } else {
            print("error getting radius")
        }
        print("selected radius is \(selectedRadius)")
        
        coordinate = myAnnotation.coordinate
        if let coordinate = coordinate, let tmpAddressName = myAnnotation.title {
            print("coordinate is \(coordinate)")
        
            if let list = currentList {
                let reminder = Reminder(coordinate: coordinate, notifyOnEntry: notifyOnEntry, notifyOnExit: notifyOnExit, selectedRadius: selectedRadius, listTitle: list["listName"] as! String, addressName: tmpAddressName)
                RemindersManager.shared.add(reminder: reminder)
                
                list["location"] = tmpAddressName as CKRecordValue?
                list["radius"] = selectedRadius as CKRecordValue?
                list["coordinateLong"] = coordinate.longitude as CKRecordValue? // not quite there yet
                list["coordinateLat"] = coordinate.latitude as CKRecordValue? // not quite there yet
                list["radiusIndex"] = radiusIndex as CKRecordValue?
                list["notifyIndex"] = notifyIndex as CKRecordValue?
            
                if reminder.notifyOnEntry && reminder.notifyOnExit {
                    list["locationDetailLabel"] = "radius: \(reminder.selectedRadius) notify on: Entry & Exit" as CKRecordValue?
                } else if reminder.notifyOnEntry {
                    //detailsLabel += "\nNotify on Entry"
                    list["locationDetailLabel"] = "radius: \(reminder.selectedRadius) notify on: Entry" as CKRecordValue?
                } else {
                    //detailsLabel += "\nNotify on Exit"
                    list["locationDetailLabel"] = "radius: \(reminder.selectedRadius) notify on: Exit" as CKRecordValue?
                }
                
                privateDatabase.save(list, completionHandler: { (record: CKRecord?, error: Error?) in
                    if error == nil {
                        print("location saved!")
                        DispatchQueue.main.async {
                            self.savedAnimation(message: "Location Saved!")
                        }
                        self.dismiss(animated: true, completion: nil)
                        Flurry.logEvent("Location Reminder Added")
                    } else {
                        print("Error: \(error.debugDescription)")
                        self.showAlert(title: "Unable to save location", message: "Check connection and try again")
                    }
                })
            }
        }
    }
    
    func addMapTrackingButton(){
        let image = #imageLiteral(resourceName: "mapTrackerIcon")
        let button   = UIButton(type: UIButtonType.custom) as UIButton
        button.frame = CGRect(origin: CGPoint(x:5, y: 25), size: CGSize(width: 40, height: 40))
        button.setImage(image, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(self.centerMapOnUserButtonClicked), for:.touchUpInside)
        mapView.addSubview(button)
    }
    
    @objc func centerMapOnUserButtonClicked() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
        }
    }
}

//funcs to help with debugging:
func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("Monitoring failed for region with identifier: \(region!.identifier)")
}

func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location Manager failed with the following error: \(error)")
}

extension LocationReminderViewController: HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark){
        // cache the pin
        selectedPin = placemark
        
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        
        myAnnotation = MKPointAnnotation()
        myAnnotation.coordinate = placemark.coordinate
        myAnnotation.title = placemark.name
        if let city = placemark.locality,
            let state = placemark.administrativeArea {
            myAnnotation.subtitle = "\(city) \(state)"
        }
        mapView.addAnnotation(myAnnotation)
        
        let span = MKCoordinateSpanMake(0.03, 0.03)
        let region = MKCoordinateRegionMake(placemark.coordinate, span)
        mapView.setRegion(region, animated: true)
    }
}


