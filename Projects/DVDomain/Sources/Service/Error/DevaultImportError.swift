// Copyright © 2026 Devault. All rights reserved

public enum DevaultImportError: Error, Equatable, Sendable {
    case corrupted
    case versionMismatch
    case expired

    /// 헤더 변조로 인한 AAD 인증 실패, 빈 비밀번호 등 입력 자체가 안 된 경우까지 모두 이 케이스로 수렴한다.
    case invalidPassword
}
