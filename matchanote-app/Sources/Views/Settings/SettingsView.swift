import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: SettingsSection? = nil
    @State private var showingPremiumAlert = false
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    enum SettingsSection {
        case account
        case preferences
        case trash
        case models
        case noteEditor
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let section = selectedSection {
                    // Show the selected section
                    switch section {
                    case .account:
                        AccountSettingsView()
                    case .preferences:
                        PreferencesView()
                    case .noteEditor:
                        NoteEditorSettingsView()
                    case .trash:
                        TrashView()
                    case .models:
                        ModelsSettingsView()
                    }
                } else {
                    // Show main settings menu
                    mainSettingsView
                }
            }
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedSection != nil {
                        Button(action: { selectedSection = nil }) {
                            HStack(spacing: 4) {
                                Text("Back")
                            }
                        }
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
            }
        }
    }
    
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return version
    }
    
    private var mainSettingsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
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
            
            // Settings content (non-scrollable, no subheadings)
            VStack(alignment: .leading, spacing: 12) {
                SettingsItemView(item: SettingsItem(
                    title: "Account",
                    subtitle: "Manage your account",
                    icon: "person.circle",
                    action: {
                        selectedSection = .account
                    }
                ))

                SettingsItemView(item: SettingsItem(
                    title: "Preferences",
                    subtitle: "Customize your Matcha experience",
                    icon: "paintpalette",
                    action: {
                        selectedSection = .preferences
                    }
                ))

                SettingsItemView(item: SettingsItem(
                    title: "Note editor",
                    subtitle: "Preferences for the note editor",
                    icon: "pencil.and.outline",
                    action: {
                        selectedSection = .noteEditor
                    }
                ))

                SettingsItemView(item: SettingsItem(
                    title: "Models",
                    subtitle: "Enable or disable AI models",
                    icon: "slider.vertical.3",
                    action: {
                        // Check if user is pro before allowing access to models
                        let userTier = subscriptionManager.userProfile?.subscriptionTier ?? .free
                        if userTier == .pro {
                            selectedSection = .models
                        } else {
                            showingPremiumAlert = true
                        }
                    }
                ))

                SettingsItemView(item: SettingsItem(
                    title: "Trash",
                    subtitle: "Manage deleted items",
                    icon: "trash",
                    action: {
                        selectedSection = .trash
                    }
                ))

                SettingsItemView(item: SettingsItem(
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    icon: "arrow.right.square",
                    isDestructive: true,
                    action: {
                        Task {
                            // Sign out from Supabase and clear local auth state
                            do { try await auth.signOut() } catch { print("Supabase signOut error: \(error)") }
                            LocalAuthManager.shared.logout()
                        }
                    }
                ))

                Spacer()
                Text("Version \(appVersionString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            // Fetch user profile to check subscription status
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
        .alert("Premium Feature", isPresented: $showingPremiumAlert) {
            Button("OK", role: .cancel) { }
            Button("Upgrade") {
                // Take user to the Account page for upgrade options
                selectedSection = .account
            }
        } message: {
            Text("Model configuration is a premium feature. Upgrade to Pro to customize your AI models.")
        }
    }
    
    private func settingsSection(title: String, icon: String, items: [SettingsItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            }
            
            VStack(spacing: 8) {
                ForEach(items) { item in
                    SettingsItemView(item: item)
                }
            }
        }
    }
}

struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
}

struct SettingsItemView: View {
    let item: SettingsItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(
                        item.isDestructive 
                            ? .red 
                            : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    )
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.jost(.subheadline()))
                        .foregroundColor(item.isDestructive ? .red : .primary)
                    
                    Text(item.subtitle)
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Legacy SettingsPopover for backward compatibility
struct SettingsPopover: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingPreferences = false
    @State private var showingTrash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                .padding(.bottom, 5)

            Divider()

            Button(action: {
                if let url = URL(string: "https://matchanote.app/app/settings") {
                    UIApplication.shared.open(url)
                }
            }) {
                Label("Account", systemImage: "person.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                showingPreferences = true
            }) {
                Label("Preferences", systemImage: "paintpalette")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                showingTrash = true
            }) {
                Label("Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
            .buttonStyle(PlainButtonStyle())

            Divider()

            Button(action: {
                LocalAuthManager.shared.logout()
            }) {
                Label("Sign Out", systemImage: "arrow.right.square")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .frame(width: 200)
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingTrash) {
            TrashView()
        }
    }
}