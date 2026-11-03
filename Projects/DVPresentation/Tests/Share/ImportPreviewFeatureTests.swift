// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ImportPreviewFeature")
struct ImportPreviewFeatureTests {

  private func makeExport(_ name: String) -> DevaultSecretExport {
    DevaultSecretExport(
      name: name,
      content: .accessToken(APIKeyPayload(value: "token"), nil),
      payloadSchemaVersion: 1
    )
  }

  @Test("단일 payload는 Single 변형이고 전부 선택된 채 시작한다")
  func singleVariantStartsFullySelected() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let state = ImportPreviewFeature.State(payload: payload)

    #expect(state.variant == .single)
    #expect(state.selectedIndices == [0])
  }

  @Test("projectName이 있으면 Project 변형이고, 없으면 Multiple 변형이다")
  func variantDependsOnProjectName() async {
    let withProject = ImportPreviewFeature.State(
      payload: DevaultContainerPayload(projectName: "DrinkiG", secrets: [makeExport("A"), makeExport("B")])
    )
    #expect(withProject.variant == .project(name: "DrinkiG"))
    #expect(withProject.showsProjectSelection)

    let withoutProject = ImportPreviewFeature.State(
      payload: DevaultContainerPayload(secrets: [makeExport("A"), makeExport("B")])
    )
    #expect(withoutProject.variant == .multiple)
    #expect(!withoutProject.showsProjectSelection)
  }

  @Test("같은 이름의 프로젝트가 이미 있으면 Merge를 기본 선택한다")
  func defaultsToMergeWhenProjectExists() async {
    let existingID = UUID()
    let payload = DevaultContainerPayload(projectName: "DrinkiG", secrets: [makeExport("A"), makeExport("B")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.projectClient.fetchProjects = { [Project(id: existingID, name: "DrinkiG", createdAt: Date(), updatedAt: Date())] }
      $0.entitlementClient.remainingSecretSlots = { nil }
      $0.entitlementClient.canCreateProject = { true }
      $0.shareClient.judgeDuplicates = { filtered, _ in ImportDuplicateJudgement(totalCount: filtered.secrets.count, conflicts: []) }
    }

    await store.send(.task)
    await store.receive(\.projectsResponse.success) {
      $0.availableProjects = [Project(id: existingID, name: "DrinkiG", createdAt: Date(), updatedAt: Date())]
      $0.projectChoice = .existing(id: existingID)
    }
    await store.receive(\.slotsResponse)
    await store.receive(\.canCreateProjectResponse)
    await store.receive(\.judgementResponse)
  }

  @Test("프로젝트를 새로 못 만들면 Create new 기본 선택을 Without project로 내린다")
  func fallsBackWhenCreateProjectBlocked() async {
    let payload = DevaultContainerPayload(projectName: "NewProject", secrets: [makeExport("A")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.projectClient.fetchProjects = { [] }
      $0.entitlementClient.remainingSecretSlots = { nil }
      $0.entitlementClient.canCreateProject = { false }
      $0.shareClient.judgeDuplicates = { filtered, _ in ImportDuplicateJudgement(totalCount: filtered.secrets.count, conflicts: []) }
    }

    #expect(store.state.projectChoice == .create(name: "NewProject"))

    await store.send(.task)
    await store.receive(\.projectsResponse.success) { $0.availableProjects = [] }
    await store.receive(\.slotsResponse)
    await store.receive(\.canCreateProjectResponse) {
      $0.canCreateNewProject = false
      $0.projectChoice = .none
    }
    await store.receive(\.judgementResponse)
  }

  @Test("didToggleSelectAll은 전부 선택되어 있으면 전부 해제하고, 아니면 전부 선택한다")
  func toggleSelectAll() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A"), makeExport("B")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 0, conflicts: []) }
    }

    await store.send(.didToggleSelectAll) { $0.selectedIndices = [] }
    await store.send(.didToggleSelectAll) { $0.selectedIndices = [0, 1] }
    await store.receive(\.judgementResponse)
  }

  @Test("didTapImport — 중복이 없으면 proceedWithoutDuplicates delegate")
  func importWithoutConflictsProceeds() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { filtered, _ in
        ImportDuplicateJudgement(totalCount: filtered.secrets.count, conflicts: [])
      }
      $0.entitlementClient.canImportSecrets = { _ in true }
    }

    await store.send(.didTapImport)
    await store.receive(\.delegate.proceedWithoutDuplicates)
  }

  @Test("didTapImport — 중복이 있으면 duplicatesFound delegate")
  func importWithConflictsRoutesToReviewDuplicates() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0,
      name: "A",
      secretType: .apiKeyToken,
      subType: .accessToken,
      target: .existingSecret(id: UUID())
    )
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict]) }
      $0.entitlementClient.canImportSecrets = { _ in true }
    }

    await store.send(.didTapImport)
    await store.receive(\.delegate.duplicatesFound)
  }

  @Test("didTapImport — 게이트①을 막으면 paywallRequired delegate")
  func importBlockedByGateSendsPaywall() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: []) }
      $0.entitlementClient.canImportSecrets = { _ in false }
    }

    await store.send(.didTapImport)
    await store.receive(\.delegate.paywallRequired)
  }

  @Test("didTapCancel은 cancelled delegate로 알린다")
  func cancelSendsDelegate() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: ImportPreviewFeature.State(payload: payload)) {
      ImportPreviewFeature()
    }

    await store.send(.didTapCancel)
    await store.receive(\.delegate.cancelled)
  }
}
