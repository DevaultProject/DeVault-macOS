// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol FetchSecretUseCase: Sendable {
    /// ID로 단일 Secret을 조회한다.
    /// - Parameter id: 조회할 Secret의 ID
    /// - Returns: 해당 Secret. 존재하지 않으면 nil
    func fetch(id: UUID) async throws -> Secret?

    /// 쿼리 조건에 맞는 Secret 목록을 조회한다.
    /// - Parameter query: 필터·정렬 조건을 담은 SecretQuery
    /// - Returns: 조건에 부합하는 Secret 배열
    func fetch(query: SecretQuery) async throws -> [Secret]

    /// 쿼리 조건에 맞는 Secret의 개수만 조회한다. 사이드바 카운트처럼 목록 본문이 필요 없을 때 쓴다.
    /// - Parameter query: 필터 조건을 담은 SecretQuery. `sort`는 무시된다
    /// - Returns: 조건에 부합하는 Secret 개수
    func count(query: SecretQuery) async throws -> Int

    /// 휴지통을 제외한 전체 Secret 개수. 무료 한도(`EntitlementLimits.maxSecrets`) 사용량 표시에 쓴다.
    ///
    /// `count(query:)`와 다르다 — 그쪽(`SecretQuery.Collection.all`)은 만료된 항목도 제외해
    /// 한도 계산과 어긋난다. 한도는 만료돼도 자리를 차지하는 `totalCountExcludingTrash`
    /// 기준이다(`EntitlementUseCaseImpl.canCreateSecret` 참고).
    /// - Returns: `deletedAt == nil`인 Secret의 개수
    func totalCountExcludingTrash() async throws -> Int

    /// Secret에 연결된 Project 목록을 조회한다.
    /// - Parameter secretID: 조회할 Secret의 ID
    /// - Returns: 해당 Secret에 연결된 Project 배열
    func fetchProjects(secretID: UUID) async throws -> [Project]
}
