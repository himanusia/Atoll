import XCTest
import WebKit
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

    func testFullHeightExtensionTabCentersWithinAvailableHostWidth() {
        let offset = ContentView.resolvedFullHeightExtensionTabHorizontalOffset(
            availableWidth: 659,
            contentWidth: 638
        )

        XCTAssertEqual(offset, 10.5, accuracy: 0.001)
    }

    func testFullHeightExtensionTabDoesNotShiftWhenItOverflowsHostWidth() {
        let offset = ContentView.resolvedFullHeightExtensionTabHorizontalOffset(
            availableWidth: 620,
            contentWidth: 638
        )

        XCTAssertEqual(offset, 0, accuracy: 0.001)
    }

    func testFullHeightExtensionTabReducesExcessBottomInsetToMatchSideInsets() {
        let offset = ContentView.resolvedFullHeightExtensionTabVerticalOffset(
            bottomInset: 30,
            horizontalInset: 28.5
        )
        let alreadyBalanced = ContentView.resolvedFullHeightExtensionTabVerticalOffset(
            bottomInset: 28.5,
            horizontalInset: 28.5
        )

        XCTAssertEqual(offset, 1.5, accuracy: 0.001)
        XCTAssertEqual(alreadyBalanced, 0, accuracy: 0.001)
    }

    func testTabDirectionFollowsVisibleTabOrder() {
        XCTAssertTrue(tabSwitchMovesForward(fromIndex: 0, toIndex: 4))
        XCTAssertFalse(tabSwitchMovesForward(fromIndex: 4, toIndex: 0))
        XCTAssertTrue(tabSwitchMovesForward(fromIndex: 2, toIndex: 2))
    }

    func testExtensionTabTransitionIdentityIncludesExperienceID() {
        let first = ContentView.resolvedTabTransitionIdentity(view: .extensionExperience, extensionID: "hermes.monitor")
        let second = ContentView.resolvedTabTransitionIdentity(view: .extensionExperience, extensionID: "other.extension")
        let home = ContentView.resolvedTabTransitionIdentity(view: .home, extensionID: "hermes.monitor")

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, home)
    }

    func testUserActivatedHermesSessionLinkOpensAndCancelsNavigation() throws {
        let url = try XCTUnwrap(URL(string: "hermes://session/session-123"))
        var openedURL: URL?
        let policy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false,
            openSessionURL: { openedURL = $0 }
        )

        let decision = policy.decide(url: url, navigationType: .linkActivated)

        XCTAssertEqual(decision, .cancel)
        XCTAssertEqual(openedURL, url)
    }

    func testScriptNavigationToHermesSessionLinkDoesNotLaunch() throws {
        let url = try XCTUnwrap(URL(string: "hermes://session/session-123"))
        var openedURL: URL?
        let policy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false,
            openSessionURL: { openedURL = $0 }
        )

        let decision = policy.decide(url: url, navigationType: .other)

        XCTAssertEqual(decision, .cancel)
        XCTAssertNil(openedURL)
    }

    func testSessionHandoffClassificationRequiresUserActivationAndValidIdentifier() throws {
        let validURL = try XCTUnwrap(URL(string: "hermes://session/session-123"))
        let malformedURL = try XCTUnwrap(URL(string: "hermes://session/session%2F123"))
        let policy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false
        )

        XCTAssertTrue(policy.isUserActivatedSessionHandoff(url: validURL, navigationType: .linkActivated))
        XCTAssertFalse(policy.isUserActivatedSessionHandoff(url: validURL, navigationType: .other))
        XCTAssertFalse(policy.isUserActivatedSessionHandoff(url: malformedURL, navigationType: .linkActivated))
    }

    func testSessionHandoffAcceptsIdentifierAtMaximumLength() throws {
        let sessionID = String(repeating: "a", count: 128)
        let url = try XCTUnwrap(URL(string: "hermes://session/\(sessionID)"))
        var openedURL: URL?
        let policy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false,
            openSessionURL: { openedURL = $0 }
        )

        XCTAssertEqual(policy.decide(url: url, navigationType: .linkActivated), .cancel)
        XCTAssertEqual(openedURL, url)
    }

    func testMalformedAndArbitrarySchemeURLsAreBlockedWithoutLaunching() throws {
        let blockedURLs = [
            "hermes://session/",
            "hermes://session/session-123/extra",
            "hermes://session//session-123",
            "hermes://session/session-123?source=script",
            "hermes://session/session-123#fragment",
            "hermes://user@session/session-123",
            "hermes://session:443/session-123",
            "hermes://session/.",
            "hermes://session/..",
            "hermes://session/session.id",
            "hermes://session/session%2F123",
            "hermes://session/%2E",
            "hermes://session/session%00id",
            "hermes://session/session%20id",
            "hermes://session/%73ession-123",
            "hermes://session/\(String(repeating: "a", count: 129))",
            "javascript:window.alert(1)",
            "custom://session/session-123"
        ]
        var openedURLs: [URL] = []
        let policy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false,
            openSessionURL: { openedURLs.append($0) }
        )

        for rawURL in blockedURLs {
            let url = try XCTUnwrap(URL(string: rawURL), rawURL)
            XCTAssertEqual(
                policy.decide(url: url, navigationType: .linkActivated),
                .cancel,
                rawURL
            )
        }

        XCTAssertTrue(openedURLs.isEmpty)
    }

    func testDescriptorHTTPAllowRulesRemainUnchanged() throws {
        let aboutURL = try XCTUnwrap(URL(string: "about:blank"))
        let dataURL = try XCTUnwrap(URL(string: "data:text/plain,hello"))
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost:3000/widget"))
        let loopbackURL = try XCTUnwrap(URL(string: "https://127.0.0.1:8443/widget"))
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/widget"))

        let descriptorDefaultPolicy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: false
        )
        XCTAssertEqual(descriptorDefaultPolicy.decide(url: aboutURL, navigationType: .other), .allow)
        XCTAssertEqual(descriptorDefaultPolicy.decide(url: dataURL, navigationType: .other), .allow)
        XCTAssertEqual(descriptorDefaultPolicy.decide(url: localhostURL, navigationType: .other), .cancel)
        XCTAssertEqual(descriptorDefaultPolicy.decide(url: remoteURL, navigationType: .other), .cancel)

        let localhostPolicy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: false,
            allowLocalhostRequests: true
        )
        XCTAssertEqual(localhostPolicy.decide(url: localhostURL, navigationType: .other), .allow)
        XCTAssertEqual(localhostPolicy.decide(url: loopbackURL, navigationType: .other), .allow)
        XCTAssertEqual(localhostPolicy.decide(url: remoteURL, navigationType: .other), .cancel)

        let remotePolicy = ExtensionWebNavigationPolicy(
            allowRemoteRequests: true,
            allowLocalhostRequests: false
        )
        XCTAssertEqual(remotePolicy.decide(url: remoteURL, navigationType: .other), .allow)
    }

    // MARK: - Combined privacy wing layout

    private func standaloneFixture() -> ExtensionStandaloneLayout {
        ExtensionStandaloneLayout(
            totalWidth: 260,
            outerHeight: 38,
            contentHeight: 26,
            leadingWidth: 44,
            centerWidth: 160,
            trailingWidth: 56
        )
    }

    func testPrivacyWingWidthCameraAndMicrophoneUsesTwoIcons() {
        // 2 * 24 + 4 spacing + 9 divider reserve + 8 trailing padding
        XCTAssertEqual(ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .cameraAndMicrophone), 69, accuracy: 0.001)
    }

    func testPrivacyWingWidthSingleIndicatorUsesOneIcon() {
        // 24 + 9 + 8
        XCTAssertEqual(ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .microphoneOnly), 41, accuracy: 0.001)
        XCTAssertEqual(ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .cameraOnly), 41, accuracy: 0.001)
    }

    func testPrivacyWingWidthIsZeroWithoutCameraOrMicrophone() {
        XCTAssertEqual(ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .none), 0, accuracy: 0.001)
        XCTAssertEqual(ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .recordingOnly), 0, accuracy: 0.001)
    }

    func testCombinedLayoutAddsPrivacyWidthAndKeepsOtherWingsUnchanged() {
        let standalone = standaloneFixture()
        let privacyWidth = ExtensionPrivacyCombinedLayout.privacyWingWidth(for: .cameraAndMicrophone)
        let combined = ExtensionPrivacyCombinedLayout.combined(standalone: standalone, privacyWidth: privacyWidth)

        XCTAssertEqual(combined.totalWidth, standalone.totalWidth + privacyWidth, accuracy: 0.001)
        XCTAssertEqual(combined.outerHeight, standalone.outerHeight, accuracy: 0.001)
        XCTAssertEqual(combined.contentHeight, standalone.contentHeight, accuracy: 0.001)
        XCTAssertEqual(combined.leadingWidth, standalone.leadingWidth, accuracy: 0.001)
        XCTAssertEqual(combined.centerWidth, standalone.centerWidth, accuracy: 0.001)
        XCTAssertEqual(combined.trailingWidth, standalone.trailingWidth, accuracy: 0.001)
        XCTAssertEqual(combined.privacyWidth, privacyWidth, accuracy: 0.001)
    }
}
