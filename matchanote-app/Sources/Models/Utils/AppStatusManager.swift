//
//  AppStatusManager.swift
//  matchanote-app
//
//  Manages app status including web API checks, App Store updates, and maintenance mode
//

import Foundation
import SwiftUI

// MARK: - Models

struct AppStatus: Codable {
    let messageMode: MessageMode
    let info: InfoConfig
    let maintenance: MaintenanceConfig
    let updateSystem: UpdateSystemConfig
    let apiVersion: Int

    enum MessageMode: String, Codable {
        case disabled
        case info
        case maintenance
    }
}

struct UpdateSystemConfig: Codable {
    let enabled: Bool
    let minimumVersion: String
    let forceUpdateTitle: String
    let forceUpdateMessage: String
    let appStoreUrl: String
}

struct InfoConfig: Codable {
    let type: InfoType
    let title: String
    let message: String
    let buttonText: String?
    let buttonUrl: String?

    enum InfoType: String, Codable {
        case info
        case warning
        case error
    }
}

struct MaintenanceConfig: Codable {
    let title: String
    let message: String
}

// MARK: - Manager

@MainActor
class AppStatusManager: ObservableObject {
    static let shared = AppStatusManager()

    // Web API status
    @Published var appStatus: AppStatus?
    @Published var currentMessageMode: AppStatus.MessageMode = .disabled

    // Update system (controlled by web API + App Store)
    @Published var shouldShowForceUpdate = false
    @Published var shouldShowAppStoreUpdateBanner = false
    @Published var latestAppStoreVersion: String?

    // API configuration
    private let statusAPIURL = "https://matchanote.app/api/app-status"
    private let appStoreID = "6744668137"
    private let checkInterval: TimeInterval = 3600 // Check every hour

    private init() {
        // Load cached status immediately on init to prevent data loss
        loadCachedStatus()
    }

    /// Load cached status from UserDefaults to provide immediate protection
    private func loadCachedStatus() {
        if let cachedData = UserDefaults.standard.data(forKey: "cachedAppStatus"),
           let cachedStatus = try? JSONDecoder().decode(AppStatus.self, from: cachedData) {
            self.appStatus = cachedStatus

            // Apply cached maintenance mode immediately
            if cachedStatus.messageMode == .maintenance {
                self.currentMessageMode = .maintenance
            }
        }
    }

