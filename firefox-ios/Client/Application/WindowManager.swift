// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Common
import Shared
import TabDataStore

/// General window management class that provides some basic coordination and
/// state management for multiple windows shared across a single running app.
protocol WindowManager {
    /// The UUID of the active window (there is always at least 1, except in
    /// the earliest stages of app startup lifecycle)
    var activeWindow: WindowUUID { get set }

    /// A collection of all open windows and their related metadata.
    var windows: [WindowUUID: AppWindowInfo] { get }

    /// Signals the WindowManager that a new browser window has been configured.
    /// - Parameter windowInfo: the information for the window.
    /// - Parameter uuid: the window's unique ID.
    func newBrowserWindowConfigured(_ windowInfo: AppWindowInfo, uuid: WindowUUID)

    /// Convenience. Returns the TabManager for a specific window.
    func tabManager(for windowUUID: WindowUUID) -> TabManager

    /// Convenience. Returns all TabManagers for all open windows.
    func allWindowTabManagers() -> [TabManager]

    /// Returns the UUIDs for all open windows, optionally also including windows that
    /// are still in the process of being configured but have not yet completed.
    /// Note: the order of the UUIDs is undefined.
    /// - Parameter includingReserved: whether to include windows that are still launching.
    /// - Returns: a list of UUIDs. Order is undefined.
    func allWindowUUIDs(includingReserved: Bool) -> [WindowUUID]

    /// Signals the WindowManager that a window was closed.
    /// - Parameter uuid: the ID of the window.
    func windowWillClose(uuid: WindowUUID)

    /// Supplies the UUID for the next window the iOS app should open. This
    /// corresponds with the window tab data saved to disk, or, if no data is
    /// available it provides a new UUID for the window. The resulting UUID
    /// is then "reserved" in order to ensure that during app launch if multiple
    /// windows are being restored concurrently, we never supply the same UUID
    /// to more than one window.
    /// - Returns: a UUID for the next window to be opened.
    func reserveNextAvailableWindowUUID() -> WindowUUID

    /// Signals the WindowManager that a window event has occurred. Window events
    /// are communicated to any interested Coordinators for _all_ windows, but
    /// any one event is always associated with one window in specific. 
    /// - Parameter event: the event that occurred and any associated metadata.
    /// - Parameter windowUUID: the UUID of the window triggering the event.
    func postWindowEvent(event: WindowEvent, windowUUID: WindowUUID)
}

/// Captures state and coordinator references specific to one particular app window.
struct AppWindowInfo {
    weak var tabManager: TabManager?
    weak var sceneCoordinator: SceneCoordinator?
}

final class WindowManagerImplementation: WindowManager {
    enum WindowPrefKeys {
        static let windowOrdering = "windowOrdering"
    }

    private(set) var windows: [WindowUUID: AppWindowInfo] = [:]
    private var reservedUUIDs: [WindowUUID] = []
    var activeWindow: WindowUUID {
        get { return uuidForActiveWindow() }
        set { _activeWindowUUID = newValue }
    }
    private let logger: Logger
    private let tabDataStore: TabDataStore
    private let defaults: UserDefaultsInterface
    private var _activeWindowUUID: WindowUUID?

    // Ordered set of UUIDs which determines the order that windows are re-opened on iPad
    // UUIDs at the beginning of the list are prioritized over UUIDs at the end
    private(set) var windowOrderingPriority: [WindowUUID] {
        get {
            let stored = defaults.object(forKey: WindowPrefKeys.windowOrdering)
            guard let prefs: [String] = stored as? [String] else { return [] }
            return prefs.compactMap({ UUID(uuidString: $0) })
        }
        set {
            let mapped: [String] = newValue.compactMap({ $0.uuidString })
            defaults.set(mapped, forKey: WindowPrefKeys.windowOrdering)
        }
    }

    // MARK: - Initializer

    init(logger: Logger = DefaultLogger.shared,
         tabDataStore: TabDataStore = AppContainer.shared.resolve(),
         userDefaults: UserDefaultsInterface = UserDefaults.standard) {
        self.logger = logger
        self.tabDataStore = tabDataStore
        self.defaults = userDefaults
    }

    // MARK: - Public API

    func newBrowserWindowConfigured(_ windowInfo: AppWindowInfo, uuid: WindowUUID) {
        updateWindow(windowInfo, for: uuid)
        if let reservedUUIDIdx = reservedUUIDs.firstIndex(where: { $0 == uuid }) {
            reservedUUIDs.remove(at: reservedUUIDIdx)
        }
    }

    func tabManager(for windowUUID: WindowUUID) -> TabManager {
        guard let tabManager = window(for: windowUUID)?.tabManager else {
            assertionFailure("Tab Manager unavailable for requested UUID: \(windowUUID). This is a client error.")
            logger.log("No tab manager for window UUID.", level: .fatal, category: .window)
            return window(for: activeWindow)?.tabManager ?? windows.first!.value.tabManager!
        }

        return tabManager
    }

    func allWindowTabManagers() -> [TabManager] {
        return windows.compactMap { uuid, window in window.tabManager }
    }

    func allWindowUUIDs(includingReserved: Bool) -> [WindowUUID] {
        return Array(windows.keys) + (includingReserved ? reservedUUIDs : [])
    }

