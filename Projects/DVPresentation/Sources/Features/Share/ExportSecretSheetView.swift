// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign

// MARK: - ExportSecretSheetView

struct ExportSecretSheetView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<ExportSecretSheetFeature>

  // MARK: - Body

  var body: some View {
    content
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Subviews

extension ExportSecretSheetView {

  private var content: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(.module("Export Secrets"))
        .dvFont(.bodyLG)
        .foregroundStyle(Color.dv(.gray900))

      VStack(alignment: .leading, spacing: 8) {
        Text(.module("Password"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray700))
        DVTextField(.module("10–64 characters"), text: passwordBinding, size: .md, isSecure: true)
          .onSubmit { store.send(.didTapExport) }
        if let passwordError = store.passwordError {
          Text(passwordError)
            .dvFont(.captionMDRegular)
            .foregroundStyle(Color.dv(.danger))
        }
      }

      HStack {
        Text(.module("Expires in"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray700))
        Spacer()
        Picker(String.module("Expires in"), selection: expiryBinding) {
          ForEach(ExportExpiryOption.allCases, id: \.self) { option in
            Text(option.displayName).tag(option)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }

      HStack(spacing: 10) {
        Spacer()
        DVButton(titleText: .module("Cancel"), style: .secondary) {
          store.send(.didTapCancel)
        }
        .keyboardShortcut(.cancelAction)

        DVButton(titleText: .module("Export"), style: .secondaryProminent) {
          store.send(.didTapExport)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(store.isExporting)
      }
    }
    .padding(20)
    .frame(width: 420)
  }

  private var passwordBinding: Binding<String> {
    Binding(
      get: { store.password },
      set: { store.send(.didChangePassword($0)) }
    )
  }

  private var expiryBinding: Binding<ExportExpiryOption> {
    Binding(
      get: { store.expiryOption },
      set: { store.send(.didChangeExpiryOption($0)) }
    )
  }
}

// MARK: - Preview

#if DEBUG

#Preview {
  ExportSecretSheetView(
    store: Store(initialState: ExportSecretSheetFeature.State(secretIDs: [])) {
      ExportSecretSheetFeature()
    } withDependencies: {
      $0.shareClient = .previewValue
    }
  )
}

#endif
