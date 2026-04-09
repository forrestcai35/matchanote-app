import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("lastSelectedSettingsSection") private var lastSelectedSectionRaw: String = "account"
    @State private var selectedSection: SettingsSection? = nil

    @StateObject private var subscriptionManager = SubscriptionManager()

    enum SettingsSection: String {
        case account
        case preferences
        case trash
        case models
        case noteEditor
        case helpAndFeedback
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // Sidebar layout for iPad/Mac
                sidebarLayout
            } else {
                // Current navigation for iPhone
                navigationLayout
            }
        }
        .onAppear {
            // Load persisted section or default to account
            if selectedSection == nil {
                selectedSection = SettingsSection(rawValue: lastSelectedSectionRaw) ?? .account
            }
            // Fetch user profile to check subscription status
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
        .onChange(of: selectedSection) { _, newValue in
            // Persist the selected section
            if let section = newValue {
                lastSelectedSectionRaw = section.rawValue
            }
        }

    }

    // MARK: - Sidebar Layout (iPad/Mac)

    private var sidebarLayout: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 0) {
                    // Sidebar items
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            SidebarItemView(
                                title: "Account",
                                icon: "person.circle",
                                isSelected: selectedSection == .account,
                                action: { selectedSection = .account }
                            )

                            SidebarItemView(
                                title: "Preferences",
                                icon: "paintpalette",
                                isSelected: selectedSection == .preferences,
                                action: { selectedSection = .preferences }
                            )

                            SidebarItemView(
                                title: "Note Editor",
                                icon: "pencil.and.outline",
                                isSelected: selectedSection == .noteEditor,
                                action: { selectedSection = .noteEditor }
                            )

                            SidebarItemView(
                                title: "Models",
                                icon: "slider.vertical.3",
                                isSelected: selectedSection == .models,
                                action: { selectedSection = .models },
                                trailingBadge: (subscriptionManager.userProfile?.subscriptionTier ?? .free) == .pro ? nil : "PRO"
                            )

                            SidebarItemView(
                                title: "Trash",
                                icon: "trash",
                                isSelected: selectedSection == .trash,
                                action: { selectedSection = .trash }
                            )

                            SidebarItemView(
                                title: "Help & Feedback",
                                icon: "questionmark.circle",
                                isSelected: selectedSection == .helpAndFeedback,
                                action: { selectedSection = .helpAndFeedback }
                            )

                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 20)
                    }

                    // Version at bottom
                    Text("Version \(appVersionString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }
                .frame(width: 280)
                .background(
                    colorScheme == .dark
                        ? Color.matchabackground_dark : Color.matchabackground_light)

            // Divider
            Divider()

            // Content area
            NavigationView {
                Group {
                    if let section = selectedSection {
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
                        case .helpAndFeedback:
                            HelpAndFeedbackView()
                        }
                    }
                }
                .navigationBarHidden(true)
            }
            .navigationViewStyle(.stack)
        }

        // Done button at top right
        Button("Done") {
            dismiss()
        }
        .font(.jost(.body()))
        .foregroundColor(
            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        .padding(.top, 20)
        .padding(.trailing, 20)
        }
    }

    // MARK: - Navigation Layout (iPhone)

    private var navigationLayout: some View {
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
                    case .helpAndFeedback:
                        HelpAndFeedbackView()
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
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSection == nil {
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
            .padding(.bottom, 12)
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
                    badgeText: (subscriptionManager.userProfile?.subscriptionTier ?? .free) == .pro ? nil : "PRO",
                    action: {
                        selectedSection = .models
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
                    title: "Help & Feedback",
                    subtitle: "Get help and share feedback",
                    icon: "questionmark.circle",
                    action: {
                        selectedSection = .helpAndFeedback
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
    let badgeText: String?
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, isDestructive: Bool = false, badgeText: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.badgeText = badgeText
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
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.jost(.subheadline()))
                            .foregroundColor(item.isDestructive ? .red : .primary)

                        if let badge = item.badgeText {
                            Text(badge)
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
                    }

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

// Sidebar item for iPad/Mac layout
struct SidebarItemView: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let isSelected: Bool
    let action: () -> Void
    var trailingBadge: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        isDestructive
                            ? .red
                            : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    )
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.jost(.subheadline()))
                    .foregroundColor(isDestructive ? .red : .primary)

                if let badge = trailingBadge {
                    Text(badge)
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
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.2)
                                : Color.matchalight_light.opacity(0.15))
                            : (isHovered
                                ? Color.secondary.opacity(0.1)
                                : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
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