//
//  AuthService.swift
//  UberClone
//
//  Created by Ronan Mak on 18/4/2022.
//

import UIKit
import Firebase
import GeoFire

typealias FirestoreAuthCompletion = (AuthDataResult?, Error?) -> Void

struct AuthService {
    
    static func logUserIn(withEmail email: String, password: String, completion: @escaping FirestoreAuthCompletion) {
        Auth.auth().signIn(withEmail: email, password: password, completion: completion)
    }
    
    static func registerUser(withCredentials credentials: AuthCredentials, completion: @escaping(Error?) -> Void) {
        
        Auth.auth().createUser(withEmail: credentials.email, password: credentials.password) { (result, error) in
            if let error = error {
                print("\(error)")
                return
            }
            
            guard let uid = result?.user.uid else { return }
            
            let location = LocationHandler.shared.locationManager.location
            
            let values = ["email": credentials.email,
                          "fullname": credentials.fullname,
                          "accountType": credentials.accountType] as [String : Any]
            
            if credentials.accountType == 1 {
                
                let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATIONS)
                
                guard let location = location else { return }
                
                geofire.setLocation(location, forKey: uid, withCompletionBlock: { (error) in
                    Database.database().reference().child("users").child(uid).updateChildValues(values)
                })
            }
            
            Database.database().reference().child("users").child(uid).updateChildValues(values)
        }
    }
}


