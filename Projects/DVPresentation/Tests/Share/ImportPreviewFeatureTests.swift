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

  private func makeState(fileName: String = "Export.dvt", payload: DevaultContainerPayload) -> ImportPreviewFeature.State {
    ImportPreviewFeature.State(fileName: fileName, payload: payload)
  }

  @Test("시크릿이 하나면 출처가 프로젝트든 아니든 Single 변형이고 전부 선택된 채 시작한다")
  func singleVariantTakesPrecedenceOverProjectName() async {
    let withoutProject = makeState(payload: DevaultContainerPayload(secrets: [makeExport("A")]))
    #expect(withoutProject.variant == .single)
    #expect(withoutProject.selectedIndices == [0])

    // 멀티선택 Export가 우연히 같은 프로젝트 하나로 좁혀져도(#201) 시크릿 1개면 Single이다.
    let withProject = makeState(payload: DevaultContainerPayload(projectName: "DrinkiG", secrets: [makeExport("A")]))
    #expect(withProject.variant == .single)
  }

  @Test("시크릿이 여럿이면 projectName 유무로 Project/Multiple을 가른다")
  func variantDependsOnProjectNameWhenMultiple() async {
    let withProject = makeState(
      payload: DevaultContainerPayload(projectName: "DrinkiG", secrets: [makeExport("A"), makeExport("B")])
    )
    #expect(withProject.variant == .project(name: "DrinkiG"))
    #expect(withProject.showsProjectSelection)

    let withoutProject = makeState(payload: DevaultContainerPayload(secrets: [makeExport("A"), makeExport("B")]))
    #expect(withoutProject.variant == .multiple)
    #expect(!withoutProject.showsProjectSelection)
  }

  @Test("같은 이름의 프로젝트가 대소문자만 다르게 있어도 Merge를 기본 선택한다")
  func defaultsToMergeWhenProjectExistsCaseInsensitively() async {
    let existingID = UUID()
    let payload = DevaultContainerPayload(projectName: "DrinkiG", secrets: [makeExport("A"), makeExport("B")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      // 저장된 쪽은 소문자 "drinkig" — 대소문자 구분 비교였다면 못 찾아 Create new로 남았을 것.
      $0.projectClient.fetchProjects = { [Project(id: existingID, name: "drinkig", createdAt: Date(), updatedAt: Date())] }
      $0.entitlementClient.remainingSecretSlots = { nil }
      $0.entitlementClient.canCreateProject = { true }
      $0.shareClient.judgeDuplicates = { filtered, _ in ImportDuplicateJudgement(totalCount: filtered.secrets.count, conflicts: []) }
    }

    await store.send(.task)
    await store.receive(\.projectsResponse.success) {
      $0.availableProjects = [Project(id: existingID, name: "drinkig", createdAt: Date(), updatedAt: Date())]
      $0.projectChoice = .existing(id: existingID)
    }
    await store.receive(\.slotsResponse)
    await store.receive(\.canCreateProjectResponse)
    await store.receive(\.judgementResponse)
  }

  @Test("프로젝트를 새로 못 만들면 Create new 기본 선택을 Without project로 내린다")
  func fallsBackWhenCreateProjectBlocked() async {
    let payload = DevaultContainerPayload(projectName: "NewProject", secrets: [makeExport("A"), makeExport("B")])
    let store = TestStore(initialState: makeState(payload: payload)) {
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
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 0, conflicts: []) }
    }

    await store.send(.didToggleSelectAll) { $0.selectedIndices = [] }
    await store.send(.didToggleSelectAll) { $0.selectedIndices = [0, 1] }
    await store.receive(\.judgementResponse)
  }

  @Test("선택이 전부 해제되면 남아있던 Duplicated 표시도 비운다")
  func clearsDuplicateIndicesWhenSelectionBecomesEmpty() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    var state = makeState(payload: payload)
    state.duplicateIndices = [0]

    let store = TestStore(initialState: state) {
      ImportPreviewFeature()
    }

    await store.send(.didToggleSelection(index: 0)) {
      $0.selectedIndices = []
      $0.duplicateIndices = []
    }
  }

  @Test("judgementResponse는 필터링된 payload 기준 인덱스를 원본 인덱스로 되돌린다")
  func judgementResponseMapsFilteredIndexBackToOriginal() async {
    // B를 선택 해제하면 필터링된 payload는 [A, C]가 되어, 그 안의 index 1(C)은 원본에서는 index 2다.
    let payload = DevaultContainerPayload(secrets: [makeExport("A"), makeExport("B"), makeExport("C")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { filtered, _ in
        #expect(filtered.secrets.map(\.name) == ["A", "C"])
        let conflict = ImportDuplicateConflict(
          index: 1,
          name: "C",
          secretType: .apiKeyToken,
          subType: .accessToken,
          target: .existingSecret(id: UUID())
        )
        return ImportDuplicateJudgement(totalCount: 2, conflicts: [conflict])
      }
    }

    await store.send(.didToggleSelection(index: 1)) { $0.selectedIndices = [0, 2] }
    await store.receive(\.judgementResponse) { $0.duplicateIndices = [2] }
  }

  @Test("didTapImport — 중복이 없으면 게이트①을 보고 proceedWithoutDuplicates delegate")
  func importWithoutConflictsChecksGateThenProceeds() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    var checkedCount: Int?
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { filtered, _ in
        ImportDuplicateJudgement(totalCount: filtered.secrets.count, conflicts: [])
      }
      $0.entitlementClient.canImportSecrets = { count in
        checkedCount = count
        return true
      }
    }

    await store.send(.didTapImport) { $0.isCheckingImport = true }
    await store.receive(\.importCheckResponse.success) { $0.isCheckingImport = false }
    await store.receive(\.delegate.proceedWithoutDuplicates)

    #expect(checkedCount == 1)
  }

  @Test("didTapImport — 중복이 있으면 게이트①을 건너뛰고 바로 duplicatesFound delegate")
  func importWithConflictsSkipsGateAndRoutesToReviewDuplicates() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0,
      name: "A",
      secretType: .apiKeyToken,
      subType: .accessToken,
      target: .existingSecret(id: UUID())
    )
    var gateChecked = false
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict]) }
      $0.entitlementClient.canImportSecrets = { _ in
        gateChecked = true
        return true
      }
    }

    await store.send(.didTapImport) { $0.isCheckingImport = true }
    await store.receive(\.importCheckResponse.success) { $0.isCheckingImport = false }
    await store.receive(\.delegate.duplicatesFound)

    #expect(!gateChecked)
  }

  @Test("didTapImport — 게이트①을 막으면 paywallRequired delegate")
  func importBlockedByGateSendsPaywall() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: []) }
      $0.entitlementClient.canImportSecrets = { _ in false }
    }

    await store.send(.didTapImport) { $0.isCheckingImport = true }
    await store.receive(\.importCheckResponse.success) { $0.isCheckingImport = false }
    await store.receive(\.delegate.paywallRequired)
  }

  @Test("didTapImport — judgeDuplicates가 실패하면 alert를 띄운다")
  func importCheckFailureShowsAlert() async {
    struct SomeError: Error {}
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in throw SomeError() }
    }

    await store.send(.didTapImport) { $0.isCheckingImport = true }
    await store.receive(\.importCheckResponse.failure) {
      $0.isCheckingImport = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't Check Secrets"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
  }

  @Test("didTapImport 연타는 이미 확인 중이면 무시된다")
  func doubleTapIsIgnoredWhileChecking() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    var state = makeState(payload: payload)
    state.isCheckingImport = true

    let store = TestStore(initialState: state) {
      ImportPreviewFeature()
    }

    await store.send(.didTapImport)
  }

  @Test("didTapCancel은 cancelled delegate로 알린다")
  func cancelSendsDelegate() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportPreviewFeature()
    }

    await store.send(.didTapCancel)
    await store.receive(\.delegate.cancelled)
  }
}
