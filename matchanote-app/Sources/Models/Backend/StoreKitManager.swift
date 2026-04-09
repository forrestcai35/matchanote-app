import Foundation
import StoreKit
import Supabase

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs
    private let productDict: [String: String] = [
        "Pro_Monthly": "PRO",
        "Pro_Annual": "PRO",
        "Student_Monthly": "STUDENT",
        "Student_Annual": "STUDENT"
    ]
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        updates = newTransactionListenerTask()
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() async {
        // Skip if products are already loaded to avoid layout flash
        guard products.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = Set(productDict.keys)
            products = try await Product.products(for: productIDs)
            
            // Sort products by price
            products.sort { $0.price < $1.price }
            
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("StoreKit load error: \(error)")
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check whether the transaction is verified. If it isn't,
                // this function rethrows the verification error.
                let transaction = try checkVerified(verification)
                
                // The transaction is verified. Deliver content to the user.
                await updatePurchasedProducts()
                
                // Verify with backend
                try await verifyWithBackend(transaction: transaction)
                
                // Always finish a transaction.
                await transaction.finish()
                
            case .userCancelled:
                print("User cancelled purchase")
            case .pending:
                print("Purchase pending")
            @unknown default:
                print("Unknown purchase result")
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("Purchase error: \(error)")
            
            // Auto-clear error after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    if self.errorMessage == "Purchase failed: \(error.localizedDescription)" {
                        self.errorMessage = nil
                    }
                }
            }
            
            throw error
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            
            // Auto-clear error after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    if self.errorMessage == "Restore failed: \(error.localizedDescription)" {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Internal Methods
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver content to the user.
                    await self.updatePurchasedProducts()
                    
                    // Verify with backend
                    try await self.verifyWithBackend(transaction: transaction)
                    
                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreKitError.verificationError
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    @MainActor
    private func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                self.purchasedProductIDs.insert(transaction.productID)
            } else {
                self.purchasedProductIDs.remove(transaction.productID)
            }
        }
    }
    
    enum StoreKitError: Error, LocalizedError {
        case verificationError
        case subscriptionConflict
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .verificationError:
                return "Transaction failed verification"
            case .subscriptionConflict:
                return "This Apple ID is already linked to another Matcha account. Please log in to your original account or contact support."
            case .serverError(let message):
                return message
            }
        }
    }
    
    // MARK: - Backend Verification
    
    private func verifyWithBackend(transaction: Transaction) async throws {
        print("Verifying transaction with backend: \(transaction.id)")
        
        let session = try await supabase.auth.session
        let accessToken = session.accessToken
        
        guard let url = URL(string: "https://matchanote.app/api/apple/verify") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Correct ms conversion
        let expiresMs = (transaction.expirationDate?.timeIntervalSince1970 ?? 0) * 1000
        
        let jsonBody: [String: Any] = [
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "productId": transaction.productID,
            "expiresDateMs": Int64(expiresMs)
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Backend verification failed: \(responseString)")
                
                // Parse JSON error if possible
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverError = json["error"] as? String {
                    if (response as? HTTPURLResponse)?.statusCode == 409 {
                        throw StoreKitError.subscriptionConflict
                    }
                    throw StoreKitError.serverError(serverError)
                }
            }
            throw URLError(.badServerResponse)
        }
        
        print("Backend verification successful")
        
        // Notify that subscription status has changed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionUpdated, object: nil)
        }
    }
}

extension Notification.Name {
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
}
