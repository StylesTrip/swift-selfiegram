//
//  DetailViewController.swift
//  Selfiegram
//
//  Created by Ryan Turinsky on 1/10/19.
//  Copyright © 2019 Ryan Turinsky. All rights reserved.
//

import UIKit
import MapKit

class SelfieDetailViewController: UIViewController {

    @IBOutlet weak var dateCreatedLabel: UILabel!
    @IBOutlet weak var selfieNameField: UITextField!
    @IBOutlet weak var selfieImageView: UIImageView!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBAction func expandMap(_ sender: Any) {
        if let coordinate = self.selfie?.position?.location {
            let options = [MKLaunchOptionsMapCenterKey:NSValue(mkCoordinate: coordinate.coordinate), MKLaunchOptionsMapTypeKey:NSNumber(value:MKMapType.mutedStandard.rawValue)]
            
            let placemark = MKPlacemark(coordinate: coordinate.coordinate, addressDictionary: nil)
            let item = MKMapItem(placemark: placemark)
            item.name = selfie?.title
            
            item.openInMaps(launchOptions: options)
        }
    }
    
    func configureView() {
        guard let selfie = selfie else {
            return
        }
        
        // Ensure that we have references to the controls we need
        guard let selfieNameField = selfieNameField,
              let selfieImageView = selfieImageView,
              let dateCreatedLabel = dateCreatedLabel
            else {
                return
        }
        
        selfieNameField.text = selfie.title
        dateCreatedLabel.text = dateFormatter.string(from: selfie.created)
        selfieImageView.image = selfie.image
        
        if let position = selfie.position {
            self.mapView.setCenter(position.location.coordinate, animated: false)
            mapView.isHidden = false
        }
    }
    
    @IBAction func doneButtonTaped(_ sender: Any) {
       
       // Tells the text field to dismiss the keyboard
        self.selfieNameField.resignFirstResponder()
        
        // Ensure that we have a selfie to work with
        guard let selfie = selfie else {
            return
        }
        
        // Ensure that we have text in the field
        guard let text = selfieNameField?.text else {
            return
        }
        
        // Update the selfie and save it
        selfie.title = text
        
        try? SelfieStore.shared.save(selfie: selfie)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
    }

    var selfie: Selfie? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    let dateFormatter = { () -> DateFormatter in
        let d = DateFormatter()
        d.dateStyle = .short
        d.timeStyle = .short
        return d
    }()
}

