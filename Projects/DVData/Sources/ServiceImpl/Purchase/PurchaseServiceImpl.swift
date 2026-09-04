// Copyright © 2026 Devault. All rights reserved

import Foundation
import StoreKit

import DVCore
import DVDomain

/// StoreKit 2로 구독을 판매하고 권한을 확인하는 구현체.
///
/// 등급을 자체 필드에 들고 있지 않고 `SettingsRepository`의 캐시에 쓴다. 게이트 판정은 동기로 답해야 하는데 StoreKit 조회는 비동기라, 값을 UserDefaults에 두면 동기 읽기와 변경 스트림을 둘 다 공짜로 얻는다. 서비스가 상태를 갖지 않으므로 락도 actor도 필요 없다.
public struct PurchaseServiceImpl: PurchaseService {

    private let settingsRepository: any SettingsRepository
    private let productIDs: [String]

    public init(
        settingsRepository: any SettingsRepository,
        productIDs: [String] = SubscriptionProductID.all
    ) {
        self.settingsRepository = settingsRepository
        self.productIDs = productIDs
    }

    public func products() async throws -> [SubscriptionProduct] {
        do {
            let products = try await Product.products(for: productIDs)
            // 기간이 짧은 것부터 보여준다. 스토어는 순서를 보장하지 않는다.
            let mapped = products.compactMap(Self.subscriptionProduct(from:))
                .sorted { $0.periodInMonths < $1.periodInMonths }
            Log.debug("[Purchase] 상품 조회 완료 — 요청: \(productIDs.count), 표시: \(mapped.count)", category: .data)
            return mapped
        } catch {
            Log.error("[Purchase] 상품 조회 실패 — error: \(error)", category: .data)
            throw PurchaseError.storeUnavailable
        }
    }

    public func purchase(productID: String) async throws -> PurchaseResult {
        // StoreKit이 프로세스 안에서 상품을 캐시하므로 이 조회는 보통 네트워크를 타지 않는다. 서비스가 상태를 갖지 않는 편(struct)이 락 없이 공유되는 이점이 커서 자체 캐시는 두지 않는다.
        let products: [Product]
        do {
            products = try await Product.products(for: [productID])
        } catch {
            Log.error("[Purchase] 구매 전 상품 조회 실패 — error: \(error)", category: .data)
            throw PurchaseError.storeUnavailable
        }

        guard let product = products.first else {
            Log.error("[Purchase] 상품을 찾을 수 없음 — productID: \(productID)", category: .data)
            throw PurchaseError.productNotFound
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            Log.error("[Purchase] 구매 실패 — error: \(error)", category: .data)
            throw PurchaseError.storeUnavailable
        }

        switch result {
        case .success(let verification):
            // 검증에 실패한 트랜잭션은 **완료 처리하지 않는다.** finish는 권한을 부여했다는 신고이며, 여기서 끝내면 변조된 트랜잭션이 사라져 재검토할 기회도 없어진다.
            guard case .verified(let transaction) = verification else {
                Log.error("[Purchase] 트랜잭션 검증 실패 — productID: \(productID)", category: .data)
                throw PurchaseError.verificationFailed
            }
            await transaction.finish()
            Log.info("[Purchase] 구매 성공 — productID: \(productID)", category: .data)
            // 방금 검증한 트랜잭션이 손에 있으므로 currentEntitlements를 다시 묻지 않는다. 구매 직후에는
            // 스토어가 아직 반영 전이라 같은 트랜잭션을 미검증으로 돌려주는 순간이 있고, 그때 다시 물으면
            // 결제에 성공한 사용자가 잠시 무료로 떨어진다. 갱신일 등 세부 정보도 지금 손에 있는
            // 트랜잭션으로 바로 캐시에 채워 둔다 — `subscriptionStatus()`가 나중에 재조회 없이 즉시
            // 정확한 값을 돌려줄 수 있게 하기 위해서다.
            applyEntitlement(.pro)
            settingsRepository.setCachedSubscriptionStatus(await status(for: transaction))
            await logPendingPlanChange()
            return .success

        case .userCancelled:
            // 오류가 아니라 화면이 조용히 닫히는 경로다. 로그가 없으면 "눌렀는데 아무 일도 안 일어난다"와 구분되지 않는다.
            Log.info("[Purchase] 사용자 취소 — productID: \(productID)", category: .data)
            return .userCancelled

        case .pending:
            Log.info("[Purchase] 승인 대기 — productID: \(productID)", category: .data)
            return .pending

        @unknown default:
            Log.error("[Purchase] 알 수 없는 구매 결과 — productID: \(productID)", category: .data)
            throw PurchaseError.unknown
        }
    }

