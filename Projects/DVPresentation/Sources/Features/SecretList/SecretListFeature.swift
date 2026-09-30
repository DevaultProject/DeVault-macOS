// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - SecretListFeature

@Reducer
public struct SecretListFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public let collection: SecretQuery.Collection
    /// `.project`일 때 표시할 프로젝트 이름. `SecretQuery.Collection.project`은 id만 가지고 있어서,
    /// 어떤 프로젝트인지 알고 있는 호출부(사이드바)가 이름을 함께 넘겨준다.
    public internal(set) var projectName: String?
    public internal(set) var secretsState: LoadingState<IdentifiedArrayOf<Secret>, SecretUseCaseError> = .idle
    public internal(set) var selectedSecretID: Secret.ID?
    public internal(set) var searchText = ""
    public internal(set) var sort: SecretQuery.Sort = .recentlyAdded
    /// 검색과 무관한 컬렉션 전체 개수(정리 버튼 활성 판단용).
    public internal(set) var collectionCount = 0
    @Presents var alert: AlertState<Action.Alert>?

    public init(collection: SecretQuery.Collection = .all, projectName: String? = nil) {
      self.collection = collection
      self.projectName = projectName
    }

    /// 다른 대상을 보도록 바꾼다. **State를 직접 갈아끼우지 말고 이걸 쓴다.**
    ///
    /// 대상이 같으면 목록을 그대로 둔다. 새로 만들면 `secretsState`가 비는데 뷰의
    /// `.task(id: collection)`은 `collection`이 그대로라 다시 돌지 않아 빈 화면이 남는다.
    ///
    /// **데이터가 무효해진 경우에는 쓰지 않는다** — 저장소 전환은 이전 시크릿이 남으면 안 되므로
    /// 통째로 새로 만든다(`MainFeature.resetVaultContent`).
    mutating func retarget(to collection: SecretQuery.Collection, projectName: String? = nil) {
      guard self.collection == collection else {
        self = .init(collection: collection, projectName: projectName)
        return
      }
      if let projectName { self.projectName = projectName }
      selectedSecretID = nil
    }

    var query: SecretQuery {
      let normalizedSearchText = searchText.isEmpty ? nil : searchText
      switch collection {
      case .expired:
        return SecretQuery(
          collection: collection,
          searchText: normalizedSearchText,
          sort: SecretQuery.Sort(key: .expiry, direction: .ascending)
        )
      case .notice:
        // predicate가 이미 "지나지 않음 + window 이내"를 전부 검사하므로 window 변환이 필요 없다.
        // 임박한 것부터 보여주는 게 자연스러워 정렬은 고정한다(사용자가 바꿀 이유가 없는 화면).
        return SecretQuery(
          collection: collection,
          searchText: normalizedSearchText,
          sort: SecretQuery.Sort(key: .expiry, direction: .ascending)
        )
      case .all, .liked, .deleted, .project:
        return SecretQuery(collection: collection, searchText: normalizedSearchText, sort: sort)
      }
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case task
    case didSelectSecret(id: Secret.ID?)
    case didChangeSearchText(String)
    case didSelectSort(SecretQuery.Sort)
    case didTapDelete(id: Secret.ID)
    case didTapRecover(id: Secret.ID)
    case didTapDeleteForever(id: Secret.ID)
    /// Expired/Deleted 탭의 "모두 삭제"/"비우기" — 컬렉션 전체 정리.
    case didTapEmptyCollection
    case didTapRetry
    /// 외부(예: SecretDetail의 즐겨찾기·삭제)에서 목록 갱신을 요청할 때 사용.
    /// `task`/`didTapRetry`와 달리 `secretsState`를 `.loading`으로 바꾸지 않아 목록이 깜빡이지 않는다 —
    /// 내부 mutation(`mutationResponse(.success)`)이 재조회하는 방식과 동일하다.
    case refresh
    /// 다른 기기(iCloud)의 변경 알림 뒤의 재조회. `refresh`와 달리, 조회 중이던 시크릿이 재조회 결과에 없으면 선택을 풀어 상세를 닫는다 — 알림은 **어떤 id가 바뀌었는지 알려주지 않으므로** 재조회 결과와 대조하는 것 말고는 알아낼 방법이 없다.
    case refreshRevalidatingSelection

    // MARK: - Internal

    case secretsResponse(Result<[Secret], SecretUseCaseError>)
    case mutationResponse(Result<Secret.ID, SecretUseCaseError>)
    /// 컬렉션 일괄 정리(비우기/모두 삭제) 결과. nil이면 성공.
    case emptyCollectionResponse(SecretUseCaseError?)
    /// 지금 조회 중이던 시크릿을 삭제·복구·영구삭제해 목록에서 사라졌을 때만 보낸다.
    /// 재조회가 끝난 뒤 남은 목록의 맨 위 항목으로 조회뷰를 옮기거나(있으면), 없으면 닫는다.
    case reselectAfterMutation
    /// 재조회 결과에 조회 중이던 시크릿이 없으면 선택을 푼다. 남아 있으면 아무것도 하지 않는다 — 원격 변경은 사용자가 한 조작이 아니라서 ``reselectAfterMutation``처럼 다른 항목으로 옮기면 보고 있던 화면이 제멋대로 바뀐다.
    case revalidateSelection

    // MARK: - Child

    case alert(PresentationAction<Alert>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case secretSelected(Secret.ID?)
      /// 삭제·복구·영구삭제로 Secret 집합이 바뀌었음을 부모에게 알린다.
      /// 부모가 사이드바 개수를 다시 세는 근거가 된다.
      case secretsChanged
    }

    public enum Alert: Equatable {
      case confirmDeleteForever(id: Secret.ID)
      case confirmEmptyCollection
    }
  }

  // MARK: - Dependencies

  @Dependency(\.secretClient) var secretClient
  @Dependency(\.continuousClock) var clock

  private enum CancelID {
    case fetch
  }

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // 이미 받아둔 목록이 있으면 비우지 않는다. `.task`는 최초 진입이 아니라 뷰가 다시
      // 만들어질 때마다 실행되므로(설정 화면 왕복 등) 비우면 목록이 사라졌다 나타난다.
      case .task:
        switch state.secretsState {
        case .loaded: break
        default: state.secretsState = .loading
        }
        return fetchSecretsEffect(query: state.query, debounced: false)

      // 재시도는 실패 화면에서만 눌리므로 되돌릴 목록이 없다.
      case .didTapRetry:
        state.secretsState = .loading
        return fetchSecretsEffect(query: state.query, debounced: false)

      case .refresh:
        return fetchSecretsEffect(query: state.query, debounced: false)

      // 대조는 최신 목록을 봐야 하므로 재조회 뒤에 와야 한다(`.send`는 즉시 끝나므로 지연은 없다). 부모가 `.send(.secretList(.refresh))` 뒤에 대조를 이어 붙이는 방식으로는 안 된다 — `.send`는 자식이 돌려준 재조회 effect의 완료를 기다리지 않는다.
      case .refreshRevalidatingSelection:
        return .concatenate(
          fetchSecretsEffect(query: state.query, debounced: false),
          .send(.revalidateSelection)
        )

      case .didChangeSearchText(let text):
        state.searchText = text
        return fetchSecretsEffect(query: state.query, debounced: true)

      case .didSelectSort(let sort):
        state.sort = sort
        return fetchSecretsEffect(query: state.query, debounced: false)

      case .secretsResponse(.success(let secrets)):
        // CloudKit 동기화가 같은 id의 중복 레코드를 만들 수 있다. uniqueElements는 중복 id에서
        // fatalError로 죽으므로, 중복이 와도 첫 항목만 남기고 트랩되지 않게 한다.
        let list = IdentifiedArray(secrets, uniquingIDsWith: { current, _ in current })
        state.secretsState = .loaded(list)
        // 검색이 없을 때의 결과가 곧 컬렉션 전체 수. 검색 중엔 갱신하지 않아 직전 전체 수를 유지한다.
        if state.searchText.isEmpty {
          state.collectionCount = list.count
        }
        return .none

      case .secretsResponse(.failure(let error)):
        state.secretsState = .failed(error)
        return .none

      case .didSelectSecret(let id):
        state.selectedSecretID = id
        return .send(.delegate(.secretSelected(id)))

      case .didTapDelete(let id):
        return mutationEffect(id: id) { try await secretClient.softDelete(id) }

      case .didTapRecover(let id):
        return mutationEffect(id: id) { try await secretClient.restore(id) }

      case .didTapDeleteForever(let id):
        state.alert = deleteForeverConfirmationAlert(id: id)
        return .none

      case .didTapEmptyCollection:
        guard state.collectionCount > 0 else { return .none }
        state.alert = emptyCollectionConfirmationAlert(collection: state.collection, count: state.collectionCount)
        return .none

      case .alert(.presented(.confirmDeleteForever(let id))):
        return mutationEffect(id: id) { try await secretClient.permanentlyDelete(id) }

      case .alert(.presented(.confirmEmptyCollection)):
        return emptyCollectionEffect(collection: state.collection)

      case .emptyCollectionResponse(nil):
        // 컬렉션이 통째로 비워졌다. 검색 중이어도 전체 수는 0이 됐으므로 직접 반영한다.
        state.collectionCount = 0
        // 부모 개수 갱신 → 재조회 → 재선택(빈 목록이면 조회뷰가 닫힌다).
        return .concatenate(
          .send(.delegate(.secretsChanged)),
          fetchSecretsEffect(query: state.query, debounced: false),
          .send(.reselectAfterMutation)
        )

      case .emptyCollectionResponse(.some):
        state.alert = mutationFailureAlert()
        return .none

      // 세 효과는 서로 독립적이지만 `.merge`는 도착 순서를 보장하지 않아 테스트가 깨지기 쉽다.
      // 부모 갱신 → 재조회 → (조회 중이던 항목이 사라졌다면) 재선택 순으로 흘려보낸다
      // (`.send`는 즉시 끝나므로 지연은 없다). 재선택은 재조회가 끝난 뒤 최신 목록을 봐야 하므로
      // `fetchSecretsEffect` 다음에 와야 한다.
      case .mutationResponse(.success(let id)):
        let wasViewingMutatedSecret = state.selectedSecretID == id
        var effects: [Effect<Action>] = [
          .send(.delegate(.secretsChanged)),
          fetchSecretsEffect(query: state.query, debounced: false)
        ]
        if wasViewingMutatedSecret {
          effects.append(.send(.reselectAfterMutation))
        }
        return .concatenate(effects)

      case .reselectAfterMutation:
        guard case .loaded(let secrets) = state.secretsState else { return .none }
        let newID = secrets.first?.id
        state.selectedSecretID = newID
        return .send(.delegate(.secretSelected(newID)))

      // `.loaded`가 아니면(재조회 실패) 목록이 비었는지 알 수 없다. 일시적인 오류에 상세가 닫히지 않도록 그냥 둔다.
      case .revalidateSelection:
        guard let id = state.selectedSecretID,
              case .loaded(let secrets) = state.secretsState,
              secrets[id: id] == nil
        else { return .none }
        state.selectedSecretID = nil
        return .send(.delegate(.secretSelected(nil)))

      case .mutationResponse(.failure):
        state.alert = mutationFailureAlert()
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  // MARK: - Helpers

  private func fetchSecretsEffect(query: SecretQuery, debounced: Bool) -> Effect<Action> {
    .run { send in
      if debounced {
        try await clock.sleep(for: .milliseconds(300))
      }
      do {
        let secrets = try await secretClient.fetchByQuery(query)
        await send(.secretsResponse(.success(secrets)))
      } catch {
        await send(.secretsResponse(.failure(SecretUseCaseError.map(error))))
      }
    }
    .cancellable(id: CancelID.fetch, cancelInFlight: true)
  }

  private func mutationEffect(id: Secret.ID, operation: @escaping () async throws -> Void) -> Effect<Action> {
    .run { send in
      do {
        try await operation()
        await send(.mutationResponse(.success(id)))
      } catch {
        await send(.mutationResponse(.failure(SecretUseCaseError.map(error))))
      }
    }
  }

  /// 컬렉션 전체 정리. Deleted면 영구 삭제, 그 외(Expired)는 소프트 삭제로 '삭제됨'으로 옮긴다.
  private func emptyCollectionEffect(collection: SecretQuery.Collection) -> Effect<Action> {
    .run { send in
      do {
        switch collection {
        case .deleted:
          try await secretClient.permanentlyDeleteAll(collection)
        default:
          try await secretClient.softDeleteAll(collection)
        }
        await send(.emptyCollectionResponse(nil))
      } catch {
        await send(.emptyCollectionResponse(SecretUseCaseError.map(error)))
      }
    }
  }

  private func mutationFailureAlert() -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't complete the action."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }

  /// Deleted는 영구 삭제(되돌릴 수 없음), Expired는 '삭제됨'으로 이동(복구 가능)이라 문구가 다르다.
  private func emptyCollectionConfirmationAlert(
    collection: SecretQuery.Collection,
    count: Int
  ) -> AlertState<Action.Alert> {
    switch collection {
    case .deleted:
      return AlertState {
        TextState(String.module("Empty Deleted list?"))
      } actions: {
        ButtonState(role: .destructive, action: .confirmEmptyCollection) {
          TextState(String.module("Empty"))
        }
        ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
      } message: {
        TextState(String.module("\(count) secrets will be permanently deleted. This can't be undone."))
      }
    default:
      return AlertState {
        TextState(String.module("Delete All Expired?"))
      } actions: {
        ButtonState(role: .destructive, action: .confirmEmptyCollection) {
          TextState(String.module("Delete All"))
        }
        ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
      } message: {
        TextState(String.module("\(count) secrets will move to Deleted. You can recover them later."))
      }
    }
  }

  /// 되돌릴 수 없는 작업이라 실수로 누른 걸 걸러낸다.
  private func deleteForeverConfirmationAlert(id: Secret.ID) -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Delete Forever?"))
    } actions: {
      ButtonState(role: .destructive, action: .confirmDeleteForever(id: id)) {
        TextState(String.module("Delete Forever"))
      }
      ButtonState(role: .cancel) {
        TextState(String.module("Cancel"))
      }
    } message: {
      TextState(String.module("This action cannot be undone."))
    }
  }
}
