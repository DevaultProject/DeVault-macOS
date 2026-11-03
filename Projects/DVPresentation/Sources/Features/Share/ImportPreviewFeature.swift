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
    public let payload: DevaultContainerPayload
    public internal(set) var selectedIndices: Set<Int>
    public internal(set) var availableProjects: [Project] = []
    public internal(set) var projectChoice: ImportProjectChoice
    public internal(set) var remainingSlots: Int?
    public internal(set) var duplicateIndices: Set<Int> = []
    /// "Create new project" 라디오 게이트 — Project 변형에서만 묻는다. 응답 전까지는 막지 않는다(깜빡임 방지).
    public internal(set) var canCreateNewProject = true

    public init(payload: DevaultContainerPayload) {
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

    public var variant: Variant {
      // projectName이 있으면 "프로젝트 공유" 진입점에서 온 것 — 그 프로젝트가 시크릿을 하나만
      // 갖고 있어도 Single이 아니라 Project다(사용자가 명시적으로 프로젝트 단위를 골랐다).
      if let name = payload.projectName { return .project(name: name) }
      if payload.secrets.count == 1 { return .single }
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

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case proceedWithoutDuplicates(payload: DevaultContainerPayload, project: ImportProjectChoice)
      case duplicatesFound(payload: DevaultContainerPayload, judgement: ImportDuplicateJudgement, project: ImportProjectChoice)
      case paywallRequired
      case cancelled
    }
  }

  /// `ProjectUseCaseError` 같은 구체 에러를 Action에 직접 담으면 Equatable 합성이 막히므로 지운다.
  public struct ProjectFetchError: Error, Equatable {
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
            let slots = try? await entitlementClient.remainingSecretSlots()
            await send(.slotsResponse(slots ?? nil))
          },
          canCreateProjectEffect(state: state),
          judgeEffect(state: state)
        )

      case let .projectsResponse(.success(projects)):
        state.availableProjects = projects
        // 같은 이름의 프로젝트가 이미 있으면 Merge를, 없으면 Create new를 기본 선택한다.
        if case .create(let name) = state.projectChoice,
           let existing = projects.first(where: { $0.name == name }) {
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
        return judgeEffect(state: state)

      case .didToggleSelectAll:
        if state.selectedIndices.count == state.payload.secrets.count {
          state.selectedIndices.removeAll()
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
        if !allowed, case .create = state.projectChoice {
          if let existing = state.availableProjects.first(where: { $0.name == projectName(state) }) {
            state.projectChoice = .existing(id: existing.id)
          } else {
            state.projectChoice = .none
          }
        }
        return .none

      case .didTapImport:
        let filtered = filteredPayload(state)
        return .run { [projectChoice = state.projectChoice] send in
          let judgement = try await shareClient.judgeDuplicates(filtered, [:])
          let allowed = try await entitlementClient.canImportSecrets(judgement.slotsConsumed(by: [:]))
          guard allowed else {
            await send(.delegate(.paywallRequired))
            return
          }
          if judgement.conflicts.isEmpty {
            await send(.delegate(.proceedWithoutDuplicates(payload: filtered, project: projectChoice)))
          } else {
            await send(.delegate(.duplicatesFound(payload: filtered, judgement: judgement, project: projectChoice)))
          }
        }

      case .didTapCancel:
        return .send(.delegate(.cancelled))

      case .delegate:
        return .none
      }
    }
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

  private func projectName(_ state: State) -> String? {
    if case .project(let name) = state.variant { return name }
    return nil
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
}
