//
//  HomeController.swift
//  UberClone
//
//  Created by Ronan Mak on 18/4/2022.
//

import UIKit
import Firebase
import MapKit

private let reuseIdentifier = "LocationCell"
private let annotationIdentifier = "DriverAnnotation"

private enum ActionButtonConfiguration {
    case showMenu
    case dismissActionView
    
    init() {
        self = .showMenu
    }
}

class HomeController: UIViewController {
    
    // MARK: - Properties
    
    private let mapView = MKMapView()
    let locationManager = LocationHandler.shared.locationManager
    
    private let locationInputActivationView = LocationInputActivationView()
    private let locationInputView = LocationInputView()
    private let rideActionView = RideActionView()
    private let tableView = UITableView()
    
    private var searchResults = [MKPlacemark]()
    private final let locationInputViewHeight: CGFloat = 200
    private final let rideActionViewHeight: CGFloat = 300
    
    private var user: User? {
        didSet {
            locationInputView.user = self.user

            if user?.accountType == .passenger {
                fetchDriver()
                configureLocationInputActivationView()
            } else {
                // driver type
                observeTrips()
            }
        }
    }

    private var trip: Trip? {
        didSet {
            guard let trip = trip else { return }
            let controller = PickupController(trip: trip)
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "baseline_menu_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private var actionButtonConfig = ActionButtonConfiguration()
    private var route: MKRoute?
    
    // sign out
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
    
    // MARK: - Selectors
    
    @objc func actionButtonPressed() {
        switch actionButtonConfig {
        case .showMenu:
            print("hi")
        case .dismissActionView:
            self.removeAnnotaionAndOverlays()
            mapView.showAnnotations(mapView.annotations, animated: true)
            
            UIView.animate(withDuration: 0.3) {
                self.locationInputActivationView.alpha = 1
                self.configureActionButton(config: .showMenu)
                self.animateRideActionView(shouldShow: false)
            }
        }
    }
    
    // MARK: - API
    
    func fetchUserData() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        Service.shared.fetchUserData(uid: currentUid) { user in
            self.user = user
        }
    }
    
    func fetchDriver() {
        guard let location = locationManager?.location else { return }
        Service.shared.fetchDrivers(location: location) { driver in
            guard let coordinate = driver.location?.coordinate else { return }
            let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
            print("debug: driver coordinate is \(coordinate)")
            
            
            var driverIsVisible: Bool {
                return self.mapView.annotations.contains(where: { annotation -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false }
                    if driverAnno.uid == driver.uid {
                        print("debug: handle update driver position")
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        return true
                    }
                    return false
                })
            }
            
            if !driverIsVisible {
                self.mapView.addAnnotation(annotation)
            }
        }
    }

    func observeTrips() {
        Service.shared.observeTrips { trip in
            self.trip = trip
        }
    }
    
    func checkIfUserIsLoggedIn() {
        if Auth.auth().currentUser?.uid == nil {
            presentLogInController()
        } else {
            self.configure()
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
    
    // sign out
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
    
    // MARK: - Helper
    
    func configure() {
        configureUI()
        fetchUserData()
    }
    
    fileprivate func configureActionButton(config: ActionButtonConfiguration) {
        switch config {
        case .showMenu:
            self.actionButton.setImage(UIImage(named: "baseline_menu_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu
        case .dismissActionView:
            actionButton.setImage(UIImage(named: "baseline_arrow_back_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .dismissActionView
        }
    }
    
    func configureUI() {
        configureMapView()
        configureRideActionView()
        
        view.addSubview(actionButton)
        actionButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor, paddingTop: 16, paddingLeft: 16, width: 30, height: 30)
        
//         sign out
        view.addSubview(signOutButton)
        signOutButton.centerX(inView: view)
        signOutButton.anchor(bottom: view.safeAreaLayoutGuide.bottomAnchor)
        
        configureTableView()
    }

    func configureLocationInputActivationView() {
        view.addSubview(locationInputActivationView)
        locationInputActivationView.centerX(inView: view)
        locationInputActivationView.setDimensions(height: 50, width: view.frame.width - 35)
//        locationInputActivationView.anchor(bottom: view.bottomAnchor)
        locationInputActivationView.anchor(top: view.safeAreaLayoutGuide.topAnchor, paddingTop: 80)
        locationInputActivationView.delegate = self
        locationInputActivationView.alpha = 0

        UIView.animate(withDuration: 2) {
            self.locationInputActivationView.alpha = 1
        }
    }
    
    func configureMapView() {
        view.addSubview(mapView)
        mapView.frame = view.frame
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
    }
    
    func configureLocationInputView() {
        
        locationInputView.delegate = self
        view.addSubview(locationInputView)
        locationInputView.anchor(top: view.topAnchor, left: view.leftAnchor, right: view.rightAnchor, height: locationInputViewHeight)
        locationInputView.alpha = 0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.locationInputView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.tableView.frame.origin.y = self.locationInputViewHeight
            }
        }
    }
    
    func configureRideActionView() {
        view.addSubview(rideActionView)
        rideActionView.delegate = self
        rideActionView.frame = CGRect(x: 0, y: view.frame.height,
                                      width: view.frame.width, height: rideActionViewHeight)
    }
    
    func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 60
        tableView.tableFooterView = UIView()
        
        let height = view.frame.height - locationInputViewHeight
        tableView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: height)
        tableView.backgroundColor = .white
        
        view.addSubview(tableView)
    }
    
    func dismissLocationInputViewHandler(completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.locationInputView.alpha = 0
            self.tableView.frame.origin.y = self.view.frame.height
            self.locationInputView.removeFromSuperview()
            
        }, completion: completion)
    }
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil) {
        let yOrigin = shouldShow ? self.view.frame.height - self.rideActionViewHeight : self.view.frame.height
        
        if shouldShow {
            guard let destination = destination else { return }
            self.rideActionView.destination = destination
        }
        UIView.animate(withDuration: 0.3) {
            self.rideActionView.frame.origin.y = yOrigin
        }
    }
}

