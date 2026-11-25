import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let radarLocation = RadarLocation()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CampusRadarLocation")
    else { return }
    FlutterMethodChannel(name: "campussave/location", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "currentPosition" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let self = self else {
          result(nil)
          return
        }
        self.radarLocation.request(result)
      }
  }
}

private final class RadarLocation: NSObject, CLLocationManagerDelegate {
  private lazy var manager: CLLocationManager = {
    let manager = CLLocationManager()
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.delegate = self
    return manager
  }()
  private var pending: FlutterResult?
  private var timeout: DispatchWorkItem?
  private var requestingFix = false

  func request(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(nil)
      return
    }
    pending = result
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else {
      requestIfAuthorized()
    }
  }

  private func requestIfAuthorized() {
    guard pending != nil, !requestingFix else { return }
    switch manager.authorizationStatus {
    case .notDetermined:
      return
    case .authorizedWhenInUse, .authorizedAlways:
      requestingFix = true
      let task = DispatchWorkItem { [weak self] in self?.finish(nil) }
      timeout = task
      DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: task)
      manager.requestLocation()
    default:
      finish(nil)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    requestIfAuthorized()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    finish(locations.last)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(nil)
  }

  private func finish(_ location: CLLocation?) {
    timeout?.cancel()
    timeout = nil
    requestingFix = false
    let result = pending
    pending = nil
    manager.stopUpdatingLocation()
    result?(location.map { [$0.coordinate.latitude, $0.coordinate.longitude] })
  }
}
