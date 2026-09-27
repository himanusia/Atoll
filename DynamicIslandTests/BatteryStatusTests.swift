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

    func testLowBatteryColorRemainsRedWhenLowPowerModeIsEnabled() {
        let view = BatteryView(
            levelBattery: 15,
            isPluggedIn: false,
            isCharging: false,
            isInLowPowerMode: true,
            isForNotification: false
        )

        XCTAssertEqual(view.batteryColor, .red)
    }

    func testChargingAndFullyChargedBatteryColorsAreGreen() {
        XCTAssertEqual(
            BatteryStatusPresentation.chargeColor(level: 8, isPluggedIn: false, isCharging: true),
            .green
        )
        XCTAssertEqual(
            BatteryStatusPresentation.chargeColor(level: 100, isPluggedIn: false, isCharging: false),
            .green
        )
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
        XCTAssertTrue(
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
