import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                MatchaPageHeader("Preferences", subtitle: "Customize your Matcha experience")

                // Appearance Section
                VStack(alignment: .leading, spacing: 12) {
                    MatchaSectionHeader(
                        title: "Appearance",
                        icon: "paintbrush.fill",
                        delay: 0.1
                    )

                    MatchaCard(delay: 0.2) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Theme")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Choose how Matcha looks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    MatchaThemeOption(
                                        theme: theme,
                                        isSelected: preferencesManager.theme == theme,
                                        onSelect: {
                                            preferencesManager.theme = theme
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                // Assistant Section
                VStack(alignment: .leading, spacing: 12) {
                    MatchaSectionHeader(
                        title: "Assistant",
                        icon: "brain.head.profile",
                        delay: 0.3
                    )

                    MatchaCard(delay: 0.4) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default Orientation")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Choose which side the assistant appears on")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
                                ForEach(AssistantOrientation.allCases, id: \.self) { orientation in
                                    MatchaOrientationOption(
                                        orientation: orientation,
                                        isSelected: preferencesManager.assistantDefaultOrientation == orientation,
                                        onSelect: {
                                            preferencesManager.assistantDefaultOrientation = orientation
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                }
            }
        }
    }
}
