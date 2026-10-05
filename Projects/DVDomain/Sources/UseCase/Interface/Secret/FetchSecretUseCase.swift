// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol FetchSecretUseCase: Sendable {
    func fetch(id: UUID) async throws -> Secret?

    func fetch(query: SecretQuery) async throws -> [Secret]

    /// 사이드바 카운트처럼 목록 본문이 필요 없을 때 쓴다. `sort`는 무시된다.
    func count(query: SecretQuery) async throws -> Int

    /// 무료 한도(`EntitlementLimits.maxSecrets`) 사용량 표시에 쓴다. `count(query:)`와 다르다 — 그쪽(`SecretQuery.Collection.all`)은 만료된 항목도 제외해 한도 계산과 어긋난다. 한도는 만료돼도 자리를 차지하는 `totalCountExcludingTrash` 기준이다(`EntitlementUseCaseImpl.canCreateSecret` 참고).
    func totalCountExcludingTrash() async throws -> Int

    func fetchProjects(secretID: UUID) async throws -> [Project]
}
