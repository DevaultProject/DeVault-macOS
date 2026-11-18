// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - MainFeature

@Reducer
public struct MainFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    var sidebar: SidebarFeature.State = .init()
    var secretList: SecretListFeature.State = .init(collection: .all)

    // 시트
    @Presents var createProject: CreateProjectFeature.State?
    @Presents var paywall: DevaultProPaywallFeature.State?
    @Presents var exportSecret: ExportSecretSheetFeature.State?
    /// Export 뒤 Share/Save As 선택을 기다리는 임시 파일. 단순 optional이라 @Presents를 쓰지 않는다.
    var exportedFile: ExportedFile?
    @Presents var importPassword: ImportPasswordFeature.State?
    @Presents var importFlow: ImportFlowFeature.State?

    // 화면 전환 — sheet가 아니라 컬럼·콘텐츠를 바꾸므로 @Presents를 쓰지 않는다.
    var selectSecretType: SelectSecretTypeFeature.State?
    var createSecret: CreateSecretFeature.State?
    var secretDetail: SecretDetailFeature.State?
    var settings: SettingsFeature.State?

    // 작성 중인 폼의 취소 확인을 기다리는 동안 보관한다.
    var pendingSelection: SidebarSelection?
    var pendingCreateType: CreatableSecretType?

    /// 삭제된 시크릿을 고르면 상세 대신 그릴 복구 안내 대상. 상세를 닫는 경로가 여럿이라 저장하지 않고 계산한다.
    var deletedNoticeSecret: Secret? {
      guard secretDetail == nil,
            let id = secretList.selectedSecretID,
            case .loaded(let secrets) = secretList.secretsState,
            let secret = secrets[id: id],
            secret.deletedAt != nil
      else { return nil }
      return secret
    }

    /// 화면 분기는 이 값 하나만 본다 — 뷰에서 optional을 조합하면 판정이 흩어진다.
    var screen: Screen {
      if settings != nil { return .settings }
      if createSecret != nil || selectSecretType != nil { return .creating }
      return .browsing
    }

    /// 서로 배타적인 최상위 화면.
    enum Screen: Equatable {
      case browsing
      case creating
      case settings
    }

    public init() {}
  }

  // MARK: - Action

  public enum Action: BindableAction, Equatable {

    // MARK: - View

    case binding(BindingAction<State>)
    case task
    case didTapLock
    /// App 메뉴에서 타입 선택을 건너뛰고 바로 생성.
    case createSecretRequested(CreatableSecretType)

    // MARK: - Internal

    case iCloudRemoteChangeDetected
    case importFileOpened(fileName: String, data: Data)

    // MARK: - Child

    case sidebar(SidebarFeature.Action)
    case secretList(SecretListFeature.Action)
    case selectSecretType(SelectSecretTypeFeature.Action)
    case createProject(PresentationAction<CreateProjectFeature.Action>)
    /// Project 생성 게이트 판정 결과. 시도 전에 묻는다.
    case canCreateProjectResponse(Result<Bool, ProjectUseCaseError>)
    /// Secret 생성 게이트 판정 결과. 타입 선택을 열기 전에 묻는다.
    case canCreateSecretResponse(Result<Bool, SecretUseCaseError>)
    case paywall(PresentationAction<DevaultProPaywallFeature.Action>)
    case createSecret(CreateSecretFeature.Action)
    case secretDetail(SecretDetailFeature.Action)
    case settings(SettingsFeature.Action)
    case exportSecret(PresentationAction<ExportSecretSheetFeature.Action>)
    case importPassword(PresentationAction<ImportPasswordFeature.Action>)
    case importFlow(PresentationAction<ImportFlowFeature.Action>)
    /// 프로젝트 공유 — 사이드바는 id만 알아서 내보낼 시크릿을 여기서 조회한다.
    case projectExportSecretsFetched(Result<[Secret.ID], SecretUseCaseError>)
    case didDismissExportedFile

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case lockRequested
    }
  }

  // MARK: - Dependencies

  @Dependency(\.date.now) var now
  @Dependency(\.entitlementClient) var entitlementClient
  @Dependency(\.secretClient) var secretClient

  // MARK: - Init

  public init() {}

  // MARK: - Cancellation

  private enum CancelID {
    /// 생성 게이트 판정. 세 진입점이 한 ID를 공유해야 앞선 판정이 취소된다 — 나누면 두 응답이 모두 도착해 한쪽 화면이 덮인다.
    case createGate
  }

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.sidebar, action: \.sidebar) {
      SidebarFeature()
    }
    Scope(state: \.secretList, action: \.secretList) {
      SecretListFeature()
    }
    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return .none

      case .canCreateSecretResponse(.success(true)):
        // 메뉴 진입이면 타입이 정해져 있고, 사이드바 `+`는 타입 선택부터 연다.
        if let secretType = state.pendingCreateType {
          state.pendingCreateType = nil
          return startCreating(secretType: secretType, &state)
        }
        enterCreating(&state)
        return .send(.sidebar(.setCreatingSecret(true)))

      case .canCreateSecretResponse(.success(false)):
        state.pendingCreateType = nil
        state.paywall = DevaultProPaywallFeature.State()
        return .none

      case .canCreateSecretResponse(.failure):
        // 판정 실패는 저장소가 깨진 것이다. 페이월을 띄우면 결제해도 해결되지 않는다.
        state.pendingCreateType = nil
        return .none

      case .canCreateProjectResponse(.success(true)):
        state.createProject = .init()
        return .none

      case .canCreateProjectResponse(.success(false)):
        state.paywall = DevaultProPaywallFeature.State()
        return .none

      case .canCreateProjectResponse(.failure):
        // 판정 실패는 저장소가 깨진 것이다. 페이월을 띄우면 결제해도 해결되지 않는다.
        return .none

      case .paywall(.presented(.delegate(.didFinish))):
        state.paywall = nil
        return .none

      case .paywall:
        return .none

      // 알림에 바뀐 id가 없어 재조회 결과와 대조해 선택을 정리한다.
      case .iCloudRemoteChangeDetected:
        return .concatenate(
          .send(.secretList(.refreshRevalidatingSelection)),
          .send(.sidebar(.task))
        )

      case .didTapLock:
        return .send(.delegate(.lockRequested))

      case .sidebar(.delegate(let delegate)):
        return handleSidebarDelegate(&state, delegate: delegate)

      case .sidebar:
        return .none

      // `case .settings:` catch-all보다 앞에 둔다 — 뒤면 잡히지 않아 페이월이 뜨지 않는다.
      case .settings(.delegate(.paywallRequired)),
           .secretDetail(.delegate(.paywallRequired)),
           .secretList(.delegate(.paywallRequired)),
           .createSecret(.delegate(.paywallRequired)):
        state.paywall = DevaultProPaywallFeature.State()
        return .none

      case let .importFileOpened(fileName, data):
        // importFlow 진행 중이면 끼어들지 않는다 — 시트가 겹쳐 뜨는 것을 막는다.
        guard state.importFlow == nil else { return .none }
        state.importPassword = ImportPasswordFeature.State(fileName: fileName, data: data)
        return .none

      case .importPassword(.presented(.delegate(.decrypted(let payload)))):
        guard let fileName = state.importPassword?.fileName else { return .none }
        state.importPassword = nil
        state.importFlow = ImportFlowFeature.State(fileName: fileName, payload: payload)
        return .none

      // 거절은 비밀번호 화면이 알럿으로 이미 안내한 뒤에만 온다 — 시트만 닫는다.
      case .importPassword(.presented(.delegate(.rejected))):
        state.importPassword = nil
        return .none

      case .importPassword:
        return .none

      // 시트 위에 시트를 못 쌓아 importFlow를 통째로 닫는다. 결제 뒤에는 파일 선택부터 다시 해야 한다.
      case .importFlow(.presented(.delegate(.paywallRequired))):
        state.importFlow = nil
        state.paywall = DevaultProPaywallFeature.State()
        return .none

      case .importFlow(.presented(.delegate(.imported))):
        state.importFlow = nil
        return .concatenate(
          .send(.secretList(.refresh)),
          .send(.sidebar(.refresh))
        )

      case .importFlow(.presented(.delegate(.cancelled))):
        state.importFlow = nil
        return .none

      case .importFlow:
        return .none

      case .settings(.delegate(.closeRequested)):
        state.settings = nil
        return .none

      case .settings(.delegate(.storageDidSwitch)),
           .settings(.delegate(.vaultDataReset)):
        resetVaultContent(&state)
        return .concatenate(
          .send(.secretList(.refresh)),
          .send(.sidebar(.task))
        )

      case .settings:
        return .none

      // 삭제된 시크릿은 상세를 만들지 않는다 — 상세가 조회·복사·수정의 유일한 진입점이다.
      // 선택이 아니라 여기서 막는다 — 선택을 막으면 `List` selection이 확정되지 않아 방향키 탐색과 영구 삭제가 키보드로 안 된다.
      case .secretList(.delegate(.secretSelected(let id))):
        if let id, case .loaded(let secrets) = state.secretList.secretsState, let secret = secrets[id: id],
           secret.deletedAt == nil {
          state.secretDetail = SecretDetailFeature.State(secret: secret)
        } else {
          state.secretDetail = nil
        }
        return .none

      // 자식끼리 직접 연결하지 않고 부모가 사이드바 개수 갱신을 지시한다 (TCA_GUIDELINES 7.4).
      case .secretList(.delegate(.secretsChanged)):
        return .send(.sidebar(.countsRefreshRequested))

      case .secretList(let secretListAction):
        if case .delegate(.exportRequested(let ids)) = secretListAction {
          state.exportSecret = ExportSecretSheetFeature.State(secretIDs: ids)
        }
        if case .delegate(.exportProjectRequested(let id)) = secretListAction {
          return exportProjectEffect(id: id)
        }
        return .none

      case .exportSecret(let presentationAction):
        // dismiss() 대신 여기서 시트 닫기+다음 시트 열기를 원자적으로 처리한다.
        if case .presented(.delegate(.exportSucceeded(let url))) = presentationAction {
          state.exportSecret = nil
          state.exportedFile = ExportedFile(url: url)
        }
        return .none

      // 빈 프로젝트는 비밀번호·Touch ID까지 거치고도 내보낼 게 없다.
      case .projectExportSecretsFetched(.success(let ids)):
        guard !ids.isEmpty else { return .none }
        state.exportSecret = ExportSecretSheetFeature.State(secretIDs: ids, target: .project)
        return .none

      // 저장소가 깨진 것이라 조용히 무시한다(`.canCreateProjectResponse(.failure)`와 같은 이유).
      case .projectExportSecretsFetched(.failure):
        return .none

      case .didDismissExportedFile:
        state.exportedFile = nil
        return .none

      case .secretDetail(.delegate(.closed)):
        state.secretDetail = nil
        state.secretList.selectedSecretID = nil
        return .none

      // 항목만 교체하면 필터 컬렉션(liked·expired·project)에서 조건을 벗어난 항목이 남는다.
      case .secretDetail(.delegate(.secretUpdated)):
        return .concatenate(
          .send(.secretList(.refresh)),
          .send(.sidebar(.countsRefreshRequested))
        )

      case .secretDetail(.delegate(.deleted)):
        state.secretDetail = nil
        state.secretList.selectedSecretID = nil
        return .concatenate(
          .send(.secretList(.refresh)),
          .send(.sidebar(.countsRefreshRequested))
        )

      // 자식끼리 직접 연결하지 않고 부모가 사이드바 재조회를 지시한다 (TCA_GUIDELINES 7.4).
      // 아래 `.secretDetail` 캐치올보다 앞에 둔다 — 뒤면 그쪽이 먼저 잡는다.
      case .secretDetail(.delegate(.projectsChanged)):
        return .send(.sidebar(.refresh))

      case .secretDetail(let secretDetailAction):
        if case .delegate(.shareTapped(let id)) = secretDetailAction {
          state.exportSecret = ExportSecretSheetFeature.State(secretIDs: [id])
        }
        return .none

      case .createSecretRequested(let secretType):
        // 설정 화면엔 사이드바·리스트가 없어, 진행하면 보이지 않는 상태만 바뀐다.
        guard state.settings == nil else { return .none }
        // 작성 중인 폼은 덮어쓰지 않는다 — 취소 확인을 거쳐 확인되면 이 타입으로 새 폼을 연다.
        guard state.createSecret == nil else {
          state.pendingCreateType = secretType
          return .send(.createSecret(.didTapCancel))
        }
        // 사이드바 `+`와 같은 게이트를 태운다 — 빠지면 폼을 채운 뒤 저장에서 막혀 입력이 날아간다.
        state.pendingCreateType = secretType
        return .run { send in
          await send(.canCreateSecretResponse(Result {
            try await entitlementClient.canCreateSecret()
          }.mapError(SecretUseCaseError.map)))
        }
        .cancellable(id: CancelID.createGate, cancelInFlight: true)

      case .selectSecretType(.delegate(.typeSelected(let secretType))):
        state.createSecret = CreateSecretFeature.State(secretType: secretType)
        return .none

      case .selectSecretType:
        return .none

      // 컬럼만 접히고 뷰는 살아 있어 `.task`가 다시 돌지 않으므로 목록을 직접 다시 읽는다.
      case .createSecret(.delegate(.secretCreated(_))):
        exitCreating(&state)
        // `.merge`는 도착 순서를 보장하지 않아 순차 실행한다.
        return .concatenate(
          .send(.sidebar(.setCreatingSecret(false))),
          .send(.secretList(.refresh)),
          .send(.sidebar(.countsRefreshRequested))
        )

      // 자식끼리 직접 연결하지 않고 부모가 사이드바 재조회를 지시한다 (TCA_GUIDELINES 7.4).
      case .createSecret(.delegate(.projectsChanged)):
        return .send(.sidebar(.refresh))

      // 사이드바가 시작한 취소면 목록으로, 폼의 Cancel이면 타입 그리드로 — 목적지가 다르다.
      case .createSecret(.delegate(.cancelled)):
        // New▸로 다른 타입을 요청했으면 그 타입 폼을 새로 연다.
        if let secretType = state.pendingCreateType {
          state.pendingCreateType = nil
          return startCreating(secretType: secretType, &state)
        }
        guard let pending = state.pendingSelection else {
          state.createSecret = nil
          state.selectSecretType = .init()
          return .none
        }
        state.pendingSelection = nil
        applySelection(pending, &state)
        return .send(.sidebar(.setCreatingSecret(false)))

      // 목적지를 버리지 않으면 다음 폼 Cancel이 엉뚱하게 목록으로 나간다. 사이드바는 아직 안 움직여 되돌릴 게 없다.
      case .createSecret(.alert(.dismiss)):
        state.pendingSelection = nil
        state.pendingCreateType = nil
        return .none

      case .createSecret:
        return .none

      case .createProject(.presented(.delegate(.projectCreated(let item)))):
        state.createProject = nil
        // 생성 중이면 목록을 옮기지 않는다 — 마치고 엉뚱한 목록으로 돌아오게 된다.
        if case .browsing = state.sidebar.mode {
          state.sidebar.selection = .project(id: item.id)
          // 새 프로젝트는 아직 `sidebar.projects`에 없어 `applySelection`을 못 쓴다.
          state.secretDetail = nil
          state.secretList.retarget(to: .project(id: item.id), projectName: item.name)
        }
        return .send(.sidebar(.refresh))

      case .createProject:
        return .none

      case .delegate:
        return .none
      }
    }
    // `ifLet`이 메인 리듀서를 감싸야 자식이 먼저 돌고(부모가 자식 상태를 `nil`로 만들기 전에 자식 액션 처리),
    // 자식 State가 교체될 때 이전 자식의 effect를 취소한다. 체인이 길면 타입체크가 타임아웃 나서 둘로 나눴다.
    .presentationsA()
    .presentationsB()
  }
}

