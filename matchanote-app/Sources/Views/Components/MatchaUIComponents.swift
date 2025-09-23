import SwiftUI

// MARK: - Matcha UI Constants
struct MatchaUI {
    // Animation constants
    struct Animation {
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
        static let enterDelay: Double = 0.1
        static let staggerDelay: Double = 0.1

        static var spring: SwiftUI.Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }

        static func springWithDelay(_ delay: Double) -> SwiftUI.Animation {
            spring.delay(delay)
        }
    }

    // Styling constants
    struct Style {
        static let cardCornerRadius: Double = 16
        static let itemCornerRadius: Double = 12
        static let cardPadding: Double = 20
        static let sectionSpacing: Double = 32
        static let itemSpacing: Double = 16
    }
}

// MARK: - Animated Card Component
struct MatchaCard<Content: View>: View {
    let content: Content
    @State private var animateOnAppear = false
    let delay: Double

    @Environment(\.colorScheme) private var colorScheme

    init(delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, MatchaUI.Style.cardPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MatchaUI.Style.cardCornerRadius)
                    .fill(
                        colorScheme == .dark
                            ? Color.black.opacity(0.2)
                            : Color.white.opacity(0.7)
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.08),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
            .padding(.horizontal, MatchaUI.Style.cardPadding)
            .opacity(animateOnAppear ? 1.0 : 0.0)
            .offset(y: animateOnAppear ? 0 : 20)
            .animation(MatchaUI.Animation.springWithDelay(delay), value: animateOnAppear)
            .onAppear {
                animateOnAppear = true
            }
    }
}

// MARK: - Section Header Component
struct MatchaSectionHeader: View {
    let title: String
    let icon: String
    let delay: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var animateOnAppear = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                .font(.title3)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
        .padding(.horizontal, MatchaUI.Style.cardPadding)
        .opacity(animateOnAppear ? 1.0 : 0.0)
        .offset(y: animateOnAppear ? 0 : 20)
        .animation(MatchaUI.Animation.springWithDelay(delay), value: animateOnAppear)
        .onAppear {
            animateOnAppear = true
        }
    }
}

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

// MARK: - Animated Page Header
struct MatchaPageHeader: View {
    let title: String
    let subtitle: String?

    @State private var animateOnAppear = false
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(animateOnAppear ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateOnAppear)
            }
        }
        .padding(.horizontal, MatchaUI.Style.cardPadding)
        .padding(.top, 16)
        .onAppear {
            animateOnAppear = true
        }
    }
}

// MARK: - Sidebar Item Component
struct MatchaSidebarItem: View {
    let item: SidebarItem
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                            : (colorScheme == .dark ? Color.matchadark_dark.opacity(0.8) : Color.matchadark_light.opacity(0.8))
                    )
                    .frame(width: 24)

                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            : (colorScheme == .dark ? Color.matchabrown_dark.opacity(0.8) : Color.matchabrown_light.opacity(0.8))
                    )

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
                                    ? (colorScheme == .dark ? Color.matchalight_dark.opacity(0.3) : Color.matchalight_light.opacity(0.3))
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(MatchaUI.Animation.spring, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Menu Item Component
struct MatchaMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let isDestructive: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        isDestructive
                            ? .red
                            : (colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
                    )
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(
                        isDestructive
                            ? .red
                            : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    )

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Bar Component
struct MatchaSearchBar: View {
    @Binding var searchText: String
    let placeholder: String

    @Environment(\.colorScheme) private var colorScheme

    init(_ placeholder: String = "Search", text: Binding<String>) {
        self.placeholder = placeholder
        self._searchText = text
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color.matchadark_dark.opacity(0.6) : Color.matchadark_light.opacity(0.6))

            TextField(placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                .fill(
                    colorScheme == .dark
                        ? Color.black.opacity(0.2)
                        : Color.white.opacity(0.7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MatchaUI.Style.itemCornerRadius)
                        .stroke(
                            colorScheme == .dark
                                ? Color.gray.opacity(0.2)
                                : Color.gray.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }
}