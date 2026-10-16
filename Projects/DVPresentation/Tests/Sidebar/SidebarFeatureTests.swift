// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("SidebarFeature")
struct SidebarFeatureTests {

  /// Expired 카운트 기준 시각. `@Dependency(\.date.now)`를 고정해 집계 쿼리를 결정적으로 만든다.
  static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

  // MARK: - Fetch

  @Test("task는 프로젝트 목록을 fetch해 이름 순으로 정렬한다")
  func taskFetchesSortedProjects() async {
    let projects = [
      ProjectItem(id: UUID(), name: "Mobile"),
      ProjectItem(id: UUID(), name: "Backend"),
    ]
    let counts = SecretCounts(byFilter: [.all: 5], byProject: [:])
    let store = TestStore(initialState: SidebarFeature.State()) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { projects }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.task) {
      $0.projectsState = .loading
      $0.countsState = .loading
    }
    await store.receive(.projectsResponse(.success(projects))) {
      $0.projectsState = .loaded(IdentifiedArray(uniqueElements: [
        ProjectItem(id: projects[1].id, name: "Backend"),
        ProjectItem(id: projects[0].id, name: "Mobile"),
      ]))
    }
    await store.receive(.countsResponse(.success(counts))) {
      $0.countsState = .loaded(counts)
    }
  }

  @Test("projectsResponse에 같은 id 중복이 와도 크래시 없이 하나로 합쳐진다")
  func taskDeduplicatesProjectsById() async {
    // CloudKit이 같은 id의 중복 레코드를 만들 수 있다. 방어가 없으면 IdentifiedArray가 fatalError.
    let id = UUID()
    let projects = [
      ProjectItem(id: id, name: "Backend"),
      ProjectItem(id: id, name: "Backend copy"),
    ]
    let counts = SecretCounts(byFilter: [.all: 5], byProject: [:])
    let store = TestStore(initialState: SidebarFeature.State()) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { projects }
      $0.sidebarClient.fetchCounts = { _, projectIDs in
        // 중복 id가 와도 카운트 조회는 고유한 id로만 이뤄져야 한다(같은 프로젝트 중복 조회 방지).
        #expect(projectIDs == [id])
        return counts
      }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.task) {
      $0.projectsState = .loading
      $0.countsState = .loading
    }
    // 이름 정렬 후 같은 id 중 첫 항목("Backend")만 남는다.
    await store.receive(.projectsResponse(.success(projects))) {
      $0.projectsState = .loaded(IdentifiedArray(uniqueElements: [
        ProjectItem(id: id, name: "Backend"),
      ]))
    }
    await store.receive(.countsResponse(.success(counts))) {
      $0.countsState = .loaded(counts)
    }
  }

  /// 화면이 다시 만들어지면 `.task`가 한 번 더 실행된다. 여기서 `.loading`으로 되돌리면 깜빡인다.
  @Test("이미 로드된 상태에서 task가 다시 실행돼도 값을 비우지 않는다")
  func taskAfterReloadKeepsLoadedValues() async {
    let projects = [ProjectItem(id: UUID(), name: "Backend")]
    let counts = SecretCounts(byFilter: [.all: 5], byProject: [:])

    var initial = SidebarFeature.State()
    initial.projectsState = .loaded(IdentifiedArray(uniqueElements: projects))
    initial.countsState = .loaded(counts)

    let store = TestStore(initialState: initial) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { projects }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }

    // `projectsState`·`countsState`를 단언하지 않는 것 자체가 검증이다 — 바뀌면 전수 검사에 걸린다.
    await store.send(.task) {
      $0.isRefreshingProjects = true
    }
    await store.receive(.projectsResponse(.success(projects))) {
      $0.isRefreshingProjects = false
    }
    await store.receive(.countsResponse(.success(counts)))
  }

  @Test("task fetch 실패 시 projectsState가 .failed로 전환된다")
  func taskFetchFailureSetsFailedState() async {
    let counts = SecretCounts(byFilter: [.all: 5], byProject: [:])
    let store = TestStore(initialState: SidebarFeature.State()) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { throw SidebarError.fetchFailed }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.task) {
      $0.projectsState = .loading
      $0.countsState = .loading
    }
    await store.receive(.projectsResponse(.failure(.fetchFailed))) {
      $0.projectsState = .failed(.fetchFailed)
    }
    // 프로젝트 목록이 실패해도 필터 카드 개수는 독립적으로 집계된다.
    await store.receive(.countsResponse(.success(counts))) {
      $0.countsState = .loaded(counts)
    }
  }

  // MARK: - Counts

  @Test("초기 countsState는 idle이라 '로드 전'과 '0건'이 구분된다")
  func initialCountsStateIsIdle() {
    let state = SidebarFeature.State()

    #expect(state.countsState == .idle)
    #expect(state.counts == nil)
  }

  @Test("countsRefreshRequested는 현재 프로젝트 ID로 개수를 다시 집계한다")
  func countsRefreshRequestedRecountsWithCurrentProjects() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])

    let counts = SecretCounts(byFilter: [.all: 7], byProject: [item.id: 2])
    let store = TestStore(initialState: state) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchCounts = { date, projectIDs in
        #expect(date == Self.referenceDate)
        #expect(projectIDs == [item.id])
        return counts
      }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.countsRefreshRequested)
    await store.receive(.countsResponse(.success(counts))) {
      $0.countsState = .loaded(counts)
      #expect($0.counts?.count(for: .all) == 7)
      #expect($0.counts?.count(forProject: item.id) == 2)
    }
  }

  @Test("카운트 집계 실패 시 countsState가 .failed로 전환된다")
  func countsFailureSetsFailedState() async {
    let store = TestStore(initialState: SidebarFeature.State()) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.fetchCounts = { _, _ in throw SidebarError.fetchFailed }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.countsRefreshRequested)
    await store.receive(.countsResponse(.failure(.fetchFailed))) {
      $0.countsState = .failed(.fetchFailed)
      #expect($0.counts == nil)
    }
  }

  // MARK: - Selection

  @Test("didSelect는 selection을 바꾸고 delegate를 발송한다")
  func didSelectChangesSelectionAndSendsDelegate() async {
    let id = UUID()
    let store = TestStore(
      initialState: SidebarFeature.State()
    ) {
      SidebarFeature()
    }

    await store.send(.didSelect(.project(id: id))) {
      $0.selection = .project(id: id)
    }
    await store.receive(.delegate(.selectionChanged(.project(id: id))))
  }

  /// `selection`으로 판정하면 "같은 선택"으로 삼켜져 All에서 생성에 들어가면 돌아오지 못했다.
  @Test("생성 중에는 같은 항목을 다시 눌러도 delegate가 나간다")
  func didSelectSameItemWhileCreatingStillNotifies() async {
    var state = SidebarFeature.State()
    state.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: state) { SidebarFeature() }

    await store.send(.didSelect(.filter(.all)))
    await store.receive(.delegate(.selectionChanged(.filter(.all))))
    #expect(store.state.highlighted == nil)
  }

  /// 여기서 갈아두면 되돌릴 방법이 없어, 부모의 확인에서 "계속 편집"을 골라도
  /// 생성을 마쳤을 때 강조는 새 항목인데 목록은 원래 것이 남는다.
  @Test("생성 중의 선택은 돌아갈 곳을 바꾸지 않고 알리기만 한다")
  func didSelectWhileCreatingKeepsReturnDestination() async {
    var state = SidebarFeature.State()
    state.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: state) { SidebarFeature() }

    await store.send(.didSelect(.filter(.starred)))
    await store.receive(.delegate(.selectionChanged(.filter(.starred))))
    #expect(store.state.mode == .creating(previous: .filter(.all)))
    #expect(store.state.highlighted == nil)
  }

  @Test("setCreatingSecret은 강조만 끄고 돌아갈 곳은 유지한다")
  func setCreatingSecretKeepsReturnDestination() async {
    var state = SidebarFeature.State()
    state.mode = .browsing(.filter(.starred))

    let store = TestStore(initialState: state) { SidebarFeature() }

    await store.send(.setCreatingSecret(true)) {
      $0.mode = .creating(previous: .filter(.starred))
    }
    #expect(store.state.highlighted == nil)
    #expect(store.state.selection == .filter(.starred))

    await store.send(.setCreatingSecret(false)) {
      $0.mode = .browsing(.filter(.starred))
    }
    #expect(store.state.highlighted == .filter(.starred))
  }

  /// 대상 ID가 남으면 다음 삭제가 엉뚱한 프로젝트를 지울 수 있다.
  @Test("삭제 alert를 확인 없이 닫으면 대상이 지워진다")
  func dismissingDeleteAlertClearsTarget() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])

    let store = TestStore(initialState: state) { SidebarFeature() }

    await store.send(.didTapDelete(id: item.id)) {
      $0.deletingProjectID = item.id
      $0.alert = AlertState {
        TextState(String.module("Delete project '\(item.name)'?"))
      } actions: {
        ButtonState(role: .destructive, action: .confirmDelete) { TextState(String.module("Delete")) }
        ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
      } message: {
        TextState(String.module("Deleting this project will unlink its secrets. The secrets themselves won't be deleted."))
      }
    }
    await store.send(.alert(.dismiss)) {
      $0.deletingProjectID = nil
      $0.alert = nil
    }
  }

  /// 흘려보내면 MainFeature가 목록 State를 새로 만드는데, `collection`이 그대로라
  /// `.task(id:)`가 재조회를 걸지 않아 목록이 빈 채로 남는다.
  @Test("이미 선택된 항목을 다시 눌러도 delegate를 보내지 않는다")
  func didSelectSameSelectionSendsNothing() async {
    // 기본 selection이 .filter(.all)이므로 그대로 다시 누른다.
    let store = TestStore(
      initialState: SidebarFeature.State()
    ) {
      SidebarFeature()
    }

    await store.send(.didSelect(.filter(.all)))
  }

  @Test("같은 프로젝트를 다시 눌러도 delegate를 보내지 않는다")
  func didSelectSameProjectSendsNothing() async {
    let id = UUID()
    var initial = SidebarFeature.State()
    initial.selection = .project(id: id)

    let store = TestStore(initialState: initial) {
      SidebarFeature()
    }

    await store.send(.didSelect(.project(id: id)))
  }

  // MARK: - Rename

  @Test("didTapRename은 renameText를 프로젝트 이름으로 세팅한다")
  func didTapRenameSetRenameText() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    await store.send(.didTapRename(id: item.id)) {
      $0.renamingProjectID = item.id
      $0.renameText = "Backend"
    }
  }

  @Test("didTapExportProject는 delegate로 알리기만 한다")
  func didTapExportProjectSendsDelegate() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    await store.send(.didTapExportProject(id: item.id))
    await store.receive(.delegate(.exportProjectTapped(id: item.id)))
  }

  @Test("didConfirmRename 성공 시 delegate를 발송하고 refetch한다")
  func didConfirmRenameSuccessDelegate() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    let renamed = ProjectItem(id: item.id, name: "Backend V2")

    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])
    state.renamingProjectID = item.id
    state.renameText = "Backend V2"

    let store = TestStore(initialState: state) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.renameProject = { _, _ in renamed }
      $0.sidebarClient.fetchProjects = { [renamed] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    // 편집 상태는 성공 응답에서 닫힌다.
    await store.send(.didConfirmRename)
    await store.receive(.renameResponse(projectID: item.id, .success(renamed))) {
      $0.renamingProjectID = nil
      $0.renameText = ""
    }
    await store.receive(.delegate(.projectRenamed(renamed)))
    await store.receive(.refresh) {
      $0.isRefreshingProjects = true
    }
    await store.receive(.projectsResponse(.success([renamed]))) {
      $0.isRefreshingProjects = false
      $0.projectsState = .loaded([renamed])
    }
    await store.receive(.countsResponse(.success(SecretCounts()))) {
      $0.countsState = .loaded(SecretCounts())
    }
  }

  @Test("didConfirmRename에서 nameTaken 오류 시 alert를 띄우고 편집을 닫아 원래 이름으로 되돌린다")
  func didConfirmRenameNameTakenShowsAlertAndReverts() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])
    state.renamingProjectID = item.id
    state.renameText = "Mobile"

    let store = TestStore(initialState: state) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.renameProject = { _, _ in throw SidebarError.nameTaken }
    }

    // 이름 중복이면 저장을 막고 편집을 닫아 원래 이름으로 되돌린다.
    await store.send(.didConfirmRename)
    await store.receive(.renameResponse(projectID: item.id, .failure(.nameTaken))) {
      $0.alert = AlertState {
        TextState(String.module("This name is already in use."))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Please enter a different project name."))
      }
      $0.renamingProjectID = nil
      $0.renameText = ""
    }
  }

  @Test("편집 대상이 바뀐 뒤 도착한 이전 이름 변경의 nameTaken 응답은 현재 편집을 건드리지 않는다")
  func staleRenameResponseDoesNotDisturbCurrentEdit() async {
    let editingID = UUID()  // 지금 편집 중인 프로젝트(B)
    let staleID = UUID()    // 이전에 확정했던 프로젝트(A)

    var state = SidebarFeature.State()
    state.renamingProjectID = editingID
    state.renameText = "편집 중"

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    // A(staleID)의 뒤늦은 nameTaken 응답 — 지금은 B를 편집 중이므로 무시되어야 한다(상태 변화·alert 없음).
    await store.send(.renameResponse(projectID: staleID, .failure(.nameTaken)))
  }

  @Test("didConfirmRename에 빈 이름이면 alert를 띄우고 편집을 닫아 원래 이름으로 되돌린다")
  func didConfirmRenameEmptyShowsAlertAndReverts() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])
    state.renamingProjectID = item.id
    state.renameText = "   "  // 공백만 → trim 후 빈 문자열

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    await store.send(.didConfirmRename) {
      $0.alert = AlertState {
        TextState(String.module("Please enter a name."))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("Project name can't be empty."))
      }
      $0.renamingProjectID = nil
      $0.renameText = ""
    }
  }

  @Test("didCancelRename은 rename 상태를 초기화한다")
  func didCancelRenameResetsState() async {
    var state = SidebarFeature.State()
    state.renamingProjectID = UUID()
    state.renameText = "Some Name"

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    await store.send(.didCancelRename) {
      $0.renamingProjectID = nil
      $0.renameText = ""
    }
  }

  // MARK: - Delete

  @Test("didTapDelete는 alert를 표시한다")
  func didTapDeleteShowsAlert() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])

    let store = TestStore(initialState: state) {
      SidebarFeature()
    }

    await store.send(.didTapDelete(id: item.id)) {
      $0.deletingProjectID = item.id
      $0.alert = AlertState {
        TextState(String.module("Delete project '\(item.name)'?"))
      } actions: {
        ButtonState(role: .destructive, action: .confirmDelete) { TextState(String.module("Delete")) }
        ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
      } message: {
        TextState(String.module("Deleting this project will unlink its secrets. The secrets themselves won't be deleted."))
      }
    }
  }

  @Test("삭제 확인 후 선택 중이던 프로젝트면 selection이 .all로 초기화되고 refetch한다")
  func deleteResetsSelectionAndRefetches() async {
    let item = ProjectItem(id: UUID(), name: "Backend")

    var state = SidebarFeature.State()
    state.projectsState = .loaded([item])
    state.selection = .project(id: item.id)
    state.deletingProjectID = item.id
    state.alert = AlertState {
      TextState(String.module("Delete project '\(item.name)'?"))
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) { TextState(String.module("Delete")) }
      ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
    } message: {
      TextState(String.module("Deleting this project will unlink its secrets. The secrets themselves won't be deleted."))
    }

    let store = TestStore(initialState: state) {
      SidebarFeature()
    } withDependencies: {
      $0.sidebarClient.deleteProject = { _ in }
      $0.sidebarClient.fetchProjects = { [] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.deletingProjectID = nil
      $0.alert = nil
    }
    await store.receive(.deleteResponse(.success(item.id))) {
      $0.selection = .filter(.all)
    }
    await store.receive(.delegate(.selectionChanged(.filter(.all))))
    await store.receive(.refresh) {
      $0.isRefreshingProjects = true
    }
    await store.receive(.projectsResponse(.success([]))) {
      $0.isRefreshingProjects = false
      $0.projectsState = .loaded([])
    }
    await store.receive(.countsResponse(.success(SecretCounts()))) {
      $0.countsState = .loaded(SecretCounts())
    }
  }
}
