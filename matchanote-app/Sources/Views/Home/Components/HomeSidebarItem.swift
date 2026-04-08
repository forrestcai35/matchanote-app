import SwiftUI
// MARK: - Sidebar Item Component
struct SidebarItem: Identifiable {
    var id: String
    var title: String
    var icon: String
}

struct HomeSidebarItem: View {
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
                    .font(.jost(.subheadline()))
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            : (colorScheme == .dark ? Color.matchabrown_dark.opacity(0.8) : Color.matchabrown_light.opacity(0.8))
                    )

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            .padding(.horizontal, 18)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(MatchaUI.Animation.spring, value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
