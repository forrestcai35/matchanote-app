import SwiftUI
import StoreKit
import Supabase

struct AccountSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var storeKitManager = StoreKitManager.shared
    @State private var email: String? = nil
    @State private var loadingEmail = false
    @State private var showDeleteConfirmation = false
    @State private var showAppleSubscriptionAlert = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil

    // Computed property to detect Apple ID subscription conflict
    private var hasAppleSubscriptionConflict: Bool {
        guard let profile = subscriptionManager.userProfile else {
            return false  // No false positives if profile not loaded
        }

        let hasApplePurchases = !storeKitManager.purchasedProductIDs.isEmpty
        let accountHasAppleSubscription = profile.subscriptionSource == "apple"

        return hasApplePurchases && !accountHasAppleSubscription
    }

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

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {


                        // User info card
                        userInfoCard

                        // Subscription status card
                        subscriptionStatusCard

                        // Upgrade Options
                        if let profile = subscriptionManager.userProfile {
                            if profile.subscriptionSource == "stripe" {
                                stripeManagedCard
                            } else if profile.subscriptionSource == "apple" {
                                upgradeOptionsCard
                                // Show web option even for Apple subscriptions if there's a conflict
                                if hasAppleSubscriptionConflict {
                                    manageOnWebCard
                                }
                            } else {
                                // Free or unknown: Show both
                                upgradeOptionsCard
                                manageOnWebCard
                            }
                        }


                        // Sign Out
                        signOutCard

                        // Delete Account
                        deleteAccountCard

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .scrollIndicators(.hidden)

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
        .task {
            await subscriptionManager.fetchUserProfile()
            await storeKitManager.loadProducts()
        }
        .onChange(of: storeKitManager.purchasedProductIDs) { _, _ in
            Task {
                await subscriptionManager.fetchUserProfile()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionUpdated)) { _ in
            Task {
                await subscriptionManager.fetchUserProfile()
            }
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
                    // Only show premium requests for pro users
                    if profile.subscriptionTier == .pro {
                        HStack {
                            Text("Premium requests:")
                                .font(.jost(.caption()))
                                .foregroundColor(.secondary)
                            Text("\(profile.premiumRequests)")
                                .font(.jost(.caption()))
                        }
                    }
                    // Show normal requests for student and free users
                    if profile.subscriptionTier != .pro {
                        HStack {
                            Text("Normal requests:")
                                .font(.jost(.caption()))
                                .foregroundColor(.secondary)
                            Text("\(profile.normalRequests)")
                                .font(.jost(.caption()))
                        }
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

    private var stripeManagedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                Text("Managed via Stripe")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }
            Text("Your subscription is managed via Stripe on the web. Please visit the web app to manage your plan.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)
            
            Button {
                if let url = webManagerURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Manage on Web")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.jost(.subheadline()))
                .foregroundColor(.blue)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
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

    private var upgradeOptionsCard: some View {
        let currentTier = subscriptionManager.userProfile?.subscriptionTier ?? .free
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: currentTier == .pro ? "checkmark.seal.fill" : "star.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(currentTier == .pro ? .green : .yellow)
                Text(currentTier == .pro ? "Manage Plan" : "Upgrade Plan")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }

            // Show conflict warning if detected
            if hasAppleSubscriptionConflict {
                appleConflictWarningCard
            }

            if storeKitManager.isLoading {
                ProgressView()
            } else {
                let currentTier = subscriptionManager.userProfile?.subscriptionTier ?? .free
                
                // If Pro, show nothing (already at top tier)
                if currentTier == .pro {
                    Text("You are currently on the Pro plan.")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                } else {
                    // Group products
                    let proProducts = storeKitManager.products.filter { $0.id.lowercased().contains("pro") }
                    let studentProducts = storeKitManager.products.filter { $0.id.lowercased().contains("student") }
                    
                    // Show Pro Plans
                    if !proProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pro Plans")
                                .font(.jost(.headline()))
                            ForEach(proProducts) { product in
                                ProductRow(
                                    product: product,
                                    allProducts: storeKitManager.products,
                                    isDisabled: hasAppleSubscriptionConflict
                                ) {
                                    Task { try? await storeKitManager.purchase(product) }
                                }
                            }
                        }
                    }
                    
                    // Show Student Plans (only if Free)
                    if currentTier == .free && !studentProducts.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Student Plans")
                                .font(.jost(.headline()))

                            ForEach(studentProducts) { product in
                                ProductRow(
                                    product: product,
                                    allProducts: storeKitManager.products,
                                    isDisabled: hasAppleSubscriptionConflict
                                ) {
                                    Task { try? await storeKitManager.purchase(product) }
                                }
                            }
                        }
                    }
                }
                
                Button("Restore Purchases") {
                    Task {
                        await storeKitManager.restorePurchases()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
            
            if let error = storeKitManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
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

    struct ProductRow: View {
        let product: Product
        let allProducts: [Product]
        let isDisabled: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.headline)

                            if let subscription = product.subscription, subscription.subscriptionPeriod.unit == .year {
                                // Annual subscription
                                if let monthlyPrice = getMonthlyPrice(for: product) {
                                    Text("\(monthlyPrice) / month (billed annually)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                // Monthly subscription
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(product.displayPrice)
                                .fontWeight(.bold)

                            if let discount = calculateDiscount() {
                                Text("SAVE \(discount)%")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Features (only show for monthly subscriptions)
                    if isMonthlySubscription {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(planFeatures, id: \.self) { feature in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                    Text(feature)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Disabled badge
                    if isDisabled {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("Unavailable - See warning above")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isDisabled ? Color.gray.opacity(0.2) : Color.blue.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
        
        private var isMonthlySubscription: Bool {
            product.subscription?.subscriptionPeriod.unit == .month
        }

        private var planFeatures: [String] {
            let productIdLower = product.id.lowercased()

            if productIdLower.contains("pro") {
                return [
                    "Unlimited Basic AI Requests",
                    "Unlimited Flashcards & Quizzes",
                    "Access to premium models",
                    "500 Premium AI Requests/month",
                    "Intelligent Autocomplete"
                ]
            } else if productIdLower.contains("student") {
                return [
                    "2000 Basic AI Requests/month",
                    "Flashcards & Quizzes Generation",
                ]
            } else {
                return []
            }
        }

        private func getMonthlyPrice(for product: Product) -> String? {
            guard let subscription = product.subscription,
                  subscription.subscriptionPeriod.unit == .year else { return nil }

            let monthlyPrice = product.price / 12
            return monthlyPrice.formatted(product.priceFormatStyle)
        }

        private func calculateDiscount() -> Int? {
            guard let subscription = product.subscription, subscription.subscriptionPeriod.unit == .year else { return nil }

            // Extract the base tier from the product ID by removing period indicators
            // e.g., "matchanote_pro_annual" -> "pro", "matchanote_student_monthly" -> "student"
            let productIdLower = product.id.lowercased()

            // Determine the tier by looking for known tier names
            let tier: String
            if productIdLower.contains("student") && !productIdLower.contains("pro") {
                tier = "student"
            } else if productIdLower.contains("pro") {
                tier = "pro"
            } else {
                return nil // Unknown tier
            }

            // Find the monthly product for the same tier
            let monthlyProduct = allProducts.first(where: { p in
                guard let pSubscription = p.subscription,
                      pSubscription.subscriptionPeriod.unit == .month else { return false }

                let pIdLower = p.id.lowercased()

                // Match the same tier
                if tier == "student" {
                    return pIdLower.contains("student") && !pIdLower.contains("pro")
                } else if tier == "pro" {
                    return pIdLower.contains("pro") && !pIdLower.contains("student")
                }
                return false
            })

            guard let monthly = monthlyProduct else {
                print("❌ No monthly product found for tier: \(tier)")
                return nil
            }

            let annualPrice = product.price
            let monthlyPrice = monthly.price
            let yearlyCostIfMonthly = monthlyPrice * 12

            let savings = yearlyCostIfMonthly - annualPrice

            guard yearlyCostIfMonthly > 0, savings > 0 else {
                print("❌ Invalid pricing: annual=\(annualPrice), monthly=\(monthlyPrice), yearly cost if monthly=\(yearlyCostIfMonthly)")
                return nil
            }

            let percentage = (savings / yearlyCostIfMonthly) * 100
            let roundedPercentage = NSDecimalNumber(decimal: percentage)
                .rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                ))
                .intValue

            print("✅ Discount calculated: \(tier) tier - Annual: \(annualPrice), Monthly: \(monthlyPrice), Savings: \(savings), Percentage: \(roundedPercentage)%")

            return roundedPercentage > 0 ? roundedPercentage : nil
        }
    }

    // Warning card for Apple ID subscription conflicts
    private var appleConflictWarningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.orange)
                Text("Apple ID Subscription Conflict")
                    .font(.jost(.subheadline()))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }

            Text("Your Apple ID has an active subscription linked to a different Matcha account.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("To resolve this:")
                    .font(.jost(.caption()))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text("Log into the account originally linked to this Apple ID")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text("Or upgrade this account using the \"Manage on Web\" option below")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                        Text("Or contact support for assistance")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Sign Out")
                    .font(.jost(.subheadline()))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Spacer()
            }
            Text("Sign out of your account and clear local data.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)

            Button {
                Task {
                    await AuthService.shared.signOut()
                    subscriptionManager.clearProfileCache()
                }
            } label: {
                HStack {
                    Text("Sign Out")
                    Spacer()
                    Image(systemName: "arrow.right")
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
                switch profile.subscriptionTier {
                case .pro:
                    Text("PRO")
                        .font(.jost(.caption2()))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .foregroundColor(.white)
                case .student:
                    Text("STUDENT")
                        .font(.jost(.caption2()))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundColor(.blue)
                case .free:
                    Text("FREE")
                        .font(.jost(.caption2()))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                        .foregroundColor(.secondary)
                }
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
        email = await AuthService.shared.getCurrentEmail()
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()

    private var deleteAccountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.red)
                Text("Delete Account")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.red)
                Spacer()
            }
            Text("Permanently delete your account and all associated data. This action cannot be undone.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)

            if let error = deleteError {
                Text(error)
                    .font(.jost(.caption()))
                    .foregroundColor(.red)
            }

            Button {
                if subscriptionManager.userProfile?.subscriptionSource == "apple" {
                    showAppleSubscriptionAlert = true
                } else {
                    showDeleteConfirmation = true
                }
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text("Delete Account")
                    }
                    Spacer()
                    Image(systemName: "trash")
                }
                .font(.jost(.subheadline()))
                .foregroundColor(.red)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
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
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account, cancel any subscriptions, and remove all your data. This cannot be undone.")
        }
        .alert("Active Apple Subscription", isPresented: $showAppleSubscriptionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Manage Subscriptions") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("You have an active Apple subscription. You MUST cancel it in iOS Settings before deleting your account to avoid further charges.")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }

        do {
            try await AuthService.shared.deleteAccount()
            subscriptionManager.clearProfileCache()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
