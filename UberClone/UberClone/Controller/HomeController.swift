//
//  HomeController.swift
//  UberClone
//
//  Created by Ronan Mak on 18/4/2022.
//

import UIKit
import Firebase
import MapKit

class HomeController: UIViewController {
    
    // MARK: - Properties
    
    private let mapView = MKMapView()
    
    private let signOutButton: UIButton = {
        let button = UIButton().authButton(withText: "Sign Out")
        button.addTarget(self, action: #selector(handleSignOut), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        checkIfUserIsLoggedIn()
    }
    
    // MARK: - API
    
    func checkIfUserIsLoggedIn() {
        if Auth.auth().currentUser?.uid == nil {
            presentLogInController()
        } else {
            configureUI()
        }
    }
    
    @objc func handleSignOut() {
        print("123")
        AuthService.signUserOut { error in
            if let error = error {
                print("Error Sign Out \(error.localizedDescription)")
            } else {
                self.presentLogInController()
            }
        }
        
    }
    
    func presentLogInController() {
        DispatchQueue.main.async {
            let nav = UINavigationController(rootViewController: LoginController())
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true, completion: nil)
        }
    }
    // MARK: - Style
    
    func configureUI() {
        view.addSubview(mapView)
        mapView.frame.size.height = view.frame.size.height / 2
        mapView.frame.size.width = view.frame.size.width
        
        view.addSubview(signOutButton)
        signOutButton.centerX(inView: view)
        signOutButton.anchor(top: mapView.bottomAnchor, paddingTop: 100)
    }
}
