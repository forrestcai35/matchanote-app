import SwiftUI

struct NoteEditorToolsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var preferencesManager = PreferencesManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Tools")
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
                Section {
                    ForEach(preferencesManager.noteEditorToolsOrder, id: \.self) { toolId in
                        let isEnabled = preferencesManager.isToolEnabled(toolId)
                        
                        HStack(spacing: 12) {
                            // Visibility toggle (eye / eye.slash) on the left
                            let visBinding = Binding(
                                get: { preferencesManager.isToolEnabled(toolId) },
                                set: { preferencesManager.setTool(toolId, enabled: $0) }
                            )
                            let canDisable = preferencesManager.canDisableTool(toolId)
                            
                            Button(action: { 
                                if canDisable {
                                    visBinding.wrappedValue.toggle()
                                }
                            }) {
                                Image(systemName: visBinding.wrappedValue ? "eye" : "eye.slash")
                                    .foregroundColor(
                                        visBinding.wrappedValue
                                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                            : .secondary)
                                    .opacity(canDisable ? 1.0 : 0.3)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!canDisable)
                            .accessibilityLabel(visBinding.wrappedValue ? "Hide tool" : "Show tool")

                            // Tool icon (fill), adaptive to light/dark
                            Image(iconName(for: toolId))
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(
                                    isEnabled
                                        ? (colorScheme == .dark ? .white : .black)
                                        : .secondary
                                )
                                .opacity(isEnabled ? 1.0 : 0.4)

                            // Tool name
                            Text(displayName(for: toolId))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(
                                    isEnabled
                                        ? (colorScheme == .dark ? .white : .black)
                                        : .secondary
                                )
                                .opacity(isEnabled ? 1.0 : 0.4)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .opacity(isEnabled ? 1.0 : 0.6) // Gray out the entire row for disabled tools
                    }
                    .onMove { indices, newOffset in
                        var items = preferencesManager.noteEditorToolsOrder
                        items.move(fromOffsets: indices, toOffset: newOffset)
                        preferencesManager.updateToolsOrder(items)
                    }
                } header: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Tools order & visibility")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                } footer: {
                    Text("Enable tools to show them in the editor toolbar. At least one tool must remain enabled.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            // Always enable edit mode to show system drag handles
            .environment(\.editMode, .constant(.active))
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Text("Back")
                    }
                }
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            }
        }
    }

    // MARK: - Helpers

    private func displayName(for toolId: String) -> String {
        switch toolId {
        case "pen": return "Pen"
        case "marker": return "Marker"
        case "eraser": return "Eraser"
        case "lasso": return "Lasso"
        case "photo": return "Photo"
        case "textbox": return "Textbox"
        case "shape": return "Shape"
        default: return toolId.capitalized
        }
    }

    private func iconName(for toolId: String) -> String {
        switch toolId {
        case "pen": return "pen_fill"
        case "marker": return "highlighter_fill"
        case "eraser": return "eraser_fill"
        case "lasso": return "lasso_fill"
        case "photo": return "photo_fill"
        case "textbox": return "textbox_fill"
        case "shape": return "shapes_fill"
        default: return "pen_fill"
        }
    }
}


