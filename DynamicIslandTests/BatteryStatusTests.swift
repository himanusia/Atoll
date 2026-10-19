/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if os(macOS)
import CoreLocation
import SwiftUI
import XCTest
@testable import Atoll

final class BatteryStatusTests: XCTestCase {
    func testLowPowerModeOnlyTransitionDoesNotTriggerLowBatteryHUD() {
        let previous = BatteryInfo(
            isPluggedIn: false,
            isCharging: false,
            currentCapacity: 60,
            maxCapacity: 100,
            isInLowPowerMode: false,
            timeToFullCharge: 0
        )
        let current = BatteryInfo(
            isPluggedIn: false,
            isCharging: false,
            currentCapacity: 60,
            maxCapacity: 100,
            isInLowPowerMode: true,
            timeToFullCharge: 0
        )

        XCTAssertFalse(
            BatteryStatusTransition.shouldPresentLowBatteryHUD(
                previous: previous,
                current: current,
                threshold: 20
            )
        )
    }

    func testLowPowerModeIndicatorAppearsOnlyWhenActive() {
        XCTAssertNil(BatteryStatusPresentation.lowPowerModeSymbol(isActive: false))
        XCTAssertEqual(
            BatteryStatusPresentation.lowPowerModeSymbol(isActive: true),
            "leaf.fill"
        )
    }

    func testLowPowerModeUsesYellowBatteryToneEvenWhenCharging() {
        let view = BatteryView(
            levelBattery: 60,
            isPluggedIn: true,
            isCharging: true,
            isInLowPowerMode: true,
            isForNotification: false
        )

        XCTAssertEqual(view.batteryColor, .yellow)
    }

    func testNormalChargingAndFullBatteryUseWhiteInsteadOfGreen() {
        XCTAssertEqual(
            BatteryStatusPresentation.chargeColor(level: 8, isPluggedIn: false, isCharging: true, isInLowPowerMode: false),
            .neutral
        )
        XCTAssertEqual(
            BatteryStatusPresentation.chargeColor(level: 100, isPluggedIn: true, isCharging: false),
            .neutral
        )
    }

    func testLowBatteryWarningRemainsRedWhenLowPowerModeIsOff() {
        XCTAssertEqual(
            BatteryStatusPresentation.chargeColor(level: 15, isPluggedIn: false, isCharging: false),
            .red
        )
    }

    func testPowerSourceHUDOnlyAppearsForAnActualConnectOrDisconnect() {
        XCTAssertEqual(
            BatteryStatusTransition.powerSourceHUDKind(previousPluggedIn: false, currentPluggedIn: true),
            .powerConnected
        )
        XCTAssertEqual(
            BatteryStatusTransition.powerSourceHUDKind(previousPluggedIn: true, currentPluggedIn: false),
            .powerDisconnected
        )
        XCTAssertNil(BatteryStatusTransition.powerSourceHUDKind(previousPluggedIn: true, currentPluggedIn: true))
    }

    func testFullBatteryHUDRequiresAThresholdCrossingWhileConnectedToPower() {
        let previous = BatteryInfo(isPluggedIn: true, isCharging: true, currentCapacity: 99, maxCapacity: 100, isInLowPowerMode: false, timeToFullCharge: 0)
        let full = BatteryInfo(isPluggedIn: true, isCharging: false, currentCapacity: 100, maxCapacity: 100, isInLowPowerMode: false, timeToFullCharge: 0)
        let unplugged = BatteryInfo(isPluggedIn: false, isCharging: false, currentCapacity: 100, maxCapacity: 100, isInLowPowerMode: false, timeToFullCharge: 0)

        XCTAssertTrue(BatteryStatusTransition.shouldPresentFullBatteryHUD(previous: previous, current: full, threshold: 100))
        XCTAssertFalse(BatteryStatusTransition.shouldPresentFullBatteryHUD(previous: full, current: full, threshold: 100))
        XCTAssertFalse(BatteryStatusTransition.shouldPresentFullBatteryHUD(previous: previous, current: unplugged, threshold: 100))
    }

    func testLowBatteryPulseIsPreservedOutsideLowPowerMode() {
        XCTAssertTrue(BatteryStatusPresentation.shouldPulseLowBatteryIndicator(isInLowPowerMode: false))
        XCTAssertFalse(BatteryStatusPresentation.shouldPulseLowBatteryIndicator(isInLowPowerMode: true))
    }

    func testLocationPermissionIsNotRequestedAtAppLaunch() {
        XCTAssertFalse(
            LocationAuthorizationRequestPolicy.shouldRequestAuthorization(
                for: .appLaunch,
                status: .notDetermined
            )
        )
        XCTAssertFalse(
            LocationAuthorizationRequestPolicy.shouldRequestAuthorization(
                for: .weatherFeatureEnabled,
                status: .notDetermined
            )
        )
        XCTAssertTrue(
            LocationAuthorizationRequestPolicy.shouldRequestAuthorization(
                for: .explicitUserAction,
                status: .notDetermined
            )
        )
    }

    func testAutomaticLocationTriggersDoNotPrompt() {
        for trigger: LocationAuthorizationRequestTrigger in [
            .appLaunch,
            .weatherFeatureEnabled,
            .weatherWidgetDisplayed
        ] {
            XCTAssertFalse(
                LocationAuthorizationRequestPolicy.shouldRequestAuthorization(
                    for: trigger,
                    status: .notDetermined
                ),
                "Unexpected location prompt for \(trigger)"
            )
        }
    }

    func testDownloadsFolderAccessIsOnlyRequestedAfterUserEnablement() {
        XCTAssertFalse(DownloadsFolderAccessRequestPolicy.shouldProbe(for: .appLaunch))
        XCTAssertTrue(DownloadsFolderAccessRequestPolicy.shouldProbe(for: .userEnabledListener))
    }

    func testAccessibilityPromptRequiresExplicitUserAction() {
        XCTAssertFalse(AccessibilityPermissionPromptPolicy.shouldPrompt(for: .appStartup))
        XCTAssertTrue(AccessibilityPermissionPromptPolicy.shouldPrompt(for: .explicitUserAction))
    }

    func testLocationPermissionIsNotRequestedAgainAfterDecision() {
        for status: CLAuthorizationStatus in [.authorized, .denied, .restricted] {
            XCTAssertFalse(
                LocationAuthorizationRequestPolicy.shouldRequestAuthorization(
                    for: .explicitUserAction,
                    status: status
                )
            )
        }
    }
}
#endif
