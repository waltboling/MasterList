//
//  RemindersManager.swift
//  MasterList
//
//  Created by Jon Boling on 8/13/18.
//  Copyright © 2018 Walt Boling. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import UserNotifications

class RemindersManager: NSObject, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    let userDefaults = UserDefaults.standard
    static let shared = RemindersManager()
    let userDefaultsKey = "RemindersUserDefaultsKey"
    let notificationCenter = UNUserNotificationCenter.current()
    
    func updateLocation() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    func add(reminder: Reminder) {
        let region = CLCircularRegion(center: reminder.coordinate, radius: CLLocationDistance(reminder.selectedRadius), identifier: reminder.identifier)
        
        if (reminder.notifyOnEntry) {
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            let content = UNMutableNotificationContent()
            content.title = reminder.listTitle
            content.body = "Entering \(reminder.addressName)"
            content.sound = UNNotificationSound.default()
            let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
            let identifier = "\(reminder.listTitle)_\(reminder.addressName)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            notificationCenter.add(request, withCompletionHandler: { (error) in
                if error != nil {
                    print("Something went wrong")
                } else {
                    print("location notification set up successfully 2")
                }
            })
        }
        
        if (reminder.notifyOnExit) {
            region.notifyOnEntry = false
            region.notifyOnExit = true
            
            let content = UNMutableNotificationContent()
            content.title = reminder.listTitle
            content.body = "Exiting \(reminder.addressName)"
            content.sound = UNNotificationSound.default()
            let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
            let identifier = "\(reminder.listTitle)_\(reminder.addressName)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            notificationCenter.add(request, withCompletionHandler: { (error) in
                if error != nil {
                    print("Something went wrong")
                } else {
                    print("location notification set up successfully")
                }
            })
        }
    }
}
