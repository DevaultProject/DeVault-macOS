// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - ExportSecretSheetFeature

@Reducer
public struct ExportSecretSheetFeature {

  /// 비밀번호 강도는 조합 강제 없이 길이만 본다 — 공백 포함 패스프레이즈를 허용한다.
  static let passwordLengthRange = 10...64

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public let secretIDs: [Secret.ID]
    public internal(set) var password = ""
    public internal(set) var expiryOption: ExportExpiryOption = .oneHour
    public internal(set) var isExporting = false
    public internal(set) var passwordError: String?
    @Presents var alert: AlertState<Action.Alert>?

    public init(secretIDs: [Secret.ID]) {
      self.secretIDs = secretIDs
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case didChangePassword(String)
    case didChangeExpiryOption(ExportExpiryOption)
    case didTapExport
    case didTapCancel

    // MARK: - Internal

    case exportSucceeded(URL)
    case exportFailed

    // MARK: - Child

    case alert(PresentationAction<Alert>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case exportSucceeded(URL)
    }

    public enum Alert: Equatable {}
  }

  // MARK: - Dependencies

  @Dependency(\.shareClient) var shareClient
  @Dependency(\.dismiss) var dismiss

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .didChangePassword(let password):
        state.password = password
        state.passwordError = nil
        return .none

      case .didChangeExpiryOption(let option):
        state.expiryOption = option
        return .none

      case .didTapExport:
        guard Self.passwordLengthRange.contains(state.password.count) else {
          state.passwordError = String.module("Password must be 10–64 characters.")
          return .none
        }
        state.passwordError = nil
        state.isExporting = true
        return .run { [secretIDs = state.secretIDs, password = state.password, expiresAt = state.expiryOption.expiresAt()] send in
          do {
            try await shareClient.authenticate(.exportSecrets)
            let url = try await shareClient.exportSecrets(secretIDs, password, expiresAt)
            await send(.exportSucceeded(url))
          } catch {
            await send(.exportFailed)
          }
        }

      case .exportSucceeded(let url):
        state.isExporting = false
        // dismiss를 먼저 끝내야 한다 — delegate가 부모에서 다른 시트(Export Complete)를 여는데,
        // 이 시트가 아직 닫히기 전에 열리면 두 .sheet(item:)가 겹쳐 뜨는 경합이 생긴다.
        return .run { send in
          await dismiss()
          await send(.delegate(.exportSucceeded(url)))
        }

      case .exportFailed:
        state.isExporting = false
        state.alert = exportFailureAlert
        return .none

      case .didTapCancel:
        return .run { _ in await dismiss() }

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Private

private extension ExportSecretSheetFeature {

  var exportFailureAlert: AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't export the secrets."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }
}
