// Copyright © 2026 Devault. All rights reserved

import Foundation

@testable import DVDomain

/// 도메인 계층 테스트용 in-memory Project 저장소.
///
/// 실제 저장소 규약을 흉내내 duplicateID 등을 재현하며,
/// 각 메서드별로 에러 주입과 호출 카운트를 제공한다.
public final class InMemoryProjectRepository: ProjectRepository, @unchecked Sendable {
    public var projects: [UUID: Project] = [:]

    public var errorOnCreate: ProjectRepositoryError?
    public var errorOnFetchByID: ProjectRepositoryError?
    public var errorOnFetchAll: ProjectRepositoryError?
    public var errorOnPatch: ProjectRepositoryError?
    public var errorOnDelete: ProjectRepositoryError?

    public private(set) var createCount = 0
    public private(set) var fetchByIDCount = 0
    public private(set) var fetchAllCount = 0
    public private(set) var patchCount = 0
    public private(set) var deleteCount = 0

    public private(set) var lastPatch: ProjectPatch?

    public init() {}

    public func seed(_ project: Project) { projects[project.id] = project }

    // MARK: - ProjectRepository

    public func create(_ project: Project, withinTotalLimit limit: Int) async throws -> Project? {
        guard projects.count < limit else { return nil }
        return try await create(project)
    }

    public func create(_ project: Project) async throws -> Project {
        createCount += 1
        if let error = errorOnCreate { throw error }
        guard projects[project.id] == nil else {
            throw ProjectRepositoryError.duplicateID(id: project.id)
        }
        guard !containsName(project.name, excluding: nil) else {
            throw ProjectRepositoryError.duplicateName(name: project.name)
        }
        projects[project.id] = project
        return project
    }

    public func fetch(id: UUID) async throws -> Project? {
        fetchByIDCount += 1
        if let error = errorOnFetchByID { throw error }
        return projects[id]
    }

    public func fetchAll() async throws -> [Project] {
        fetchAllCount += 1
        if let error = errorOnFetchAll { throw error }
        return Array(projects.values)
    }

    public func patch(id: UUID, with patch: ProjectPatch) async throws -> Project {
        patchCount += 1
        lastPatch = patch
        if let error = errorOnPatch { throw error }
        guard var project = projects[id] else {
            throw ProjectRepositoryError.notFound(id: id)
        }
        if case let .set(name) = patch.name {
            guard !containsName(name, excluding: id) else {
                throw ProjectRepositoryError.duplicateName(name: name)
            }
            project.name = name
        }
        if case let .set(updatedAt) = patch.updatedAt { project.updatedAt = updatedAt }
        projects[id] = project
        return project
    }

    public func delete(id: UUID) async throws {
        deleteCount += 1
        if let error = errorOnDelete { throw error }
        guard projects[id] != nil else {
            throw ProjectRepositoryError.notFound(id: id)
        }
        projects.removeValue(forKey: id)
    }

    /// 실제 저장소처럼 대소문자를 무시한다.
    private func containsName(_ name: String, excluding id: UUID?) -> Bool {
        let key = name.lowercased()
        return projects.values.contains { $0.id != id && $0.name.lowercased() == key }
    }
}
