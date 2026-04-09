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
            ZStack {
                List {
                    // Force list to refresh its styling when theme changes
                    // Appearance Section
                    Section {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Theme")
                                    .font(.jost(.subheadline()))
                                    .foregroundColor(.primary)

                                Text("Choose how Matcha looks")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                            .fixedSize()
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
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default Orientation")
                                    .font(.jost(.subheadline()))
                                    .foregroundColor(.primary)

                                Text("Choose which side the assistant appears on")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                            .fixedSize()
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
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.matchalight_dark, Color.matchalight_light],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(4)
                                    }

                                    Text("Automatically insert answers into forms and worksheets")
                                        .font(.jost(.caption2()))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(Color.matchalight_light)
                            .padding(.vertical, 4)
                        }

                        // Draggable Text Blocks toggle
                        Toggle(isOn: $preferencesManager.assistantDraggableBlocks) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Draggable Text Blocks")
                                    .font(.jost(.subheadline()))
                                    .foregroundColor(.primary)

                                Text("Enable \"\"\" blocks for dragging content to canvas")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color.matchalight_light)
                        .padding(.vertical, 4)

                        // Quiz Show Answer toggle
                        Toggle(isOn: $preferencesManager.quizShowAnswerImmediately) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Answer Immediately")
                                    .font(.jost(.subheadline()))
                                    .foregroundColor(.primary)

                                Text("Show answers after each quiz question instead of at the end")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color.matchalight_light)
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



                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
                .id(preferencesManager.theme)

                // Top fade effect
                VStack {
                    (colorScheme == .dark
                        ? Color.matchabackground_dark
                        : Color.matchabackground_light)
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
