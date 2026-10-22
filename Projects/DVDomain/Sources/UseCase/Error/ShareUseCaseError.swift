// Copyright © 2026 Devault. All rights reserved

/// `.dvt` Export/Import가 요청 자체를 거부한 이유.
///
/// 전부 **화면이 먼저 걸러야 하는 것**이고, 여기까지 왔다면 화면을 우회했거나 화면이 보여준 판정 이후 상태가 바뀐 것이다. 게이트 차단(``EntitlementError``)·저장소 오류와 섞지 않아야 호출부가 안내 문구를 고를 수 있다.
public enum ShareUseCaseError: Error, Equatable, Sendable {

    /// 내보낼 시크릿을 하나도 고르지 않았다.
    case emptySelection

    /// 휴지통 항목이 섞였다. 삭제된 시크릿은 조회·복사가 막혀 있어 내보내기도 막는다.
    case trashedSecretIncluded

    /// `(secretType, subType)` 조합이 어긋나 복호화할 payload 타입을 고를 수 없다.
    case unsupportedContent

    /// 중복으로 판정된 항목에 덮어쓰기·건너뛰기·이름변경 중 아무것도 고르지 않았다.
    case unresolvedConflict

    /// 덮어쓰기를 골랐는데 덮어쓸 대상이 없다 — 파일 내부 충돌이거나, 판정 이후 대상이 사라졌다.
    case overwriteTargetMissing

    /// 연결하려는 Project가 없다.
    case projectNotFound
}
