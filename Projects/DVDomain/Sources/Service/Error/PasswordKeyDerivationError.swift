// Copyright © 2026 Devault. All rights reserved

public enum PasswordKeyDerivationError: Error, Equatable, Sendable {
    case invalidParameters
    /// argon2 원시 에러 코드 — 사용자에게 그대로 보여줄 값 아님.
    case derivationFailed(code: Int32)
}
