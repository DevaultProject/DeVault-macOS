// Copyright © 2026 Devault. All rights reserved

/// 무료 티어에 적용되는 한도의 단일 소스.
///
/// 서버가 없어 원격으로 조정할 수 없다. 값을 바꾸려면 앱을 새로 배포해야 하므로, 이미 한도를 넘겨 보유 중인 사용자가 생긴다는 점을 함께 고려해야 한다(초과 보유는 정상 상태로 다룬다 — ``EntitlementUseCase/canEditSecrets()``).
public enum EntitlementLimits {

    /// 무료 티어가 생성할 수 있는 Secret의 최대 개수. **휴지통 항목은 세지 않고, 만료된 항목은 센다** — 만료돼도 조회·수정이 되므로 자리를 차지한다.
    public static let maxSecrets = 15

    /// 무료 티어가 생성할 수 있는 Project의 최대 개수.
    public static let maxProjects = 1

    /// 무료 티어가 한 Secret에 예약할 수 있는 만료 알림 개수.
    ///
    /// **특정 시점을 고정하지 않고 개수만 줄인다.** 게이팅의 본질은 "다중 시점이 Pro"이지 "7일 전만 무료"가 아니다. 시점을 고정하면 사용자가 그 시점을 꺼둔 채 무료로 내려왔을 때 알림이 0건이 된다.
    ///
    /// 저장된 설정값은 건드리지 않고 읽은 값을 줄이기만 한다 — 지우면 재구독 시 복원할 수 없다.
    public static let maxExpiryAlertDays = 1
}
