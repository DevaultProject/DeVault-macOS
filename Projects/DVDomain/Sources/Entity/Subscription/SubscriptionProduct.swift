// Copyright © 2026 Devault. All rights reserved

/// 페이월에 표시할 구독 상품.
///
/// **StoreKit의 `Product`를 도메인에 노출하지 않기 위한 변환 타입이다.** DVDomain은 Foundation과 DVCore 외의 프레임워크를 import하지 않으며, `StoreKit.Product`는 공개 이니셜라이저가 없어 테스트에서 만들 수 없다. DVData의 `PurchaseService` 구현이 `Product`를 읽어 이 타입으로 옮긴다.
public struct SubscriptionProduct: Equatable, Identifiable, Sendable {

    /// App Store Connect에 등록한 상품 ID. `id`로도 쓰인다.
    public let id: String

    /// 상품 이름. App Store Connect에 등록한 지역화 표시명이 그대로 온다.
    public let displayName: String

    /// 통화 기호와 지역 형식이 이미 적용된 가격 문자열(`Product.displayPrice`). **직접 포맷하지 않는다** — 통화·지역·자릿수 처리를 StoreKit에 맡긴다.
    public let displayPrice: String

    /// 구독 기간을 개월로 환산한 값. 1 / 3 / 6 / 12.
    ///
    /// 페이월의 **정렬 기준**이다. 스토어는 상품 순서를 보장하지 않으므로 표시 순서를 여기서 정한다. 기간을 알 수 없는 상품은 애초에 이 타입으로 변환되지 않는다.
    public let periodInMonths: Int

    /// 월 환산 가격. 1개월 상품은 `displayPrice`와 같아지므로 nil이다.
    ///
    /// **문자열을 그대로 받는 이유**는 통화 서식 때문이다. `displayPrice`를 나눌 수 없어 숫자 가격이 필요한데, 그걸 도메인이나 뷰에서 포맷하면 통화 기호와 자릿수가 지역에 따라 어긋난다. StoreKit의 `Product.priceFormatStyle`을 아는 DVData가 계산과 서식을 함께 처리해 넘긴다.
    public let monthlyEquivalentPrice: String?

    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        periodInMonths: Int,
        monthlyEquivalentPrice: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.periodInMonths = periodInMonths
        self.monthlyEquivalentPrice = monthlyEquivalentPrice
    }
}
