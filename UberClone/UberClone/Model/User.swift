//
//  User.swift
//  UberClone
//
//  Created by Ronan Mak on 25/4/2022.
//

import Foundation
import CoreLocation
import SwiftUI

enum AccountType: Int {
    case passenger
    case driver
}

struct User {
    let fullname: String
    let email: String
    var accountType: AccountType!
    var location: CLLocation?
    let uid: String
    
    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        self.fullname = dictionary["fullname"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""

        if let index = dictionary["accountType"] as? Int {
            self.accountType = AccountType(rawValue: index)
        }
    }
}
