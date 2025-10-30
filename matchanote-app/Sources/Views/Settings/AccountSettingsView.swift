import SwiftUI
import StoreKit
import Supabase

struct AccountSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var email: String? = nil
    @State private var loadingEmail = false
    
    private let webManagerURL = URL(string: "https://matchanote.app/app/settings")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Account")
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

            ScrollView {
                VStack(spacing: 16) {
     

                    // User info card
                    userInfoCard

                    // Subscription status card
                    subscriptionStatusCard

                    // Manage on Web
                    manageOnWebCard

                    Spacer(minLength: 12)
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .task {
            await subscriptionManager.fetchUserProfile()
        }

        .task { await loadEmail() }
    }





    private var userInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Signed in")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)

            Text(emailText)
                .font(.jost(.caption()))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var subscriptionStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "seal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Subscription Status")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
                statusBadge
            }

            if let profile = subscriptionManager.userProfile {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Tier:")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text(profile.subscriptionTier.rawValue.uppercased())
                            .font(.jost(.caption()))
                    }
                    HStack {
                        Text("Premium requests:")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text("\(profile.premiumRequests)")
                            .font(.jost(.caption()))
                    }
                    HStack {
                        Text("Normal requests:")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text("\(profile.normalRequests)")
                            .font(.jost(.caption()))
                    }
                    if let start = profile.subscriptionStartDate {
                        HStack {
                            Text("Started:")
                                .font(.jost(.caption()))
                                .foregroundColor(.secondary)
                            Text(Self.dateFormatter.string(from: start))
                                .font(.jost(.caption()))
                        }
                    }
           
            
                }
                .padding(.top, 4)
            } else if subscriptionManager.isLoading {
                ProgressView().progressViewStyle(.circular)
            } else if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var manageOnWebCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Manage on Web")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }
            Text("Open the web manager to update billing and account details.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)

            Button {
                if let url = webManagerURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Open Web Manager")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light).opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var statusBadge: some View {
        Group {
            if let profile = subscriptionManager.userProfile {
                let isPro = profile.subscriptionTier == .pro
                Text(isPro ? "PRO" : "FREE")
                    .font(.jost(.caption2()))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(isPro ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    )
                    .foregroundColor(isPro ? .green : .secondary)
            } else {
                Text("–")
                    .font(.jost(.caption2()))
                    .foregroundColor(.secondary)
            }
        }
    }


    private var emailText: String {
        if loadingEmail { return "Loading…" }
        return email ?? "Unknown"
    }

    private func loadEmail() async {
        loadingEmail = true
        defer { loadingEmail = false }
        do {
            let session = try await supabase.auth.session
            email = session.user.email
        } catch {
            email = nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
}
