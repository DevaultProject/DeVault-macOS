// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import SwiftData

@ModelActor
public actor ProjectRepositoryImpl: ProjectRepository {
    public func create(_ project: DVDomain.Project) async throws -> DVDomain.Project {
        try insert(project)
    }

    public func create(
        _ project: DVDomain.Project,
        withinTotalLimit limit: Int
    ) async throws -> DVDomain.Project? {
        // 세기와 넣기 사이에 await가 없어야 actor가 다른 요청을 끼워 넣지 못한다. 둘 다 동기 호출로 유지할 것.
        let held: Int
        do {
            held = try modelContext.fetchCount(FetchDescriptor<SwiftDataModel.Project>())
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }

        guard held < limit else { return nil }
        return try insert(project)
    }

    private func insert(_ project: DVDomain.Project) throws -> DVDomain.Project {
        do {
            if try fetchLocalProject(id: project.id) != nil {
                throw ProjectRepositoryError.duplicateID(id: project.id)
            }

            if try containsProjectName(project.name, excluding: nil) {
                throw ProjectRepositoryError.duplicateName(name: project.name)
            }

            let localProject = SwiftDataModel.Project(
                id: project.id,
                name: project.name,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt
            )

            modelContext.insert(localProject)
            try modelContext.save()

            return localProject.toDomain()
        } catch let error as ProjectRepositoryError {
            throw error
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }
    }

    public func fetch(id: UUID) async throws -> DVDomain.Project? {
        do {
            guard let localProject = try fetchLocalProject(id: id) else {
                return nil
            }
            return localProject.toDomain()
        } catch let error as ProjectRepositoryError {
            throw error
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }
    }

    public func fetchAll() async throws -> [DVDomain.Project] {
        do {
            let descriptor = FetchDescriptor<SwiftDataModel.Project>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let localProjects = try modelContext.fetch(descriptor)
            return localProjects.map { $0.toDomain() }
        } catch let error as ProjectRepositoryError {
            throw error
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }
    }

    public func patch(id: UUID, with patch: ProjectPatch) async throws -> DVDomain.Project {
        do {
            guard let localProject = try fetchLocalProject(id: id) else {
                throw ProjectRepositoryError.notFound(id: id)
            }

            let shouldSave = try apply(patch, to: localProject)
            if shouldSave {
                try modelContext.save()
            }

            return localProject.toDomain()
        } catch let error as ProjectRepositoryError {
            throw error
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }
    }

    public func delete(id: UUID) async throws {
        do {
            guard let localProject = try fetchLocalProject(id: id) else {
                throw ProjectRepositoryError.notFound(id: id)
            }

            modelContext.delete(localProject)
            try modelContext.save()
        } catch let error as ProjectRepositoryError {
            throw error
        } catch {
            throw ProjectRepositoryError.persistenceFailed
        }
    }
}

extension ProjectRepositoryImpl {
    private func fetchLocalProject(id: UUID) throws -> SwiftDataModel.Project? {
        var descriptor = FetchDescriptor<SwiftDataModel.Project>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// ProjectPatch를 SwiftData model에 반영하고 저장 필요 여부를 반환한다.
    private func apply(
        _ patch: ProjectPatch,
        to project: SwiftDataModel.Project
    ) throws -> Bool {
        var shouldSave = false

        if case let .set(name) = patch.name {
            if try containsProjectName(name, excluding: project.id) {
                throw ProjectRepositoryError.duplicateName(name: name)
            }
            project.name = name
            shouldSave = true
        }

        if case let .set(updatedAt) = patch.updatedAt {
            project.updatedAt = updatedAt
            shouldSave = true
        }

        return shouldSave
    }

    /// 비교용 이름 key를 기준으로 같은 이름의 Project가 있는지 확인한다.
    private func containsProjectName(
        _ name: String,
        excluding excludedID: UUID?
    ) throws -> Bool {
        guard let nameKey = ProjectNameRule.comparisonKey(name) else { return false }
        let descriptor = FetchDescriptor<SwiftDataModel.Project>()
        let projects = try modelContext.fetch(descriptor)

        return projects.contains { project in
            let isExcluded = excludedID.map { project.id == $0 } ?? false // 자기 자신 제외
            return !isExcluded && ProjectNameRule.comparisonKey(project.name) == nameKey
        }
    }
}
