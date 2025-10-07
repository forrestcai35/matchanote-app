import SwiftUI

struct ModelsSettingsView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
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
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ModelConfiguration.allModels, id: \.displayName) { model in
                            HStack(spacing: 10) {
                                ModelNameLabel(name: model.displayName, font: .subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { preferencesManager.isModelEnabled(model.displayName) },
                                    set: { preferencesManager.setModel(model.displayName, enabled: $0) }
                                ))
                                .labelsHidden()
                                .controlSize(.small)
                                .tint(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                .scaleEffect(0.9)
                            }
                            .padding(.vertical, 4)
                        }
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
                    Text("Enable models to show them in AI dropdowns. Some models require a paid plan.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
    }
}


