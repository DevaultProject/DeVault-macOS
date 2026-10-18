// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Import할 `.dvt` 항목 하나가 (이름, 타입) 중복 규칙에 걸렸음을 나타낸다. 판정은 `ImportSecretsUseCase`가 생성·수정 경로와 같은 규칙으로 내리고, 이 타입은 결과만 나른다.
public struct ImportDuplicateConflict: Equatable, Sendable, Identifiable {

    /// 충돌 상대 — 기존 시크릿이면 덮어쓰기가 가능하고, 파일 내부 항목이면 rename/skip만 유효하다.
    public enum Target: Equatable, Sendable {
        /// 금고의 기존 시크릿과 충돌 — 연관값은 덮어쓰기 대상 ID.
        ///
        /// ``SecretRepository/fetchSecretIDs(name:secretType:)``는 동명·동타입을 여러 개 돌려줄 수 있고(동기화), **그중 하나를 고르는 정책은 `ImportSecretsUseCase`가 적용한 뒤** 여기엔 결과만 담는다. 사용자가 직접 고르는 정책으로 바뀌면 이 연관값이 후보 목록이 된다.
        case existingSecret(id: UUID)
        /// 같은 `.dvt` 안의 앞선 항목과 충돌 — 연관값은 그 항목의 인덱스.
        case itemInFile(index: Int)
    }

    /// `.dvt` payload의 secrets 배열에서의 위치 — 선택(``ImportDuplicateResolution``)과 잇는 식별자.
    public let index: Int

    /// 충돌한 이름 — Review Duplicates 행 제목으로 노출된다.
    public let name: String

    /// 중복 규칙 (이름, 타입)의 타입 축.
    public let secretType: SecretType

    /// 행 부제(타입 라벨) — database·envSet 계열은 nil.
    public let subType: SecretSubType?

    /// ``ImportDuplicateResolution/overwrite``는 ``Target/existingSecret(id:)``에만 유효하다.
    public let target: Target

    public var id: Int { index }

    public init(
        index: Int,
        name: String,
        secretType: SecretType,
        subType: SecretSubType?,
        target: Target
    ) {
        self.index = index
        self.name = name
        self.secretType = secretType
        self.subType = subType
        self.target = target
    }
}
