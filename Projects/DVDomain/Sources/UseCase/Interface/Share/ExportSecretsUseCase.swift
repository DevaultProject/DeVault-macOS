// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 선택된 시크릿을 비밀번호로 봉인해 `.dvt` 파일로 내보내는 UseCase입니다.
public protocol ExportSecretsUseCase: Sendable {
    /// 시크릿을 복호화해 `.dvt`로 재봉인하고 임시 디렉터리에 쓴 파일 URL을 반환한다.
    ///
    /// 휴지통 항목이 섞여 있으면 전체를 거부한다. 인증(Touch ID)은 호출 전에 Feature가 끝낸다 — 이 UseCase는 인증을 모른다.
    /// - Parameters:
    ///   - secretIDs: 내보낼 시크릿 ID 목록
    ///   - password: `.dvt` 봉인 비밀번호. ``DevaultContainerService/export(payload:password:expiresAt:)``에 그대로 넘어간다
    ///   - expiresAt: 만료 시각 — nil이면 영구
    /// - Returns: 임시 디렉터리에 쓰인 `.dvt` 파일 URL. **삭제는 호출부 책임이다** — 사용자의 시크릿 전체가 담긴 파일이라 공유·저장이 끝나면 지워야 한다
    func execute(secretIDs: [UUID], password: SensitiveString, expiresAt: Date?) async throws -> URL
}
