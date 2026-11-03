// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

// MARK: - ImportPasswordView

struct ImportPasswordView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<ImportPasswordFeature>

  // MARK: - Body

  var body: some View {
    content
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Subviews

extension ImportPasswordView {

  private var content: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      passwordField
      buttons
    }
    .padding(24)
    .frame(width: 420)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(.module("Enter Password"))
        .dvFont(.headingLG)
        .foregroundStyle(Color.dv(.gray900))
      Text(store.fileName)
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray500))
    }
  }

  private var passwordField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(.module("Password"))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray700))
      DVTextField(
        "",
        text: passwordBinding,
        size: .md,
        isSecure: true,
        errorMessage: store.isWrongPassword ? String.module("Incorrect password. Please try again.") : nil,
        reservesErrorSpace: true
      )
      .dvShake(trigger: store.shakeCount)
      .disabled(store.isDecrypting)
      .onSubmit { store.send(.didTapUnlock) }
    }
  }

  private var buttons: some View {
    HStack(spacing: 12) {
      Spacer()
      DVButton(titleText: .module("Cancel"), style: .secondary) {
        store.send(.didTapCancel)
      }
      .keyboardShortcut(.cancelAction)

      DVButton(titleText: .module("Unlock"), style: .secondaryProminent) {
        store.send(.didTapUnlock)
      }
      .keyboardShortcut(.defaultAction)
      .disabled(store.password.isEmpty || store.isDecrypting)
    }
  }

  private var passwordBinding: Binding<String> {
    Binding(
      get: { store.password },
      set: { store.send(.didChangePassword($0)) }
    )
  }
}

// MARK: - Preview

#if DEBUG

#Preview("Enter Password") {
  ImportPasswordView(
    store: Store(initialState: ImportPasswordFeature.State(fileName: "AWS-Keys.devault", data: Data())) {
      ImportPasswordFeature()
    } withDependencies: {
      $0.shareClient = .previewValue
    }
  )
}

#Preview("Wrong Password") {
  var state = ImportPasswordFeature.State(fileName: "AWS-Keys.devault", data: Data())
  state.isWrongPassword = true
  return ImportPasswordView(
    store: Store(initialState: state) {
      ImportPasswordFeature()
    } withDependencies: {
      $0.shareClient = .previewValue
    }
  )
}

#Preview("Always Wrong") {
  ImportPasswordView(
    store: Store(initialState: ImportPasswordFeature.State(fileName: "AWS-Keys.devault", data: Data())) {
      ImportPasswordFeature()
    } withDependencies: {
      $0.shareClient = .previewValue
      $0.shareClient.decryptContainer = { _, _ in throw DevaultImportError.invalidPassword }
    }
  )
}

#endif
