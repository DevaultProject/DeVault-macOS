// Copyright © 2026 Devault. All rights reserved

/// App Store Connect에 등록한 구독 상품 ID의 단일 소스.
///
/// **이 문자열은 App Store Connect의 상품 ID와 정확히 일치해야 한다.** 어긋나면 `Product.products(for:)`가 빈 배열을 돌려주고, 페이월이 상품 없이 열린다 — 컴파일도 통과하고 크래시도 나지 않아 심사에서야 발견된다.
///
/// **ASC에 한 번 등록한 ID는 바꿀 수 없다.** 이름을 고치려면 새 상품을 만들어야 하고, 기존 구독자는 옛 ID에 남는다.
public enum SubscriptionProductID {

    /// 1개월 구독.
    public static let proMonthly = "com.devault.app.pro.monthly"

    /// 3개월 구독.
    public static let proQuarterly = "com.devault.app.pro.quarterly"

    /// 6개월 구독.
    public static let proHalfYearly = "com.devault.app.pro.halfyearly"

    /// 1년 구독.
    public static let proYearly = "com.devault.app.pro.yearly"

    /// 페이월이 조회할 상품 목록. **기간이 짧은 것부터 정렬돼 있다** — 스토어는 등록 순서를 보장하지 않으므로 페이월은 이 배열의 순서를 기준으로 삼는다.
    ///
    /// 상품을 추가하면 **반드시 같은 구독 그룹에 넣는다.** 그룹이 다르면 StoreKit이 전환을 처리하지 못해 사용자가 두 상품을 동시에 구독할 수 있게 된다.
    public static let all = [proMonthly, proQuarterly, proHalfYearly, proYearly]
}
