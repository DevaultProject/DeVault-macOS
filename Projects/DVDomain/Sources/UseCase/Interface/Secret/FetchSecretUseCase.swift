// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol FetchSecretUseCase: Sendable {
    func fetch(id: UUID) async throws -> Secret?

    func fetch(query: SecretQuery) async throws -> [Secret]

    /// 사이드바 카운트처럼 목록 본문이 필요 없을 때 쓴다. `sort`는 무시된다.
    func count(query: SecretQuery) async throws -> Int

    /// 무료 한도(`EntitlementLimits.maxSecrets`) 사용량 표시에 쓴다. `count(query:)`와 다르다 — 그쪽(`SecretQuery.Collection.all`)은 만료된 항목도 제외해 한도 계산과 어긋난다. 한도는 만료돼도 자리를 차지하는 `totalCountExcludingTrash` 기준이다(`EntitlementUseCaseImpl.canCreateSecret` 참고).
    func totalCountExcludingTrash() async throws -> Int

    /// 같은 타입 안에 이름이 겹치는 Secret이 있는지 확인한다.
    ///
    /// 이름은 생성 경로와 같게 trim한 뒤 **대소문자를 구분해** 비교한다. 휴지통은 빼고 만료된 Secret은 포함한다. 공백뿐이면 `false` — 빈 이름은 ``SecretUseCaseError/invalidName``이 생성 시점에 막는다.
    /// - Parameters:
    ///   - name: 검사할 이름
    ///   - secretType: 비교 범위가 되는 타입
    ///   - excludingID: 비교에서 뺄 Secret의 ID. 수정 화면에서 자기 자신을 뺄 때 쓴다
    func isNameDuplicated(name: String, secretType: SecretType, excludingID: UUID?) async throws -> Bool

    /// Secret에 연결된 Project 목록을 조회한다.
    /// - Parameter secretID: 조회할 Secret의 ID
    /// - Returns: 해당 Secret에 연결된 Project 배열
    func fetchProjects(secretID: UUID) async throws -> [Project]
}
