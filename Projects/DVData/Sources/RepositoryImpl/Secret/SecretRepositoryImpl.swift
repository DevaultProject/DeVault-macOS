// Copyright © 2026 Devault. All rights reserved

import Foundation
import SwiftData

import DVCore
import DVDomain

@ModelActor
public actor SecretRepositoryImpl: SecretRepository {
    public func create(_ secret: DVDomain.Secret) async throws -> DVDomain.Secret {
        do {
            if try fetchLocalSecret(id: secret.id) != nil {
                throw SecretRepositoryError.duplicateID(id: secret.id)
            }

            let localSecret = SwiftDataModel.Secret(
                id: secret.id,
                name: secret.name,
                secretType: secret.secretType.rawValue,
                subType: secret.subType?.rawValue,
                service: secret.service,
                environment: secret.environment,
                expiresAt: secret.expiresAt,
                memo: secret.memo,
                liked: secret.liked,
                deletedAt: secret.deletedAt,
                createdAt: secret.createdAt,
                updatedAt: secret.updatedAt
            )
            
            let localPayload = SwiftDataModel.SecretPayload(
                encryptedData: secret.payload.encryptedData,
                keyTag: secret.payload.keyTag,
                schemaVersion: secret.payload.schemaVersion,
                secret: localSecret
            )
            localSecret.payload = localPayload
            
            modelContext.insert(localSecret)
            modelContext.insert(localPayload)
            
            if let metadata = secret.metadata {
                let localMetadata = SwiftDataModel.SecretMetadata(
                    metadataJSON: metadata.metadataJSON,
                    schemaVersion: metadata.schemaVersion,
                    secret: localSecret
                )
                localSecret.metadata = localMetadata
                modelContext.insert(localMetadata)
            }
            
            try modelContext.save()
            
            return try localSecret.toDomain()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }
    
    public func fetch(id: UUID) async throws -> DVDomain.Secret? {
        do {
            guard let localSecret = try fetchLocalSecret(id: id) else {
                return nil
            }
            return try localSecret.toDomain()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }
    
    /// SecretFetchDescriptorBuilder로 원하는 조건으로 fetch 후 InMemorySecretQueryFilter로 searchText 보정
    public func fetch(_ query: SecretQuery) async throws -> [DVDomain.Secret] {
        do {
            let descriptor = SecretFetchDescriptorBuilder.make(from: query)
            let localSecrets = try modelContext.fetch(descriptor)
            let domainSecrets = localSecrets.compactMap { localSecret -> DVDomain.Secret? in
                do {
                    return try localSecret.toDomain()
                } catch {
                    // CloudKit 동기화 지연 등으로 payload가 아직 도착하지 않았을 수 있어 목록에서만 건너뜀
                    // 반복적으로 찍히면 진짜 손상된 레코드일 수 있으니 확인 필요
                    Log.warn("Secret(\(localSecret.id)) 변환 실패, 목록에서 제외: \(error)", category: .storage)
                    return nil
                }
            }
            return InMemorySecretQueryFilter.apply(query, to: domainSecrets)
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    /// 조건에 맞는 개수만 집계한다. 엔티티를 Domain으로 매핑하지 않으므로
    /// 손상된 레코드가 섞여 있어도 실패하지 않는다.
    public func count(_ query: SecretQuery) async throws -> Int {
        do {
            let descriptor = SecretFetchDescriptorBuilder.makeCountDescriptor(
                from: query,
                referenceDate: .now
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            Log.error(
                "[SecretRepository] count 실패 — collection: \(query.collection), error: \(error)",
                category: .data
            )
            throw SecretRepositoryError.persistenceFailed
        }
    }
    
    /// 휴지통을 제외한 전체 개수를 집계한다. 무료 티어 한도 계산 전용이다.
    public func totalCountExcludingTrash() async throws -> Int {
        do {
            let descriptor = SecretFetchDescriptorBuilder.makeTotalCountExcludingTrashDescriptor()
            return try modelContext.fetchCount(descriptor)
        } catch {
            Log.error(
                "[SecretRepository] totalCountExcludingTrash 실패 — error: \(error)",
                category: .data
            )
            throw SecretRepositoryError.persistenceFailed
        }
    }

    /// 개수만 세고 엔티티를 Domain으로 매핑하지 않는다.
    public func containsSecret(
        name: String,
        secretType: DVDomain.SecretType,
        excludingID: UUID?
    ) async throws -> Bool {
        do {
            let descriptor = SecretFetchDescriptorBuilder.makeDuplicateNameDescriptor(
                name: name,
                secretType: secretType,
                excludingID: excludingID
            )
            return try modelContext.fetchCount(descriptor) > 0
        } catch {
            Log.error(
                "[SecretRepository] containsSecret 실패 — secretType: \(secretType), error: \(error)",
                category: .data
            )
            throw SecretRepositoryError.persistenceFailed
        }
    }

    /// SecretPatch 적용하여 update
    public func patch(id: UUID, with patch: SecretPatch) async throws -> DVDomain.Secret {
        do {
            guard let localSecret = try fetchLocalSecret(id: id) else {
                throw SecretRepositoryError.notFound(id: id)
            }
            
            apply(patch, to: localSecret)
            try modelContext.save()
            
            return try localSecret.toDomain()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }
    
    public func delete(id: UUID) async throws {
        do {
            guard let localSecret = try fetchLocalSecret(id: id) else {
                throw SecretRepositoryError.notFound(id: id)
            }
            
            modelContext.delete(localSecret)
            try modelContext.save()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    public func fetchProjects(secretID: UUID) async throws -> [DVDomain.Project] {
        do {
            guard let localSecret = try fetchLocalSecret(id: secretID) else {
                throw SecretRepositoryError.notFound(id: secretID)
            }

            return localSecret.projects
                .sorted { $0.name < $1.name }
                .map { $0.toDomain() }
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    public func linkProject(secretID: UUID, projectID: UUID) async throws {
        do {
            guard let localSecret = try fetchLocalSecret(id: secretID) else {
                throw SecretRepositoryError.notFound(id: secretID)
            }

            guard let localProject = try fetchLocalProject(id: projectID) else {
                throw SecretRepositoryError.projectNotFound(id: projectID)
            }

            if try fetchLocalProjectLink(secretID: secretID, projectID: projectID) != nil {
                throw SecretRepositoryError.duplicateProjectLink(
                    secretID: secretID,
                    projectID: projectID
                )
            }

            let link = SwiftDataModel.SecretProjectLink(
                project: localProject,
                secret: localSecret
            )
            modelContext.insert(link)
            try modelContext.save()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    public func unlinkProject(secretID: UUID, projectID: UUID) async throws {
        do {
            guard try fetchLocalSecret(id: secretID) != nil else {
                throw SecretRepositoryError.notFound(id: secretID)
            }

            guard try fetchLocalProject(id: projectID) != nil else {
                throw SecretRepositoryError.projectNotFound(id: projectID)
            }

            guard let link = try fetchLocalProjectLink(
                secretID: secretID,
                projectID: projectID
            ) else {
                throw SecretRepositoryError.projectLinkNotFound(
                    secretID: secretID,
                    projectID: projectID
                )
            }

            modelContext.delete(link)
            try modelContext.save()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    public func create(_ secret: DVDomain.Secret, projectIDs: [UUID]) async throws -> DVDomain.Secret {
        try insert(secret, projectIDs: projectIDs)
    }

    public func create(
        _ secret: DVDomain.Secret,
        projectIDs: [UUID],
        withinTotalLimit limit: Int
    ) async throws -> DVDomain.Secret? {
        // 세기와 넣기 사이에 await가 없어야 actor가 다른 요청을 끼워 넣지 못한다. 둘 다 동기 호출로 유지할 것.
        let held: Int
        do {
            held = try modelContext.fetchCount(
                SecretFetchDescriptorBuilder.makeTotalCountExcludingTrashDescriptor()
            )
        } catch {
            Log.error("[SecretRepository] 한도 검사용 개수 조회 실패 — error: \(error)", category: .data)
            throw SecretRepositoryError.persistenceFailed
        }

        guard held < limit else { return nil }
        return try insert(secret, projectIDs: projectIDs)
    }

    private func insert(_ secret: DVDomain.Secret, projectIDs: [UUID]) throws -> DVDomain.Secret {
        do {
            if try fetchLocalSecret(id: secret.id) != nil {
                throw SecretRepositoryError.duplicateID(id: secret.id)
            }

            let localSecret = SwiftDataModel.Secret(
                id: secret.id,
                name: secret.name,
                secretType: secret.secretType.rawValue,
                subType: secret.subType?.rawValue,
                service: secret.service,
                environment: secret.environment,
                expiresAt: secret.expiresAt,
                memo: secret.memo,
                liked: secret.liked,
                deletedAt: secret.deletedAt,
                createdAt: secret.createdAt,
                updatedAt: secret.updatedAt
            )

            let localPayload = SwiftDataModel.SecretPayload(
                encryptedData: secret.payload.encryptedData,
                keyTag: secret.payload.keyTag,
                schemaVersion: secret.payload.schemaVersion,
                secret: localSecret
            )
            localSecret.payload = localPayload
            modelContext.insert(localSecret)
            modelContext.insert(localPayload)

            if let metadata = secret.metadata {
                let localMetadata = SwiftDataModel.SecretMetadata(
                    metadataJSON: metadata.metadataJSON,
                    schemaVersion: metadata.schemaVersion,
                    secret: localSecret
                )
                localSecret.metadata = localMetadata
                modelContext.insert(localMetadata)
            }

            for projectID in Set(projectIDs) {
                guard let localProject = try fetchLocalProject(id: projectID) else {
                    throw SecretRepositoryError.projectNotFound(id: projectID)
                }
                let link = SwiftDataModel.SecretProjectLink(
                    project: localProject,
                    secret: localSecret
                )
                modelContext.insert(link)
            }

            try modelContext.save()
            return try localSecret.toDomain()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    public func patch(id: UUID, with patch: SecretPatch, projectIDs: [UUID]) async throws -> DVDomain.Secret {
        do {
            guard let localSecret = try fetchLocalSecret(id: id) else {
                throw SecretRepositoryError.notFound(id: id)
            }

            apply(patch, to: localSecret)

            let currentIDs = Set((localSecret.projectLinks ?? []).map(\.projectID))
            let desiredIDs = Set(projectIDs)

            for projectID in desiredIDs.subtracting(currentIDs) {
                guard let localProject = try fetchLocalProject(id: projectID) else {
                    throw SecretRepositoryError.projectNotFound(id: projectID)
                }
                let link = SwiftDataModel.SecretProjectLink(
                    project: localProject,
                    secret: localSecret
                )
                modelContext.insert(link)
            }

            for projectID in currentIDs.subtracting(desiredIDs) {
                if let link = try fetchLocalProjectLink(secretID: id, projectID: projectID) {
                    modelContext.delete(link)
                }
            }

            try modelContext.save()
            return try localSecret.toDomain()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    /// 쿼리에 맞는 로컬 Secret 전체에 patch를 적용하고 한 번만 save한다
    public func patchAll(matching query: SecretQuery, with patch: SecretPatch) async throws {
        do {
            let descriptor = SecretFetchDescriptorBuilder.make(from: query)
            let localSecrets = try modelContext.fetch(descriptor)
            for localSecret in localSecrets {
                apply(patch, to: localSecret)
            }
            try modelContext.save()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }

    /// 쿼리에 맞는 로컬 Secret 전체를 삭제하고 한 번만 save한다.
    public func deleteAll(matching query: SecretQuery) async throws {
        do {
            let descriptor = SecretFetchDescriptorBuilder.make(from: query)
            let localSecrets = try modelContext.fetch(descriptor)
            for localSecret in localSecrets {
                modelContext.delete(localSecret)
            }
            try modelContext.save()
        } catch let error as SecretRepositoryError {
            throw error
        } catch {
            throw SecretRepositoryError.persistenceFailed
        }
    }
}

extension SecretRepositoryImpl {
    private func fetchLocalSecret(id: UUID) throws -> SwiftDataModel.Secret? {
        var descriptor = FetchDescriptor<SwiftDataModel.Secret>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLocalProject(id: UUID) throws -> SwiftDataModel.Project? {
        var descriptor = FetchDescriptor<SwiftDataModel.Project>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLocalProjectLink(
        secretID: UUID,
        projectID: UUID
    ) throws -> SwiftDataModel.SecretProjectLink? {
        let linkKey = projectLinkKey(secretID: secretID, projectID: projectID)
        var descriptor = FetchDescriptor<SwiftDataModel.SecretProjectLink>(
            predicate: #Predicate { $0.linkKey == linkKey }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func projectLinkKey(secretID: UUID, projectID: UUID) -> String {
        "\(projectID.uuidString):\(secretID.uuidString)"
    }

    /// SecretPatch를 SwiftData model에 반영
    private func apply(_ patch: SecretPatch, to secret: SwiftDataModel.Secret) {
        if case let .set(name) = patch.name {
            secret.name = name
        }
        if case let .set(secretType) = patch.secretType {
            secret.secretType = secretType.rawValue
        }
        if case let .set(subType) = patch.subType {
            secret.subType = subType?.rawValue
        }
        if case let .set(service) = patch.service {
            secret.service = service
        }
        if case let .set(environment) = patch.environment {
            secret.environment = environment
        }
        if case let .set(expiresAt) = patch.expiresAt {
            secret.expiresAt = expiresAt
        }
        if case let .set(memo) = patch.memo {
            secret.memo = memo
        }
        if case let .set(liked) = patch.liked {
            secret.liked = liked
        }
        if case let .set(deletedAt) = patch.deletedAt {
            secret.deletedAt = deletedAt
        }
        if case let .set(updatedAt) = patch.updatedAt {
            secret.updatedAt = updatedAt
        }
        if case let .set(payload) = patch.payload {
            apply(payload, to: secret)
        }
        if case let .set(metadata) = patch.metadata {
            apply(metadata, to: secret)
        }
    }

    /// payload가 있으면 업데이트하고, 없으면 새 payload를 만든다.
    private func apply(_ payload: DVDomain.SecretPayload, to secret: SwiftDataModel.Secret) {
        if let localPayload = secret.payload {
            localPayload.encryptedData = payload.encryptedData
            localPayload.keyTag = payload.keyTag
            localPayload.schemaVersion = payload.schemaVersion
        } else {
            let localPayload = SwiftDataModel.SecretPayload(
                encryptedData: payload.encryptedData,
                keyTag: payload.keyTag,
                schemaVersion: payload.schemaVersion,
                secret: secret
            )
            secret.payload = localPayload
            modelContext.insert(localPayload)
        }
    }

    /// metadata가 nil이면 기존 metadata를 삭제하고, 값이 있으면 업데이트 또는 생성한다.
    private func apply(_ metadata: DVDomain.SecretMetadata?, to secret: SwiftDataModel.Secret) {
        guard let metadata else {
            if let localMetadata = secret.metadata {
                modelContext.delete(localMetadata)
            }
            secret.metadata = nil
            return
        }

        if let localMetadata = secret.metadata {
            localMetadata.metadataJSON = metadata.metadataJSON
            localMetadata.schemaVersion = metadata.schemaVersion
        } else {
            let localMetadata = SwiftDataModel.SecretMetadata(
                metadataJSON: metadata.metadataJSON,
                schemaVersion: metadata.schemaVersion,
                secret: secret
            )
            secret.metadata = localMetadata
            modelContext.insert(localMetadata)
        }
    }
}
