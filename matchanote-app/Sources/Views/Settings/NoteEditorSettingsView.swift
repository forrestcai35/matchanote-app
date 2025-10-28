import SwiftUI

struct NoteEditorSettingsView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Note editor")
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

            List {
                // Tools subsection - navigates to tool toggles view (moved to top)
                Section {
                    NavigationLink {
                        NoteEditorToolsSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "hammer")
                                .foregroundColor(colorScheme == .dark ? .matchabrown_dark : .matchabrown_light)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tools")
                                    .font(.jost(.subheadline()))
                                Text("Show or hide tools in the editor toolbar")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }

                // Display subsection
                Section {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide status bar")
                                .font(.jost(.subheadline()))
                            Text("Show or hide time, battery, and carrier while editing notes")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $preferencesManager.noteEditorStatusBarHidden)
                            .labelsHidden()
                            .controlSize(.small)
                            .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .scaleEffect(0.9)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable finger drawing")
                                .font(.jost(.subheadline()))
                            Text("Allow drawing with finger in addition to Apple Pencil")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $preferencesManager.noteEditorFingerDrawingEnabled)
                            .labelsHidden()
                            .controlSize(.small)
                            .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .scaleEffect(0.9)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left-hand mode")
                                .font(.jost(.subheadline()))
                            Text("Swap toolbar layout for left-handed users")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $preferencesManager.noteEditorLeftHandMode)
                            .labelsHidden()
                            .controlSize(.small)
                            .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .scaleEffect(0.9)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Page boundary indicators")
                                .font(.jost(.subheadline()))
                            Text("Choose how to show page boundaries when zoomed in")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $preferencesManager.noteEditorPageBoundaryIndicatorMode) {
                            ForEach(PageBoundaryIndicatorMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dark mode for white paper")
                                .font(.jost(.subheadline()))
                            Text("Allow dark mode only for white paper notes")
                                .font(.jost(.caption2()))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $preferencesManager.noteEditorDarkModeForWhitePaper)
                            .labelsHidden()
                            .controlSize(.small)
                            .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .scaleEffect(0.9)
                    }
                    .padding(.vertical, 4)


                } header: {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Display")
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
                
                // Gestures subsection
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Undo/Redo gestures")
                                    .font(.jost(.subheadline()))
                                Text(preferencesManager.noteEditorUndoRedoGestureMode.description)
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $preferencesManager.noteEditorUndoRedoGestureMode) {
                                ForEach(UndoRedoGestureMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                        }
                        .padding(.vertical, 4)
                        
                        // Show note for 2-tap/3-tap mode
                        if preferencesManager.noteEditorUndoRedoGestureMode == .twoThreeTap {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("For best results, disable 'Productivity Gestures' in iPad Settings → General → Gestures")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Gestures")
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .navigationBarTitleDisplayMode(.inline)
    }
}


