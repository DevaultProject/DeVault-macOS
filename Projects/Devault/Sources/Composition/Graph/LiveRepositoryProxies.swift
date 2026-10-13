// Copyright © 2026 Devault. All rights reserved

import Foundation

import DVDomain

/// 기존 Client와 UseCase가 인스턴스를 다시 만들지 않아도 현재 Secret Repository를 사용하게 하는 Proxy.
struct LiveSecretRepository: SecretRepository {
  let storage: LiveStorage

  func create(_ secret: Secret) async throws -> Secret {
    try await storage.secretRepository().create(secret)
  }

  func fetch(id: UUID) async throws -> Secret? {
    try await storage.secretRepository().fetch(id: id)
  }

  func fetch(_ query: SecretQuery) async throws -> [Secret] {
    try await storage.secretRepository().fetch(query)
  }

  func count(_ query: SecretQuery) async throws -> Int {
    try await storage.secretRepository().count(query)
  }

  func totalCountExcludingTrash() async throws -> Int {
    try await storage.secretRepository().totalCountExcludingTrash()
  }

  func containsSecret(name: String, secretType: SecretType, excludingID: UUID?) async throws -> Bool {
    try await storage.secretRepository().containsSecret(
      name: name,
      secretType: secretType,
      excludingID: excludingID
    )
  }

  func patch(id: UUID, with patch: SecretPatch) async throws -> Secret {
    try await storage.secretRepository().patch(id: id, with: patch)
  }

  func delete(id: UUID) async throws {
    try await storage.secretRepository().delete(id: id)
  }

  func fetchProjects(secretID: UUID) async throws -> [Project] {
    try await storage.secretRepository().fetchProjects(secretID: secretID)
  }

  func linkProject(secretID: UUID, projectID: UUID) async throws {
    try await storage.secretRepository().linkProject(secretID: secretID, projectID: projectID)
  }

  func unlinkProject(secretID: UUID, projectID: UUID) async throws {
    try await storage.secretRepository().unlinkProject(secretID: secretID, projectID: projectID)
  }

  func create(_ secret: Secret, projectIDs: [UUID]) async throws -> Secret {
    try await storage.secretRepository().create(secret, projectIDs: projectIDs)
  }

  func create(_ secret: Secret, projectIDs: [UUID], withinTotalLimit limit: Int) async throws -> Secret? {
    try await storage.secretRepository().create(secret, projectIDs: projectIDs, withinTotalLimit: limit)
  }

  func patch(id: UUID, with patch: SecretPatch, projectIDs: [UUID]) async throws -> Secret {
    try await storage.secretRepository().patch(id: id, with: patch, projectIDs: projectIDs)
  }

  func patchAll(matching query: SecretQuery, with patch: SecretPatch) async throws {
    try await storage.secretRepository().patchAll(matching: query, with: patch)
  }

  func deleteAll(matching query: SecretQuery) async throws {
    try await storage.secretRepository().deleteAll(matching: query)
  }
}

/// 기존 Client와 UseCase가 인스턴스를 다시 만들지 않아도 현재 Project Repository를 사용하게 하는 Proxy.
struct LiveProjectRepository: ProjectRepository {
  let storage: LiveStorage

  func create(_ project: Project) async throws -> Project {
    try await storage.projectRepository().create(project)
  }

  func create(_ project: Project, withinTotalLimit limit: Int) async throws -> Project? {
    try await storage.projectRepository().create(project, withinTotalLimit: limit)
  }

  func fetch(id: UUID) async throws -> Project? {
    try await storage.projectRepository().fetch(id: id)
  }

  func fetchAll() async throws -> [Project] {
    try await storage.projectRepository().fetchAll()
  }

  func patch(id: UUID, with patch: ProjectPatch) async throws -> Project {
    try await storage.projectRepository().patch(id: id, with: patch)
  }

  func delete(id: UUID) async throws {
    try await storage.projectRepository().delete(id: id)
  }
}

/// 현재 활성 ModelContainer의 Data Reset Repository로 호출을 전달하는 Proxy.
struct LiveDataResetRepository: DataResetRepository {
  let storage: LiveStorage

  func deleteAll() async throws {
    try await storage.dataResetRepository().deleteAll()
  }
}
