//
//  AuthService.swift
//  UberClone
//
//  Created by Ronan Mak on 18/4/2022.
//

import UIKit
import Firebase

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
            
            let values = ["email": credentials.email,
                          "fullname": credentials.fullname,
                          "accountType": credentials.accountType] as [String : Any]
            
            Database.database().reference().child("users").child(uid).updateChildValues(values)
        }
    }
    
    static func signUserOut(completion: @escaping(Error?) -> Void) {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error: signing out")
        }
    }
}


