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

  @Test("중복 없이 proceed하면 Touch ID 인증 후 execute하고 imported delegate로 알린다")
  func proceedsWithoutDuplicatesAndExecutes() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let secret = makeSecret("A")
    var authenticatedReason: AuthenticationReason?

    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { reason in authenticatedReason = reason }
      $0.shareClient.importSecrets = { _, _, _ in [secret] }
    }

    await store.send(.preview(.delegate(.proceedWithoutDuplicates(payload: payload, project: .none)))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.success) { $0.isExecuting = false }
    await store.receive(\.delegate.imported)

    #expect(authenticatedReason == .importSecrets)
  }

  @Test("중복이 있으면 Review Duplicates로 전환하고, 거기서 resolved되면 execute한다")
  func duplicatesFoundThenResolvedExecutes() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0,
      name: "A",
      secretType: .apiKeyToken,
      subType: .accessToken,
      target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])
    let secret = makeSecret("A")

    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
      ImportFlowFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in }
      $0.shareClient.importSecrets = { _, _, _ in [secret] }
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.preview = nil
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    await store.send(.reviewDuplicates(.delegate(.resolved([0: .overwrite])))) {
      $0.isExecuting = true
    }
    await store.receive(\.executeResponse.success) { $0.isExecuting = false }
    await store.receive(\.delegate.imported)
  }

  @Test("Review Duplicates에서 뒤로 가면 Preview로 되돌아간다")
  func cancellingReviewDuplicatesReturnsToPreview() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let conflict = ImportDuplicateConflict(
      index: 0,
      name: "A",
      secretType: .apiKeyToken,
      subType: .accessToken,
      target: .existingSecret(id: UUID())
    )
    let judgement = ImportDuplicateJudgement(totalCount: 1, conflicts: [conflict])

    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: .none)))) {
      $0.preview = nil
      $0.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
    }

    await store.send(.reviewDuplicates(.delegate(.cancelled))) {
      $0.reviewDuplicates = nil
      $0.preview = ImportPreviewFeature.State(payload: payload)
    }
  }

  @Test("execute가 EntitlementError를 던지면 paywallRequired delegate로 상향한다")
  func executeFailureWithEntitlementErrorRequestsPaywall() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])

    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
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

    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
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
        TextState(String.module("Couldn't import the secrets."))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
  }

  @Test("Preview가 cancelled/paywallRequired를 올리면 그대로 상향한다")
  func previewDelegatesPassThrough() async {
    let payload = DevaultContainerPayload(secrets: [makeExport("A")])
    let store = TestStore(initialState: ImportFlowFeature.State(payload: payload)) {
      ImportFlowFeature()
    }

    await store.send(.preview(.delegate(.cancelled)))
    await store.receive(\.delegate.cancelled)
  }
}