    @discardableResult
    public func refreshEntitlement() async -> Entitlement {
        guard let transaction = await activeTransaction() else {
            applyEntitlement(.free)
            settingsRepository.setCachedSubscriptionStatus(.free)
            return .free
        }
        applyEntitlement(.pro)
        settingsRepository.setCachedSubscriptionStatus(await status(for: transaction))
        return .pro
    }

    /// 등급 캐시를 갱신하고 **실제로 바뀔 때만** 로그를 남긴다. `Transaction.updates`가 돌 때마다 같은 값이 다시 쓰이므로, 비교 없이 찍으면 전환이 없는 갱신까지 전부 남아 실제 전환 시점을 못 찾는다.
    private func applyEntitlement(_ entitlement: Entitlement) {
        let previous = settingsRepository.cachedEntitlement()
        settingsRepository.setCachedEntitlement(entitlement)
        guard previous != entitlement else { return }
        Log.info("[Purchase] 등급 전환 — \(previous) → \(entitlement)", category: .data)
    }

    // StoreKit에도 `SubscriptionStatus`가 있어 한정이 필요하다. `Transaction`과 같은 이유다.
    public func subscriptionStatus() async -> DVDomain.SubscriptionStatus {
        if let transaction = await activeTransaction() {
            return await status(for: transaction)
        }

        // 구매/복원 직후에는 스토어가 아직 반영 전이라 currentEntitlements가 잠시 비어 있을 수 있다
        // (`purchase(productID:)` 주석 참고). 재조회로 그 틈을 메우는 대신, 등급이 바뀔 때마다
        // `setCachedSubscriptionStatus`로 이미 저장해 둔 값을 그대로 돌려준다 — 재시도·대기 없이도
        // 항상 정확하다. 캐시가 free면 진짜 무료 사용자다.
        let cached = settingsRepository.cachedSubscriptionStatus()
        return cached.entitlement == .pro ? cached : .free
    }

    /// 자동 갱신 여부·예약 상품은 트랜잭션이 아니라 구독 상태(renewalInfo)에 있다. 조회에 실패해도 등급·갱신일은 유효하므로 갱신 정보만 비운다.
    private func status(for transaction: StoreKit.Transaction) async -> DVDomain.SubscriptionStatus {
        let renewal = await renewalInfo(for: transaction)
        return DVDomain.SubscriptionStatus(
            entitlement: .pro,
            productID: transaction.productID,
            renewsAt: transaction.expirationDate,
            willAutoRenew: renewal.willAutoRenew,
            // 자동 갱신이 꺼져 있으면 다음 갱신 자체가 없으므로 예약 상품도 없다(있어도 "변경 예약"이 아니라 만료).
            renewalProductID: renewal.willAutoRenew ? renewal.autoRenewPreference : nil
        )
    }

    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            Log.error("[Purchase] 구매 복원 실패 — error: \(error)", category: .data)
            throw PurchaseError.storeUnavailable
        }
        let entitlement = await refreshEntitlement()
        // `AppStore.sync()`는 복원할 구매가 없어도 성공한다. 결과 등급까지 찍어야 "복원했는데 무료 그대로"와 "복원이 실패했다"가 구분된다.
        Log.info("[Purchase] 복원 완료 — 등급: \(entitlement)", category: .data)
    }

    public func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [self] in
            // 앱이 꺼져 있는 동안 도착한 트랜잭션은 updates로 오지 않는다. 시작 시 한 번 걷어야 승인 대기(pending)에서 승인된 구매나 다른 기기의 구매가 반영된다.
            await finishUnfinishedTransactions()
            await refreshEntitlement()

            for await verification in Transaction.updates {
                guard case .verified(let transaction) = verification else {
                    Log.error("[Purchase] 갱신 트랜잭션 검증 실패", category: .data)
                    continue
                }
                Log.info("[Purchase] 갱신 트랜잭션 수신 — productID: \(transaction.productID), 취소일: \(transaction.revocationDate.map(String.init(describing:)) ?? "없음")", category: .data)
                await transaction.finish()
                await refreshEntitlement()
                await logPendingPlanChange()
            }
        }
    }

    /// 다음 갱신 때 적용될 상품이 지금 권한과 다르면 남긴다. 같은 레벨·다른 기간의 기간 전환(crossgrade)은 **갱신일까지 화면에 아무 변화도 만들지 않으므로**, 이 줄이 변경 접수 여부를 확인하는 유일한 신호다.
    ///
    /// 기준은 방금 구매한 트랜잭션이 아니라 `activeTransaction()`이다. 전환이 유예되면 구매 트랜잭션은 이미 새 상품이라 그것끼리 비교하면 차이가 사라진다. 화면이 "현재 플랜"으로 읽는 값과 같은 것을 봐야 한다.
    private func logPendingPlanChange() async {
        guard let current = await activeTransaction(),
              let statuses = try? await current.subscriptionStatus,
              case .verified(let renewalInfo) = statuses.renewalInfo,
              let next = renewalInfo.autoRenewPreference,
              next != current.productID
        else {
            return
        }
        Log.info("[Purchase] 다음 갱신 예정 — 현재: \(current.productID), 예약: \(next)", category: .data)
    }
}

