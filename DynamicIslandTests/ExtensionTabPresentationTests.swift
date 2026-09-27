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

    func testMalformedAndArbitrarySchemeURLsAreBlockedWithoutLaunching() throws {
        let blockedURLs = [
            "hermes://session/",
            "hermes://session/session-123/extra",
            "hermes://session//session-123",
            "hermes://session/session-123?source=script",
            "hermes://session/session-123#fragment",
            "hermes://user@session/session-123",
            "hermes://session:443/session-123",
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
}
