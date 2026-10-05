// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

/// 가격은 `SubscriptionProduct.displayPrice`를 그대로 쓴다 — 직접 포맷하면 통화 기호와 자릿수가 지역에 따라 어긋난다. 월 환산도 `monthlyEquivalentPrice`로 이미 계산돼 온다.
@DependencyClient
public struct PurchaseClient: Sendable {

    /// 기간이 짧은 것부터 정렬돼 온다.
    public var products: @Sendable () async throws -> [SubscriptionProduct]

    /// `.userCancelled`는 오류가 아니므로 알럿을 띄우지 않는다.
    public var purchase: @Sendable (_ productID: String) async throws -> PurchaseResult

    /// 기기를 바꾼 사용자를 위해 구매 이력을 동기화한다.
    public var restore: @Sendable () async throws -> Void

    /// 게이트 판정에는 쓰지 않는다.
    public var subscriptionStatus: @Sendable () async -> SubscriptionStatus = { .free }

    /// `Transaction.updates`가 아직 반영 전일 때
    /// 사용자가 수동으로 강제 재조회할 수 있는 탈출구다("방금 결제했는데 왜 무료로 보이지").
    public var refreshEntitlement: @Sendable () async -> Void = {}

    /// macOS엔 iOS의 인앱 구독 관리 시트가 없어, App Store의 구독 관리 페이지를 연다.
    public var openManageSubscriptions: @Sendable () -> Void = {}
}

extension PurchaseClient: TestDependencyKey {
    public static let testValue = PurchaseClient()

    public static let previewValue = PurchaseClient(
        products: {
            [
                SubscriptionProduct(id: "preview.monthly", displayName: "1개월", displayPrice: "₩4,900", periodInMonths: 1),
                SubscriptionProduct(id: "preview.quarterly", displayName: "3개월", displayPrice: "₩12,900", periodInMonths: 3, monthlyEquivalentPrice: "₩4,300"),
                SubscriptionProduct(id: "preview.halfyearly", displayName: "6개월", displayPrice: "₩23,900", periodInMonths: 6, monthlyEquivalentPrice: "₩3,983"),
                SubscriptionProduct(id: "preview.yearly", displayName: "1년", displayPrice: "₩39,000", periodInMonths: 12, monthlyEquivalentPrice: "₩3,250"),
            ]
        },
        purchase: { _ in .success },
        restore: {},
        subscriptionStatus: { .free },
        refreshEntitlement: {},
        openManageSubscriptions: {}
    )
}

extension DependencyValues {
    public var purchaseClient: PurchaseClient {
        get { self[PurchaseClient.self] }
        set { self[PurchaseClient.self] = newValue }
    }
}
