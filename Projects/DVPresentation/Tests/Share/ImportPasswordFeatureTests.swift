// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ImportPasswordFeature")
struct ImportPasswordFeatureTests {

  private func makeStore(
    decrypt: @escaping @Sendable (Data, String) async throws -> DevaultContainerPayload = { _, _ in
      DevaultContainerPayload(secrets: [])
    }
  ) -> TestStoreOf<ImportPasswordFeature> {
    TestStore(initialState: ImportPasswordFeature.State(fileName: "AWS-Keys.devault", data: Data("file".utf8))) {
      ImportPasswordFeature()
    } withDependencies: {
      $0.shareClient.decryptContainer = decrypt
    }
  }

  @Test("비밀번호가 비어 있으면 Unlock은 아무 일도 하지 않는다")
  func unlockDoesNothingWhenPasswordEmpty() async {
    let store = makeStore()

    await store.send(.didTapUnlock)
  }

  @Test("성공하면 payload를 delegate로 알리고 비밀번호를 비운다 — dismiss는 부모가 한다")
  func unlockSucceedsNotifiesDelegate() async {
    let payload = DevaultContainerPayload(secrets: [])
    let store = makeStore(decrypt: { _, _ in payload })

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptSucceeded(payload)) {
      $0.isDecrypting = false
      $0.password = ""
    }
    await store.receive(.delegate(.decrypted(payload)))
  }

  @Test("틀린 비밀번호면 에러 상태로 두고 흔들며 입력은 그대로 둔다")
  func wrongPasswordShakesAndKeepsInput() async {
    let store = makeStore(decrypt: { _, _ in throw DevaultImportError.invalidPassword })

    await store.send(.didChangePassword("wrong")) { $0.password = "wrong" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptFailed(.invalidPassword)) {
      $0.isDecrypting = false
      $0.isWrongPassword = true
      $0.shakeCount = 1
    }
  }

  @Test("틀린 뒤 입력을 바꾸면 에러가 사라진다")
  func editingClearsWrongPasswordState() async {
    let store = makeStore(decrypt: { _, _ in throw DevaultImportError.invalidPassword })

    await store.send(.didChangePassword("wrong")) { $0.password = "wrong" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptFailed(.invalidPassword)) {
      $0.isDecrypting = false
      $0.isWrongPassword = true
      $0.shakeCount = 1
    }
    await store.send(.didChangePassword("wrong2")) {
      $0.password = "wrong2"
      $0.isWrongPassword = false
    }
  }

  @Test("에러가 떠 있는 채로 Unlock을 다시 누르면 복호화 없이 흔들기만 한다")
  func unlockAgainWhileWrongOnlyShakes() async {
    let calls = LockIsolated(0)
    let store = makeStore(decrypt: { _, _ in
      calls.withValue { $0 += 1 }
      throw DevaultImportError.invalidPassword
    })

    await store.send(.didChangePassword("wrong")) { $0.password = "wrong" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptFailed(.invalidPassword)) {
      $0.isDecrypting = false
      $0.isWrongPassword = true
      $0.shakeCount = 1
    }
    await store.send(.didTapUnlock) { $0.shakeCount = 2 }

    #expect(calls.value == 1)
  }

  @Test("손상·버전·만료는 알럿을 띄우고 확인하면 거절을 delegate로 알린다",
        arguments: [DevaultImportError.corrupted, .versionMismatch, .expired])
  func rejectionShowsAlertThenNotifiesDelegate(error: DevaultImportError) async {
    let store = makeStore(decrypt: { _, _ in throw error })

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptFailed(error)) {
      $0.isDecrypting = false
      $0.rejection = error
      $0.alert = Self.expectedAlert(for: error)
    }
    await store.send(.alert(.presented(.didConfirm))) {
      $0.alert = nil
      $0.rejection = nil
    }
    await store.receive(.delegate(.rejected(error)))
  }

  @Test("알럿을 버튼 없이 닫아도 거절을 알린다")
  func dismissingAlertAlsoNotifies() async {
    let store = makeStore(decrypt: { _, _ in throw DevaultImportError.expired })

    await store.send(.didChangePassword("passphrase")) { $0.password = "passphrase" }
    await store.send(.didTapUnlock) { $0.isDecrypting = true }
    await store.receive(.decryptFailed(.expired)) {
      $0.isDecrypting = false
      $0.rejection = .expired
      $0.alert = Self.expectedAlert(for: .expired)
    }
    await store.send(.alert(.dismiss)) {
      $0.alert = nil
      $0.rejection = nil
    }
    await store.receive(.delegate(.rejected(.expired)))
  }

  private static func expectedAlert(for error: DevaultImportError) -> AlertState<ImportPasswordFeature.Action.Alert> {
    let title: String
    let message: String
    switch error {
    case .versionMismatch:
      title = String.module("Unsupported File Version")
      message = String.module("This file requires a newer version of DeVault. Please update the app and try again.")
    case .expired:
      title = String.module("File Expired")
      message = String.module("This file has expired and can no longer be opened. Ask the sender to share it again.")
    case .corrupted, .invalidPassword:
      title = String.module("File Corrupted")
      message = String.module("This file appears to be damaged or tampered with and can't be opened.")
    }
    return AlertState {
      TextState(title)
    } actions: {
      ButtonState(action: .didConfirm) { TextState(String.module("OK")) }
    } message: {
      TextState(message)
    }
  }
}
