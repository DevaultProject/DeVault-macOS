// Copyright © 2026 Devault. All rights reserved

import Foundation

/// `.dvt` 파일을 열어 시크릿을 금고로 들여오는 UseCase입니다. Password Entry → Preview → Review Duplicates 세 화면이 단계별로 소비한다.
public protocol ImportSecretsUseCase: Sendable {

    /// `.dvt` 바이트를 비밀번호로 열어 내용을 복원한다.
    ///
    /// 실패는 전부 ``DevaultImportError``로 닫힌다 — 키 유도·복호화·역직렬화 중 어디서 깨졌든 호출부는 이 네 가지만 분기하면 된다. **틀린 비밀번호와 변조된 암호문은 구분하지 않는다**(구분하면 공격자에게 오라클이 된다).
    /// - Parameters:
    ///   - data: `.dvt` 파일 바이트
    ///   - password: 사용자가 입력한 비밀번호
    /// - Returns: 복원된 컨테이너 내용
    func decrypt(data: Data, password: SensitiveString) async throws -> DevaultContainerPayload

    /// 들여올 항목들이 (이름, 타입) 중복 규칙에 걸리는지 판정한다. 금고의 기존 시크릿과 `.dvt` 내부의 앞선 항목을 같은 규칙으로 본다.
    ///
    /// **이름을 바꾼 뒤 다시 불러 재판정한다.** `resolutions`에 담긴 ``ImportDuplicateResolution/rename(_:)``은 그 항목의 이름을 대신하므로, 바꾼 이름이 만드는 새 충돌이 결과에 나타난다. ``ImportDuplicateResolution/skip``된 항목은 이름을 차지하지 않는다.
    /// - Parameters:
    ///   - payload: ``decrypt(data:password:)``가 돌려준 내용
    ///   - resolutions: 지금까지의 선택. 첫 판정에는 빈 딕셔너리를 넘긴다
    /// - Returns: 충돌 목록과 슬롯 계산이 담긴 판정 결과
    func judgeDuplicates(
        payload: DevaultContainerPayload,
        resolutions: [Int: ImportDuplicateResolution]
    ) async throws -> ImportDuplicateJudgement

    /// 선택을 반영해 실제로 들여온다.
    ///
    /// 전량-아니면-전무다 — 도중에 실패하면 이미 만든 것을 지우고 던진다. 벌크 생성 API가 없어 N건이 N트랜잭션으로 나뉘고 한도 판정이 건별로 재평가되므로, 보상 삭제 없이는 부분 성공이 남는다.
    ///
    /// 한도 판정(``EntitlementUseCase/canImportSecrets(count:)``)을 여기서 한 번 더 한다 — 화면이 이미 물었더라도 그 사이 다른 생성이 끼어들 수 있고, 화면을 우회한 호출도 막아야 한다.
    /// - Parameters:
    ///   - payload: 들여올 내용
    ///   - resolutions: 충돌 항목에 대한 선택. 충돌이 있는데 선택이 없으면 거부한다
    ///   - project: 연결할 Project 선택
    /// - Returns: 새로 만들어지거나 덮어쓰인 Secret 목록
    func execute(
        payload: DevaultContainerPayload,
        resolutions: [Int: ImportDuplicateResolution],
        project: ImportProjectChoice
    ) async throws -> [Secret]
}
