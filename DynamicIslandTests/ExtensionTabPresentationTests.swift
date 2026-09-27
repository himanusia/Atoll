import XCTest
@testable import Atoll

@MainActor
final class ExtensionTabPresentationTests: XCTestCase {
    func testFullHeightExtensionTabMatchesTerminalHeight() {
        let height = ContentView.resolvedExtensionTabHeight(
            fullHeightMode: true,
            preferredHeight: 160,
            baseHeight: 222,
            maximumHeight: 354,
            terminalHeight: 474
        )

        XCTAssertEqual(height ?? 0, 474, accuracy: 0.001)
    }

    func testStandardExtensionTabKeepsItsExistingHeightClamp() {
        let baseHeight = ContentView.resolvedExtensionTabHeight(
            fullHeightMode: false,
            preferredHeight: 160,
            baseHeight: 222,
            maximumHeight: 354,
            terminalHeight: 474
        )
        let cappedHeight = ContentView.resolvedExtensionTabHeight(
            fullHeightMode: false,
            preferredHeight: 500,
            baseHeight: 222,
            maximumHeight: 354,
            terminalHeight: 474
        )
        let missingHeight = ContentView.resolvedExtensionTabHeight(
            fullHeightMode: false,
            preferredHeight: nil,
            baseHeight: 222,
            maximumHeight: 354,
            terminalHeight: 474
        )

        XCTAssertEqual(baseHeight ?? 0, 222, accuracy: 0.001)
        XCTAssertEqual(cappedHeight ?? 0, 354, accuracy: 0.001)
        XCTAssertNil(missingHeight)
    }

    func testFullHeightModeRemovesCapsuleOnlyFromExtensionTab() {
        XCTAssertFalse(shouldDisplayTabSelectionCapsule(
            isSelected: true,
            isExtensionTab: true,
            fullHeightMode: true
        ))
        XCTAssertTrue(shouldDisplayTabSelectionCapsule(
            isSelected: true,
            isExtensionTab: false,
            fullHeightMode: true
        ))
        XCTAssertTrue(shouldDisplayTabSelectionCapsule(
            isSelected: true,
            isExtensionTab: true,
            fullHeightMode: false
        ))
        XCTAssertFalse(shouldDisplayTabSelectionCapsule(
            isSelected: false,
            isExtensionTab: true,
            fullHeightMode: true
        ))
    }

    func testFullHeightContentWidthMatchesNativePanelWithoutGrowingTheWindow() {
        let contentWidth = ContentView.resolvedFullHeightExtensionTabContentWidth(
            openNotchWidth: 690,
            horizontalInset: 19.5
        )

        XCTAssertEqual(contentWidth, 651, accuracy: 0.001)
        XCTAssertEqual((690 - contentWidth) / 2, 19.5, accuracy: 0.001)
        XCTAssertLessThan(contentWidth, 690)
    }
}
