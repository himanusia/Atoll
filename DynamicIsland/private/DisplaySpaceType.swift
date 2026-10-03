/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit

/// Reads the type of the Space currently shown on a display.
///
/// Native fullscreen apps live in a dedicated Space of type 4; ordinary
/// desktops are type 0. Unlike `AXFullScreen`, this does not require the
/// Accessibility permission.
enum DisplaySpaceType {
    private static let fullscreenSpaceType = 4

    /// `true`/`false` when the display's current Space was found, `nil` otherwise.
    static func isCurrentSpaceFullscreen(on screen: NSScreen) -> Bool? {
        guard let spaces = CGSCopyManagedDisplaySpaces(_CGSDefaultConnection()) as? [[String: Any]] else {
            return nil
        }

        let uuid = displayUUID(for: screen)
        // With "Displays have separate Spaces" off, a single entry is reported
        // under the "Main" identifier for every display.
        let entry = spaces.first { ($0["Display Identifier"] as? String) == uuid }
            ?? spaces.first { ($0["Display Identifier"] as? String) == "Main" }
            ?? (spaces.count == 1 ? spaces.first : nil)

        guard let current = entry?["Current Space"] as? [String: Any],
              let type = current["type"] as? Int else {
            return nil
        }
        return type == fullscreenSpaceType
    }

    private static func displayUUID(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

// Must match the declaration in CGSSpace.swift: both files link the same symbol.
private typealias CGSConnectionID = UInt
@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray?
