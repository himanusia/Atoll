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

func isClosedMusicPairingEligible(
    notchState: NotchState,
    hasActiveMusicSnapshot: Bool,
    musicLiveActivityEnabled: Bool,
    closedMusicContentEnabled: Bool,
    hideOnClosed: Bool,
    isLocked: Bool,
    isDeferredAfterUnlock: Bool
) -> Bool {
    notchState == .closed
        && hasActiveMusicSnapshot
        && musicLiveActivityEnabled
        && closedMusicContentEnabled
        && !hideOnClosed
        && !isLocked
        && !isDeferredAfterUnlock
}

/// Whether a closed-notch live activity (timer, reminder, recording, download,
/// LocalSend, Focus, privacy, shelf) may render the extension wing beside it.
///
/// Mirrors `isClosedMusicPairingEligible` without music-specific requirements:
/// any coexistence-eligible extension payload rides along with every surface
/// that owns the closed notch, so the Hermes session count stays visible
/// during calls and the other closed live activities - not only with music.
func isClosedExtensionPairingEligible(
    notchState: NotchState,
    hasCoexistingPayload: Bool,
    extensionLiveActivitiesEnabled: Bool,
    hideOnClosed: Bool,
    isLocked: Bool
) -> Bool {
    notchState == .closed
        && hasCoexistingPayload
        && extensionLiveActivitiesEnabled
        && !hideOnClosed
        && !isLocked
}
