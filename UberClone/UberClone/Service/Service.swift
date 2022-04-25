//
//  Service.swift
//  UberClone
//
//  Created by Ronan Mak on 25/4/2022.
//

import Firebase

let DB_REF = Database.database().reference()
let REF_USER = DB_REF.child("users")

struct Service {
    
    static let shared = Service()
    
    func fetchUser() {
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        REF_USER.child(currentUid).observeSingleEvent(of: .value) { (snapshot) in
            
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            
            guard let fullname = dictionary["fullname"] as? String else { return }
            print("\(fullname)")
        }
    }
}
