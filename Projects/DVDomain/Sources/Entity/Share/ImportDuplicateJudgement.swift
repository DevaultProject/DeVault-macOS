// Copyright © 2026 Devault. All rights reserved

/// `.dvt` 전체의 중복 판정 결과를 담는다. `ImportSecretsUseCase`가 만들고 Preview·Review Duplicates 화면이 소비한다.
public struct ImportDuplicateJudgement: Equatable, Sendable {

    /// 판정 대상이 된 `.dvt` 항목 수.
    public let totalCount: Int

    /// 중복 규칙에 걸린 항목들 — 비어 있으면 Review Duplicates를 건너뛴다.
    ///
    /// ``ImportDuplicateConflict/index``는 `0..<totalCount`에서 **유일하다** — 한 항목이 금고와 파일 내부 양쪽에 걸리면 ``ImportDuplicateConflict/Target/itemInFile(index:)``만 보고한다(앞선 항목이 어떻게 처리될지 모르는 채로 금고 덮어쓰기를 제안할 수 없다). 유일성이 깨지면 ``slotsConsumed(by:)``가 과소 계산하고 `Identifiable` id가 충돌한다.
    public let conflicts: [ImportDuplicateConflict]

    public init(totalCount: Int, conflicts: [ImportDuplicateConflict]) {
        self.totalCount = totalCount
        self.conflicts = conflicts
    }

    /// 선택을 반영했을 때 새로 생성될 시크릿 수를 센다 — "N to import" 카운터와 ``EntitlementUseCase/canImportSecrets(count:)``가 이 값 하나를 본다.
    ///
    /// 모든 항목이 슬롯을 쓰는 것에서 출발해, 생성하지 않기로 한 충돌(overwrite·skip)만 뺀다. 선택이 아직 없는 충돌은 빼지 않는다 — 보수적으로 잡아 과소 계산만 막는다.
    /// - Parameter resolutions: 충돌 ``ImportDuplicateConflict/index`` → 선택
    /// - Returns: 새로 생성될 시크릿 수. 음수가 될 수 없다
    public func slotsConsumed(by resolutions: [Int: ImportDuplicateResolution]) -> Int {
        let waived = Set(conflicts.map(\.index)).count { resolutions[$0]?.consumesSlot == false }
        return max(0, totalCount - waived)
    }
}
