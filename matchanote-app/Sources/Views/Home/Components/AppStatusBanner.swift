//
//  AppStatusBanner.swift
//  matchanote-app
//
//  Unified banner for app status notifications (web API + App Store updates)
//

import SwiftUI

struct AppStatusBanner: View {
    @ObservedObject var statusManager: AppStatusManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Info Mode Banner (from web API - MESSAGE_MODE = 'info')
            if statusManager.currentMessageMode == .info, let info = statusManager.appStatus?.info {
                infoBanner(info)
            }
            // Force Update Banner (users below minimum version)
            else if statusManager.shouldShowForceUpdate, let updateSystem = statusManager.appStatus?.updateSystem {
                forceUpdateBanner(updateSystem)
            }
            // App Store Update Banner (optional update available)
            else if statusManager.shouldShowAppStoreUpdateBanner {
                appStoreUpdateBanner
            }
        }
    }

    // MARK: - Info Banner (Web API)

    @ViewBuilder
    private func infoBanner(_ info: InfoConfig) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName(for: info.type))
                .font(.system(size: 24))
                .foregroundColor(iconColor(for: info.type))

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.jost(.body()))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(info.message)
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Action button (if provided)
            if let buttonText = info.buttonText {
                Button(action: {
                    if let buttonUrl = info.buttonUrl {
                        statusManager.openURL(buttonUrl)
                    }
                }) {
                    Text(buttonText)
                        .font(.jost(.body()))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(iconColor(for: info.type))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Dismiss button (always dismissible in info mode)
            Button(action: {
                withAnimation {
                    statusManager.dismissInfo()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: info.type))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor(for: info.type), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Force Update Banner (for users below minimum version)

    @ViewBuilder
    private func forceUpdateBanner(_ updateSystem: UpdateSystemConfig) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(updateSystem.forceUpdateTitle)
                    .font(.jost(.body()))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(updateSystem.forceUpdateMessage)
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Update button
            Button(action: {
                statusManager.openAppStore()
            }) {
                Text("Update")
                    .font(.jost(.body()))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Dismiss button
            Button(action: {
                withAnimation {
                    statusManager.dismissForceUpdate()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - App Store Update Banner (optional update)

    private var appStoreUpdateBanner: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Update Available")
                    .font(.jost(.body()))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let version = statusManager.latestAppStoreVersion {
                    Text("Version \(version) is now available")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Update button
            Button(action: {
                statusManager.openAppStore()
            }) {
                Text("Update")
                    .font(.jost(.body()))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Dismiss button
            Button(action: {
                withAnimation {
                    statusManager.dismissAppStoreUpdate()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    colorScheme == .dark
                        ? Color.matchalight_dark.opacity(0.1)
                        : Color.matchalight_light.opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.3)
                                : Color.matchalight_light.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Styling Helpers

    private func iconName(for type: InfoConfig.InfoType) -> String {
        switch type {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func iconColor(for type: InfoConfig.InfoType) -> Color {
        switch type {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func backgroundColor(for type: InfoConfig.InfoType) -> Color {
        switch type {
        case .info:
            return Color.blue.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }

    private func borderColor(for type: InfoConfig.InfoType) -> Color {
        switch type {
        case .info:
            return Color.blue.opacity(0.3)
        case .warning:
            return Color.orange.opacity(0.3)
        case .error:
            return Color.red.opacity(0.3)
        }
    }
}
