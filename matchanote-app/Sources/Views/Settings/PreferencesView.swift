import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager(supabaseClient: supabase)
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

                    // Auto-Fill toggle (PRO only)
                    if subscriptionManager.getEffectiveProfile()?.subscriptionTier == .pro {
                        Toggle(isOn: $preferencesManager.assistantAutoFill) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Auto-Fill Worksheets")
                                        .font(.jost(.subheadline()))
                                        .foregroundColor(.primary)

                                    // PRO badge
                                    Text("PRO")
                                        .font(.jost(.caption2()))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .cornerRadius(4)
                                }

                                Text("Automatically insert answers into forms and worksheets")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }


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
