// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - ImportPreviewFeature

@Reducer
public struct ImportPreviewFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public let fileName: String
    public let payload: DevaultContainerPayload
    public internal(set) var selectedIndices: Set<Int>
    public internal(set) var availableProjects: [Project] = []
    public internal(set) var projectChoice: ImportProjectChoice
    public internal(set) var remainingSlots: Int?
    public internal(set) var duplicateIndices: Set<Int> = []
    /// "Create new project" 라디오 게이트 — Project 변형에서만 묻는다. 응답 전까지는 막지 않는다(깜빡임 방지).
    public internal(set) var canCreateNewProject = true
    /// didTapImport 연타 방지 — 판정·게이트 왕복이 끝날 때까지 다시 누를 수 없다.
    public internal(set) var isCheckingImport = false
    @Presents public var alert: AlertState<Action.Alert>?

    public init(fileName: String, payload: DevaultContainerPayload) {
      self.fileName = fileName
      self.payload = payload
      self.selectedIndices = Set(payload.secrets.indices)
      if let name = payload.projectName {
        self.projectChoice = .create(name: name)
      } else {
        self.projectChoice = .none
      }
    }

    /// Figma 3종 분기 — 단일, 프로젝트 단위 공유, 여러 출처 섞임.
    public enum Variant: Equatable {
      case single
      case project(name: String)
      case multiple
    }

    /// 합의된 우선순위: 시크릿이 하나면 그 출처가 프로젝트든 아니든 Single이다 — 멀티선택이 우연히
    /// 같은 프로젝트에 걸쳐도 projectName이 채워지므로(#201), count 체크가 반드시 먼저여야 한다.
    public var variant: Variant {
      if payload.secrets.count == 1 { return .single }
      if let name = payload.projectName { return .project(name: name) }
      return .multiple
    }

    /// 프로젝트 라디오가 보이는 변형인지 — Multiple은 출처가 섞여 있어 연결 자체를 안 보여준다.
    public var showsProjectSelection: Bool {
      if case .multiple = variant { return false }
      return true
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case task
    case didToggleSelection(index: Int)
    case didToggleSelectAll
    case didSelectProjectChoice(ImportProjectChoice)
    case didTapImport
    case didTapCancel

    // MARK: - Internal

    case projectsResponse(Result<[Project], ProjectFetchError>)
    case slotsResponse(Int?)
    case judgementResponse(ImportDuplicateJudgement)
    case canCreateProjectResponse(Bool)
    case importCheckResponse(Result<ImportCheckResult, ImportCheckError>)

    // MARK: - Child

    case alert(PresentationAction<Alert>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case proceedWithoutDuplicates(payload: DevaultContainerPayload, project: ImportProjectChoice)
      case duplicatesFound(payload: DevaultContainerPayload, judgement: ImportDuplicateJudgement, project: ImportProjectChoice)
      case paywallRequired
      case cancelled
    }

    public enum Alert: Equatable {}
  }

  /// `didTapImport`가 재판정한 뒤 어디로 보낼지 — 중복이 있으면 게이트①을 건너뛴다(중복 항목은
  /// 실제로 슬롯을 안 쓸 수 있어 섣불리 막으면 과잉 차단이다). execute의 게이트②가 실해결 반영 뒤 다시 본다.
  public enum ImportCheckResult: Equatable {
    case proceed(payload: DevaultContainerPayload, project: ImportProjectChoice)
    case duplicates(payload: DevaultContainerPayload, judgement: ImportDuplicateJudgement, project: ImportProjectChoice)
    case blocked
  }

  /// `ProjectUseCaseError`·`ShareClient` 구체 에러를 Action에 직접 담으면 Equatable 합성이 막히므로 지운다.
  public struct ProjectFetchError: Error, Equatable {
    public init() {}
  }

  public struct ImportCheckError: Error, Equatable {
    public init() {}
  }

  // MARK: - Dependencies

  @Dependency(\.projectClient) var projectClient
  @Dependency(\.entitlementClient) var entitlementClient
  @Dependency(\.shareClient) var shareClient

  // MARK: - Init

  public init() {}

  // MARK: - Cancellation

  private enum CancelID {
    case judge
  }

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .merge(
          .run { send in
            do {
              let projects = try await projectClient.fetchProjects()
              await send(.projectsResponse(.success(projects)))
            } catch {
              await send(.projectsResponse(.failure(ProjectFetchError())))
            }
          },
          .run { send in
            // 실패하면 nil 그대로 둔다 — Pro(무제한)와 같은 표시(배지 숨김)가 되지만,
            // 저장소가 깨진 드문 경우라 추가 UI 분기를 두지 않았다.
            guard let slots = try? await entitlementClient.remainingSecretSlots() else { return }
            await send(.slotsResponse(slots))
          },
          canCreateProjectEffect(state: state),
          judgeEffect(state: state)
        )

      case let .projectsResponse(.success(projects)):
        state.availableProjects = projects
        // 같은 이름의 프로젝트가 이미 있으면 Merge를, 없으면 Create new를 기본 선택한다.
        // 대소문자를 구분하면 "drinkig"와 기존 "DrinkiG"를 못 알아봐 화면은 Create new인데
        // execute(ProjectNameRule 기준)는 합류해 화면·실행이 어긋난다(#188과 같은 버그).
        if case .create(let name) = state.projectChoice,
           let key = ProjectNameRule.comparisonKey(name),
           let existing = projects.first(where: { ProjectNameRule.comparisonKey($0.name) == key }) {
          state.projectChoice = .existing(id: existing.id)
        }
        return .none

      case .projectsResponse(.failure):
        return .none

      case let .slotsResponse(slots):
        state.remainingSlots = slots
        return .none

      case let .didToggleSelection(index):
        if state.selectedIndices.contains(index) {
          state.selectedIndices.remove(index)
        } else {
          state.selectedIndices.insert(index)
        }
        if state.selectedIndices.isEmpty { state.duplicateIndices = [] }
        return judgeEffect(state: state)

      case .didToggleSelectAll:
        if state.selectedIndices.count == state.payload.secrets.count {
          state.selectedIndices.removeAll()
          state.duplicateIndices = []
        } else {
          state.selectedIndices = Set(state.payload.secrets.indices)
        }
        return judgeEffect(state: state)

      case let .didSelectProjectChoice(choice):
        state.projectChoice = choice
        return .none

      case let .judgementResponse(judgement):
        state.duplicateIndices = Set(judgement.conflicts.map { selectedOriginalIndex(at: $0.index, in: state) })
        return .none

      case let .canCreateProjectResponse(allowed):
        state.canCreateNewProject = allowed
        // 막혀 있는데 Create new가 기본 선택돼 있으면 Merge(있으면)나 Without project로 내려 사용자가
        // 비활성 라디오에 묶이지 않게 한다.
        if !allowed, case .create(let name) = state.projectChoice {
          if let key = ProjectNameRule.comparisonKey(name),
             let existing = state.availableProjects.first(where: { ProjectNameRule.comparisonKey($0.name) == key }) {
            state.projectChoice = .existing(id: existing.id)
          } else {
            state.projectChoice = .none
          }
        }
        return .none

      case .didTapImport:
        guard !state.isCheckingImport, !state.selectedIndices.isEmpty else { return .none }
        state.isCheckingImport = true
        let filtered = filteredPayload(state)
        return .run { [projectChoice = state.projectChoice] send in
          do {
            let judgement = try await shareClient.judgeDuplicates(filtered, [:])
            guard judgement.conflicts.isEmpty else {
              await send(.importCheckResponse(.success(.duplicates(payload: filtered, judgement: judgement, project: projectChoice))))
              return
            }
            // 중복이 없을 때만 게이트①을 본다 — 중복이 있으면 해결(덮어쓰기·건너뛰기)에 따라
            // 실제 슬롯 소모가 달라지므로, 여기서 빈 resolutions로 판단하면 과잉 차단된다.
            let allowed = try await entitlementClient.canImportSecrets(judgement.slotsConsumed(by: [:]))
            guard allowed else {
              await send(.importCheckResponse(.success(.blocked)))
              return
            }
            await send(.importCheckResponse(.success(.proceed(payload: filtered, project: projectChoice))))
          } catch {
            await send(.importCheckResponse(.failure(ImportCheckError())))
          }
        }

      case let .importCheckResponse(.success(result)):
        state.isCheckingImport = false
        switch result {
        case let .proceed(payload, project):
          return .send(.delegate(.proceedWithoutDuplicates(payload: payload, project: project)))
        case let .duplicates(payload, judgement, project):
          return .send(.delegate(.duplicatesFound(payload: payload, judgement: judgement, project: project)))
        case .blocked:
          return .send(.delegate(.paywallRequired))
        }

      case .importCheckResponse(.failure):
        state.isCheckingImport = false
        state.alert = importCheckFailureAlert
        return .none

      case .didTapCancel:
        return .send(.delegate(.cancelled))

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

