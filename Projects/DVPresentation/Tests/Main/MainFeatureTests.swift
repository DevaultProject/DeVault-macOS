// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("MainFeature")
struct MainFeatureTests {

  /// 사이드바 카운트 집계의 기준 시각을 고정한다.
  static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

  nonisolated static func makeSecret(name: String = "Test Token") -> Secret {
    Secret(
      id: UUID(),
      name: name,
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )
  }

  // MARK: - Screen 판정

  /// 화면 분기가 이 값 하나에 걸려 있다.
  @Test("screen: 아무것도 없으면 browsing")
  func screenDefaultsToBrowsing() {
    #expect(MainFeature.State().screen == .browsing)
  }

  @Test("screen: 타입 선택만 있어도, 폼만 있어도 creating")
  func screenIsCreatingForBothCreationSteps() {
    var selecting = MainFeature.State()
    selecting.selectSecretType = .init()
    #expect(selecting.screen == .creating)

    var form = MainFeature.State()
    form.createSecret = .init(secretType: .apiKeyToken)
    #expect(form.screen == .creating)
  }

  @Test("screen: 설정이 생성보다 우선한다")
  func screenPrefersSettingsOverCreating() {
    var state = MainFeature.State()
    state.selectSecretType = .init()
    state.settings = .init()
    #expect(state.screen == .settings)
  }

  @Test("screen: 상세가 열려 있어도 browsing이다")
  func screenStaysBrowsingWithDetail() {
    var state = MainFeature.State()
    state.secretDetail = .init(secret: Self.makeSecret())
    #expect(state.screen == .browsing)
  }

  // MARK: - Count Refresh

  @Test("secretList의 secretsChanged 델리게이트는 사이드바 카운트를 다시 세게 한다")
  func secretsChangedRefreshesSidebarCounts() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    let counts = SecretCounts(byFilter: [.all: 3], byProject: [item.id: 1])

