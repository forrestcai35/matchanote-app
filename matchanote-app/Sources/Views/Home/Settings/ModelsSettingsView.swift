import SwiftUI

struct ModelsSettingsView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Models")
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
                    ForEach(preferencesManager.getAllOrderedModels(), id: \.self) { modelName in
                        let isEnabled = preferencesManager.isModelEnabled(modelName)
                        
                        HStack(spacing: 12) {
                            // Visibility toggle (eye / eye.slash) on the left
                            let visBinding = Binding(
                                get: { preferencesManager.isModelEnabled(modelName) },
                                set: { preferencesManager.setModel(modelName, enabled: $0) }
                            )
                            let canDisable = preferencesManager.canDisableModel(modelName)
                            
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
                            .accessibilityLabel(visBinding.wrappedValue ? "Hide model" : "Show model")

                            // Model name
                            ModelNameLabel(name: modelName, font: .subheadline)
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
                        .opacity(isEnabled ? 1.0 : 0.6) // Gray out the entire row for disabled models
                    }
                    .onMove { indices, newOffset in
                        var items = preferencesManager.getAllOrderedModels()
                        items.move(fromOffsets: indices, toOffset: newOffset)
                        preferencesManager.updateModelOrder(items)
                    }
                } header: {
                    HStack {
                        Image(systemName: "slider.vertical.3")
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            .font(.system(size: 14))
                        Text("Models")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                } footer: {
                    Text("Enable models to show them in AI dropdowns. Some models require a paid plan. At least one model must remain enabled.")
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
 
    }
}


