// Copyright © 2026 Devault. All rights reserved

public enum DevaultImportError: Error, Equatable, Sendable {
    case corrupted
    case versionMismatch
    case expired

    /// 헤더 변조도 AAD 인증 실패로 수렴해 이 케이스로 처리된다.
    case wrongPassword
}
