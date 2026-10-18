// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 비밀번호와 salt로부터 대칭키 원료를 유도하는 서비스 프로토콜입니다.
public protocol PasswordKeyDerivationService: Sendable {
    /// Argon2id로 비밀번호와 salt로부터 지정 길이의 대칭키 원료를 유도한다.
    /// - Parameters:
    ///   - password: 유도에 사용할 비밀번호
    ///   - salt: 유도에 사용할 salt
    ///   - derivedKeyByteCount: 유도할 키의 바이트 길이 (AES-256은 32)
    /// - Returns: 유도된 키 원료
    func deriveKey(
        password: SensitiveString,
        salt: Data,
        derivedKeyByteCount: Int
    ) async throws -> Data
}
