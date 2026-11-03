// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - ImportPasswordFeature

@Reducer
public struct ImportPasswordFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public let fileName: String
    let data: Data
    public internal(set) var password = ""
    public internal(set) var isDecrypting = false
    public internal(set) var isWrongPassword = false
    public internal(set) var shakeCount = 0
    var rejection: DevaultImportError?
    @Presents var alert: AlertState<Action.Alert>?

    public init(fileName: String, data: Data) {
      self.fileName = fileName
      self.data = data
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case didChangePassword(String)
    case didTapUnlock
    case didTapCancel

    // MARK: - Internal

    case decryptSucceeded(DevaultContainerPayload)
    case decryptFailed(DevaultImportError)

    // MARK: - Child

    case alert(PresentationAction<Alert>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case decrypted(DevaultContainerPayload)
      case rejected(DevaultImportError)
    }

    public enum Alert: Equatable {
      case didConfirm
    }
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
        state.isWrongPassword = false
        return .none

      case .didTapUnlock:
        guard !state.password.isEmpty, !state.isDecrypting else { return .none }
        // 같은 값으로 다시 풀어도 결과가 같으므로 키 유도를 돌리지 않고 거절만 다시 알린다.
        guard !state.isWrongPassword else {
          state.shakeCount += 1
          return .none
        }
        state.isDecrypting = true
        return .run { [data = state.data, password = state.password] send in
          do {
            let payload = try await shareClient.decryptContainer(data, password)
            await send(.decryptSucceeded(payload))
          } catch {
            await send(.decryptFailed(error as? DevaultImportError ?? .corrupted))
          }
        }
        .cancellable(id: CancelID.decrypt)

      case .decryptSucceeded(let payload):
        // dismiss()를 여기서 부르면 이 effect 자체가 취소돼 delegate가 안 나가므로, 부모가 닫는다.
        state.isDecrypting = false
        state.password = ""
        return .send(.delegate(.decrypted(payload)))

      case .decryptFailed(let error):
        state.isDecrypting = false
        if let alert = Self.rejectionAlert(for: error) {
          state.rejection = error
          state.alert = alert
        } else {
          state.isWrongPassword = true
          state.shakeCount += 1
        }
        return .none

      case .didTapCancel:
        return .merge(
          .cancel(id: CancelID.decrypt),
          .run { _ in await dismiss() }
        )

      case .alert(.presented(.didConfirm)), .alert(.dismiss):
        guard let error = state.rejection else { return .none }
        state.rejection = nil
        return .send(.delegate(.rejected(error)))

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

private extension ImportPasswordFeature {

  enum CancelID {
    case decrypt
  }

  static func rejectionAlert(for error: DevaultImportError) -> AlertState<Action.Alert>? {
    guard let text = error.rejectionAlertText else { return nil }
    return AlertState {
      TextState(text.title)
    } actions: {
      ButtonState(action: .didConfirm) { TextState(String.module("OK")) }
    } message: {
      TextState(text.message)
    }
  }
}
