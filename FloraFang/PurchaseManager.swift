//
//  PurchaseManager.swift
//  FloraFang
//
//  StoreKit 2 wrapper for the app's one-time unlock.
//
//  WHAT THIS DOES NOT GATE: the camera scan, every spider and plant hazard
//  verdict, the exposure intake checklist, and exporting an exposure
//  incident report. None of that code reads `isUnlocked` anywhere in the
//  app — that line was a deliberate product decision, not an oversight, and
//  it should stay that way if this file is ever touched again.
//
//  What IS behind the unlock is explicitly non-safety: the Flora field
//  naturalist chat, exporting your personal field log, the shareable ID
//  card, the field checklist, and the full species catalog browser. See
//  PaywallSheet.swift for the feature list shown to the user.
//
//  One non-consumable product, no subscription, no server, no receipt
//  validation service: entitlement is whatever StoreKit's on-device state
//  says, checked at launch, after a purchase, and whenever a transaction
//  updates (family sharing, a refund, a restore on a new device).
//

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class PurchaseManager {

    /// Must match the non-consumable In-App Purchase product ID created in
    /// App Store Connect. See SETUP.md for the exact steps to create it.
    static let unlockProductID = "com.aramirez.FloraFang.fullunlock"

    private(set) var products: [Product] = []
    private(set) var isUnlocked = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    var lastError: String?

    // deinit always runs non-isolated (deallocation can happen off the
    // main actor even for a @MainActor class), so this needs to be readable
    // there. Plain `nonisolated` compiles but the @Observable macro's
    // generated accessor for a mutable property rejects it downstream —
    // `nonisolated(unsafe)` is the actual escape hatch here, which is safe
    // because Task.cancel() is documented as callable from any isolation
    // domain and nothing else mutates this after init. @ObservationIgnored
    // because this is internal plumbing, not observable UI state, and
    // doesn't need tracking either way.
    @ObservationIgnored
    nonisolated(unsafe) private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactionUpdates()
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    var unlockProduct: Product? {
        products.first { $0.id == Self.unlockProductID }
    }

    /// Falls back to the advertised price so the paywall never shows a blank
    /// price while StoreKit is still loading or unreachable (e.g. no
    /// network on first launch). The real, localized price replaces this
    /// the moment `products` loads.
    var priceText: String {
        unlockProduct?.displayPrice ?? "$4.99"
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: [Self.unlockProductID])
        } catch {
            lastError = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    func purchase() async {
        guard !isPurchasing else { return }
        guard let product = unlockProduct else {
            lastError = "The unlock isn't available from the App Store right now. Try again in a moment."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                isUnlocked = true
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase is waiting on approval (Ask to Buy or similar). It unlocks automatically once approved."
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            // Fall through to refreshEntitlements regardless. A cancelled
            // sign-in prompt or sync hiccup here doesn't mean there is
            // nothing to restore, and the entitlement check below is the
            // only signal that actually matters to the user.
        }
        await refreshEntitlements()
        if !isUnlocked {
            lastError = "No previous purchase found for this Apple ID."
        }
    }

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.productID == Self.unlockProductID, transaction.revocationDate == nil {
                isUnlocked = true
            }
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard let transaction = try? Self.checkVerified(result) else { continue }
                if transaction.productID == Self.unlockProductID {
                    isUnlocked = transaction.revocationDate == nil
                }
                await transaction.finish()
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? {
            "This purchase couldn't be verified by the App Store."
        }
    }
}