    /// Cache the status for immediate loading on next launch
    private func cacheStatus(_ status: AppStatus) {
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: "cachedAppStatus")
        }
    }

    /// Check all app status sources (web API + App Store)
    func checkAppStatus() async {
        // Check web API for immediate status
        await checkWebAPIStatus()

        // Check App Store for updates (less frequent)
        if shouldCheckAppStore() {
            await checkAppStoreUpdate()
        }
    }

    /// Check the web API for app status
    private func checkWebAPIStatus() async {
        do {
            guard let url = URL(string: statusAPIURL) else {
                applyDefaultFallback()
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let status = try JSONDecoder().decode(AppStatus.self, from: data)

            // Update status
            self.appStatus = status

            // Cache status for next launch (provides immediate protection)
            cacheStatus(status)

            // SYSTEM 1: Handle message mode
            switch status.messageMode {
            case .disabled:
                self.currentMessageMode = .disabled
            case .info:
                // Only show if not dismissed
                if !isInfoDismissed(status.info) {
                    self.currentMessageMode = .info
                } else {
                    self.currentMessageMode = .disabled
                }
            case .maintenance:
                self.currentMessageMode = .maintenance
            }

            // SYSTEM 2: Handle update system (independent)
            if status.updateSystem.enabled {
                // Check if user needs force update
                if shouldForceUpdate(status.updateSystem) {
                    self.shouldShowForceUpdate = true
                } else {
                    self.shouldShowForceUpdate = false
                }
            } else {
                // Update system disabled - hide all update prompts
                self.shouldShowForceUpdate = false
                self.shouldShowAppStoreUpdateBanner = false
            }

            // Update last check time
            UserDefaults.standard.set(Date(), forKey: "lastWebAPICheck")

        } catch {
            // FALLBACK: If API fails, default to normal operation (no banners, no blocking)
            print("Error checking web API status: \(error) - using default fallback")
            applyDefaultFallback()
        }
    }

    /// Apply default fallback behavior if API fails
    private func applyDefaultFallback() {
        self.currentMessageMode = .disabled
        self.shouldShowForceUpdate = false
        self.shouldShowAppStoreUpdateBanner = false
        // Don't clear appStatus in case we have cached data
    }

    /// Check App Store for updates
    private func checkAppStoreUpdate() async {
        // Only check if update system is enabled
        guard let updateSystem = appStatus?.updateSystem, updateSystem.enabled else {
            self.shouldShowAppStoreUpdateBanner = false
            return
        }

        guard let currentVersion = getCurrentAppVersion() else {
            self.shouldShowAppStoreUpdateBanner = false
            return
        }

        do {
            let (storeVersion, _) = try await fetchAppStoreVersion()

            // Update last check time
            UserDefaults.standard.set(Date(), forKey: "lastAppStoreCheck")

            // Compare versions - only show banner if newer version available
            if isVersion(storeVersion, greaterThan: currentVersion) {
                self.shouldShowAppStoreUpdateBanner = true
                self.latestAppStoreVersion = storeVersion
            } else {
                self.shouldShowAppStoreUpdateBanner = false
                self.latestAppStoreVersion = nil
            }
        } catch {
            // FALLBACK: If App Store check fails, don't show banner
            print("Error checking App Store: \(error) - hiding update banner")
            self.shouldShowAppStoreUpdateBanner = false
        }
    }

    /// Check if we should check the App Store (based on interval)
    private func shouldCheckAppStore() -> Bool {
        if let lastCheck = UserDefaults.standard.object(forKey: "lastAppStoreCheck") as? Date {
            return Date().timeIntervalSince(lastCheck) >= checkInterval
        }
        return true
    }

    /// Check if the current version requires a force update
    private func shouldForceUpdate(_ config: UpdateSystemConfig) -> Bool {
        guard let currentVersion = getCurrentAppVersion() else { return false }
        return isVersion(config.minimumVersion, greaterThan: currentVersion)
    }

    /// Check if an info banner has been dismissed
    private func isInfoDismissed(_ info: InfoConfig) -> Bool {
        let key = "dismissedInfo_\(info.title)_\(info.message)"
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Dismiss the info banner
    func dismissInfo() {
        guard let info = appStatus?.info else { return }
        let key = "dismissedInfo_\(info.title)_\(info.message)"
        UserDefaults.standard.set(true, forKey: key)
        self.currentMessageMode = .disabled
    }

    /// Dismiss force update banner
    func dismissForceUpdate() {
        shouldShowForceUpdate = false
    }

    /// Dismiss App Store update notification
    func dismissAppStoreUpdate() {
        shouldShowAppStoreUpdateBanner = false
    }

    /// Open URL in Safari
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    /// Open the App Store page
    func openAppStore() {
        if let urlString = appStatus?.updateSystem.appStoreUrl {
            openURL(urlString)
        }
    }

    // MARK: - Helper Methods

    /// Get current app version (same as SettingsView)
    private func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Get formatted app version string for display
    var appVersionString: String {
        return getCurrentAppVersion() ?? "Unknown"
    }

    private func fetchAppStoreVersion() async throws -> (version: String, url: String) {
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(appStoreID)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]],
              let firstResult = results.first,
              let version = firstResult["version"] as? String else {
            throw NSError(domain: "AppStatusManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from App Store"])
        }

        // URL comes from web API config now
        let appStoreUrl = appStatus?.updateSystem.appStoreUrl ?? ""
        return (version, appStoreUrl)
    }

    private func isVersion(_ version1: String, greaterThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0

            if v1Value > v2Value {
                return true
            } else if v1Value < v2Value {
                return false
            }
        }

        return false
    }
}
