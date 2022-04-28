//
//  User.swift
//  UberClone
//
//  Created by Ronan Mak on 25/4/2022.
//

import Foundation
import CoreLocation

struct User {
    let fullname: String
    let email: String
    var accountType: Int!
    var location: CLLocation?
    let uid: String
    
    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        self.fullname = dictionary["fullname"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""
        self.accountType = dictionary["accountType"] as? Int ?? 0
    }
    
}
