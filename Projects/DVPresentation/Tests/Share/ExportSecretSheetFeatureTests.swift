// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ExportSecretSheetFeature")
struct ExportSecretSheetFeatureTests {

  @Test("내보내기 대상은 기본이 시크릿이고 프로젝트로 지정할 수 있다 — 시트 제목을 가른다")
  func targetDefaultsToSecretsAndCanBeProject() {
    #expect(ExportSecretSheetFeature.State(secretIDs: []).target == .secrets)
    #expect(ExportSecretSheetFeature.State(secretIDs: [], target: .project).target == .project)
  }

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

  // 비밀번호 필드 onSubmit(Enter)과 버튼 클릭이 거의 동시에 들어오면 isExporting이 뷰에 반영되기
  // 전에 두 번 다 리듀서를 탈 수 있다 — 두 번째 exportSucceeded가 이미 닫힌 상태로 부모에 도착해
  // TCA ifLet 경고로 이어진다.
  @Test("didTapExport 연타는 이미 내보내는 중이면 무시된다")
  func doubleTapIsIgnoredWhileExporting() async {
    var state = ExportSecretSheetFeature.State(secretIDs: [])
    state.password = "a-valid-password"
    state.isExporting = true

    let store = TestStore(initialState: state) {
      ExportSecretSheetFeature()
    }

    await store.send(.didTapExport)
  }

  @Test("didTapExport는 성공하면 Touch ID 인증 후 delegate로 알린다 — dismiss는 부모가 한다")
  func exportSucceedsNotifiesDelegate() async {
    let secretID = UUID()
    let fileURL = URL(fileURLWithPath: "/tmp/preview.dvt")
    var authenticatedReason: AuthenticationReason?

    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [secretID])) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { reason in authenticatedReason = reason }
      $0.shareClient.exportSecrets = { _, _, _ in fileURL }
    }

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapExport) { $0.isExporting = true }
    await store.receive(.exportSucceeded(fileURL)) { $0.isExporting = false }
    await store.receive(.delegate(.exportSucceeded(fileURL)))

    #expect(authenticatedReason == .exportSecrets)
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
        TextState(String.module("Couldn't Export Secret"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Something went wrong while creating the file. Please try again."))
      }
    }
  }

  @Test("프로젝트 내보내기가 실패하면 프로젝트용 제목의 alert를 띄운다")
  func projectExportFailureAlertUsesProjectTitle() async {
    let store = TestStore(initialState: ExportSecretSheetFeature.State(secretIDs: [], target: .project)) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.shareClient.authenticate = { _ in throw CancellationError() }
    }

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapExport) { $0.isExporting = true }
    await store.receive(.exportFailed) {
      $0.isExporting = false
      $0.alert = AlertState {
        TextState(String.module("Couldn't Export Project"))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Something went wrong while creating the file. Please try again."))
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
