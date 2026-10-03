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

/// Decides whether a screen-filling window is in *native* fullscreen.
///
/// MacroVisionKit flags every window whose frame matches the screen's safe area,
/// which includes merely maximized windows. Two independent signals separate
/// the two cases:
///
/// - `spaceIsFullscreen`: the WindowServer type of the display's current Space
///   (native fullscreen always runs in its own fullscreen Space). Needs no
///   permission; `nil` when the Space could not be resolved.
/// - `axFullscreen`: the window's `AXFullScreen` attribute, only meaningful when
///   Accessibility is trusted.
///
/// A missing signal never counts as fullscreen. Defaulting to `true` hid the
/// closed notch (and every live activity in it) whenever a maximized window
/// belonged to the now-playing app and Accessibility was not granted.
func isNativeFullscreenDecision(
    spaceIsFullscreen: Bool?,
    accessibilityTrusted: Bool,
    axFullscreen: Bool
) -> Bool {
    if spaceIsFullscreen == false {
        return false
    }
    if accessibilityTrusted {
        return axFullscreen
    }
    return spaceIsFullscreen == true
}
