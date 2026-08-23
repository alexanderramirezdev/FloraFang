//
//  LocationService.swift
//  FloraFang
//
//  Optional coarse location on saved entries.
//
//  WHY: geographic range is a cheap accuracy lever. A recluse is plausible in
//  New Mexico and a Sydney funnel web is not, and filtering candidates by
//  where you actually are beats a bigger model for the cost. None of that is
//  wired into the cascade yet; this just starts recording the data so it is
//  there when it is.
//
//  PRIVACY: this is opt in and off by default, and the app works completely
//  without it. Nothing is transmitted. Note that turning this on makes the
//  current privacy policy wrong, since it says the app does not request or
//  record location. Update that page before shipping this.
//

import CoreLocation
import Foundation

@MainActor
@Observable
final class LocationService: NSObject {

    /// User facing switch. Off unless explicitly enabled in settings.
    static let enabledKey = "locationCaptureEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private(set) var lastLocation: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Neighbourhood level is plenty for a range check and avoids
        // recording precisely where someone lives.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorization = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Call before a scan so a fix is ready by save time. Cheap to call often.
    func refresh() {
        guard isEnabled else { return }
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.requestLocation()
    }

    /// Coordinates to stamp on an entry, or nil when disabled or unavailable.
    var coordinate: (latitude: Double, longitude: Double)? {
        guard isEnabled, let loc = lastLocation else { return nil }
        return (loc.coordinate.latitude, loc.coordinate.longitude)
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.lastLocation = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Silent by design. A missing fix is not worth interrupting a scan
        // over, and the entry simply saves without coordinates.
        print("[FloraFang] location failed: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.refresh()
            }
        }
    }
}
