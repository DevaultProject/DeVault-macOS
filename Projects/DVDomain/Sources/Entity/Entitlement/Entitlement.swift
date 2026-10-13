// Copyright © 2026 Devault. All rights reserved

/// 사용자가 지금 쓸 수 있는 기능 등급.
///
/// **게이트 판정의 유일한 입력이다.** 갱신일이나 결제 상태를 여기 담지 않는다 — `case pro(expiresAt:)` 형태로 만들면 등급만 보면 되는 호출부(게이트 5곳)의 `switch`와 `==` 비교가 전부 지저분해진다. 날짜가 필요한 화면은 ``SubscriptionStatus``를 따로 읽는다.
public enum Entitlement: String, Equatable, Sendable {

    /// 무료 티어. 개수·동기화·알림 시점에 제한이 걸린다.
    case free

    /// 구독 중. 모든 제한이 풀린다.
    case pro
}
