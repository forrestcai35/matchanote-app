import SwiftUI

// MARK: - Animated Option Button
struct MatchaOptionButton<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: {
            withAnimation(MatchaUI.Animation.spring) {
                action()
            }
        }) {
            content
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(MatchaUI.Animation.spring, value: isSelected)
    }
}

// MARK: - Theme Option Component
struct MatchaThemeOption: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MatchaOptionButton(isSelected: isSelected, action: onSelect) {
            VStack(spacing: 8) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : Color.gray.opacity(0.15)
                        )
                        .frame(width: 36, height: 36)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(MatchaUI.Animation.spring, value: isSelected)

                    Image(systemName: theme.iconName)
                        .font(.subheadline)
                        .foregroundColor(
                            isSelected
                                ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                : Color.primary.opacity(0.7)
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(MatchaUI.Animation.spring, value: isSelected)
                }

                // Label
                Text(theme.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(MatchaUI.Animation.spring, value: isSelected)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.15)
                                : Color.matchalight_light.opacity(0.15))
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                            .stroke(
                                isSelected
                                    ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
    }
}

// MARK: - Orientation Option Component
struct MatchaOrientationOption: View {
    let orientation: AssistantOrientation
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MatchaOptionButton(isSelected: isSelected, action: onSelect) {
            VStack(spacing: 12) {
                // Visual representation with animation
                ZStack {
                    RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                        .stroke(
                            isSelected
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2.5 : 1.5
                        )
                        .fill(
                            isSelected
                                ? (colorScheme == .dark
                                    ? Color.matchalight_dark.opacity(0.1)
                                    : Color.matchalight_light.opacity(0.1))
                                : Color.clear
                        )
                        .frame(width: 70, height: 42)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(MatchaUI.Animation.spring, value: isSelected)

                    HStack(spacing: 3) {
                        if orientation == .left {
                            Rectangle()
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 16, height: 24)
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(MatchaUI.Animation.spring, value: isSelected)
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 42, height: 24)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 42, height: 24)
                            Rectangle()
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 16, height: 24)
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(MatchaUI.Animation.spring, value: isSelected)
                        }
                    }
                    .cornerRadius(6)
                }

                // Label and description
                VStack(spacing: 4) {
                    Text(orientation.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(MatchaUI.Animation.spring, value: isSelected)

                    Text("Assistant on the \(orientation.displayName.lowercased())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.08)
                                : Color.matchalight_light.opacity(0.08))
                            : Color.clear
                    )
            )
        }
    }
}

// MARK: - Compact Orientation Option Component
struct MatchaCompactOrientationOption: View {
    let orientation: AssistantOrientation
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MatchaOptionButton(isSelected: isSelected, action: onSelect) {
            HStack(spacing: 8) {
                // Compact visual representation
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                        .fill(
                            isSelected
                                ? (colorScheme == .dark
                                    ? Color.matchalight_dark.opacity(0.1)
                                    : Color.matchalight_light.opacity(0.1))
                                : Color.clear
                        )
                        .frame(width: 50, height: 30)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(MatchaUI.Animation.spring, value: isSelected)

                    HStack(spacing: 2) {
                        if orientation == .left {
                            Rectangle()
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 12, height: 18)
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(MatchaUI.Animation.spring, value: isSelected)
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 30, height: 18)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 30, height: 18)
                            Rectangle()
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 12, height: 18)
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(MatchaUI.Animation.spring, value: isSelected)
                        }
                    }
                    .cornerRadius(4)
                }

                // Label - use abbreviated form
                Text(orientation == .left ? "L" : "R")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(.primary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(MatchaUI.Animation.spring, value: isSelected)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.08)
                                : Color.matchalight_light.opacity(0.08))
                            : Color.clear
                    )
            )
        }
    }
}