    func windowWillClose(uuid: WindowUUID) {
        postWindowEvent(event: .windowWillClose, windowUUID: uuid)
        updateWindow(nil, for: uuid)

        // Closed windows are popped off and moved behind any already-open windows in the list
        var prefs = windowOrderingPriority
        prefs.removeAll(where: { $0 == uuid })
        let openWindows = Array(windows.keys)
        let idx = prefs.firstIndex(where: { !openWindows.contains($0) })
        prefs.insert(uuid, at: idx ?? prefs.count)
        windowOrderingPriority = prefs
    }

    func reserveNextAvailableWindowUUID() -> WindowUUID {
        // Continue to provide the expected hardcoded UUID for UI tests.
        guard !AppConstants.isRunningUITests else { return WindowUUID.DefaultUITestingUUID }

        // • If no saved windows (tab data), we generate a new UUID.
        // • If user has saved windows (tab data), we return the first available UUID
        //   not already associated with an open window.
        // • If multiple window UUIDs are available, we currently return the first one
        //   after sorting based on the order they were last closed (which we track in
        //   client user defaults).
        // • If for some reason the user defaults are unavailable we sort open the
        //   windows by order of their UUID value.

        // Fetch available window data on disk, and remove any already-opened windows
        // or UUIDs that are already reserved and in the process of opening.
        let openWindowUUIDs = windows.keys
        let filteredUUIDs = tabDataStore.fetchWindowDataUUIDs().filter {
            !openWindowUUIDs.contains($0) && !reservedUUIDs.contains($0)
        }

        let result = nextWindowUUIDToOpen(filteredUUIDs)
        let resultUUID = result.uuid
        if result.isNew {
            // Be sure to add any brand-new windows to our ordering preferences
            var prefs = windowOrderingPriority
            prefs.insert(resultUUID, at: 0)
            windowOrderingPriority = prefs
        }

        // Reserve the UUID until the Client finishes the window configuration process
        reservedUUIDs.append(resultUUID)
        return resultUUID
    }

    func postWindowEvent(event: WindowEvent, windowUUID: WindowUUID) {
        windows.forEach { uuid, windowInfo in
            // Notify any interested Coordinators, in each window, of the
            // event. Any Coordinator can receive these by conforming to the
            // WindowEventCoordinator protocol.
            windowInfo.sceneCoordinator?.recurseChildCoordinators {
                guard let coordinator = $0 as? WindowEventCoordinator else { return }
                coordinator.coordinatorHandleWindowEvent(event: event, uuid: windowUUID)
            }
        }
    }

    // MARK: - Internal Utilities

    /// When provided a list of UUIDs of available window data files on disk,
    /// this function determines which of them should be the next to be
    /// opened. This allows multiple windows to be restored in a sensible way.
    /// - Parameter onDiskUUIDs: on-disk UUIDs representing windows that are not
    /// already open or reserved (this is important - these UUIDs should be pre-
    /// filtered).
    /// - Returns: the UUID for the next window that will be opened on iPad.
    private func nextWindowUUIDToOpen(_ onDiskUUIDs: [WindowUUID]) -> (uuid: WindowUUID, isNew: Bool) {
        func nextUUIDUsingFallbackSorting() -> (uuid: WindowUUID, isNew: Bool) {
            let sortedUUIDs = onDiskUUIDs.sorted(by: { return $0.uuidString > $1.uuidString })
            if let resultUUID = sortedUUIDs.first {
                return (uuid: resultUUID, isNew: false)
            }
            return (uuid: WindowUUID(), isNew: true)
        }

        guard !onDiskUUIDs.isEmpty else {
            return (uuid: WindowUUID(), isNew: true)
        }

        // Get the ordering preference
        let priorityPreference = windowOrderingPriority
        guard !priorityPreference.isEmpty else {
            // Preferences are empty. Could be initial launch after multi-window release
            // or preferences have been cleared. Fallback to default sort.
            return nextUUIDUsingFallbackSorting()
        }

        // Iterate and return the first UUID that is available within our on-disk UUIDs
        // (which excludes windows already open or reserved).
        for uuid in priorityPreference where onDiskUUIDs.contains(uuid) {
            return (uuid: uuid, isNew: false)
        }

        return nextUUIDUsingFallbackSorting()
    }

    private func updateWindow(_ info: AppWindowInfo?, for uuid: WindowUUID) {
        windows[uuid] = info
        didUpdateWindow(uuid)
    }

    /// Called internally when a window is updated (or removed).
    /// - Parameter uuid: the UUID of the window that changed.
    private func didUpdateWindow(_ uuid: WindowUUID) {
        // Convenience. If the client has successfully configured
        // a window and it is the only window in the app, we can
        // be sure we automatically set it as the active window.
        if windows.count == 1 {
            activeWindow = windows.keys.first!
        }
    }

    private func uuidForActiveWindow() -> WindowUUID {
        guard !windows.isEmpty else {
            // No app windows. Unsupported state; can't recover gracefully.
            fatalError()
        }

        guard windows.count > 1 else {
            // For apps with only 1 window we can always safely return it as the active window.
            return windows.keys.first!
        }

        guard let uuid = _activeWindowUUID else {
            let message = "App has multiple windows but no active window UUID. This is a client error."
            logger.log(message, level: .fatal, category: .window)
            assertionFailure(message)
            return windows.keys.first!
        }
        return uuid
    }

    private func window(for windowUUID: WindowUUID, createIfNeeded: Bool = false) -> AppWindowInfo? {
        let windowInfo = windows[windowUUID]
        if windowInfo == nil && createIfNeeded {
            return AppWindowInfo(tabManager: nil)
        }
        return windowInfo
    }
}
