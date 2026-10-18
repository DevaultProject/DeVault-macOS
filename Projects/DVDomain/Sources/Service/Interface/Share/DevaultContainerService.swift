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
    func export(payload: DevaultContainerPayload, password: String, expiresAt: Date?) throws -> Data

    /// `.dvt` 바이트를 비밀번호로 열어 payload를 복원한다.
    /// - Parameters:
    ///   - data: `.dvt` 컨테이너 바이트
    ///   - password: 개봉에 사용할 비밀번호
    /// - Returns: 복원된 payload
    /// - Throws: ``DevaultImportError`` 4종(`corrupted`/`versionMismatch`/`expired`/`invalidPassword`) 중 하나.
    func `import`(data: Data, password: String) throws -> DevaultContainerPayload
}
