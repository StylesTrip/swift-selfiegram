//
//  MasterViewController.swift
//  Selfiegram
//
//  Created by Ryan Turinsky on 1/10/19.
//  Copyright © 2019 Ryan Turinsky. All rights reserved.
//

import UIKit
import CoreLocation

class SelfieListViewController: UITableViewController {

    var detailViewController: SelfieDetailViewController? = nil
    var selfies : [Selfie] = []
    var lastLocation : CLLocation?
    let locationManager = CLLocationManager()
    
    // The formatter for creating the "1 minute ago"-style label
    let timeIntervalFormatter : DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.maximumUnitCount = 1
        return formatter
    } ()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        // Load the list of selfies from the selfie store
        do {
            // Get the list of photos, sorted by date (newer first)
            selfies = try SelfieStore.shared.listSelfies()
                .sorted(by: { $0.created > $1.created })
        } catch let error {
            showError(message: "Failed to load selfies: \(error.localizedDescription)")
        }
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count - 1]
            as? UINavigationController)?.topViewController
            as? SelfieDetailViewController
        }
        
        // Displays the plus button to add a new selfie
        let addSelfieButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewSelfie))
        navigationItem.rightBarButtonItem = addSelfieButton
    }
    
    @objc func createNewSelfie() {
        // Clear the last location
        lastLocation = nil
        
        // Handle our auth status
        switch CLLocationManager.authorizationStatus() {
        case .denied, .restricted: //Not permitted, give up
            return
        case .notDetermined: //Don't know if we have permission
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
        locationManager.requestLocation()
        
        let imagePicker = UIImagePickerController()
        
        // If a camera is available, use it; otherwise, use photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            
            // If the front-facing camera is available, use that
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                imagePicker.cameraDevice = .front
            }
        } else {
            imagePicker.sourceType = .photoLibrary
        }
        
        // We want this object to be notified when the user takes a photo
        imagePicker.delegate = self
        
        // Present the image picker
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    // Called when we tap on a row.
    // The SelfieDetailViewController is given the photo.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let selfie = selfies[indexPath.row]
                
                if let controller = (segue.destination as? UINavigationController)?.topViewController as? SelfieDetailViewController {
                    controller.selfie = selfie
                    controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                    controller.navigationItem.leftItemsSupplementBackButton = true
                }
            }
        }
    }
    
    func showError(message : String) {
        // Create an alert controller, with the message we received
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        
        // Add an action to it - it won't do anything, but
        // doing this means that it will have a button to dismiss it
        let action = UIAlertAction(title: "OK",
                                   style: .default,
                                   handler: nil)
        alert.addAction(action)
        
        // Show the alert and its message
        self.present(alert, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
        
        // Reload all data in the table view
        tableView.reloadData()
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selfies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Get a cell from the table view
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        // Get a selfie and use it to configure the cell
        let selfie = selfies[indexPath.row]
        
        // Set up the main label
        cell.textLabel!.text = selfie.title
        
        // Set up its time ago sublabel
        if let interval = timeIntervalFormatter.string(from: selfie.created, to: Date()) {
            cell.detailTextLabel?.text = "\(interval) ago"
        } else {
            cell.detailTextLabel?.text = nil
        }
        
        // Show the selfie image to the left of the cell
        cell.imageView?.image = selfie.image
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // If this was a deletion, we have deleting to do
        if editingStyle == .delete {
            // Get the object from the content array
            let selfieToRemove = selfies[indexPath.row]
            
            // Attempt to delete the selfie
            do {
                try SelfieStore.shared.delete(selfie: selfieToRemove)
                
                // Remove it from the array
                selfies.remove(at: indexPath.row)
                
                // Remove the entry from the table view
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                let title = selfieToRemove.title
                showError(message: "Failed to delete \(title).")
            }
        }
    }
    
    // called when the user cancels selecting an image
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // called when the user has finished selecting an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
            ?? info[UIImagePickerController.InfoKey.originalImage] as? UIImage
            else {
                let message = "Couldn't get a picture from the image picker!"
                showError(message: message)
                return
        }
        
        self.newSelfieTaken(image: image)
        
        // Get rid of the view controller
        self.dismiss(animated: true, completion: nil)
    }
    
    func newSelfieTaken(image : UIImage) {
        let newSelfie = Selfie(title: "New Selfie")
        
        newSelfie.image = image
        
        if let location = self.lastLocation {
            newSelfie.position = Selfie.Coordinate(location: location)
        }
        
        // Attempt to save the photo
        do {
            try SelfieStore.shared.save(selfie: newSelfie)
        } catch let error {
            showError(message: "Can't save photo: \(error)")
            return
        }
        
        // Insert this photo into this view controller's list
        selfies.insert(newSelfie, at: 0)
        
        // Update the table view to show the new photo
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error)
    {
        showError(message: error.localizedDescription)
    }

}

extension SelfieListViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {}

extension SelfieListViewController : CLLocationManagerDelegate
{
}