    var initial = MainFeature.State()
    initial.sidebar.projectsState = .loaded([item])

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchCounts = { _, projectIDs in
        #expect(projectIDs == [item.id])
        return counts
      }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.secretList(.delegate(.secretsChanged)))
    await store.receive(.sidebar(.countsRefreshRequested))
    await store.receive(.sidebar(.countsResponse(.success(counts)))) {
      $0.sidebar.countsState = .loaded(counts)
    }
  }

  // MARK: - List Menu Delete/Recover → Detail Sync

  /// 리스트 메뉴로 지금 조회 중인 시크릿을 삭제하면, `SecretListFeature`가 재조회 후 남은
  /// 목록의 맨 위 항목으로 스스로 재선택하고 `.secretSelected`를 보낸다 — `MainFeature`는
  /// 기존 `secretSelected` 처리(위 SecretDetail Routing 섹션)를 그대로 타므로 새 시크릿으로
  /// 조회뷰가 자동으로 옮겨간다.
  /// 자식(`SecretListFeature`)의 재선택 concatenate와 부모가 델리게이트에 반응해 붙이는
  /// 사이드바 카운트 갱신이 뒤섞여 정확한 도착 순서를 안전하게 단정할 수 없다 —
  /// 최종 상태만 확인한다.
  @Test("리스트 메뉴로 조회 중인 시크릿을 삭제하면 남은 목록의 맨 위 항목으로 조회뷰가 옮겨간다")
  func listMenuDeleteOfViewedSecretMovesDetailToTopOfRemainingList() async {
    let deleted = Self.makeSecret(name: "삭제될 시크릿")
    let remainingTop = Self.makeSecret(name: "남은 시크릿 1")
    let remainingBottom = Self.makeSecret(name: "남은 시크릿 2")
    let counts = SecretCounts(byFilter: [.all: 2], byProject: [:])

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([deleted, remainingTop, remainingBottom])
    initial.secretList.selectedSecretID = deleted.id
    initial.secretDetail = SecretDetailFeature.State(secret: deleted)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.softDelete = { _ in deleted }
      $0.secretClient.fetchByQuery = { _ in [remainingTop, remainingBottom] }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.secretList(.didTapDelete(id: deleted.id)))
    // .off 모드에서 finish()는 effect가 보낸 액션을 state에 reduce하지 않는다. 종단 액션을
    // 명시적으로 receive해 그 앞의 재조회·재선택 체인을 모두 굴린 뒤 최종 상태만 확인한다.
    await store.receive(.secretList(.delegate(.secretSelected(remainingTop.id))))
    await store.finish()

    #expect(store.state.secretList.secretsState == .loaded([remainingTop, remainingBottom]))
    #expect(store.state.secretList.selectedSecretID == remainingTop.id)
    #expect(store.state.secretDetail?.secret.id == remainingTop.id)
  }

  /// 남은 항목이 없으면 갈 곳이 없으므로 조회뷰를 닫는다 — 기존 `secretSelected(nil)` 처리와 동일하다.
  @Test("리스트 메뉴로 조회 중인 마지막 시크릿을 삭제하면 조회뷰가 닫힌다")
  func listMenuDeleteOfLastViewedSecretClosesDetail() async {
    let deleted = Self.makeSecret(name: "삭제될 시크릿")
    let counts = SecretCounts(byFilter: [.all: 0], byProject: [:])

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([deleted])
    initial.secretList.selectedSecretID = deleted.id
    initial.secretDetail = SecretDetailFeature.State(secret: deleted)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.softDelete = { _ in deleted }
      $0.secretClient.fetchByQuery = { _ in [] }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.secretList(.didTapDelete(id: deleted.id)))
    // .off 모드에서 finish()는 effect가 보낸 액션을 state에 reduce하지 않는다. 종단 액션을
    // 명시적으로 receive해 그 앞의 재조회·재선택 체인을 모두 굴린 뒤 최종 상태만 확인한다.
    await store.receive(.secretList(.delegate(.secretSelected(nil))))
    await store.finish()

    #expect(store.state.secretList.secretsState == .loaded([]))
    #expect(store.state.secretList.selectedSecretID == nil)
    #expect(store.state.secretDetail == nil)
  }

  /// 지금 조회 중이지 않은 다른 시크릿을 리스트 메뉴로 삭제한 경우까지 재선택하면
  /// 무관한 조작에 조회뷰가 튕겨 나간다.
  @Test("리스트 메뉴로 조회 중이지 않은 다른 시크릿을 삭제해도 조회뷰는 그대로다")
  func listMenuDeleteOfOtherSecretKeepsDetail() async {
    let viewed = Self.makeSecret(name: "조회 중인 시크릿")
    let deleted = Self.makeSecret(name: "다른 곳에서 삭제된 시크릿")
    let counts = SecretCounts(byFilter: [.all: 1], byProject: [:])

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([viewed, deleted])
    initial.secretList.selectedSecretID = viewed.id
    initial.secretDetail = SecretDetailFeature.State(secret: viewed)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.softDelete = { _ in deleted }
      $0.secretClient.fetchByQuery = { _ in [viewed] }
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.date = .constant(Self.referenceDate)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.secretList(.didTapDelete(id: deleted.id)))
    await store.finish()

    #expect(store.state.secretDetail?.secret.id == viewed.id)
    #expect(store.state.secretList.selectedSecretID == viewed.id)
  }

  // MARK: - Sidebar Delegate

  @Test("selectionChanged(.project)는 secretList를 해당 프로젝트로 갱신한다")
  func selectionChangedUpdatesSecretList() async {
    let item = ProjectItem(id: UUID(), name: "Backend")

    var initial = MainFeature.State()
    initial.sidebar.projectsState = .loaded([item])

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.sidebar(.didSelect(.project(id: item.id)))) {
      $0.sidebar.selection = .project(id: item.id)
    }
    await store.receive(.sidebar(.delegate(.selectionChanged(.project(id: item.id))))) {
      $0.secretList = SecretListFeature.State(
        collection: .project(id: item.id),
        projectName: "Backend"
      )
    }
    await store.receive(.sidebar(.setCreatingSecret(false)))
  }

  /// State를 새로 만들면 `secretsState`가 비는데 `.task(id: collection)`은 다시 돌지 않아
  /// 개수는 0이 아닌데 목록만 빈 화면이 남는다.
  @Test("같은 대상으로 돌아오면 이미 불러온 목록을 버리지 않는다")
  func returningToSameCollectionKeepsLoadedSecrets() async {
    let secret = Self.makeSecret()

    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.sidebar.mode = .creating(previous: .filter(.all))
    initial.secretList.secretsState = .loaded([secret])
    initial.secretList.selectedSecretID = secret.id

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.sidebar(.didSelect(.filter(.all))))
    await store.receive(.sidebar(.delegate(.selectionChanged(.filter(.all))))) {
      $0.selectSecretType = nil
      // `secretsState`를 단언하지 않는 것 자체가 검증이다.
      $0.secretList.selectedSecretID = nil
    }
    await store.receive(.sidebar(.setCreatingSecret(false))) {
      $0.sidebar.mode = .browsing(.filter(.all))
    }
    #expect(store.state.secretList.secretsState == .loaded([secret]))
  }

  /// State를 갈아끼우면 목록이 버려지는데 `collection`이 같아 다시 읽지도 않는다.
  @Test("프로젝트 이름 변경은 목록을 버리지 않고 이름만 갈아끼운다")
  func projectRenameKeepsLoadedSecrets() async {
    let projectID = UUID()
    let secret = Self.makeSecret()
    let renamed = ProjectItem(id: projectID, name: "Backend V2")

    var initial = MainFeature.State()
    initial.sidebar.mode = .browsing(.project(id: projectID))
    initial.secretList = .init(collection: .project(id: projectID), projectName: "Backend")
    initial.secretList.secretsState = .loaded([secret])

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.sidebar(.delegate(.projectRenamed(renamed)))) {
      $0.secretList.projectName = "Backend V2"
    }
    #expect(store.state.secretList.secretsState == .loaded([secret]))
  }

  @Test("selectionChanged는 selectSecretType을 닫고 생성 모드를 벗어난다")
  func selectionChangedClosesSecretTypeSelection() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.sidebar.mode = .creating(previous: initial.sidebar.selection)
    initial.sidebar.selection = .filter(.starred)

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    // 생성 중에는 사이드바가 스스로 옮기지 않는다 — 확정한 부모가 옮긴다.
    await store.send(.sidebar(.didSelect(.filter(.all))))
    await store.receive(.sidebar(.delegate(.selectionChanged(.filter(.all))))) {
      $0.sidebar.selection = .filter(.all)
      $0.selectSecretType = nil
    }
    await store.receive(.sidebar(.setCreatingSecret(false))) {
      $0.sidebar.mode = .browsing($0.sidebar.selection)
    }
  }

  @Test("addButtonTapped은 selectSecretType을 열고 생성 모드로 들어간다")
  func addButtonTappedOpensSecretTypeSelection() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateSecret = { true }
    }

    await store.send(.sidebar(.didTapAddButton))
    await store.receive(.sidebar(.delegate(.addButtonTapped)))
    await store.receive(.canCreateSecretResponse(.success(true))) {
      $0.selectSecretType = .init()
    }
    await store.receive(.sidebar(.setCreatingSecret(true))) {
      $0.sidebar.mode = .creating(previous: $0.sidebar.selection)
    }
  }

  /// 상세 State가 살아남으면 돌아올 때 되살아나고 Touch ID까지 다시 요구한다.
  @Test("addButtonTapped은 조회 중이던 secretDetail과 목록 선택을 놓는다")
  func addButtonTappedClearsViewingSecret() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateSecret = { true }
    }

    await store.send(.sidebar(.didTapAddButton))
    await store.receive(.sidebar(.delegate(.addButtonTapped)))
    await store.receive(.canCreateSecretResponse(.success(true))) {
      $0.selectSecretType = .init()
      $0.secretDetail = nil
      $0.secretList.selectedSecretID = nil
    }
    await store.receive(.sidebar(.setCreatingSecret(true))) {
      $0.sidebar.mode = .creating(previous: $0.sidebar.selection)
    }
  }

  /// 사이드바 선택은 확인을 거치는데 `+`만 조용히 버리면 같은 사이드바에서 결과가 갈린다.
  @Test("addButtonTapped은 폼이 열려 있으면 확인을 거친다")
  func addButtonTappedAsksBeforeDiscardingForm() async {
    var initial = MainFeature.State()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.sidebar.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.sidebar(.didTapAddButton))
    await store.receive(.sidebar(.delegate(.addButtonTapped)))
    await store.receive(.createSecret(.didTapCancel)) {
      $0.createSecret?.alert = AlertState {
        TextState("Discard changes?", bundle: .module)
      } actions: {
        ButtonState(role: .destructive, action: .confirmCancel) {
          TextState("Discard", bundle: .module)
        }
        ButtonState(role: .cancel) {
          TextState("Keep editing", bundle: .module)
        }
      }
    }
    // 목적지를 두지 않았으므로 확인하면 목록이 아니라 타입 선택으로 돌아간다.
    #expect(store.state.pendingSelection == nil)
  }

  // MARK: - CreateSecret Routing

  @Test("typeSelected는 createSecret State를 세팅한다")
  func typeSelectedSetsCreateSecret() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.selectSecretType(.delegate(.typeSelected(.apiKeyToken)))) {
      $0.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    }
  }

  @Test("createSecretRequested는 그리드 없이 바로 생성하며 사이드바 선택 하이라이트와 조회 상태를 해제한다")
  func createSecretRequestedOpensCreateSecretDirectly() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    // 사이드바에 필터가 선택돼 있고 시크릿을 조회 중인 상태 — App 메뉴 서브메뉴에서 바로 생성.
    var initial = MainFeature.State()
    initial.sidebar.selection = .filter(.starred)
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateSecret = { true }
    }

    await store.send(.createSecretRequested(.oauth)) {
      $0.pendingCreateType = .oauth
    }
    await store.receive(.canCreateSecretResponse(.success(true))) {
      $0.pendingCreateType = nil
      $0.createSecret = CreateSecretFeature.State(secretType: .oauth)
      $0.secretDetail = nil
      $0.secretList.selectedSecretID = nil
    }
    // 생성 모드로 들어가면 사이드바는 어떤 행도 선택되지 않은 상태로 표시된다.
    await store.receive(.sidebar(.setCreatingSecret(true))) {
      $0.sidebar.mode = .creating(previous: $0.sidebar.selection)
    }
  }

  /// 설정 화면엔 사이드바·리스트가 없어, 진행하면 보이지 않는 상태만 바뀌고 설정을 닫을 때 튄다.
  @Test("설정 화면에서는 createSecretRequested를 무시한다")
  func createSecretRequestedIgnoredDuringSettings() async {
    var initial = MainFeature.State()
    initial.settings = .init()

    let store = TestStore(initialState: initial) { MainFeature() }

    // 아무 상태도 바꾸지 않고 효과도 없어야 한다(닫혀 있는 상태를 조용히 오염시키지 않는다).
    await store.send(.createSecretRequested(.oauth))
  }

  /// 다른 진입점(⌘N·사이드바)은 확인을 거치는데 New▸만 조용히 버리면 작성 중 입력이 사라진다.
  @Test("createSecretRequested는 작성 중인 폼이 있으면 덮어쓰지 않고 취소 확인을 거친다")
  func createSecretRequestedAsksBeforeDiscardingForm() async {
    var initial = MainFeature.State()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.sidebar.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: initial) { MainFeature() }

    // createSecret을 바꾸지 않고 pendingCreateType만 잡는다 — 바꿨다면 exhaustive가 실패한다.
    await store.send(.createSecretRequested(.oauth)) {
      $0.pendingCreateType = .oauth
    }
    await store.receive(.createSecret(.didTapCancel)) {
      $0.createSecret?.alert = AlertState {
        TextState("Discard changes?", bundle: .module)
      } actions: {
        ButtonState(role: .destructive, action: .confirmCancel) {
          TextState("Discard", bundle: .module)
        }
        ButtonState(role: .cancel) {
          TextState("Keep editing", bundle: .module)
        }
      }
    }
  }

  @Test("취소를 확인하면 New▸로 요청한 타입으로 새 폼을 연다")
  func confirmingDiscardOpensRequestedType() async {
    var initial = MainFeature.State()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.pendingCreateType = .oauth
    initial.sidebar.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.createSecret(.delegate(.cancelled))) {
      $0.pendingCreateType = nil
      $0.createSecret = CreateSecretFeature.State(secretType: .oauth)
    }
    // 이미 creating 모드라 setCreatingSecret(true)는 상태를 바꾸지 않는다.
    await store.receive(.sidebar(.setCreatingSecret(true)))
  }

  @Test("secretCreated는 생성 플로우를 닫고 사이드바 카운트를 다시 세게 한다")
  func secretCreatedClearsCreationFlow() async {
    let secretID = UUID()
    let counts = SecretCounts(byFilter: [.all: 1], byProject: [:])
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.sidebar.mode = .creating(previous: initial.sidebar.selection)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchCounts = { _, _ in counts }
      $0.secretClient.fetchByQuery = { _ in [] }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.createSecret(.delegate(.secretCreated(secretID)))) {
      $0.createSecret = nil
      $0.selectSecretType = nil
    }
    await store.receive(.sidebar(.setCreatingSecret(false))) {
      $0.sidebar.mode = .browsing($0.sidebar.selection)
    }
    // 지시가 먼저 다 나가고 비동기 응답이 뒤따른다.
    await store.receive(.secretList(.refresh))
    await store.receive(.sidebar(.countsRefreshRequested))
    await store.receive(.sidebar(.countsResponse(.success(counts)))) {
      $0.sidebar.countsState = .loaded(counts)
    }
    await store.receive(.secretList(.secretsResponse(.success([])))) {
      $0.secretList.secretsState = .loaded([])
    }
  }

  @Test("cancelled는 createSecret을 닫고 selectSecretType을 초기화해 타입 선택으로 돌아간다")
  func cancelledResetsToTypeSelection() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.createSecret(.delegate(.cancelled))) {
      $0.createSecret = nil
      $0.selectSecretType = .init()
    }
  }

  /// 문구를 복제하지 않으려고 자식의 기존 취소 alert를 그대로 띄운다.
  @Test("생성 폼에서 사이드바를 누르면 바로 나가지 않고 취소 확인을 띄운다")
  func sidebarSelectionWhileFormOpenAsksForConfirmation() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.sidebar.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: initial) { MainFeature() }

    // 아직 확정이 아니므로 사이드바는 움직이지 않는다.
    await store.send(.sidebar(.didSelect(.filter(.starred))))
    await store.receive(.sidebar(.delegate(.selectionChanged(.filter(.starred))))) {
      $0.pendingSelection = .filter(.starred)
    }
    await store.receive(.createSecret(.didTapCancel)) {
      $0.createSecret?.alert = AlertState {
        TextState("Discard changes?", bundle: .module)
      } actions: {
        ButtonState(role: .destructive, action: .confirmCancel) {
          TextState("Discard", bundle: .module)
        }
        ButtonState(role: .cancel) {
          TextState("Keep editing", bundle: .module)
        }
      }
    }
  }

  /// 폼의 Cancel과 문구는 같지만 목적지가 다르다.
  @Test("확인하면 타입 선택이 아니라 누른 목록으로 나간다")
  func confirmingLeavesToSelectedList() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    // 들어오기 전 자리(All)와 다른 곳을 골라야 사이드바가 실제로 옮겨지는지 보인다.
    initial.sidebar.mode = .creating(previous: .filter(.all))
    initial.pendingSelection = .filter(.starred)

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.createSecret(.delegate(.cancelled))) {
      $0.pendingSelection = nil
      $0.sidebar.selection = .filter(.starred)
      $0.createSecret = nil
      $0.selectSecretType = nil
      $0.secretList = SecretListFeature.State(collection: .liked)
    }
    await store.receive(.sidebar(.setCreatingSecret(false))) {
      $0.sidebar.mode = .browsing(.filter(.starred))
    }
  }

  /// 계속 편집을 골랐는데 사이드바가 옮겨져 있으면, 생성을 마쳤을 때 강조는 새 항목인데
  /// 목록은 원래 것이 남아 둘이 영영 어긋난다.
  @Test("확인 없이 alert를 닫으면 사이드바의 돌아갈 곳이 그대로다")
  func dismissingConfirmationKeepsSidebarDestination() async {
    var initial = MainFeature.State()
    initial.selectSecretType = .init()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.sidebar.mode = .creating(previous: .filter(.all))

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.sidebar(.didSelect(.filter(.starred))))
    await store.receive(.sidebar(.delegate(.selectionChanged(.filter(.starred))))) {
      $0.pendingSelection = .filter(.starred)
    }
    await store.receive(.createSecret(.didTapCancel)) {
      $0.createSecret?.alert = AlertState {
        TextState("Discard changes?", bundle: .module)
      } actions: {
        ButtonState(role: .destructive, action: .confirmCancel) {
          TextState("Discard", bundle: .module)
        }
        ButtonState(role: .cancel) {
          TextState("Keep editing", bundle: .module)
        }
      }
    }

    await store.send(.createSecret(.alert(.dismiss))) {
      $0.createSecret?.alert = nil
      $0.pendingSelection = nil
    }
    #expect(store.state.sidebar.mode == .creating(previous: .filter(.all)))

    // 마치고 나면 들어오기 전 자리로 돌아가야 한다.
    await store.send(.sidebar(.setCreatingSecret(false))) {
      $0.sidebar.mode = .browsing(.filter(.all))
    }
  }

  /// 목적지를 버리지 않으면 나중에 폼의 Cancel이 엉뚱하게 목록으로 나간다.
  @Test("확인 없이 alert를 닫으면 기억해 둔 목적지를 버린다")
  func dismissingConfirmationDropsPendingSelection() async {
    var initial = MainFeature.State()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)
    initial.createSecret?.alert = AlertState {
      TextState("Discard changes?", bundle: .module)
    } actions: {
      ButtonState(role: .destructive, action: .confirmCancel) {
        TextState("Discard", bundle: .module)
      }
      ButtonState(role: .cancel) {
        TextState("Keep editing", bundle: .module)
      }
    }
    initial.pendingSelection = .filter(.starred)

    let store = TestStore(initialState: initial) { MainFeature() }

    await store.send(.createSecret(.alert(.dismiss))) {
      $0.createSecret?.alert = nil
      $0.pendingSelection = nil
    }
  }

  @Test("addButtonTapped은 게이트에 막히면 타입 선택 대신 페이월을 띄운다")
  func addButtonTappedShowsPaywallWhenBlocked() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateSecret = { false }
    }

    await store.send(.sidebar(.didTapAddButton))
    await store.receive(.sidebar(.delegate(.addButtonTapped)))
    await store.receive(.canCreateSecretResponse(.success(false))) {
      $0.paywall = DevaultProPaywallFeature.State()
    }
    #expect(store.state.selectSecretType == nil)
  }

  @Test("설정이 게이트 차단을 알리면 페이월을 띄운다 — catch-all에 삼켜지면 안 된다")
  func settingsPaywallRequiredShowsPaywall() async {
    var initial = MainFeature.State()
    initial.settings = SettingsFeature.State()

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.settings(.delegate(.paywallRequired))) {
      $0.paywall = DevaultProPaywallFeature.State()
    }
  }

  @Test("메뉴로 만드는 경로도 게이트에 막히면 페이월을 띄운다")
  func createSecretRequestedShowsPaywallWhenBlocked() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateSecret = { false }
    }

    await store.send(.createSecretRequested(.apiKeyToken)) {
      $0.pendingCreateType = .apiKeyToken
    }
    await store.receive(.canCreateSecretResponse(.success(false))) {
      $0.pendingCreateType = nil
      $0.paywall = DevaultProPaywallFeature.State()
    }
    #expect(store.state.createSecret == nil)
  }

  @Test("secretDetail이 수정 잠금을 알리면 페이월을 띄운다")
  func secretDetailPaywallRequiredShowsPaywall() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )
    var initial = MainFeature.State()
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.secretDetail(.delegate(.paywallRequired))) {
      $0.paywall = DevaultProPaywallFeature.State()
    }
  }

  @Test("addProjectTapped은 게이트를 통과하면 createProject sheet를 연다")
  func addProjectTappedOpensSheet() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateProject = { true }
    }

    await store.send(.sidebar(.didTapAddProject))
    await store.receive(.sidebar(.delegate(.addProjectTapped)))
    await store.receive(.canCreateProjectResponse(.success(true))) {
      $0.createProject = CreateProjectFeature.State()
    }
  }

  @Test("addProjectTapped은 게이트에 막히면 sheet 대신 페이월을 띄운다")
  func addProjectTappedShowsPaywallWhenBlocked() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateProject = { false }
    }

    await store.send(.sidebar(.didTapAddProject))
    await store.receive(.sidebar(.delegate(.addProjectTapped)))
    await store.receive(.canCreateProjectResponse(.success(false))) {
      $0.paywall = DevaultProPaywallFeature.State()
    }
    #expect(store.state.createProject == nil)
  }

  @Test("판정이 실패하면 페이월을 띄우지 않는다 — 결제로 해결되지 않는다")
  func addProjectTappedDoesNotShowPaywallOnJudgementFailure() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.entitlementClient.canCreateProject = { throw ProjectUseCaseError.unexpected }
    }

    await store.send(.sidebar(.didTapAddProject))
    await store.receive(.sidebar(.delegate(.addProjectTapped)))
    await store.receive(.canCreateProjectResponse(.failure(.unexpected)))
    #expect(store.state.paywall == nil)
    #expect(store.state.createProject == nil)
  }

  // MARK: - CreateProject Delegate

  @Test("projectCreated는 생성 중이 아닐 때 selection을 새 프로젝트로 설정하고 refetch한다")
  func projectCreatedSelectsNewProject() async {
    let item = ProjectItem(id: UUID(), name: "Backend")

    var initial = MainFeature.State()
    initial.createProject = .init()
    initial.sidebar.mode = .browsing(initial.sidebar.selection)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { [item] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.createProject(.presented(.delegate(.projectCreated(item))))) {
      $0.createProject = nil
      $0.sidebar.selection = .project(id: item.id)
      $0.secretList = SecretListFeature.State(
        collection: .project(id: item.id),
        projectName: "Backend"
      )
    }
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success([item])))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded([item])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  /// 남겨두면 빈 새 프로젝트 목록 옆에 이전 시크릿이 그대로 떠 있고 Touch ID를 다시 요구한다.
  @Test("projectCreated는 조회 중이던 secretDetail을 놓는다")
  func projectCreatedClearsViewingSecret() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.createProject = .init()
    initial.sidebar.mode = .browsing(initial.sidebar.selection)
    initial.secretDetail = SecretDetailFeature.State(secret: secret)
    initial.secretList.selectedSecretID = secret.id

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { [item] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.createProject(.presented(.delegate(.projectCreated(item))))) {
      $0.createProject = nil
      $0.secretDetail = nil
      $0.sidebar.selection = .project(id: item.id)
      $0.secretList = SecretListFeature.State(
        collection: .project(id: item.id),
        projectName: "Backend"
      )
    }
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success([item])))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded([item])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  @Test("projectCreated는 생성 중일 때 selection을 변경하지 않는다")
  func projectCreatedDoesNotSelectWhenCreatingSecret() async {
    let item = ProjectItem(id: UUID(), name: "Backend")

    var initial = MainFeature.State()
    initial.createProject = .init()
    initial.sidebar.mode = .creating(previous: initial.sidebar.selection)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { [item] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.createProject(.presented(.delegate(.projectCreated(item))))) {
      $0.createProject = nil
      // selection 및 secretList 변경 없음
    }
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success([item])))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded([item])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  // MARK: - SecretDetail Routing

  @Test("secretSelected(id)는 해당 Secret으로 secretDetail을 세팅한다")
  func secretSelectedSetsSecretDetail() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([secret])

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.secretList(.didSelectSecret(id: secret.id))) {
      $0.secretList.selectedSecretID = secret.id
    }
    await store.receive(.secretList(.delegate(.secretSelected(secret.id)))) {
      $0.secretDetail = SecretDetailFeature.State(secret: secret)
    }
  }

  @Test("secretSelected(nil)은 secretDetail을 닫는다")
  func secretSelectedNilClearsSecretDetail() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([secret])
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.secretList(.didSelectSecret(id: nil))) {
      $0.secretList.selectedSecretID = nil
    }
    await store.receive(.secretList(.delegate(.secretSelected(nil)))) {
      $0.secretDetail = nil
    }
  }

  // MARK: - Deleted Secret Routing

  /// 상세가 조회·복사·수정의 유일한 진입점이라 여기서 끊으면 셋이 함께 막힌다. 선택 자체는 막지 않는다.
  @Test("삭제된 시크릿을 선택하면 secretDetail을 만들지 않고 복구 안내 대상으로 잡는다")
  func selectingDeletedSecretShowsRecoverNotice() async {
    var deleted = Self.makeSecret(name: "삭제된 토큰")
    deleted.deletedAt = Date()

    var initial = MainFeature.State()
    initial.secretList = .init(collection: .deleted)
    initial.secretList.secretsState = .loaded([deleted])

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.secretList(.didSelectSecret(id: deleted.id))) {
      $0.secretList.selectedSecretID = deleted.id
    }
    await store.receive(.secretList(.delegate(.secretSelected(deleted.id))))
    #expect(store.state.secretDetail == nil)
    #expect(store.state.deletedNoticeSecret == deleted)
  }

  @Test("삭제되지 않은 시크릿을 선택하면 복구 안내가 사라지고 상세가 열린다")
  func selectingLiveSecretClearsRecoverNotice() async {
    var deleted = Self.makeSecret(name: "삭제된 토큰")
    deleted.deletedAt = Date()
    let live = Self.makeSecret(name: "살아 있는 토큰")

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([deleted, live])
    initial.secretList.selectedSecretID = deleted.id

    let store = TestStore(initialState: initial) {
      MainFeature()
    }
    #expect(store.state.deletedNoticeSecret == deleted)

    await store.send(.secretList(.didSelectSecret(id: live.id))) {
      $0.secretList.selectedSecretID = live.id
    }
    await store.receive(.secretList(.delegate(.secretSelected(live.id)))) {
      $0.secretDetail = SecretDetailFeature.State(secret: live)
    }
    #expect(store.state.deletedNoticeSecret == nil)
  }

  /// detail State는 nil을 거치지 않고 다른 시크릿으로 교체된다. `ifLet`이 이 전환을 알아보지 못하면
  /// A의 복호화 응답이 B의 State에 실려, 인증한 적 없는 B에 A의 평문과 인증 창이 열린다.
  @Test("시크릿을 바꾸면 이전 시크릿의 복호화 effect가 취소된다")
  func secretSelectedCancelsPreviousRevealEffect() async {
    let secretA = Secret(
      id: UUID(),
      name: "Secret A",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )
    let secretB = Secret(
      id: UUID(),
      name: "Secret B",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.secretsState = .loaded([secretA, secretB])

    // A의 복호화를 인증 프롬프트가 떠 있는 상태로 붙잡아 둔다.
    let clock = TestClock()

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.revealPayload = { _, _ in
        try await clock.sleep(for: .seconds(1))
        return .apiKey(APIKeyPayload(value: "A의 평문"), nil)
      }
    }

    await store.send(.secretList(.didSelectSecret(id: secretA.id))) {
      $0.secretList.selectedSecretID = secretA.id
    }
    await store.receive(.secretList(.delegate(.secretSelected(secretA.id)))) {
      $0.secretDetail = SecretDetailFeature.State(secret: secretA)
    }

    await store.send(.secretDetail(.didTapToggleReveal(.value))) {
      $0.secretDetail?.payloadState = .loading
    }

    await store.send(.secretList(.didSelectSecret(id: secretB.id))) {
      $0.secretList.selectedSecretID = secretB.id
    }
    await store.receive(.secretList(.delegate(.secretSelected(secretB.id)))) {
      $0.secretDetail = SecretDetailFeature.State(secret: secretB)
    }

    // A의 복호화가 끝나는 시점. 취소되었다면 아무 액션도 도착하지 않는다 —
    // 도착하면 TestStore가 처리되지 않은 액션으로 실패시킨다.
    await clock.advance(by: .seconds(1))

    #expect(store.state.secretDetail?.secret.id == secretB.id)
    #expect(store.state.secretDetail?.payloadState == .idle)
    #expect(store.state.secretDetail?.revealAuthorizedAt == nil)
    #expect(store.state.secretDetail?.revealedFields.isEmpty == true)
  }

  @Test("secretDetail closed delegate는 secretDetail과 selectedSecretID를 초기화한다")
  func secretDetailClosedClearsDetail() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.secretDetail(.delegate(.closed))) {
      $0.secretDetail = nil
      $0.secretList.selectedSecretID = nil
    }
  }

  @Test("수정 화면에서 만든 프로젝트는 사이드바에 즉시 반영된다")
  func projectsChangedFromDetailRefreshesSidebar() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )
    let created = [ProjectItem(id: UUID(), name: "새 프로젝트")]

    var initial = MainFeature.State()
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { created }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.secretDetail(.delegate(.projectsChanged)))
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success(created)))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded(IdentifiedArray(uniqueElements: created))
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
    // 편집 중인 화면은 유지된다 — 프로젝트를 만들었다고 폼이 닫히면 안 된다.
    #expect(store.state.secretDetail != nil)
  }

  @Test("생성 화면에서 만든 프로젝트도 사이드바에 즉시 반영된다")
  func projectsChangedFromCreateRefreshesSidebar() async {
    let created = [ProjectItem(id: UUID(), name: "새 프로젝트")]

    var initial = MainFeature.State()
    initial.createSecret = CreateSecretFeature.State(secretType: .apiKeyToken)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { created }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.createSecret(.delegate(.projectsChanged)))
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success(created)))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded(IdentifiedArray(uniqueElements: created))
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
    // 생성 폼은 유지된다 — 프로젝트만 만들고 시크릿 작성은 이어가야 한다.
    #expect(store.state.createSecret != nil)
  }

  @Test("secretUpdated delegate는 목록을 재조회한다")
  func secretUpdatedRefreshesList() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      liked: true,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.fetchByQuery = { _ in [secret] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.secretDetail(.delegate(.secretUpdated(secret))))
    // refresh는 .loading으로 바꾸지 않는다 — 목록이 깜빡이지 않아야 한다.
    await store.receive(.secretList(.refresh))
    // 즐겨찾기는 Starred 개수를 바꾸므로 사이드바 개수도 갱신되어야 한다.
    await store.receive(.sidebar(.countsRefreshRequested))
    await store.receive(.secretList(.secretsResponse(.success([secret])))) {
      $0.secretList.secretsState = .loaded(IdentifiedArray(uniqueElements: [secret]))
      // 검색어가 없으므로 재조회 결과 수가 곧 컬렉션 전체 수(#121)다.
      $0.secretList.collectionCount = 1
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
    // detail은 유지된다 — 즐겨찾기 토글로 화면이 닫히면 안 된다.
    #expect(store.state.secretDetail != nil)
  }

  @Test("deleted delegate는 detail을 닫고 목록을 재조회한다")
  func secretDeletedClosesDetailAndRefreshes() async {
    let secret = Secret(
      id: UUID(),
      name: "Test Token",
      secretType: .apiKeyToken,
      createdAt: Date(),
      updatedAt: Date(),
      payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
    )

    var initial = MainFeature.State()
    initial.secretList.selectedSecretID = secret.id
    initial.secretDetail = SecretDetailFeature.State(secret: secret)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.fetchByQuery = { _ in [] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.secretDetail(.delegate(.deleted(secret.id)))) {
      $0.secretDetail = nil
      $0.secretList.selectedSecretID = nil
    }
    await store.receive(.secretList(.refresh))
    // 삭제는 All·Deleted 개수를 바꾸므로 사이드바 개수도 갱신되어야 한다.
    await store.receive(.sidebar(.countsRefreshRequested))
    await store.receive(.secretList(.secretsResponse(.success([])))) {
      $0.secretList.secretsState = .loaded([])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  // MARK: - Rename Delegate

  @Test("projectRenamed는 현재 선택된 프로젝트의 이름이면 secretList 타이틀을 갱신한다")
  func projectRenamedUpdatesSecretListTitle() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    let renamed = ProjectItem(id: item.id, name: "Backend V2")

    var initial = MainFeature.State()
    initial.sidebar.projectsState = .loaded([item])
    initial.sidebar.selection = .project(id: item.id)
    initial.secretList = SecretListFeature.State(
      collection: .project(id: item.id),
      projectName: "Backend"
    )

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { [renamed] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.sidebar(.renameResponse(projectID: renamed.id, .success(renamed))))
    // delegate payload의 이름을 직접 사용해 즉시 갱신
    await store.receive(.sidebar(.delegate(.projectRenamed(renamed)))) {
      $0.secretList = SecretListFeature.State(
        collection: .project(id: item.id),
        projectName: "Backend V2"
      )
    }
    // 이후 refetch로 목록도 동기화
    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success([renamed])))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded([renamed])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  /// 사이드바를 기준으로 삼으면 생성 중의 "돌아갈 곳"과 목록이 어긋난 사이에
  /// A의 목록에 B의 이름이 붙는다.
  @Test("projectRenamed는 목록이 그 프로젝트를 보고 있지 않으면 타이틀을 건드리지 않는다")
  func projectRenamedIgnoresWhenListTargetsElsewhere() async {
    let item = ProjectItem(id: UUID(), name: "Backend")
    let renamed = ProjectItem(id: item.id, name: "Backend V2")

    var initial = MainFeature.State()
    initial.sidebar.projectsState = .loaded([item])
    // 사이드바의 "돌아갈 곳"은 프로젝트지만 목록은 아직 All을 보고 있다.
    initial.sidebar.mode = .creating(previous: .project(id: item.id))
    initial.secretList = SecretListFeature.State(collection: .all)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.sidebarClient.fetchProjects = { [renamed] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }

    await store.send(.sidebar(.renameResponse(projectID: renamed.id, .success(renamed))))
    await store.receive(.sidebar(.delegate(.projectRenamed(renamed))))
    #expect(store.state.secretList.projectName == nil)

    await store.receive(.sidebar(.refresh)) {
      $0.sidebar.isRefreshingProjects = true
    }
    await store.receive(.sidebar(.projectsResponse(.success([renamed])))) {
      $0.sidebar.isRefreshingProjects = false
      $0.sidebar.projectsState = .loaded([renamed])
    }
    await store.receive(.sidebar(.countsResponse(.success(SecretCounts())))) {
      $0.sidebar.countsState = .loaded(SecretCounts())
    }
  }

  // MARK: - Lock

  @Test("didTapLock은 lockRequested를 delegate로 알린다")
  func didTapLockSendsDelegate() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    }

    await store.send(.didTapLock)
    await store.receive(.delegate(.lockRequested))
  }

  // MARK: - Settings

  @Test("사이드바의 settingsTapped 델리게이트는 settings를 연다")
  func settingsTappedOpensSettings() async {
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    }

    await store.send(.sidebar(.didTapSettings))
    await store.receive(.sidebar(.delegate(.settingsTapped))) {
      $0.settings = .init()
    }
  }

  @Test("settings의 closeRequested 델리게이트는 settings를 닫는다")
  func settingsCloseRequestedClosesSettings() async {
    var initial = MainFeature.State()
    initial.settings = .init()

    let store = TestStore(initialState: initial) {
      MainFeature()
    }

    await store.send(.settings(.didTapClose))
    await store.receive(.settings(.delegate(.closeRequested))) {
      $0.settings = nil
    }
  }

  @Test("저장소 전환이나 전체 삭제 뒤에는 이전 vault 화면 상태를 버리고 목록을 갱신한다")
  func vaultContentChangeResetsDerivedStateAndRefreshes() async {
    let projectID = UUID()
    var initial = MainFeature.State()
    initial.settings = .init()
    initial.selectSecretType = .init()
    initial.createProject = .init()
    initial.createSecret = .init(secretType: .apiKeyToken)
    initial.sidebar.selection = .project(id: projectID)
    initial.sidebar.mode = .creating(previous: initial.sidebar.selection)
    initial.secretList = .init(collection: .project(id: projectID), projectName: "Old")
    // 여기서 폼을 닫으면 `.alert(.dismiss)`가 다시 올 일이 없어 목적지가 영영 남는다.
    initial.pendingSelection = .filter(.starred)

    let store = TestStore(initialState: initial) {
      MainFeature()
    } withDependencies: {
      $0.secretClient.fetchByQuery = { _ in [] }
      $0.sidebarClient.fetchProjects = { [] }
      $0.sidebarClient.fetchCounts = { _, _ in SecretCounts() }
      $0.date = .constant(Self.referenceDate)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.settings(.delegate(.vaultDataReset))) {
      $0.selectSecretType = nil
      $0.createProject = nil
      $0.createSecret = nil
      $0.pendingSelection = nil
      $0.sidebar.selection = .filter(.all)
      $0.sidebar.mode = .browsing($0.sidebar.selection)
      $0.secretList = .init(collection: .all)
    }
  }
}
