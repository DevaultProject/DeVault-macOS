// Copyright © 2026 Devault. All rights reserved

/// 충돌 항목 하나에 대한 사용자의 선택을 나타낸다.
public enum ImportDuplicateResolution: Equatable, Sendable {
    /// 기존 시크릿을 교체한다 — 새 슬롯을 쓰지 않으며 ``EntitlementUseCase/canEditSecrets()`` 게이트를 지난다.
    case overwrite
    /// 이 항목을 들여오지 않는다.
    case skip
    /// 바꾼 이름으로 새로 만든다 — 슬롯 1을 쓰고, 바꾼 이름은 같은 규칙으로 재검사된다.
    ///
    /// 빈 이름·공백만 있는 이름은 **화면이 막는다** — 중복 재검사는 비교할 것이 없는 이름을 "중복 아님"으로 통과시키므로, 여기까지 오면 생성 시점에야 `SecretUseCaseError.invalidName`으로 터져 import 전체가 롤백된다.
    case rename(String)

    /// 이 선택이 새 슬롯을 소모하는지 반환한다.
    public var consumesSlot: Bool {
        if case .rename = self { return true }
        return false
    }
}
