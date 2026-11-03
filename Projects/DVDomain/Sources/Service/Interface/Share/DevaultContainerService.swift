// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 비밀번호 기반으로 `.dvt` 컨테이너를 만들고 여는 서비스입니다.
public protocol DevaultContainerService: Sendable {
    /// payload를 비밀번호로 봉인해 `.dvt` 바이트로 만든다.
    /// - Parameters:
    ///   - payload: 봉인할 원본 payload
    ///   - password: 봉인에 사용할 비밀번호
    ///   - expiresAt: 만료 시각(nil이면 영구)
    /// - Returns: `.dvt` 컨테이너 바이트
    /// - Throws: 빈 비밀번호 등 입력이 잘못되면 ``PasswordKeyDerivationError``가 전파될 수 있다.
    func export(payload: DevaultContainerPayload, password: SensitiveString, expiresAt: Date?) async throws -> Data

    /// 비밀번호 없이 헤더만 보고 열 수 있는 파일인지 판별한다. 키 유도를 하지 않는다.
    /// 헤더는 평문이라 손상·버전·만료는 비밀번호 전에 알 수 있다. 사용자에게 보여줄 사전 안내용이며 변조 방어는 아니다 — 헤더 변조는 개봉 시 AAD 검증이 막는다.
    /// - Parameter data: `.dvt` 컨테이너 바이트
    /// - Throws: ``DevaultImportError`` 중 `corrupted`/`versionMismatch`/`expired`.
    func validateHeader(data: Data) throws

    /// `.dvt` 바이트를 비밀번호로 열어 payload를 복원한다.
    /// - Parameters:
    ///   - data: `.dvt` 컨테이너 바이트
    ///   - password: 개봉에 사용할 비밀번호
    /// - Returns: 복원된 payload
    /// - Throws: ``DevaultImportError`` 4종(`corrupted`/`versionMismatch`/`expired`/`invalidPassword`) 중 하나.
    func `import`(data: Data, password: SensitiveString) async throws -> DevaultContainerPayload
}
