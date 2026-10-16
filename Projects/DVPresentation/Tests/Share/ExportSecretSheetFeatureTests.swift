// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ExportSecretSheetFeature")
struct ExportSecretSheetFeatureTests {

  @Test("didTapExport는 비밀번호가 10자 미만이면 거절한다")
  func exportRejectsTooShortPassword() async {
    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [])) {
      ExportSecretSheetFeature()
    }

    await store.send(.didChangePassword("short")) { $0.password = "short" }
    await store.send(.didTapExport) {
      $0.passwordError = String.module("Password must be 10–64 characters.")
    }
  }

  @Test("didTapExport는 비밀번호가 64자를 넘으면 거절한다")
  func exportRejectsTooLongPassword() async {
    let tooLong = String(repeating: "a", count: 65)
    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [])) {
      ExportSecretSheetFeature()
    }

    await store.send(.didChangePassword(tooLong)) { $0.password = tooLong }
    await store.send(.didTapExport) {
      $0.passwordError = String.module("Password must be 10–64 characters.")
    }
  }

  @Test("didTapExport는 성공하면 Touch ID 인증 후 delegate로 알리고 dismiss한다")
  func exportSucceedsAndDismisses() async {
    let secretID = UUID()
    let fileURL = URL(fileURLWithPath: "/tmp/preview.dvt")
    var authenticatedReason: AuthenticationReason?
    var didDismiss = false

    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [secretID])) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { reason in authenticatedReason = reason }
      $0.shareClient.exportSecrets = { _, _, _ in fileURL }
      $0.dismiss = DismissEffect { didDismiss = true }
    }

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapExport) { $0.isExporting = true }
    await store.receive(.exportSucceeded(fileURL)) { $0.isExporting = false }
    await store.receive(.delegate(.exportSucceeded(fileURL)))

    #expect(authenticatedReason == .exportSecrets)
    #expect(didDismiss)
  }

  @Test("Touch ID 인증이 실패하면 export 실패 alert를 띄운다")
  func exportFailsWhenAuthenticationFails() async {
    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [])) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in throw CancellationError() }
    }

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapExport) { $0.isExporting = true }
    await store.receive(.exportFailed) {
      $0.isExporting = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't export the secrets."))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please try again in a moment."))
      }
    }
  }

  @Test("didTapCancel은 dismiss한다")
  func cancelDismisses() async {
    var didDismiss = false
    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [])) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect { didDismiss = true }
    }

    await store.send(.didTapCancel)

    #expect(didDismiss)
  }
}
