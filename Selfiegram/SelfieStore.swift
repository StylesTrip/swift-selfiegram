//
//  SelfieStore.swift
//  Selfiegram
//
//  Created by Ryan Turinsky on 1/10/19.
//  Copyright © 2019 Ryan Turinsky. All rights reserved.
//

import Foundation
import UIKit.UIImage
import CoreLocation.CLLocation

class Selfie : Codable {
    let created : Date
    let id : UUID // Unique ID, used to link this selfie to its image on disk
    var title = "New Selfie!"
    var position : Coordinate?
    
    var image : UIImage? {
        get {
            return SelfieStore.shared.getImage(id: self.id)
        }
        set {
            try? SelfieStore.shared.setImage(id: self.id, image: newValue)
        }
    }
    
    struct Coordinate : Codable, Equatable {
        var latitude : Double
        var longitude : Double
        
        // required equality method to conform to the Equatable protocol
        public static func == (lhs: Selfie.Coordinate, rhs: Selfie.Coordinate) -> Bool {
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
        }
        
        var location : CLLocation {
            get {
                return CLLocation(latitude: self.latitude, longitude: self.longitude)
            }
        }
        
        init(location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
    }
    
    init(title: String) {
        self.title = title
        
        self.created = Date()
        self.id = UUID()
    }
}

enum SelfieStoreError : Error {
    case cannotSaveImage(UIImage?)
}

final class SelfieStore {
    private var imageCache : [UUID:UIImage] = [:]
    static let shared = SelfieStore()
    
    // returns the file URL for the app's Documents folder
    var documentsFolder : URL {
        return FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask).first!
    }
    
    // Gets an image by ID. Will be cached in memory for future lookups.
    /// - parameter id: the id of the selfie whose image you are after
    /// - returns: the image for that selfie or nil if it doesn't exist
    func getImage(id:UUID) -> UIImage? {
        
        if let image = imageCache[id] {
            return image
        }
        
        // Figure out where this image should live
        let imageURL = documentsFolder.appendingPathComponent("\(id.uuidString)-image.jpg")
        
        // Get the data from this file; exit if we fail
        guard let imageData = try? Data(contentsOf: imageURL) else {
            return nil
        }
        
        // Get the image from this data; exit if we fail
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        imageCache[id] = image
        
        return image
    }
    
    /// Saves an image to disk.
    /// - parameter id: the id of the selfie you want this image
    /// associated with
    /// - parameter image: the image you want saved
    /// - Throws: `SelfieStoreObject` if it fails to save to disk
    func setImage(id: UUID, image: UIImage?) throws {
        
        let fileName = "\(id.uuidString)-image.jg"
        let destinationURL = self.documentsFolder.appendingPathComponent(fileName)
        
        if let image = image {
            // We have an image to work with, so save it out.
            // Attempt to convert the image into JPEG data.
            guard let data = image.jpegData(compressionQuality: 90) else {
                throw SelfieStoreError.cannotSaveImage(image)
            }
            
            try data.write(to: destinationURL)
        } else {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        imageCache[id] = image
    }
    
    /// Returns a list of Selfie objects loaded from disk.
    /// - returns: an array of all selfies previously saved
    /// - Throws: `SelfieStoreError` if it fails to load a selfie correctly
    /// from disk
    func listSelfies() throws -> [Selfie] {
        // Get the list of files in the Documents directory
        let contents = try FileManager.default
        .contentsOfDirectory(at: self.documentsFolder,
                             includingPropertiesForKeys: nil)
        
        // Get all files whose path extension is 'json'
        // load them as data, and decode them from JSON
        return try contents.filter { $0.pathExtension == "json" }
            .map { try Data(contentsOf: $0) }
            .map { try JSONDecoder().decode(Selfie.self, from: $0) }
    }
    
    /// Deletes a selfie, and its corresponding image, from disk.
    /// This function simply takes the ID from the Selfie you pass in,
    /// and gives it to the other version of the delete function.
    /// - parameter selfie: the selfie you want deleted
    /// - Throws: `SelfieStoreError` if it fails to delete the selfie
    /// from disk
    func delete(selfie: Selfie) throws {
        try delete(id: selfie.id)
    }
    
    /// Deletes a selfie, and its corresponding image, from disk.
    /// - parameter id: the id property of the Selfie you want deleted
    /// - Throws: `SelfieStoreError` if it fails to delete the selfie
    /// from disk
    func delete(id: UUID) throws {
        let selfieDataFileName = "\(id.uuidString).json"
        let imageFileName = "\(id.uuidString)-image.jpg"
        
        let selfieDataURL = self.documentsFolder.appendingPathComponent(selfieDataFileName)
        let imageURL = self.documentsFolder.appendingPathComponent(imageFileName)
        
        // Remove the two files if they exist
        if FileManager.default.fileExists(atPath: selfieDataURL.path) {
            try FileManager.default.removeItem(at: selfieDataURL)
        }
        
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
        }
        
        imageCache[id]  = nil
    }
    
    /// Attempts to load a selfie from disk.
    /// - parameter id: the id property of the Selfie object you want loaded
    /// from disk
    /// - returns: the selfie with the matching id, or nil if it
    /// doesn't exist
    func load(id: UUID) -> Selfie? {
        let dataFileName = "\(id.uuidString).json"
        
        let dataURL = self.documentsFolder.appendingPathComponent(dataFileName)
        
        // Attempt to load the data in this file,
        // and then attempt to convert the data into a Photo,
        // and then return it.
        // Return nil if any of these steps fail.
        if let data = try? Data(contentsOf: dataURL),
            let selfie = try? JSONDecoder().decode(Selfie.self, from: data) {
            return selfie
        } else {
            return nil
        }
    }
    
    /// Attempts to save a selfie to disk.
    /// - parameter selfie: the selfie to save to disk
    /// - Throws: `SelfieStoreError` if it fails to write the data
    func save(selfie: Selfie) throws {
        let selfieData = try JSONEncoder().encode(selfie)
        
        let fileName = "\(selfie.id.uuidString).json"
        let destinationURL = self.documentsFolder.appendingPathComponent(fileName)
        
        try selfieData.write(to: destinationURL)
    }
}
