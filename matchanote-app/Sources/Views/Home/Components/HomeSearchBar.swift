import SwiftUI
// MARK: - Search Bar Component
struct HomeSearchBar: View {
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