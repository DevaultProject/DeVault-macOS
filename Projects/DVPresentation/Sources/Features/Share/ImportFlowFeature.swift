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
@Reducer
public struct ImportFlowFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    /// Review Duplicates로 넘어가도 **nil로 지우지 않는다** — 뒤로 가기(`reviewDuplicates == nil`)로
    /// 복귀하면 선택·프로젝트 선택이 그대로인 Preview가 다시 보여야 한다. 지웠다 새로 만들면
    /// 부분 선택(필터링된 payload만 기억)과 프로젝트 선택이 날아간다.
    var preview: ImportPreviewFeature.State?
    var reviewDuplicates: ReviewDuplicatesFeature.State?
    public internal(set) var isExecuting = false
    @Presents public var alert: AlertState<Action.Alert>?

    /// Review Duplicates·execute 단계에서 쓸 payload·project — `ReviewDuplicatesFeature.State`는
    /// judgement만 들고 있어 못 들고 있다. `preview`를 살려두므로 뒤로 갈 때 복원 용도로는 쓰이지 않고
    /// 오직 execute 호출 인자로만 쓰인다.
    var pendingPayload: DevaultContainerPayload?
    var pendingProject: ImportProjectChoice?

    public init(fileName: String, payload: DevaultContainerPayload) {
      self.preview = ImportPreviewFeature.State(fileName: fileName, payload: payload)
    }

    /// 두 단계가 겹쳐 있을 수 있어(`preview`를 안 지움) Review Duplicates가 있으면 그게 앞선다.
    var isShowingReviewDuplicates: Bool { reviewDuplicates != nil }
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
  ///
  /// Touch ID 취소도 이 경로로 들어와 같은 실패 알럿을 띄운다 — Export(#199)도 같은 동작이라
  /// 일관되게 뒀다. 인증 취소와 진짜 실패를 구분하는 건 두 Feature를 같이 바꿀 후속 과제.
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
        state.reviewDuplicates = ReviewDuplicatesFeature.State(judgement: judgement)
        return .none

      case .preview:
        return .none

      case .reviewDuplicates(.delegate(.cancelled)):
        // 뒤로 가기 — preview를 안 지웠으므로 선택·프로젝트 선택이 그대로 복귀한다.
        state.reviewDuplicates = nil
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
    // 연타 방지 — Preview의 Import를 두 번 누르면 delegate가 두 번 올라와 Touch ID가 두 번 뜰 수 있다.
    guard !state.isExecuting else { return .none }
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
      TextState(String.module("Couldn't Import Secrets"))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }
}