// MARK: - Presentations

private extension Reducer where State == MainFeature.State, Action == MainFeature.Action {

  func presentationsA() -> some Reducer<State, Action> {
    self.ifLet(\.selectSecretType, action: \.selectSecretType) {
      SelectSecretTypeFeature()
    }
    .ifLet(\.$createProject, action: \.createProject) {
      CreateProjectFeature()
    }
    .ifLet(\.$paywall, action: \.paywall) {
      DevaultProPaywallFeature()
    }
    .ifLet(\.$exportSecret, action: \.exportSecret) {
      ExportSecretSheetFeature()
    }
    .ifLet(\.$importPassword, action: \.importPassword) {
      ImportPasswordFeature()
    }
    .ifLet(\.$importFlow, action: \.importFlow) {
      ImportFlowFeature()
    }
  }

  func presentationsB() -> some Reducer<State, Action> {
    self.ifLet(\.createSecret, action: \.createSecret) {
      CreateSecretFeature()
    }
    .ifLet(\.secretDetail, action: \.secretDetail) {
      SecretDetailFeature()
    }
    .ifLet(\.settings, action: \.settings) {
      SettingsFeature()
    }
  }
}

// MARK: - Private

extension MainFeature {

  private func handleSidebarDelegate(
    _ state: inout State,
    delegate: SidebarFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    // 폼이 열려 있으면 입력이 있을 수 있어 취소 alert를 거친다. 타입 선택 단계는 입력이 없어 바로 나간다.
    case .selectionChanged(let selection):
      guard state.createSecret == nil else {
        state.pendingSelection = selection
        return .send(.createSecret(.didTapCancel))
      }
      applySelection(selection, &state)
      return .send(.sidebar(.setCreatingSecret(false)))

    // 폼이 열려 있으면 사이드바 선택처럼 확인을 거친다. `pendingSelection`을 두지 않으므로 확인되면 타입 선택으로 돌아간다.
    case .addButtonTapped:
      guard state.createSecret == nil else {
        return .send(.createSecret(.didTapCancel))
      }
      // 타입 선택을 열기 전에 묻는다 — 폼을 채운 뒤 저장에서 막으면 입력이 날아간다.
      return .run { send in
        await send(.canCreateSecretResponse(Result {
          try await entitlementClient.canCreateSecret()
        }.mapError(SecretUseCaseError.map)))
      }
      .cancellable(id: CancelID.createGate, cancelInFlight: true)

    case .addProjectTapped:
      // 생성 화면을 열기 전에 묻는다 — 채운 뒤 막으면 입력이 날아간다.
      return .run { send in
        await send(.canCreateProjectResponse(Result {
          try await entitlementClient.canCreateProject()
        }.mapError(ProjectUseCaseError.map)))
      }
      .cancellable(id: CancelID.createGate, cancelInFlight: true)

    case .settingsTapped:
      state.settings = .init()
      return .none

    // State를 갈아끼우면 목록이 버려진다. 판정 기준은 사이드바가 아니라 목록이 보고 있는 것이다 —
    // 둘은 어긋날 수 있어(생성 중) 사이드바를 보면 A의 목록에 B의 이름이 붙는다.
    case .projectRenamed(let item):
      if case .project(id: item.id) = state.secretList.collection {
        state.secretList.projectName = item.name
      }
      return .none

    case .exportProjectTapped(let id):
      return exportProjectEffect(id: id)
    }
  }

  /// 사이드바 메뉴와 목록 헤더 버튼이 같이 쓴다.
  private func exportProjectEffect(id: ProjectItem.ID) -> Effect<Action> {
    .run { send in
      do {
        let secrets = try await secretClient.fetchByQuery(SecretQuery(collection: .project(id: id)))
        await send(.projectExportSecretsFetched(.success(secrets.map(\.id))))
      } catch {
        await send(.projectExportSecretsFetched(.failure(SecretUseCaseError.map(error))))
      }
    }
  }

  /// 고른 곳이 이미 보고 있던 곳일 수 있어(생성 중 같은 필터 재선택) `retarget`을 거친다.
  /// 사이드바 이동도 여기서 한다 — `SidebarFeature.didSelect`는 생성 중일 때 알리기만 해서,
  /// 옮기지 않으면 `setCreatingSecret(false)`가 이전 자리를 강조해 목록과 어긋난다.
  private func applySelection(_ selection: SidebarSelection, _ state: inout State) {
    state.sidebar.selection = selection
    exitCreating(&state)
    state.secretDetail = nil
    let target = makeCollection(selection: selection, projects: state.sidebar.projects)
    state.secretList.retarget(to: target.collection, projectName: target.projectName)
  }

  /// New▸ 진입 — 타입 그리드를 건너뛴다. 조회 중이던 상세를 놓아 스테일 상세가 되살아나는 것을 막는다.
  private func startCreating(secretType: CreatableSecretType, _ state: inout State) -> Effect<Action> {
    state.selectSecretType = nil
    state.createSecret = CreateSecretFeature.State(secretType: secretType)
    state.secretDetail = nil
    state.secretList.selectedSecretID = nil
    return .send(.sidebar(.setCreatingSecret(true)))
  }

  /// 조회 중이던 시크릿도 놓는다 — 상세 State가 살아남으면 돌아올 때 되살아나 `.task(id:)`가 Touch ID를 다시 요구한다.
  private func enterCreating(_ state: inout State) {
    state.createSecret = nil
    state.selectSecretType = .init()
    state.secretDetail = nil
    state.secretList.selectedSecretID = nil
  }

  /// 한쪽만 남으면 `screen`이 `.creating`으로 판정돼 컬럼이 접힌 채 남는다.
  private func exitCreating(_ state: inout State) {
    state.createSecret = nil
    state.selectSecretType = nil
  }

  /// 교체 여부는 `SecretListFeature.State.retarget(to:projectName:)`이 정하므로 값만 돌려준다.
  private func makeCollection(
    selection: SidebarSelection,
    projects: IdentifiedArrayOf<ProjectItem>
  ) -> (collection: SecretQuery.Collection, projectName: String?) {
    switch selection {
    case .filter(.all):
      return (.all, nil)
    case .filter(.starred):
      return (.liked, nil)
    case .filter(.notice):
      return (.notice(referenceDate: now), nil)
    case .filter(.expired):
      return (.expired(referenceDate: now), nil)
    case .filter(.deleted):
      return (.deleted, nil)
    case .project(id: let id):
      return (.project(id: id), projects[id: id]?.name)
    }
  }

  /// 활성 저장소의 내용이 교체되거나 초기화됐을 때 이전 저장소에서 파생된 화면 상태를 버린다.
  private func resetVaultContent(_ state: inout State) {
    state.selectSecretType = nil
    state.createProject = nil
    state.createSecret = nil
    state.secretDetail = nil
    // 여기서 폼을 닫으면 `.alert(.dismiss)`가 다시 올 일이 없어 목적지가 영영 남는다.
    state.pendingSelection = nil
    state.pendingCreateType = nil
    state.sidebar.mode = .browsing(.filter(.all))
    state.secretList = .init(collection: .all)
  }
}
