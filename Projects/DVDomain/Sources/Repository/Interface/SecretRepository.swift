// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol SecretRepository: Sendable {
    func create(_ secret: Secret) async throws -> Secret

    func fetch(id: UUID) async throws -> Secret?

    func fetch(_ query: SecretQuery) async throws -> [Secret]

    /// 엔티티를 메모리로 올리지 않으므로 `fetch(_:).count`보다 가볍고,
    /// 손상된 레코드가 섞여 있어도 개수 집계는 실패하지 않는다. `sort`는 무시된다.
    func count(_ query: SecretQuery) async throws -> Int

    /// `count(SecretQuery(collection: .all))`과 다르다. 그쪽은 사이드바 배지용이라 만료된 Secret까지 제외한다. 만료돼도 조회·수정이 되므로 한도 계산에는 포함해야 한다.
    func totalCountExcludingTrash() async throws -> Int

    func patch(id: UUID, with patch: SecretPatch) async throws -> Secret

    func delete(id: UUID) async throws

    func fetchProjects(secretID: UUID) async throws -> [Project]

    func linkProject(secretID: UUID, projectID: UUID) async throws

    func unlinkProject(secretID: UUID, projectID: UUID) async throws

    /// 실패 시 ModelContext가 자동 롤백하므로 partial state가 발생하지 않는다.
    func create(_ secret: Secret, projectIDs: [UUID]) async throws -> Secret

    /// 세는 것과 넣는 것을 한 번에 처리해, 동시에 들어온 생성 둘이 같은 개수를 보고 나란히 통과하는 틈을 없앤다. 한도가 얼마인지·언제 적용되는지는 호출부가 정하고 저장소는 받은 수만 지킨다.
    func create(_ secret: Secret, projectIDs: [UUID], withinTotalLimit limit: Int) async throws -> Secret?

    /// 현재 연결 상태와 projectIDs를 비교해 link/unlink를 결정하며, 실패 시 자동 롤백한다.
    func patch(id: UUID, with patch: SecretPatch, projectIDs: [UUID]) async throws -> Secret

    /// fetch → 전체 변경 → 단일 save로 원자적으로 처리한다(예: Expired 목록을 한 번에 소프트 삭제). `sort`·`searchText`는 무시하고 collection 범위로만 동작한다.
    func patchAll(matching query: SecretQuery, with patch: SecretPatch) async throws

    /// 영구 삭제이며 복구 불가하다(예: Deleted 목록 비우기). `sort`·`searchText`는 무시하고 collection 범위로만 동작한다.
    func deleteAll(matching query: SecretQuery) async throws
}
