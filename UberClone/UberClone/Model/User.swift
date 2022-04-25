//
//  User.swift
//  UberClone
//
//  Created by Ronan Mak on 25/4/2022.
//

import Foundation

struct User {
    let fullname: String
    let email: String
    var accountType: Int!
    
    init(dictionary: [String: Any]) {
        self.fullname = dictionary["fullname"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""
        self.accountType = dictionary["accountType"] as? Int ?? 0
    }
    
}