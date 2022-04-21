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
    private let locationManager = CLLocationManager()
    
    private let signOutButton: UIButton = {
        let button = UIButton().authButton(withText: "Sign Out")
        button.addTarget(self, action: #selector(handleSignOut), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        checkIfUserIsLoggedIn()
        enableLocationService()
    }
    
    // MARK: - API
    
    func checkIfUserIsLoggedIn() {
        if Auth.auth().currentUser?.uid == nil {
            presentLogInController()
        } else {
            configureUI()
        }
    }
    
    func presentLogInController() {
        DispatchQueue.main.async {
            let controller = LoginController()
            controller.delegate = self
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true, completion: nil)
        }
    }
    
    @objc func handleSignOut() {
        do {
            try Auth.auth().signOut()
            let controller = LoginController()
            controller.delegate = self
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true, completion: nil)
        } catch {
            print("DEBUG: Failed to log out")
        }
    }
    
    // MARK: - Style
    
    func configureUI() {
        configureMapView()
        
        view.addSubview(signOutButton)
        signOutButton.centerX(inView: view)
        signOutButton.anchor(top: mapView.bottomAnchor, paddingTop: 100)
    }
    
    func configureMapView() {
        view.addSubview(mapView)
        mapView.frame.size.height = view.frame.size.height / 2
        mapView.frame.size.width = view.frame.size.width
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
    }
}

// MARK: - AuthenticationDelegate

extension HomeController: AuthenticationDelegate {
    func authenticationDidComplete() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func configureMainControllerUI() {
        self.configureUI()
    }
}

// MARK: - CLLocationManagerDelegate (Allow user to change their location usage setting)

extension HomeController: CLLocationManagerDelegate {
    func enableLocationService() {
        
        locationManager.delegate = self
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
}
