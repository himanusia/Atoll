import CoreLocation

enum LocationAuthorizationRequestTrigger {
    case appLaunch
    case explicitUserAction
    case weatherFeatureEnabled
    case weatherWidgetDisplayed
}

enum LocationAuthorizationRequestPolicy {
    static func shouldRequestAuthorization(
        for trigger: LocationAuthorizationRequestTrigger,
        status: CLAuthorizationStatus
    ) -> Bool {
        guard status == .notDetermined else { return false }

        switch trigger {
        case .appLaunch:
            return false
        case .explicitUserAction, .weatherFeatureEnabled, .weatherWidgetDisplayed:
            return true
        }
    }
}
