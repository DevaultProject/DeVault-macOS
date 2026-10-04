// Copyright © 2026 Devault. All rights reserved

import Foundation

@testable import DVDomain

/// 도메인 계층 테스트용 in-memory Secret 저장소.
///
/// 실제 저장소 규약을 흉내내 duplicateID 등을 재현하며,
/// 각 메서드별로 에러 주입과 호출 카운트를 제공한다.
public final class InMemorySecretRepository: SecretRepository, @unchecked Sendable {
    public var secrets: [UUID: Secret] = [:]
    public var projects: [UUID: Project] = [:]
    /// secretID → 연결된 projectID 집합
    public var projectLinks: [UUID: Set<UUID>] = [:]

    public var errorOnCreate: SecretRepositoryError?
    public var errorOnFetchByID: SecretRepositoryError?
    public var errorOnFetchQuery: SecretRepositoryError?
    public var errorOnCountQuery: SecretRepositoryError?
    public var errorOnContainsSecret: SecretRepositoryError?
    public var errorOnPatch: SecretRepositoryError?
    public var errorOnDelete: SecretRepositoryError?
    public var errorOnFetchProjects: SecretRepositoryError?
    public var errorOnLinkProject: SecretRepositoryError?
    public var errorOnUnlinkProject: SecretRepositoryError?
    public var errorOnCreateWithProjects: SecretRepositoryError?
    public var errorOnPatchWithProjects: SecretRepositoryError?
    public var errorOnPatchAll: SecretRepositoryError?
    public var errorOnDeleteAll: SecretRepositoryError?

    public private(set) var createCount = 0
    public private(set) var fetchByIDCount = 0
    public private(set) var fetchQueryCount = 0
    public private(set) var countQueryCount = 0
    public private(set) var containsSecretCount = 0
    public private(set) var patchCount = 0
    public private(set) var deleteCount = 0
    public private(set) var fetchProjectsCount = 0
    public private(set) var linkProjectCount = 0
    public private(set) var unlinkProjectCount = 0
    public private(set) var createWithProjectsCount = 0
    public private(set) var patchWithProjectsCount = 0
    public private(set) var patchAllCount = 0
    public private(set) var deleteAllCount = 0

    public private(set) var lastContainsSecretName: String?
    public private(set) var lastPatch: SecretPatch?
    public private(set) var lastProjectIDs: [UUID]?

    public init() {}

    public func seed(_ secret: Secret) { secrets[secret.id] = secret }
    public func seedProject(_ project: Project) { projects[project.id] = project }

    // MARK: - SecretRepository

    public func create(_ secret: Secret) async throws -> Secret {
        createCount += 1
        if let error = errorOnCreate { throw error }
        guard secrets[secret.id] == nil else {
            throw SecretRepositoryError.duplicateID(id: secret.id)
        }
        secrets[secret.id] = secret
        return secret
    }

    public func fetch(id: UUID) async throws -> Secret? {
        fetchByIDCount += 1
        if let error = errorOnFetchByID { throw error }
        return secrets[id]
    }

    public func fetch(_ query: SecretQuery) async throws -> [Secret] {
        fetchQueryCount += 1
        if let error = errorOnFetchQuery { throw error }
        return Array(secrets.values)
    }

    public func count(_ query: SecretQuery) async throws -> Int {
        countQueryCount += 1
        if let error = errorOnCountQuery { throw error }
        return secrets.values.count { matches($0, query: query) }
    }

    public func totalCountExcludingTrash() async throws -> Int {
        countQueryCount += 1
        if let error = errorOnCountQuery { throw error }
        return secrets.values.count { $0.deletedAt == nil }
    }

    /// 휴지통만 제외하고 이름을 대소문자 구분해 비교한다 — 실제 저장소 predicate와 같은 규칙.
    public func containsSecret(
        name: String,
        secretType: SecretType,
        excludingID: UUID?
    ) async throws -> Bool {
        containsSecretCount += 1
        lastContainsSecretName = name
        if let error = errorOnContainsSecret { throw error }
        return secrets.values.contains {
            $0.deletedAt == nil &&
            $0.secretType == secretType &&
            $0.name == name &&
            $0.id != excludingID
        }
    }

    public func patch(id: UUID, with patch: SecretPatch) async throws -> Secret {
        patchCount += 1
        lastPatch = patch
        if let error = errorOnPatch { throw error }
        guard var secret = secrets[id] else {
            throw SecretRepositoryError.notFound(id: id)
        }
        secret.apply(patch)
        secrets[id] = secret
        return secret
    }

    public func delete(id: UUID) async throws {
        deleteCount += 1
        if let error = errorOnDelete { throw error }
        guard secrets[id] != nil else {
            throw SecretRepositoryError.notFound(id: id)
        }
        secrets.removeValue(forKey: id)
    }

    public func fetchProjects(secretID: UUID) async throws -> [Project] {
        fetchProjectsCount += 1
        if let error = errorOnFetchProjects { throw error }
        guard secrets[secretID] != nil else {
            throw SecretRepositoryError.notFound(id: secretID)
        }
        return projectLinks[secretID]?.compactMap { projects[$0] } ?? []
    }

    public func linkProject(secretID: UUID, projectID: UUID) async throws {
        linkProjectCount += 1
        if let error = errorOnLinkProject { throw error }
        guard secrets[secretID] != nil else {
            throw SecretRepositoryError.notFound(id: secretID)
        }
        projectLinks[secretID, default: []].insert(projectID)
    }

