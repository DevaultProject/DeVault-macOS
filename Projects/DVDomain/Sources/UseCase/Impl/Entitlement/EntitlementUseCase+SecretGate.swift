// Copyright © 2026 Devault. All rights reserved

import Foundation

extension EntitlementUseCase {

    func ensureCanCreateSecret() async throws {
        try await ensure { try await canCreateSecret() }
    }

    func ensureCanImportSecrets(count: Int) async throws {
        try await ensure { try await canImportSecrets(count: count) }
    }

    /// 앞선 판정과 저장 사이에 암호화가 끼어 있어 동시 생성이 한도를 넘길 수 있다.
    /// 저장소가 세기와 넣기를 한 번에 처리해 막는다.
    func createSecretWithinLimit(
        _ secret: Secret,
        projectIDs: [UUID],
        in repository: any SecretRepository
    ) async throws -> Secret {
        let limit = current() == .free ? EntitlementLimits.maxSecrets : Int.max
        guard let created = try await repository.create(secret, projectIDs: projectIDs, withinTotalLimit: limit) else {
            throw EntitlementError.limitReached
        }
        return created
    }

    /// 판정 실패(저장소 오류)와 게이트 차단은 다름
    /// 판정 실패 - ``SecretUseCaseError``로 매핑
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
