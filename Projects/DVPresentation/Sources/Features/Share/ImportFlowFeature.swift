// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - ImportFlowFeature

/// Preview → (중복 시) Review Duplicates → Touch ID → execute를 잇는 코디네이터.
///
/// 시트 전환은 `MainFeature`가 소유한다 — 자식이 스스로 dismiss하면 그 효과 자체가
/// 취소돼 delegate가 못 나가는 TCA 함정(#164)을 피하려고, 자식은 delegate만 올리고
/// 여기서 `preview`/`reviewDuplicates`를 원자적으로 스왑한다.
///
/// Entry(Password Entry) 화면이 아직 없어 이 코디네이터의 진입점(`State.init(payload:)`를
/// 부르는 지점)은 비어 있다 — Entry가 생기면 복호화된 payload를 여기 넘기기만 하면 된다.
@Reducer
public struct ImportFlowFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    var preview: ImportPreviewFeature.State?
    var reviewDuplicates: ReviewDuplicatesFeature.State?
    public internal(set) var isExecuting = false
    @Presents public var alert: AlertState<Action.Alert>?

    /// Review Duplicates 단계에서 되돌아갈 때 원본 payload를 다시 꺼내 쓴다 —
    /// `ReviewDuplicatesFeature.State`는 judgement만 들고 있어 payload·project를 못 들고 있다.
    fileprivate var pendingPayload: DevaultContainerPayload?
    fileprivate var pendingProject: ImportProjectChoice?

    public init(payload: DevaultContainerPayload) {
      self.preview = ImportPreviewFeature.State(payload: payload)
    }
  }

  // MARK: - Action

  public enum Action: Equatable {
    case preview(ImportPreviewFeature.Action)
    case reviewDuplicates(ReviewDuplicatesFeature.Action)
    case executeResponse(Result<[Secret], ExecuteError>)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    public enum Delegate: Equatable {
      case imported([Secret])
      case cancelled
      case paywallRequired
    }

    public enum Alert: Equatable {}
  }

  /// `shareClient.importSecrets`가 던지는 구체 에러를 Equatable 경계로 감싼다.
  /// `EntitlementError`만 구분해 올린다 — 페이월 상향 여부를 가르는 유일한 신호다.
  public struct ExecuteError: Error, Equatable {
    public let entitlementError: EntitlementError?

    public init(_ error: any Error) {
      self.entitlementError = error as? EntitlementError
    }
  }

  // MARK: - Dependencies

  @Dependency(\.shareClient) var shareClient

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .preview(.delegate(.cancelled)):
        return .send(.delegate(.cancelled))

      case .preview(.delegate(.paywallRequired)):
        return .send(.delegate(.paywallRequired))

      case let .preview(.delegate(.proceedWithoutDuplicates(payload, project))):
        return executeEffect(payload: payload, resolutions: [:], project: project, state: &state)

      case let .preview(.delegate(.duplicatesFound(payload, judgement, project))):
        state.pendingPayload = payload
        state.pendingProject = project
        state.preview = nil
        state.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
        return .none

      case .preview:
        return .none

      case .reviewDuplicates(.delegate(.cancelled)):
        // 뒤로 가기 — resolutions는 reviewDuplicates state와 함께 버려진다. 선택은 처음부터 다시.
        guard let payload = state.pendingPayload else { return .none }
        state.reviewDuplicates = nil
        state.preview = ImportPreviewFeature.State(payload: payload)
        state.pendingPayload = nil
        state.pendingProject = nil
        return .none

      case let .reviewDuplicates(.delegate(.resolved(resolutions))):
        guard let payload = state.pendingPayload, let project = state.pendingProject else { return .none }
        return executeEffect(payload: payload, resolutions: resolutions, project: project, state: &state)

      case .reviewDuplicates:
        return .none

      case let .executeResponse(.success(secrets)):
        state.isExecuting = false
        return .send(.delegate(.imported(secrets)))

      case let .executeResponse(.failure(error)):
        state.isExecuting = false
        if error.entitlementError != nil {
          return .send(.delegate(.paywallRequired))
        }
        state.alert = executeFailureAlert
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.preview, action: \.preview) {
      ImportPreviewFeature()
    }
    .ifLet(\.reviewDuplicates, action: \.reviewDuplicates) {
      ReviewDuplicatesFeature()
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Private

extension ImportFlowFeature {

  private func executeEffect(
    payload: DevaultContainerPayload,
    resolutions: [Int: ImportDuplicateResolution],
    project: ImportProjectChoice,
    state: inout State
  ) -> Effect<Action> {
    state.isExecuting = true
    return .run { send in
      do {
        try await shareClient.authenticate(.importSecrets)
        let secrets = try await shareClient.importSecrets(payload, resolutions, project)
        await send(.executeResponse(.success(secrets)))
      } catch {
        await send(.executeResponse(.failure(ExecuteError(error))))
      }
    }
  }

  var executeFailureAlert: AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't import the secrets."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }
}
