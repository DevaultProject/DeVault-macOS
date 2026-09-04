// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 구독 설정 화면에 표시할 현재 구독 상태.
///
/// 게이트 판정에는 쓰지 않는다 — 그쪽은 ``Entitlement``만 본다. 이 타입은 **설정 > 구독 화면 한 곳**을 위해 존재한다.
public struct SubscriptionStatus: Equatable, Sendable {

    /// 현재 등급.
    public let entitlement: Entitlement

    /// 현재 구독 중인 상품 ID. 무료면 nil.
    ///
    /// **페이월이 "같은 플랜"과 "다른 플랜"을 구분하는 유일한 근거다.** 이게 없으면 이미 쓰고 있는
    /// 플랜을 다시 선택해도 변경 버튼이 활성화된다.
    public let productID: String?

    /// 다음 갱신(또는 만료) 시각. 무료이거나 StoreKit이 값을 주지 않으면 nil.
    public let renewsAt: Date?

    /// 사용자가 자동 갱신을 꺼둔 상태인지. 켜져 있으면 `renewsAt`에 갱신되고, 꺼져 있으면 그때 만료된다.
    public let willAutoRenew: Bool

    /// 다음 갱신에 적용될 상품 ID. 현재 상품과 다르면 변경이 예약된 것이다. 정보가 없으면 nil.
    public let renewalProductID: String?

    public init(
        entitlement: Entitlement,
        productID: String? = nil,
        renewsAt: Date? = nil,
        willAutoRenew: Bool = false,
        renewalProductID: String? = nil
    ) {
        self.entitlement = entitlement
        self.productID = productID
        self.renewsAt = renewsAt
        self.willAutoRenew = willAutoRenew
        self.renewalProductID = renewalProductID
    }

    /// 다음 갱신에 다른 플랜으로 바뀌도록 예약돼 있는지.
    public var hasPendingPlanChange: Bool {
        // 자동 갱신이 꺼져 있으면 갱신 자체가 없다 — autoRenewPreference가 남아 있어도 "변경 예약"이 아니라 만료다.
        guard willAutoRenew, let productID, let renewalProductID else { return false }
        return renewalProductID != productID
    }

    /// 구독 이력이 없는 기본 상태.
    public static let free = SubscriptionStatus(entitlement: .free)
}