    public func unlinkProject(secretID: UUID, projectID: UUID) async throws {
        unlinkProjectCount += 1
        if let error = errorOnUnlinkProject { throw error }
        guard secrets[secretID] != nil else {
            throw SecretRepositoryError.notFound(id: secretID)
        }
        projectLinks[secretID]?.remove(projectID)
    }

    // MARK: - 원자적 생성·수정 (Project 연결 포함)

    public func create(
        _ secret: Secret,
        projectIDs: [UUID],
        withinTotalLimit limit: Int
    ) async throws -> Secret? {
        let held = secrets.values.count { $0.deletedAt == nil }
        guard held < limit else { return nil }
        return try await create(secret, projectIDs: projectIDs)
    }

    public func create(_ secret: Secret, projectIDs: [UUID]) async throws -> Secret {
        createWithProjectsCount += 1
        lastProjectIDs = projectIDs
        if let error = errorOnCreateWithProjects { throw error }
        guard secrets[secret.id] == nil else {
            throw SecretRepositoryError.duplicateID(id: secret.id)
        }
        secrets[secret.id] = secret
        projectLinks[secret.id] = Set(projectIDs)
        return secret
    }

    public func patch(id: UUID, with patch: SecretPatch, projectIDs: [UUID]) async throws -> Secret {
        patchWithProjectsCount += 1
        lastPatch = patch
        lastProjectIDs = projectIDs
        if let error = errorOnPatchWithProjects { throw error }
        guard var secret = secrets[id] else {
            throw SecretRepositoryError.notFound(id: id)
        }
        secret.apply(patch)
        secrets[id] = secret
        projectLinks[id] = Set(projectIDs)
        return secret
    }

    // MARK: - 컬렉션 일괄 (원자적)

    public func patchAll(matching query: SecretQuery, with patch: SecretPatch) async throws {
        patchAllCount += 1
        lastPatch = patch
        if let error = errorOnPatchAll { throw error }
        let ids = secrets.filter { matches($0.value, query: query) }.map(\.key)
        for id in ids {
            guard var secret = secrets[id] else { continue }
            secret.apply(patch)
            secrets[id] = secret
        }
    }

    public func deleteAll(matching query: SecretQuery) async throws {
        deleteAllCount += 1
        if let error = errorOnDeleteAll { throw error }
        let ids = secrets.filter { matches($0.value, query: query) }.map(\.key)
        for id in ids {
            secrets.removeValue(forKey: id)
        }
    }
}

// MARK: - Query 판정

private extension InMemorySecretRepository {

    /// `SecretRepositoryImpl.count(_:)`의 predicate와 같은 규칙으로 Secret 하나를 판정한다.
    ///
    /// 전체 개수를 그대로 돌려주면 필터별 카운트가 모두 같은 값이어도 테스트가 통과하므로,
    /// 실제 저장소와 동일한 의미를 여기서도 구현한다.
    /// `searchText`·`sort`는 실제 count 경로에서도 무시되므로 여기서도 보지 않는다.
    func matches(_ secret: Secret, query: SecretQuery) -> Bool {
        matchesCollection(secret, collection: query.collection)
            && (query.secretType.map { secret.secretType == $0 } ?? true)
            && (query.service.flatMap { $0.isEmpty ? nil : $0 }.map { secret.service == $0 } ?? true)
            && (query.environment.flatMap { $0.isEmpty ? nil : $0 }.map { secret.environment == $0 } ?? true)
    }

    func matchesCollection(_ secret: Secret, collection: SecretQuery.Collection) -> Bool {
        // 만료일이 없으면 "만료되지 않음"으로 취급 — 실제 predicate의 `?? .distantFuture`와 같은 규칙.
        let expiresAt = secret.expiresAt ?? .distantFuture

        switch collection {
        case .all:
            return secret.deletedAt == nil && expiresAt >= .now
        case .liked:
            return secret.deletedAt == nil && secret.liked && expiresAt >= .now
        case let .notice(referenceDate):
            let windowEnd = SecretQuery.Collection.noticeWindowEnd(from: referenceDate)
            return secret.deletedAt == nil && expiresAt >= referenceDate && expiresAt <= windowEnd
        case let .expired(referenceDate):
            return secret.deletedAt == nil && expiresAt < referenceDate
        case .deleted:
            return secret.deletedAt != nil
        case let .project(projectID):
            return secret.deletedAt == nil && (projectLinks[secret.id]?.contains(projectID) ?? false)
        }
    }
}

private extension Secret {
    mutating func apply(_ patch: SecretPatch) {
        if case let .set(name) = patch.name { self.name = name }
        if case let .set(secretType) = patch.secretType { self.secretType = secretType }
        if case let .set(subType) = patch.subType { self.subType = subType }
        if case let .set(service) = patch.service { self.service = service }
        if case let .set(environment) = patch.environment { self.environment = environment }
        if case let .set(expiresAt) = patch.expiresAt { self.expiresAt = expiresAt }
        if case let .set(memo) = patch.memo { self.memo = memo }
        if case let .set(liked) = patch.liked { self.liked = liked }
        if case let .set(deletedAt) = patch.deletedAt { self.deletedAt = deletedAt }
        if case let .set(payload) = patch.payload { self.payload = payload }
        if case let .set(metadata) = patch.metadata { self.metadata = metadata }
        if case let .set(updatedAt) = patch.updatedAt { self.updatedAt = updatedAt }
    }
}
