// Copyright © 2026 Devault. All rights reserved

extension EntitlementUseCase {

    func ensureCanCreateSecret() async throws {
        try await ensure { try await canCreateSecret() }
    }

    func ensureCanImportSecrets(count: Int) async throws {
        try await ensure { try await canImportSecrets(count: count) }
    }

    /// 판정 실패(저장소 오류)와 게이트 차단은 다름
    /// 판정 실패 - 전자는 ``SecretUseCaseError``로 매핑
    /// 게이트 차단 - ``EntitlementError``로 내보내 호출부가 페이월을 띄우게 함
    private func ensure(_ judge: () async throws -> Bool) async throws {
        let allowed: Bool
        do {
            allowed = try await judge()
        } catch {
            throw SecretUseCaseError.map(error)
        }
        guard allowed else { throw EntitlementError.limitReached }
    }
}
