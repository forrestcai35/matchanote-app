import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.jost(.largeTitle()))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)
            
            // Preferences list
            List {
                // Force list to refresh its styling when theme changes
                // Appearance Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme")
                                .font(.jost(.subheadline()))
                                .foregroundColor(.primary)
                            
                            Text("Choose how Matcha looks")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
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
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Appearance")
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
                
                // Assistant Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Orientation")
                                .font(.jost(.subheadline()))
                                .foregroundColor(.primary)
                            
                            Text("Choose which side the assistant appears on")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
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
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Assistant")
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
                
                // Storage Section
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cloud Sync")
                                .font(.jost(.subheadline()))
                                .foregroundColor(.primary)
                            
                            Text("Sync your notes and folders to the cloud (Premium feature)")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $preferencesManager.supabaseStorageEnabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "externaldrive.fill")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Storage")
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
                
                // Models moved to dedicated Models settings view
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .id(preferencesManager.theme)
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        // Ensure this view subtree respects the selected theme immediately
        .preferredColorScheme(colorSchemeForTheme(preferencesManager.theme))
    }


    // Map AppTheme -> ColorScheme used for preferredColorScheme
    private func colorSchemeForTheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
