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
                    .font(.system(.largeTitle, design: .serif))
                    .bold()
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
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Show or hide tools in the editor toolbar")
                                    .font(.caption2)
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
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Show or hide time, battery, and carrier while editing notes")
                                .font(.caption2)
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
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Allow drawing with finger in addition to Apple Pencil")
                                .font(.caption2)
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
      
                } header: {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Display")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .navigationBarTitleDisplayMode(.inline)
    }
}


