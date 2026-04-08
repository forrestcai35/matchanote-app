import SwiftUI

struct ModelsSettingsView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingProAlert = false
    
    private var isProUser: Bool {
        subscriptionManager.userProfile?.subscriptionTier == .pro
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Models")
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

            ZStack {
                List {
                    Section {
                    ForEach(preferencesManager.getAllOrderedModels(), id: \.self) { modelName in
                        let isEnabled = preferencesManager.isModelEnabled(modelName)
                        let isPremium = ModelConfiguration.isPremiumModel(modelName)
                        
                        HStack(spacing: 12) {
                            // Visibility toggle (eye / eye.slash) on the left
                            let visBinding = Binding(
                                get: { preferencesManager.isModelEnabled(modelName) },
                                set: { preferencesManager.setModel(modelName, enabled: $0) }
                            )
                            let canDisable = preferencesManager.canDisableModel(modelName)
                            // Free/student users cannot disable free models (their only usable models)
                            let isLockedFreeModel = !isProUser && !isPremium
                            
                            Button(action: { 
                                // If premium model and user is not pro, show upgrade alert
                                if isPremium && !isProUser {
                                    showingProAlert = true
                                    return
                                }
                                // Don't allow free/student users to disable free models
                                if isLockedFreeModel { return }
                                if canDisable {
                                    visBinding.wrappedValue.toggle()
                                }
                            }) {
                                Image(systemName: visBinding.wrappedValue ? "eye" : "eye.slash")
                                    .foregroundColor(
                                        visBinding.wrappedValue
                                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                            : .secondary)
                                    .opacity((canDisable && !isLockedFreeModel) ? 1.0 : 0.3)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isLockedFreeModel || (!canDisable && !(isPremium && !isProUser)))
                            .accessibilityLabel(visBinding.wrappedValue ? "Hide model" : "Show model")

                            // Model name
                            ModelNameLabel(name: modelName, font: .subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(
                                    (isEnabled && !(isPremium && !isProUser))
                                        ? (colorScheme == .dark ? .white : .black)
                                        : .secondary
                                )
                                .opacity((isEnabled && !(isPremium && !isProUser)) ? 1.0 : 0.4)

                            // PRO badge for premium models
                            if isPremium && !isProUser {
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

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .opacity((isEnabled && !(isPremium && !isProUser)) ? 1.0 : 0.6) // Gray out disabled & locked pro models
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
                            .font(.jost(.subheadline()))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
            } footer: {
                    Text("Enable models to show them in AI dropdowns. Some models require a paid plan. At least one model must remain enabled.")
                        .font(.jost(.caption2()))
                        .foregroundColor(.secondary)
                }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(.top, 8)
                // Always enable edit mode to show system drag handles
                .environment(\.editMode, .constant(.active))

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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
        .alert("Premium Feature", isPresented: $showingProAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please upgrade to enable pro models.")
        }

    }
}


