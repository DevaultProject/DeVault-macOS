// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture

// MARK: - SidebarFilter

public enum SidebarFilter: Equatable, CaseIterable, Hashable, Sendable {
  case all
  case starred
  case notice
  case expired
  case deleted

  var title: String {
    switch self {
    case .all:     .module("All")
    case .starred: .module("Star")
    case .notice:  .module("Notice")
    case .expired: .module("Expired")
    case .deleted: .module("Deleted")
    }
  }

  var icon: String {
    switch self {
    case .all:     "square.grid.2x2.fill"
    case .starred: "star.fill"
    case .notice:  "exclamationmark"
    case .expired: "clock.badge.xmark"
    case .deleted: "trash"
    }
  }
}

// MARK: - SidebarSelection

public enum SidebarSelection: Equatable {
  case filter(SidebarFilter)
  case project(id: ProjectItem.ID)
}

// MARK: - SidebarFeature

@Reducer
public struct SidebarFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    /// **강조 판정은 여기서만 파생된다.** 선택과 생성 여부를 두 필드로 나눠 두면 조합 규칙이
    /// 뷰와 리듀서에 따로 생겨 어긋난다.
    public internal(set) var mode: Mode = .browsing(.filter(.all))
    public internal(set) var isProjectSectionExpanded: Bool = true

    public enum Mode: Equatable {
      case browsing(SidebarSelection)
      /// 생성 중에는 어떤 항목도 강조하지 않으며, 끝나면 `previous`로 돌아간다.
      case creating(previous: SidebarSelection)
    }

    /// **뷰와 리듀서가 함께 보는 단일 기준이다.**
    public var highlighted: SidebarSelection? {
      guard case .browsing(let selection) = mode else { return nil }
      return selection
    }

    /// 강조 여부와 무관한 "돌아갈 곳".
    public internal(set) var selection: SidebarSelection {
      get {
        switch mode {
        case .browsing(let selection), .creating(previous: let selection): return selection
        }
      }
      set {
        switch mode {
        case .browsing:  mode = .browsing(newValue)
        case .creating:  mode = .creating(previous: newValue)
        }
      }
    }
    var projectsState: LoadingState<IdentifiedArrayOf<ProjectItem>, SidebarError> = .idle
    /// "아직 안 불러옴"과 "0건"을 구분하기 위해 LoadingState로 감싼다 (TCA_GUIDELINES 2.4).
    var countsState: LoadingState<SecretCounts, SidebarError> = .idle
    /// 이미 보여줄 값이 있는 채로 다시 받아오는 중. 화면은 이전 값을 두고 opacity만 낮춘다.
    var isRefreshingProjects = false
    var renamingProjectID: ProjectItem.ID?
    var renameText: String = ""
    var deletingProjectID: ProjectItem.ID?
    @Presents var alert: AlertState<Action.Alert>?

    // computed property — LoadingState에서 추출. 외부 참조(MainFeature, View)에서 LoadingState를 몰라도 됨
    var projects: IdentifiedArrayOf<ProjectItem> {
      if case .loaded(let projects) = projectsState { return projects }
      return []
    }

    /// 로드 전·실패 시에는 nil. View가 "숫자 자리를 비울지" 판단할 수 있어야 하므로 옵셔널이다.
    var counts: SecretCounts? {
      if case .loaded(let counts) = countsState { return counts }
      return nil
    }

    public init() {}
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case task
    /// `task`와 달리 `.loading`으로 되돌리지 않아 화면에서 목록이 사라졌다 나타나지 않는다 —
    /// 프로젝트 추가·이름 변경처럼 이미 보고 있는 목록이 조금 달라지는 경우에 쓴다.
    case refresh
    case didSelect(SidebarSelection)
    case didTapAddButton
    case didTapAddProject
    case didTapSettings
    case didToggleProjectSection
    case didTapRename(id: ProjectItem.ID)
    case didChangeRenameText(String)
    case didConfirmRename
    case didCancelRename
    case didTapDelete(id: ProjectItem.ID)
    case setCreatingSecret(Bool)

    /// Secret이 생성·삭제·복구되어 개수만 다시 세야 할 때 부모(MainFeature)가 보낸다.
    case countsRefreshRequested

    // MARK: - Internal

    case projectsResponse(Result<[ProjectItem], SidebarError>)
    case countsResponse(Result<SecretCounts, SidebarError>)
    // 응답에 요청한 projectID를 실어, 편집 대상이 바뀐 뒤 도착한 stale 응답이 현재 편집을 건드리지 않게 한다.
    case renameResponse(projectID: ProjectItem.ID, Result<ProjectItem, SidebarError>)
    case deleteResponse(Result<ProjectItem.ID, SidebarError>)

    // MARK: - Child

    case alert(PresentationAction<Alert>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Alert: Equatable {
      case confirmDelete
    }

    public enum Delegate: Equatable {
      case selectionChanged(SidebarSelection)
      case addButtonTapped
      case addProjectTapped
      case projectRenamed(ProjectItem)
      case settingsTapped
    }
  }

  // MARK: - CancelID (E5)

  private enum CancelID {
    case fetch
    case counts
  }

  // MARK: - Dependencies

  @Dependency(\.sidebarClient) var sidebarClient
  @Dependency(\.date.now) var now

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // `.task`는 화면이 다시 만들어질 때마다 실행된다. 그때 `.loading`으로 되돌리면
      // 이미 받아둔 목록과 숫자가 사라졌다 나타난다.
      case .task:
        if case .loaded = state.projectsState {
          state.isRefreshingProjects = true
        } else {
          state.projectsState = .loading
        }
        // 숫자에 `isRefreshing` 짝이 없는 것은 갱신 경로(`.countsRefreshRequested`)가
        // 아예 `.loading`으로 되돌리지 않기 때문이다 — 흐릴 것 없이 이전 값이 계속 보인다.
        switch state.countsState {
        case .loaded: break
        default: state.countsState = .loading
        }
        return fetchProjectsEffect()

      case .refresh:
        state.isRefreshingProjects = true
        return fetchProjectsEffect()

      case .projectsResponse(.success(let projects)):
        state.isRefreshingProjects = false
        let sorted = projects.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        // CloudKit 중복 레코드로 같은 id가 와도 트랩되지 않게 첫 항목만 남긴다(uniqueElements는 fatalError).
        let list = IdentifiedArray(sorted, uniquingIDsWith: { current, _ in current })
        state.projectsState = .loaded(list)
        // 프로젝트별 개수를 세려면 ID 목록이 필요하므로 목록 로드 성공 후에 이어서 집계한다.
        // 중복 제거된 목록의 id를 넘겨, 같은 프로젝트를 두 번 조회하지 않게 한다.
        return countsEffect(projectIDs: Array(list.ids))

      case .projectsResponse(.failure(let error)):
        state.isRefreshingProjects = false
        state.projectsState = .failed(error)
        // 프로젝트 목록이 실패해도 필터 카드 개수는 독립적으로 유효하므로 집계는 계속 시도한다.
        return countsEffect(projectIDs: [])

      // `.loading`으로 되돌리지 않는다. 되돌리면 `counts`가 nil이 되어 모든 행의 숫자가
      // 사라졌다 다시 나타난다 — 시크릿을 하나 만들 때마다 사이드바 전체가 깜빡였다.
      // 이전 값을 그대로 두고 새 값이 오면 숫자만 바뀐다.
      case .countsRefreshRequested:
        return countsEffect(projectIDs: state.projects.map(\.id))

      case .countsResponse(.success(let counts)):
        state.countsState = .loaded(counts)
        return .none

      case .countsResponse(.failure(let error)):
        state.countsState = .failed(error)
        return .none

      // 이미 강조된 항목을 다시 눌러도 macOS List는 선택 이벤트를 보낸다 — 흘려보내면 목록 State가 버려진다.
      // `selection`이 아니라 `highlighted`를 본다 — 생성 중에는 강조가 없어야 같은 필터로 돌아갈 수 있다.
      case .didSelect(let selection) where state.highlighted == selection:
        return .none

      // 생성 중엔 선택이 아직 확정이 아니다 — 부모의 "변경사항을 버릴까요?" 확인을 거쳐야 해서
      // `mode`를 바꾸지 않고 알리기만 한다. 확정됐을 때 목적지를 옮기는 건 부모의 몫이다.
      case .didSelect(let selection):
        if case .browsing = state.mode {
          state.mode = .browsing(selection)
        }
        return .send(.delegate(.selectionChanged(selection)))

      case .didTapAddButton:
        return .send(.delegate(.addButtonTapped))

      case .didTapAddProject:
        return .send(.delegate(.addProjectTapped))

      case .didTapSettings:
        return .send(.delegate(.settingsTapped))

      case .didToggleProjectSection:
        state.isProjectSectionExpanded.toggle()
        return .none

      case .didTapRename(id: let id):
        guard let project = state.projects[id: id] else { return .none }
        state.renamingProjectID = id
        state.renameText = project.name
        return .none

      case .didChangeRenameText(let text):
        state.renameText = text
        return .none

      // "돌아갈 곳"은 유지해야 생성을 마치고 보던 목록으로 돌아간다.
      case .setCreatingSecret(let value):
        switch (value, state.mode) {
        case (true, .browsing(let selection)):
          state.mode = .creating(previous: selection)
        case (false, .creating(previous: let selection)):
          state.mode = .browsing(selection)
        case (true, .creating), (false, .browsing):
          break
        }
        return .none

      // 편집 상태는 성공·이름 중복 시 닫아 원래 이름으로 되돌린다.
      // 그 외 실패(renameFailed)는 열어 둬 입력한 이름을 보존한다(재시도 대비).
      case .didConfirmRename:
        guard let id = state.renamingProjectID else { return .none }
        let name = state.renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
          // 빈 이름은 보존할 입력이 없으므로 편집을 닫아 원래 이름으로 되돌린다.
          state.alert = makeRenameEmptyNameAlert()
          state.renamingProjectID = nil
          state.renameText = ""
          return .none
        }
        return .run { [id, name] send in
          do {
            let updated = try await sidebarClient.renameProject(id, name)
            await send(.renameResponse(projectID: id, .success(updated)))
          } catch let error as SidebarError {
            await send(.renameResponse(projectID: id, .failure(error)))
          } catch {
            await send(.renameResponse(projectID: id, .failure(.renameFailed)))
          }
        }

      case .didCancelRename:
        state.renamingProjectID = nil
        state.renameText = ""
        return .none

      case let .renameResponse(projectID, .success(updated)):
        // 편집 상태 정리는 지금 그 프로젝트를 편집 중일 때만 한다. 요청 도중 다른 프로젝트로 옮겼다면
        // 그 편집을 건드리지 않는다. 반면 이름 변경은 실제로 성공했으므로 목록·부모 반영은 무조건 한다.
        if state.renamingProjectID == projectID {
          state.renamingProjectID = nil
          state.renameText = ""
        }
        return .concatenate(
          .send(.delegate(.projectRenamed(updated))),
          .send(.refresh)
        )

      case let .renameResponse(projectID, .failure(.nameTaken)):
        // 지금 편집 중인 그 프로젝트의 응답일 때만 처리한다. 다른 프로젝트를 편집 중이면 stale 응답이므로 무시.
        guard state.renamingProjectID == projectID else { return .none }
        // 이름 중복은 저장을 막고 편집을 닫아 원래 이름으로 되돌린다.
        state.alert = makeRenameNameTakenAlert()
        state.renamingProjectID = nil
        state.renameText = ""
        return .none

      case let .renameResponse(projectID, .failure):
        guard state.renamingProjectID == projectID else { return .none }
        state.alert = makeRenameFailedAlert()
        return .none

      case .didTapDelete(id: let id):
        guard let project = state.projects[id: id] else { return .none }
        state.deletingProjectID = id
        state.alert = makeDeleteAlert(for: project)
        return .none

      case .alert(.presented(.confirmDelete)):
        guard let id = state.deletingProjectID else { return .none }
        state.deletingProjectID = nil
        return .run { [id] send in
          do {
            try await sidebarClient.deleteProject(id)
            await send(.deleteResponse(.success(id)))
          } catch let error as SidebarError {
            await send(.deleteResponse(.failure(error)))
          } catch {
            await send(.deleteResponse(.failure(.deleteFailed)))
          }
        }

      // 대상 ID를 남겨두면 다음 삭제가 엉뚱한 프로젝트를 지울 여지가 생긴다.
      case .alert(.dismiss):
        state.deletingProjectID = nil
        return .none

      case .alert:
        return .none

      case .deleteResponse(.success(let id)):
        if state.selection == .project(id: id) {
          state.selection = .filter(.all)
          return .concatenate(
            .send(.delegate(.selectionChanged(.filter(.all)))),
            .send(.refresh)
          )
        }
        return .send(.refresh)

      case .deleteResponse(.failure):
        state.alert = makeDeleteFailedAlert()
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Private

