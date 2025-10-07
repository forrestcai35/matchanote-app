import SwiftUI

struct NoteEditorToolsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // AppStorage toggles for each tool
    @AppStorage("preferences.noteEditor.tools.pen") private var showToolPen: Bool = true
    @AppStorage("preferences.noteEditor.tools.marker") private var showToolMarker: Bool = true
    @AppStorage("preferences.noteEditor.tools.eraser") private var showToolEraser: Bool = true
    @AppStorage("preferences.noteEditor.tools.lasso") private var showToolLasso: Bool = true
    @AppStorage("preferences.noteEditor.tools.photo") private var showToolPhoto: Bool = true
    @AppStorage("preferences.noteEditor.tools.textbox") private var showToolTextbox: Bool = true
    @AppStorage("preferences.noteEditor.tools.shape") private var showToolShape: Bool = true

    // Persist tool order as a comma-separated list
    @AppStorage("preferences.noteEditor.tools.order") private var toolOrderString: String = "pen,marker,eraser,lasso,photo,textbox,shape"

    private var toolOrder: [String] {
        get { toolOrderString.split(separator: ",").map { String($0) }.filter { !$0.isEmpty } }
        nonmutating set { toolOrderString = newValue.joined(separator: ",") }
    }

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
                    ForEach(toolOrder, id: \.self) { toolId in
                        HStack(spacing: 12) {
                            // Visibility toggle (eye / eye.slash) on the left
                            let visBinding = binding(for: toolId)
                            Button(action: { visBinding.wrappedValue.toggle() }) {
                                Image(systemName: visBinding.wrappedValue ? "eye" : "eye.slash")
                                    .foregroundColor(
                                        visBinding.wrappedValue
                                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                            : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(visBinding.wrappedValue ? "Hide tool" : "Show tool")

                            // Tool icon (fill), adaptive to light/dark
                            Image(iconName(for: toolId))
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)


                            // Tool name
                            Text(displayName(for: toolId))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .onMove { indices, newOffset in
                        var items = toolOrder
                        items.move(fromOffsets: indices, toOffset: newOffset)
                        toolOrder = items
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
    private func binding(for toolId: String) -> Binding<Bool> {
        switch toolId {
        case "pen": return $showToolPen
        case "marker": return $showToolMarker
        case "eraser": return $showToolEraser
        case "lasso": return $showToolLasso
        case "photo": return $showToolPhoto
        case "textbox": return $showToolTextbox
        case "shape": return $showToolShape
        default: return .constant(true)
        }
    }

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