extension ImportPreviewFeature {

  /// 선택된 항목만 걸러낸 payload — 이후 모든 단계(중복 판정·Review Duplicates·execute)의 기준이 된다.
  private func filteredPayload(_ state: State) -> DevaultContainerPayload {
    let indices = state.selectedIndices.sorted()
    return DevaultContainerPayload(
      projectName: state.payload.projectName,
      secrets: indices.map { state.payload.secrets[$0] }
    )
  }

  /// `judgementResponse`의 conflict.index(필터링된 payload 기준)를 원본 payload의 인덱스로 되돌린다 —
  /// 행 하이라이트는 원본 리스트를 그리므로 원본 인덱스가 필요하다.
  private func selectedOriginalIndex(at filteredIndex: Int, in state: State) -> Int {
    state.selectedIndices.sorted()[filteredIndex]
  }

  /// Project 변형에서만 묻는다 — Single/Multiple은 "Create new project" 선택지 자체가 없다.
  private func canCreateProjectEffect(state: State) -> Effect<Action> {
    guard case .project = state.variant else { return .none }
    return .run { send in
      let allowed = (try? await entitlementClient.canCreateProject()) ?? true
      await send(.canCreateProjectResponse(allowed))
    }
  }

  private func judgeEffect(state: State) -> Effect<Action> {
    guard !state.selectedIndices.isEmpty else { return .cancel(id: CancelID.judge) }
    let filtered = filteredPayload(state)
    return .run { send in
      guard let judgement = try? await shareClient.judgeDuplicates(filtered, [:]) else { return }
      await send(.judgementResponse(judgement))
    }
    .cancellable(id: CancelID.judge, cancelInFlight: true)
  }

  var importCheckFailureAlert: AlertState<Action.Alert> {
    AlertState {
      TextState(String.module("Couldn't Check Secrets"))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module("OK")) }
    } message: {
      TextState(String.module("Please try again in a moment."))
    }
  }
}