private extension SidebarFeature {

  /// `task`(최초)와 `refresh`(재조회)가 공유하며, 다른 것은 호출 전에 `.loading`으로 되돌리는지 여부뿐이다.
  func fetchProjectsEffect() -> Effect<Action> {
    .run { send in
      do {
        let projects = try await sidebarClient.fetchProjects()
        await send(.projectsResponse(.success(projects)))
      } catch let error as SidebarError {
        await send(.projectsResponse(.failure(error)))
      } catch {
        await send(.projectsResponse(.failure(.fetchFailed)))
      }
    }
    .cancellable(id: CancelID.fetch, cancelInFlight: true)
  }

  /// 생성/삭제가 연달아 일어나면 직전 집계는 취소한다 (E3).
  func countsEffect(projectIDs: [ProjectItem.ID]) -> Effect<Action> {
    .run { [now] send in
      do {
        let counts = try await sidebarClient.fetchCounts(now, projectIDs)
        await send(.countsResponse(.success(counts)))
      } catch let error as SidebarError {
        await send(.countsResponse(.failure(error)))
      } catch {
        await send(.countsResponse(.failure(.fetchFailed)))
      }
    }
    .cancellable(id: CancelID.counts, cancelInFlight: true)
  }

  func makeDeleteAlert(for project: ProjectItem) -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Delete project '\(project.name)'?"))
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState(String.module("Delete"))
      }
      ButtonState(role: .cancel) {
        TextState(String.module("Cancel"))
      }
    } message: {
      TextState(String.module("Deleting this project will unlink its secrets. The secrets themselves won't be deleted."))
    }
  }

  func makeRenameNameTakenAlert() -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("This name is already in use."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please enter a different project name."))
    }
  }

  func makeRenameEmptyNameAlert() -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Please enter a name."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Project name can't be empty."))
    }
  }

  func makeRenameFailedAlert() -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't rename the project."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }

  func makeDeleteFailedAlert() -> AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't delete the project."))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }
}
