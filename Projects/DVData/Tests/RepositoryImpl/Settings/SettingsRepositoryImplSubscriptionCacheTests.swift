// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

import DVDomain
@testable import DVData

@Suite("SettingsRepositoryImpl - 구독 상태 캐시")
struct SettingsRepositoryImplSubscriptionCacheTests {

    private func makeSUT() -> SettingsRepositoryImpl {
        let defaults = UserDefaults(suiteName: "SettingsRepositoryImplTests.\(UUID().uuidString)")!
        return SettingsRepositoryImpl(defaults: defaults)
    }

    @Test("예약된 플랜 변경(renewalProductID)이 캐시 왕복에서 보존된다")
    func renewalProductIDSurvivesRoundTrip() {
        let sut = makeSUT()
        sut.setCachedEntitlement(.pro)
        sut.setCachedSubscriptionStatus(
            SubscriptionStatus(
                entitlement: .pro,
                productID: "pro.monthly",
                renewsAt: Date(timeIntervalSince1970: 1_700_000_000),
                willAutoRenew: true,
                renewalProductID: "pro.yearly"
            )
        )

        let restored = sut.cachedSubscriptionStatus()

        #expect(restored.renewalProductID == "pro.yearly")
        #expect(restored.hasPendingPlanChange)
    }

    @Test("예약이 없으면 renewalProductID는 nil로 복원된다")
    func renewalProductIDClearedWhenAbsent() {
        let sut = makeSUT()
        sut.setCachedEntitlement(.pro)
        // 예약이 있던 상태를
        sut.setCachedSubscriptionStatus(
            SubscriptionStatus(entitlement: .pro, productID: "pro.monthly", willAutoRenew: true, renewalProductID: "pro.yearly")
        )
        // 예약 없는 상태로 덮어쓰면 캐시에서도 지워져야 한다
        sut.setCachedSubscriptionStatus(
            SubscriptionStatus(entitlement: .pro, productID: "pro.monthly", willAutoRenew: true, renewalProductID: nil)
        )

        #expect(sut.cachedSubscriptionStatus().renewalProductID == nil)
    }
}
