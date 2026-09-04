//
//  LocationService.swift
//  FloraFang
//
//  Optional location on saved entries.
//
//  WHY: geographic range is a cheap accuracy lever. A recluse is plausible in
//  New Mexico and a Sydney funnel web is not, and filtering candidates by
//  where you are beats a bigger model for the cost.
//
//  WHAT CHANGED, AND WHY IT MATTERS:
//
//  The first version stored raw coordinates. That is more precision than the
//  feature needs and more than is safe to hand out. A photo taken in someone's
//  garage, stamped with six decimal places, is their home address attached to
//  a picture of the inside of their home, and the export feature turns that
//  into a file they might email.
//
//  So two changes. Coordinates are rounded to two decimal places, roughly a
//  kilometre, which is far finer than any species range check requires and
//  far too coarse to find a house. And a reverse geocoded place name is
//  stored alongside, because "Albuquerque NM" is what a person actually wants
//  to read in a log entry.
//

import CoreLocation
import Foundation
import MapKit

@MainActor
@Observable
final class LocationService: NSObject {

    static let enabledKey = "locationCaptureEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private(set) var lastLocation: CLLocation?
    private(set) var placeName: String?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Kilometre accuracy is all this needs, and asking for less precision
        // means iOS can often answer without powering up GPS.
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

    /// Rounded to about a kilometre. Enough to check a species range, not
    /// enough to identify a building.
    var coarseCoordinate: (latitude: Double, longitude: Double)? {
        guard isEnabled, let loc = lastLocation else { return nil }
        return (
            (loc.coordinate.latitude * 100).rounded() / 100,
            (loc.coordinate.longitude * 100).rounded() / 100
        )
    }

    private func updatePlaceName(for location: CLLocation) async {
        guard let request = MKReverseGeocodingRequest(location: location),
              let items = try? await request.mapItems,
              let item = items.first else { return }

        // City and state only. Street level detail would defeat the point of
        // coarsening the coordinates in the first place.
        if let cityWithContext = item.addressRepresentations?.cityWithContext {
            placeName = cityWithContext
        } else {
            let city = item.addressRepresentations?.cityName ?? ""
            let region = item.addressRepresentations?.regionName ?? ""
            let combined = [city, region]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            placeName = combined.isEmpty ? nil : combined
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = latest
            await self.updatePlaceName(for: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Silent by design. A missing fix is not worth interrupting a scan
        // over, and the entry simply saves without location.
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
