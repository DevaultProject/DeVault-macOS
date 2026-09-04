// Copyright © 2026 Devault. All rights reserved

import Testing

@testable import DVDomain

@Suite("SubscriptionStatus")
struct SubscriptionStatusTests {

    @Test("다음 갱신 상품이 현재와 다르면 변경 예약으로 본다")
    func pendingWhenRenewalDiffersFromCurrent() {
        let status = SubscriptionStatus(
            entitlement: .pro,
            productID: "pro.monthly",
            willAutoRenew: true,
            renewalProductID: "pro.quarterly"
        )
        #expect(status.hasPendingPlanChange)
    }

    @Test("다음 갱신 상품이 현재와 같으면 변경 예약이 아니다")
    func notPendingWhenRenewalMatchesCurrent() {
        let status = SubscriptionStatus(
            entitlement: .pro,
            productID: "pro.monthly",
            willAutoRenew: true,
            renewalProductID: "pro.monthly"
        )
        #expect(status.hasPendingPlanChange == false)
    }

    @Test("다음 갱신 상품 정보가 없으면(nil) 변경 예약이 아니다")
    func notPendingWhenRenewalProductMissing() {
        let status = SubscriptionStatus(
            entitlement: .pro,
            productID: "pro.monthly",
            willAutoRenew: true,
            renewalProductID: nil
        )
        #expect(status.hasPendingPlanChange == false)
    }

    @Test("자동 갱신이 꺼져 있으면 다음 갱신 상품이 달라도 변경 예약이 아니다(만료)")
    func notPendingWhenAutoRenewOff() {
        let status = SubscriptionStatus(
            entitlement: .pro,
            productID: "pro.monthly",
            willAutoRenew: false,
            renewalProductID: "pro.yearly"
        )
        #expect(status.hasPendingPlanChange == false)
    }

    @Test("무료(현재 상품 없음)면 변경 예약이 아니다")
    func notPendingWhenFree() {
        #expect(SubscriptionStatus.free.hasPendingPlanChange == false)
    }
}