// MARK: - Mapping

extension PurchaseServiceImpl {

    /// `Product`를 도메인 값 타입으로 옮긴다. **기간을 읽지 못하면 제외한다** — 페이월이 설명할 수 없는 상품을 띄우느니 빼는 편이 낫다.
    private static func subscriptionProduct(from product: Product) -> SubscriptionProduct? {
        guard let months = periodInMonths(of: product) else {
            Log.error("[Purchase] 구독 기간을 읽지 못해 상품에서 제외 — productID: \(product.id)", category: .data)
            return nil
        }

        return SubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            periodInMonths: months,
            monthlyEquivalentPrice: monthlyEquivalentPrice(of: product, months: months)
        )
    }

    /// 구독 기간을 개월로 환산한다. 주·일 단위 구독은 쓰지 않으므로 nil을 돌려준다.
    private static func periodInMonths(of product: Product) -> Int? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .month: return period.value
        case .year:  return period.value * 12
        case .day, .week: return nil
        @unknown default: return nil
        }
    }

    /// 월 환산 가격을 스토어의 통화 서식으로 만든다. 1개월 상품은 `displayPrice`와 같아지므로 nil이다.
    private static func monthlyEquivalentPrice(of product: Product, months: Int) -> String? {
        guard months > 1 else { return nil }
        return (product.price / Decimal(months)).formatted(product.priceFormatStyle)
    }
}

// MARK: - Private

extension PurchaseServiceImpl {

    /// 완료 처리되지 않은 트랜잭션을 걷는다. 남겨두면 StoreKit이 앱을 켤 때마다 다시 전달한다.
    private func finishUnfinishedTransactions() async {
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            await transaction.finish()
        }
    }

    /// 현재 유효한 구독 트랜잭션. 없으면 nil.
    ///
    /// `Transaction.currentEntitlements`(Apple이 "지금 유효한 그룹 멤버"라고 계산해 주는 필터링된 뷰)를
    /// 쓰지 않는다. 같은 그룹 안에서 플랜만 바꾸는 crossgrade 직후 이 뷰가 **아무것도 못 돌려주는**
    /// 현상이 확인됐다(로컬 StoreKit 테스트 세션에서 재현).
    ///
    /// 개별 트랜잭션의 날짜 필드(`revocationDate`/`expirationDate`)를 직접 비교하는 방식도 시도했지만,
    /// 로컬 테스트 세션에서 강제 만료·환불을 시켜도 **원래 서명된 트랜잭션 객체의 날짜 필드 자체는
    /// 갱신되지 않아** 오탐이 났다. 대신 트랜잭션의 `subscriptionStatus`(Apple이 계산하는 그룹 단위
    /// 상태 — `.subscribed`/`.expired`/`.revoked` 등)를 신뢰한다. 이 값은 crossgrade·환불·만료를
    /// 전부 정확히 반영한다.
    private func activeTransaction() async -> StoreKit.Transaction? {
        for await verification in Transaction.all {
            guard case .verified(let transaction) = verification else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard let status = try? await transaction.subscriptionStatus else { continue }

            switch status.state {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                guard case .verified(let currentTransaction) = status.transaction,
                      productIDs.contains(currentTransaction.productID)
                else { continue }
                return currentTransaction
            default:
                continue
            }
        }
        return nil
    }

    /// 다음 주기 갱신 정보: 자동 갱신 여부와 예약된 상품(autoRenewPreference). 조회 실패 시 갱신 없음으로 본다.
    /// autoRenewPreference는 다음 갱신에 적용될 상품 — 지금과 다르면 crossgrade가 예약된 것이다.
    private func renewalInfo(
        for transaction: StoreKit.Transaction
    ) async -> (willAutoRenew: Bool, autoRenewPreference: String?) {
        guard let statuses = try? await transaction.subscriptionStatus,
              case .verified(let renewalInfo) = statuses.renewalInfo
        else {
            return (false, nil)
        }
        return (renewalInfo.willAutoRenew, renewalInfo.autoRenewPreference)
    }
}
