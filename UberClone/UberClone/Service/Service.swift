//
//  Service.swift
//  UberClone
//
//  Created by Ronan Mak on 25/4/2022.
//

import Firebase

let DB_REF = Database.database().reference()
let REF_USER = DB_REF.child("users")
let REF_DRIVER_LOCATIONS = DB_REF.child("driver-locations")

struct Service {
    
    static let shared = Service()
    
    func fetchUserData(completion: @escaping(User) -> Void) {
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        REF_USER.child(currentUid).observeSingleEvent(of: .value) { (snapshot) in
            
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            
            let user = User(dictionary: dictionary)
            
            completion(user)
        }
    }
}
