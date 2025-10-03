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

                // Appearance and Assistant Sections (Side by Side)
                HStack(alignment: .top, spacing: 12) {
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        MatchaSectionHeader(
                            title: "Appearance",
                            icon: "paintbrush.fill"
                        )

                        MatchaCard {
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
                    .frame(maxWidth: .infinity)

                    // Assistant Section
                    VStack(alignment: .leading, spacing: 12) {
                        MatchaSectionHeader(
                            title: "Assistant",
                            icon: "brain.head.profile"
                        )

                        MatchaCard {
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
                                        MatchaCompactOrientationOption(
                                            orientation: orientation,
                                            isSelected: preferencesManager.assistantDefaultOrientation == orientation,
                                            onSelect: {
                                                preferencesManager.assistantDefaultOrientation = orientation
                                            }
                                        )
                                    }
                                }
                                
                                // Add some extra spacing to match the theme segment height
                                Spacer()
                                    .frame(height: 10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

           

                // Storage Section
                VStack(alignment: .leading, spacing: 12) {
                    MatchaSectionHeader(
                        title: "Storage",
                        icon: "externaldrive.fill"
                    )

                    MatchaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            MatchaToggle(
                                title: "Cloud Sync",
                                subtitle: "Sync your notes and folders to the cloud (Premium feature)",
                                icon: "icloud.fill",
                                isOn: $preferencesManager.supabaseStorageEnabled
                            )
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