// MARK: - Map Helper Functions

private extension HomeController {
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark]) -> Void) {
        var results = [MKPlacemark]()
        
        let request = MKLocalSearch.Request()
        
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            
            response.mapItems.forEach({ item in
                results.append(item.placemark)
            })
            
            completion(results)
        }
    }
    
    func generatePolyline(toDestination destination: MKMapItem) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        
        print("debug: 4")
        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { response, error  in
            
            print("debug: 5")
            guard let response = response?.routes[0] else { return print("debug: 1")}
            self.route = response
            guard let polyline = self.route?.polyline else { return print("debug: 2")}
            print("debug: 6")
            self.mapView.addOverlay(polyline)
        }
    }
    
    func removeAnnotaionAndOverlays() {
        mapView.annotations.forEach { (annotaion) in
            if let annotation = annotaion as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
        if mapView.overlays.count > 0 {
            mapView.removeOverlay(mapView.overlays[0])
        }
    }
}

// MARK: - AuthenticationDelegate

extension HomeController: AuthenticationDelegate {
    func configureUIAfterRegistration() {
        self.configure()
    }
}

// MARK: - CLLocationManagerDelegate (Allow user to change their location usage setting)

extension HomeController {
    func enableLocationService() {
        
        switch locationManager?.authorizationStatus {
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways:
            locationManager?.startUpdatingLocation()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            locationManager?.requestAlwaysAuthorization()
        case .none:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - MKMapViewDelegate

extension HomeController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            view.image = UIImage(named: "chevron-sign-to-right")
            return view
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        let lineRenderer = MKPolylineRenderer(overlay: route!.polyline)
        lineRenderer.strokeColor = .black
        lineRenderer.lineWidth = 3.5
        return lineRenderer
    }
}

// MARK: - LocationInputActivationViewDelegate

extension HomeController: LocationInputActivationViewDelegate {
    func presentLocationInputView() {
        locationInputActivationView.alpha = 0
        configureLocationInputView()
    }
}


// MARK: - LocationInputViewDelegate

extension HomeController: LocationInputViewDelegate {
    func executeSearch(query: String) {
        searchBy(naturalLanguageQuery: query) { (placemarks) in
            self.searchResults = placemarks
            self.tableView.reloadData()
        }
    }
    
    func dismissLocationInputView() {
        dismissLocationInputViewHandler { _ in
            UIView.animate(withDuration: 0.5, animations: {
                self.locationInputActivationView.alpha = 1
            })
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension HomeController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Previous" : "Search Result"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LocationCell
        
        if indexPath.section == 1 {
            cell.placemark = searchResults[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPlacemark = searchResults[indexPath.row]
        
        configureActionButton(config: .dismissActionView)
        
        print("debug: 3")
        let destination = MKMapItem(placemark: selectedPlacemark)
        generatePolyline(toDestination: destination)
        
        self.dismissLocationInputViewHandler { _ in
            let annotation = MKPointAnnotation()
            annotation.coordinate = selectedPlacemark.coordinate
            self.mapView.addAnnotation(annotation)
            self.mapView.selectAnnotation(annotation, animated: true)
            
            let annotations = self.mapView.annotations.filter({ !$0.isKind(of: DriverAnnotation.self) })
            
//            self.mapView.showAnnotations(annotations, animated: true) is equal to func zoomToFit() 
            self.mapView.zoomToFit(annotations: annotations)
            
            self.animateRideActionView(shouldShow: true, destination: selectedPlacemark)
            
        }
    }
}

extension HomeController: RideActionViewDelegate {
    func uploadTrip(_ view: RideActionView) {

        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }

        Service.shared.uploadTrip(pickupCoordinates, destinationCoordinates) { (err, ref) in
            if let error = err {
                print("\(error)")
                return
            }

            print("debug: did update trip")
        }
    }
}
