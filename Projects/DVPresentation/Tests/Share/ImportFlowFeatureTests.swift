// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ImportFlowFeature")
struct ImportFlowFeatureTests {

  private func makeExport(_ name: String) -> DevaultSecretExport {
    DevaultSecretExport(
      name: name,
      content: .accessToken(APIKeyPayload(value: "token"), nil),
      payloadSchemaVersion: 1
    )
  }

  private func makeSecret(_ name: String) -> Secret {
    Secret(
      id: UUID(),
      name: name,
      secretType: .apiKeyToken,
      subType: .accessToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "tag", schemaVersion: 1)
    )
  }

  private func makeState(fileName: String = "Export.dvt", payload: DevaultContainerPayload) -> ImportFlowFeature.State {
    ImportFlowFeature.State(fileName: fileName, payload: payload)
  }

  @Test("중복 없이 proceed하면 Touch ID 인증 후 그 payload·project로 execute하고 imported delegate로 알린다")
  func proceedsWithoutDuplicatesAndExecutes() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let projectID = UUID()
    let secret = makeSecret("A")
    var authenticatedReason: AuthenticationReason?
    var capturedArgs: (payload: DevaultContainerPayload, resolutions: [Int: ImportDuplicateResolution], project: ImportProjectChoice)?

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { reason in authenticatedReason = reason }
      $0.shareClient.importSecrets = { payload, resolutions, project in
        capturedArgs = (payload, resolutions, project)
        return [secret]
      }
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .existing(id: projectID))))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.success) { $0.isExecuting = false }
    await store.receive(\.delegate.imported)

    #expect(authenticatedReason == .importSecrets)
    #expect(capturedArgs?.payload == payload)
    #expect(capturedArgs?.resolutions == [:])
    #expect(capturedArgs?.project == .existing(id: projectID))
  }

  @Test("중복이 있으면 Review Duplicates로 전환하고, resolved되면 그 payload·project·resolutions로 execute한다")
  func duplicatesFoundThenResolvedExecutesWithCapturedArgs() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let projectID = UUID()
    let conflict = ImportDuplicateConflict(
      index: 0,
      name: "A",
      secretType: .apiKeyToken,
      subType: .accessToken,
      target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let secret = makeSecret("A")
    var capturedArgs: (payload: DevaultContainerPayload, resolutions: [Int: ImportDuplicateResolution], project: ImportProjectChoice)?
    let rejudgedResolutions = LockIsolated<[Int: ImportDuplicateResolution]?>(nil)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, resolutions in
        rejudgedResolutions.setValue(resolutions)
        return ImportDuplicateJudgement(totalCount: 1, conflicts: [])
      }
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { payload, resolutions, project in
        capturedArgs = (payload, resolutions, project)
        return [secret]
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .existing(id: projectID))))) {
      $0.pendingPayload = payload
      $0.pendingProject = .existing(id: projectID)
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    await store.send(.reviewDuplicates(.delegate(.resolved([0: .overwrite]))))
    await store.receive(.renameRecheckResponse(.success([]), resolutions: [0: .overwrite], executes: true)) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.success) { $0.isExecuting = false }
    await store.receive(\.delegate.imported)

    #expect(rejudgedResolutions.value == [0: .overwrite])
    #expect(capturedArgs?.payload == payload)
    #expect(capturedArgs?.resolutions == [0: .overwrite])
    #expect(capturedArgs?.project == .existing(id: projectID))
  }

  @Test("바꾼 이름이 또 겹치면 execute하지 않고 Review Duplicates에 충돌을 돌려준다")
  func renameStillConflictingReturnsToReviewWithoutExecuting() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let importCalled = LockIsolated(false)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      // 바꾼 이름(A (1))이 금고에 이미 있어 재판정에서도 같은 항목이 충돌한다.
      $0.shareClient.judgeDuplicates = { _, _ in judgement }
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { _, _, _ in
        importCalled.setValue(true)
        return []
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    let resolutions: [Int: ImportDuplicateResolution] = [0: .rename("A (1)")]
    await store.send(.reviewDuplicates(.delegate(.resolved(resolutions))))
    await store.receive(.renameRecheckResponse(.success([0]), resolutions: resolutions, executes: true))
    await store.receive(.reviewDuplicates(.renameConflictsFound([0]))) {
      $0.reviewDuplicates?.renameConflicts = [0]
      $0.reviewDuplicates?.shakeCount = 1
    }

    #expect(!importCalled.value)
    #expect(!store.state.isExecuting)
  }

  @Test("재판정이 실패하면 execute하지 않고 실패 alert를 띄운다")
  func rejudgeFailureShowsAlertWithoutExecuting() async {
    struct SomeError: Error {}
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let importCalled = LockIsolated(false)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in throw SomeError() }
      $0.shareClient.importSecrets = { _, _, _ in
        importCalled.setValue(true)
        return []
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    await store.send(.reviewDuplicates(.delegate(.resolved([0: .overwrite]))))
    await store.receive(.renameRecheckResponse(.failure(ImportFlowFeature.ExecuteError(SomeError())), resolutions: [0: .overwrite], executes: true)) {
      $0.alert = AlertState {
        TextState(String.module("Couldn't Import Secrets"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
    await store.receive(.reviewDuplicates(.checkEnded))

    #expect(!importCalled.value)
  }

  @Test("Next에서 이름이 겹치지 않으면 execute 없이 통과 신호만 보낸다")
  func nextCheckPassesWithoutExecuting() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let importCalled = LockIsolated(false)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: []) }
      $0.shareClient.importSecrets = { _, _, _ in
        importCalled.setValue(true)
        return []
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    let resolutions: [Int: ImportDuplicateResolution] = [0: .rename("A (1)")]
    await store.send(.reviewDuplicates(.delegate(.renameCheckRequested(resolutions))))
    await store.receive(.renameRecheckResponse(.success([]), resolutions: resolutions, executes: false))
    await store.receive(.reviewDuplicates(.renameCheckPassed))

    #expect(!importCalled.value)
    #expect(!store.state.isExecuting)
  }

  @Test("Next에서 이름이 겹치면 execute 없이 충돌 칸을 돌려준다")
  func nextCheckReturnsConflictWithoutExecuting() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let importCalled = LockIsolated(false)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in judgement }
      $0.shareClient.importSecrets = { _, _, _ in
        importCalled.setValue(true)
        return []
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    let resolutions: [Int: ImportDuplicateResolution] = [0: .rename("A (1)")]
    await store.send(.reviewDuplicates(.delegate(.renameCheckRequested(resolutions))))
    await store.receive(.renameRecheckResponse(.success([0]), resolutions: resolutions, executes: false))
    await store.receive(.reviewDuplicates(.renameConflictsFound([0]))) {
      $0.reviewDuplicates?.renameConflicts = [0]
      $0.reviewDuplicates?.shakeCount = 1
    }

    #expect(!importCalled.value)
  }

  @Test("Review Duplicates에서 뒤로 가면 Preview가 살아있던 선택·프로젝트 선택 그대로 다시 보인다")
  func cancellingReviewDuplicatesRestoresUntouchedPreview() async {
    // 6개 중 4개만 고른 뒤 중복 때문에 Review로 넘어간 상황을 흉내낸다 — 뒤로 가면 그 4개
    // 선택과 프로젝트 선택이 유지돼야 한다(새 State로 재구성하면 날아간다).
    let fullPayload = DevaultContainerPayload(
      secrets: [makeExport("A"), makeExport("B"), makeExport("C"), makeExport("D"), makeExport("E"), makeExport("F")]
    )
    var initial = makeState(payload: fullPayload)
    let projectID = UUID()
    initial.preview?.selectedIndices = [0, 1, 2, 3]
    initial.preview?.projectChoice = .existing(id: projectID)
    let preSelection = initial.preview

    let filteredPayload = DevaultContainerPayload(
      secrets: [makeExport("A"), makeExport("B"), makeExport("C"), makeExport("D")]
    )
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 4, conflicts: [conflict])

    let store = TestStore(initialState: initial) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: filteredPayload, judgement: judgement, project: .existing(id: projectID))))) {
      $0.pendingPayload = filteredPayload
      $0.pendingProject = .existing(id: projectID)
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    await store.send(.reviewDuplicates(.delegate(.cancelled))) {
      $0.reviewDuplicates = nil
      $0.pendingPayload = nil
      $0.pendingProject = nil
    }

    #expect(store.state.preview == preSelection)
  }

  @Test("execute 중에 다시 execute 요청이 오면 무시한다 — 연타로 Touch ID가 두 번 뜨지 않는다")
  func doubleExecuteIsIgnoredWhileInFlight() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    var state = makeState(payload: payload)
    state.isExecuting = true

    let store = TestStore(initialState: state) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .none))))
  }

  @Test("execute가 EntitlementError를 던지면 paywallRequired delegate로 상향한다")
  func executeFailureWithEntitlementErrorRequestsPaywall() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { _, _, _ in throw EntitlementError.limitReached }
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .none)))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.failure) { $0.isExecuting = false }
    await store.receive(\.delegate.paywallRequired)
  }

  @Test("execute가 일반 오류를 던지면 alert를 띄운다")
  func executeFailureWithOtherErrorShowsAlert() async {
    struct SomeError: Error {}
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { _, _, _ in throw SomeError() }
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .none)))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.failure) {
      $0.isExecuting = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't Import Secrets"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
  }

  @Test("Touch ID 인증이 취소돼도 같은 실패 alert를 띄운다 — Export와 동일 동작")
  func authenticationCancellationShowsSameFailureAlert() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in throw UserAuthenticationError.cancelled }
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .none)))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.failure) {
      $0.isExecuting = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't Import Secrets"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
  }

  @Test("중복 검토에서 Done 뒤 가져오기가 실패하면 alert를 띄우고 확인 중 상태를 풀어 선택을 유지한다")
  func executeFailureAfterDoneReleasesReviewDuplicates() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.judgeDuplicates = { _, _ in ImportDuplicateJudgement(totalCount: 1, conflicts: []) }
      $0.shareClient.authenticate = { _ in throw UserAuthenticationError.cancelled }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    // Done: 확인 중으로 바뀌고 재판정 → 인증 단계에서 실패한다.
    await store.send(.reviewDuplicates(.didTapNext)) {
      $0.reviewDuplicates?.isChecking = true
    }
    await store.receive(.reviewDuplicates(.delegate(.resolved([0: .overwrite]))))
    await store.receive(.renameRecheckResponse(.success([]), resolutions: [0: .overwrite], executes: true)) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.failure) {
      $0.isExecuting = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't Import Secrets"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
    await store.receive(.reviewDuplicates(.checkEnded)) {
      $0.reviewDuplicates?.isChecking = false
    }

    #expect(store.state.reviewDuplicates?.resolutions == [0: .overwrite])
  }

  @Test("재판정 중 Back으로 나가면 진행 중이던 재판정이 취소돼 응답이 오지 않는다")
  func backCancelsInFlightRecheck() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0, name: "A", secretType: .apiKeyToken, subType: .accessToken, target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let clock = TestClock()
    let importCalled = LockIsolated(false)

    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      // 재판정을 붙잡아 둔 채 Back으로 나간다.
      $0.shareClient.judgeDuplicates = { _, _ in
        try await clock.sleep(for: .seconds(1))
        return ImportDuplicateJudgement(totalCount: 1, conflicts: [])
      }
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { _, _, _ in
        importCalled.setValue(true)
        return []
      }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.pendingPayload = payload
      $0.pendingProject = ImportProjectChoice.none
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }
    await store.send(.reviewDuplicates(.didTapNext)) {
      $0.reviewDuplicates?.isChecking = true
    }
    await store.receive(.reviewDuplicates(.delegate(.resolved([0: .overwrite]))))

    await store.send(.reviewDuplicates(.delegate(.cancelled))) {
      $0.reviewDuplicates = nil
      $0.pendingPayload = nil
      $0.pendingProject = nil
    }

    // 취소됐다면 아무 액션도 오지 않는다 — 오면 TestStore가 처리되지 않은 액션으로 실패시킨다.
    await clock.advance(by: .seconds(1))
    #expect(!importCalled.value)
  }

  @Test("Preview가 cancelled를 올리면 그대로 상향한다")
  func previewCancelledPassesThrough() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.cancelled)))
    await store.receive(\.delegate.cancelled)
  }

  @Test("Preview가 paywallRequired를 올리면 그대로 상향한다")
  func previewPaywallRequiredPassesThrough() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: makeState(payload: payload)) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.paywallRequired)))
    await store.receive(\.delegate.paywallRequired)
  }
}
