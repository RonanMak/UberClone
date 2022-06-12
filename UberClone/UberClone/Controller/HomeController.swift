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

    private var actionButtonConfig = ActionButtonConfiguration()
    private var route: MKRoute?
    
    private var user: User? {
        didSet {
            locationInputView.user = self.user

            if user?.accountType == .passenger {
                fetchDriver()
                configureLocationInputActivationView()
                observeCurrentTrip()
                print("debug: current trip")
            } else {
                // driver type
                observeTrips()
            }
        }
    }

    private var trip: Trip? {
        didSet {
            guard let user = user else { return }

            if user.accountType == .driver {
                guard let trip = trip else { return }
                let controller = PickupController(trip: trip)
                controller.delegate = self
                self.present(controller, animated: true, completion: nil)
            } else {
                print("debug: show ride action view for accepted trip")
            }
        }
    }
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "baseline_menu_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }()
    
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

    override func viewWillAppear(_ animated: Bool) {
        guard let trip = trip else { return }
        print("debug: state is \(trip.state.rawValue)")
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

    func observeCurrentTrip() {
        Service.shared.observeCurrentTrip { [weak self] trip in
            guard let StrongSelf = self else { return }
            StrongSelf.trip = trip

            guard let state = trip.state else { return }
            guard let driverUid = trip.driverUid else { return }
            switch state {
            case .requested:
                break
            case .denied:
                break
            case .accepted:
                StrongSelf.shouldPresentLoadingView(false)
                StrongSelf.removeAnnotaionAndOverlays()

                StrongSelf.zoomForActiveTrip(withdriverUid: driverUid)

                Service.shared.fetchUserData(uid: driverUid) { [weak self] driver in
                    guard let StrongSelf = self else { return }
                    StrongSelf.animateRideActionView(shouldShow: true, config: .tripAccepted, user: driver)
                }
            case .driverArrived:
                StrongSelf.rideActionView.config = .driverArrived
                
            case .inProgress:
                break
            case .arrivedAtDestination:
                break
            case .completed:
                break
            }
        }
    }
    
    func fetchUserData() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        Service.shared.fetchUserData(uid: currentUid) { user in
            self.user = user
        }
    }

    func startTrip() {
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .inProgress) { [weak self] (err, ref) in
            guard let strongSelf = self else { return }
            strongSelf.rideActionView.config = .tripInProgress
            strongSelf.removeAnnotaionAndOverlays()
            strongSelf.mapView.addAnnotationAndSelect(forCoordinate: trip.destinationCoordinates)

            let placemark = MKPlacemark(coordinate: trip.destinationCoordinates)
            let mapItem = MKMapItem(placemark: placemark)
            strongSelf.generatePolyline(toDestination: mapItem)
        }
    }
    
    func fetchDriver() {
        guard let location = locationManager?.location else { return }
        Service.shared.fetchDrivers(location: location) { [weak self] driver in
            guard let StrongSelf = self else { return }
            guard let coordinate = driver.location?.coordinate else { return }
            let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
            
            var driverIsVisible: Bool {
                return StrongSelf.mapView.annotations.contains(where: { annotation -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false }
                    if driverAnno.uid == driver.uid {
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        self?.zoomForActiveTrip(withdriverUid: driver.uid)
                        return true
                    }
                    return false
                })
            }
            
            if !driverIsVisible {
                StrongSelf.mapView.addAnnotation(annotation)
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
            actionButton.setImage(UIImage(named: "baseline_menu_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .showMenu
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
        signOutButton.centerY(inView: view)
        signOutButton.anchor(left: view.leftAnchor, paddingLeft:  30)
        
        configureTableView()
    }

    func configureLocationInputActivationView() {
        view.addSubview(locationInputActivationView)
        locationInputActivationView.centerX(inView: view)
        locationInputActivationView.setDimensions(height: 80, width: view.frame.width)
                locationInputActivationView.anchor(bottom: view.bottomAnchor)
//        locationInputActivationView.anchor(top: view.safeAreaLayoutGuide.topAnchor, paddingTop: 80)
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
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil, config: RideActionViewConfiguration? = nil, user: User? = nil) {
        let yOrigin = shouldShow ? self.view.frame.height - self.rideActionViewHeight : self.view.frame.height

        UIView.animate(withDuration: 0.3) {
            self.rideActionView.frame.origin.y = yOrigin
        }

        if shouldShow {
            guard let config = config else { return }

            if let destination = destination {
                self.rideActionView.destination = destination
            }

            if let user = user {
                rideActionView.user = user
            }

            rideActionView.config = config
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

        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { response, error  in

            guard let response = response?.routes[0] else { return }
            self.route = response
            guard let polyline = self.route?.polyline else { return }
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

    func centerMapOnUserLocation() {
        guard let coordinate = locationManager?.location?.coordinate else { return }
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        mapView.setRegion(region, animated: true)
    }

    func setCustomRegion(withCoordinates coordinates: CLLocationCoordinate2D) {
        let region = CLCircularRegion(center: coordinates, radius: 25, identifier: "pickup")
        locationManager?.startMonitoring(for: region)

        print("debug: did set region\(region)")
    }

    func zoomForActiveTrip(withdriverUid uid: String) {
        var annotations = [MKAnnotation]()

        self.mapView.annotations.forEach { annotation in

            if let anno = annotation as? DriverAnnotation {
                if anno.uid == uid {
                    annotations.append(anno)
                }
            }

            if let userAnno = annotation as? MKUserLocation {
                annotations.append(userAnno)
            }
        }
        print("debug: annotation array is \(annotations)")
        self.mapView.zoomToFit(annotations: annotations)
    }
}

// MARK: - AuthenticationDelegate

extension HomeController: AuthenticationDelegate {
    func configureUIAfterRegistration() {
        self.configure()
    }
}

// MARK: - CLLocationManagerDelegate (Allow user to change their location usage setting)

extension HomeController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("debug: did start monitoring for region \(region)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("debug: driver did enter passenger region")

        self.rideActionView.config = .pickupPassenger
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .driverArrived) { [weak self] (err, ref) in
            guard let strongSelf = self else { return }
            strongSelf.rideActionView.config = .pickupPassenger
        }
    }

    func enableLocationService() {
        locationManager?.delegate = self
        
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
    // this func gets called every time the user's location updates
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let user = self.user else { return }
        guard user.accountType == .driver else { return }
        guard let location = userLocation.location else { return }
        Service.shared.updateDriverLocation(location: location)
    }

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
        return section == 0 ? 2 : searchResults.count
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

        let destination = MKMapItem(placemark: selectedPlacemark)
        generatePolyline(toDestination: destination)
        
        self.dismissLocationInputViewHandler { _ in
            self.mapView.addAnnotationAndSelect(forCoordinate: selectedPlacemark.coordinate)
            
            let annotations = self.mapView.annotations.filter({ !$0.isKind(of: DriverAnnotation.self) })
            
            //            self.mapView.showAnnotations(annotations, animated: true) is equal to func zoomToFit()
            self.mapView.zoomToFit(annotations: annotations)
            
            self.animateRideActionView(shouldShow: true, destination: selectedPlacemark, config: .requestRide)
            
        }
    }
}

// MARK: - RideActionViewDelegate

extension HomeController: RideActionViewDelegate {

    func uploadTrip(_ view: RideActionView) {

        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }

        shouldPresentLoadingView(true, message: "Finding you a ride")

        Service.shared.uploadTrip(pickupCoordinates, destinationCoordinates) { (err, ref) in
            if let error = err {
                print("\(error)")
                return
            }

            UIView.animate(withDuration: 0.3, animations: {
                self.rideActionView.frame.origin.y = self.view.frame.height
            })
        }
    }

    func cancelTrip() {
        Service.shared.cancelTrip { (error, ref) in
            if let error = error {
                print("debug: Error deleting trip \(error.localizedDescription)")
                return
            }
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
            self.removeAnnotaionAndOverlays()

            self.actionButton.setImage(UIImage(named: "baseline_menu_black_36dp")?.withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu

            self.locationInputActivationView.alpha = 1
        }
    }

    func pickupPassenger() {
        startTrip()
    }
}

// MARK: - PickupControllerDelegate

extension HomeController: PickupControllerDelegate {
    func didAcceptTrip(_ trip: Trip) {
        self.trip = trip

        self.mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)

        setCustomRegion(withCoordinates: trip.pickupCoordinates)

        let placemark = MKPlacemark(coordinate: trip.pickupCoordinates)
        let mapItem = MKMapItem(placemark: placemark)
        generatePolyline(toDestination: mapItem)

        mapView.zoomToFit(annotations: mapView.annotations)

        Service.shared.observeTripCancelled(trip: trip) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeAnnotaionAndOverlays()
            strongSelf.animateRideActionView(shouldShow: false)
            strongSelf.centerMapOnUserLocation()
            strongSelf.presentAlertController(withTitle: "Oops!", message: "The passenger has decided to cancel this ride")
        }

        self.dismiss(animated: true) {
            Service.shared.fetchUserData(uid: trip.passengerUid) { passenger in
                self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: passenger)
            }
        }
    }

}
