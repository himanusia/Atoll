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
        case .appLaunch, .weatherFeatureEnabled, .weatherWidgetDisplayed:
            return false
        case .explicitUserAction:
            return true
        }
    }
}

enum AccessibilityPermissionPromptTrigger {
    case appStartup
    case explicitUserAction
}

enum AccessibilityPermissionPromptPolicy {
    static func shouldPrompt(for trigger: AccessibilityPermissionPromptTrigger) -> Bool {
        switch trigger {
        case .appStartup:
            return false
        case .explicitUserAction:
            return true
        }
    }
}

enum DownloadsFolderAccessRequestTrigger {
    case appLaunch
    case userEnabledListener
}

enum DownloadsFolderAccessRequestPolicy {
    static func shouldProbe(for trigger: DownloadsFolderAccessRequestTrigger) -> Bool {
        switch trigger {
        case .appLaunch:
            return false
        case .userEnabledListener:
            return true
        }
    }
}
