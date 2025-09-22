import SwiftUI

struct SubscriptionStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            if subscriptionManager.isLoading {
                ProgressView("Loading subscription...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let profile = subscriptionManager.userProfile {
                subscriptionDetailsView(profile)
            } else {
                Text("Unable to load subscription details")
                    .foregroundColor(.red)
            }

            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Refresh") {
                    Task {
                        await subscriptionManager.forceRefreshUserProfile()
                    }
                }
                .buttonStyle(.bordered)

                if subscriptionManager.isProfileDataStale() {
                    Text("⚠️ Data may be outdated")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
        .cornerRadius(12)
        .onAppear {
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
    }

    @ViewBuilder
    private func subscriptionDetailsView(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            // Subscription Tier
            HStack {
                Text("Plan:")
                    .font(.headline)
                Spacer()
                Text(profile.subscriptionTier.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(tierColor(profile.subscriptionTier))
            }

            Divider()

            // Request Counters
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Free Requests")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(profile.normalRequests)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(profile.normalRequests > 0 ? .green : .red)
                    }

                    Spacer()

                    if profile.subscriptionTier.hasPremiumAccess {
                        VStack(alignment: .trailing) {
                            Text("Premium Requests")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(profile.premiumRequests)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(profile.premiumRequests > 0 ? .green : .red)
                        }
                    }
                }

                // Request usage bars
                VStack(spacing: 4) {
                    requestUsageBar(
                        label: "Free",
                        current: Int(profile.normalRequests),
                        maximum: 500, // Default free requests
                        color: .blue
                    )

                    if profile.subscriptionTier.hasPremiumAccess {
                        requestUsageBar(
                            label: "Premium",
                            current: Int(profile.premiumRequests),
                            maximum: profile.subscriptionTier == .student ? 100 : 1000, // Assumed limits
                            color: .purple
                        )
                    }
                }
            }

            if profile.subscriptionTier.hasPremiumAccess {
                Divider()

                // Premium Models Available
                VStack(alignment: .leading) {
                    Text("Premium Models Available:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(PremiumModels.premiumModelsList, id: \.self) { model in
                            Text(model)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            if let startDate = profile.subscriptionStartDate {
                Divider()

                HStack {
                    Text("Subscription started:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func requestUsageBar(label: String, current: Int, maximum: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(current)/\(maximum)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (Double(current) / Double(maximum)), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }

    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free:
            return .blue
        case .student:
            return .green
        case .pro:
            return .purple
        }
    }
}

// MARK: - Compact Subscription Status Component
struct CompactSubscriptionStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some View {
        HStack {
            if let profile = subscriptionManager.userProfile {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(profile.subscriptionTier.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(tierColor(profile.subscriptionTier))

                        Spacer()

                        if profile.subscriptionTier.hasPremiumAccess {
                            Text("⭐")
                                .font(.caption)
                        }
                    }

                    HStack {
                        Text("Free: \(profile.normalRequests)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if profile.subscriptionTier.hasPremiumAccess {
                            Text("Premium: \(profile.premiumRequests)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
    }

    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free: return .blue
        case .student: return .green
        case .pro: return .purple
        }
    }
}

#Preview {
    VStack {
        SubscriptionStatusView()

        Divider()
            .padding()

        CompactSubscriptionStatusView()
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
}