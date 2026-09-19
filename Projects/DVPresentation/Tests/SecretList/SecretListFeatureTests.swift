// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("SecretListFeature")
struct SecretListFeatureTests {

    @Test("task는 조회 시작 시 loading 상태로, 성공하면 loaded로 바뀐다")
    func taskSuccess() async {
        let secret = makeSecret(name: "GitHub API Key")
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { _ in [secret] }
        }

        await store.send(.task) {
            $0.secretsState = .loading
        }
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.secretsState = .loaded([secret])
            $0.collectionCount = 1
        }
    }

    @Test("secretsResponse에 같은 id 중복이 와도 크래시 없이 하나로 합쳐진다")
    func secretsResponseDeduplicatesById() async {
        // CloudKit이 같은 id의 중복 레코드를 만들 수 있다. 방어가 없으면 IdentifiedArray가 fatalError.
        let id = UUID()
        let first = makeSecret(id: id, name: "GitHub API Key")
        let dup = makeSecret(id: id, name: "GitHub API Key (dup)")
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { _ in [first, dup] }
        }

        await store.send(.task) {
            $0.secretsState = .loading
        }
        await store.receive(.secretsResponse(.success([first, dup]))) {
            $0.secretsState = .loaded([first])  // 첫 항목만 남는다
            $0.collectionCount = 1
        }
    }

    @Test("task는 조회에 실패하면 failed 상태로 에러를 보존한다")
    func taskFailure() async {
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { _ in throw SecretUseCaseError.unexpected }
        }

        await store.send(.task) {
            $0.secretsState = .loading
        }
        await store.receive(.secretsResponse(.failure(.unexpected))) {
            $0.secretsState = .failed(.unexpected)
        }
    }

    /// `.task`는 최초 진입이 아니라 뷰가 다시 만들어질 때마다 실행된다(설정 화면 왕복 등).
    /// 비우면 이미 보고 있던 목록이 사라졌다 나타난다.
    @Test("이미 로드된 상태에서 task가 다시 실행돼도 목록을 비우지 않는다")
    func taskAfterReloadKeepsLoadedSecrets() async {
        let secret = makeSecret(name: "GitHub API Key")
        var initialState = SecretListFeature.State()
        initialState.secretsState = .loaded([secret])

        let store = TestStore(initialState: initialState) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { _ in [secret] }
        }

        await store.send(.task)
        #expect(store.state.secretsState == .loaded([secret]))
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.collectionCount = 1
        }
    }

    @Test("didTapRetry는 failed 상태에서 다시 loading으로 전환하고 재조회한다")
    func retryRefetchesAfterFailure() async {
        let secret = makeSecret(name: "GitHub API Key")
        var initialState = SecretListFeature.State()
        initialState.secretsState = .failed(.unexpected)
        let store = TestStore(initialState: initialState) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { _ in [secret] }
        }

        await store.send(.didTapRetry) {
            $0.secretsState = .loading
        }
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.secretsState = .loaded([secret])
            $0.collectionCount = 1
        }
    }

    @Test("task는 State의 collection이 반영된 query로 조회한다")
    func taskUsesCollectionInQuery() async {
        let secret = makeSecret(name: "Database Password")
        let store = TestStore(initialState: SecretListFeature.State(collection: .deleted)) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { query in
                query.collection == .deleted ? [secret] : []
            }
        }

        await store.send(.task) {
            $0.secretsState = .loading
        }
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.secretsState = .loaded([secret])
            $0.collectionCount = 1
        }
    }

    @Test("didChangeSearchText는 300ms 디바운스 후 재조회한다")
    func searchDebounces() async {
        let clock = TestClock()
        let secret = makeSecret(name: "GitHub API Key")
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.secretClient.fetchByQuery = { query in
                query.searchText == "git" ? [secret] : []
            }
        }

        await store.send(.didChangeSearchText("git")) {
            $0.searchText = "git"
        }
        await clock.advance(by: .milliseconds(300))
        // 검색 중이라 collectionCount(검색 무관 전체 수)는 갱신되지 않는다.
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.secretsState = .loaded([secret])
        }
    }

    @Test("didSelectSort는 디바운스 없이 즉시 재조회한다")
    func sortRefetchesImmediately() async {
        let secret = makeSecret(name: "GitHub API Key")
        let nameAscending = SecretQuery.Sort(key: .name, direction: .ascending)
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.fetchByQuery = { query in
                query.sort == nameAscending ? [secret] : []
            }
        }

        await store.send(.didSelectSort(nameAscending)) {
            $0.sort = nameAscending
        }
        await store.receive(.secretsResponse(.success([secret]))) {
            $0.secretsState = .loaded([secret])
            $0.collectionCount = 1
        }
    }

    @Test("초기 State는 idle이며, 조회 후 결과가 0개인 loaded([])와 구분된다")
    func initialStateIsIdleNotLoaded() {
        let state = SecretListFeature.State()

        #expect(state.secretsState == .idle)
        #expect(state.secretsState != .loaded([]))
    }

    @Test("expired collection의 query는 collection을 그대로 쓰고 만료 오름차순 정렬을 강제한다")
    func expiredQueryKeepsCollectionAsIs() {
        let today = Date(timeIntervalSince1970: 0)
        let state = SecretListFeature.State(collection: .expired(referenceDate: today))

        let query = state.query

        #expect(query.collection == .expired(referenceDate: today))
        #expect(query.sort == SecretQuery.Sort(key: .expiry, direction: .ascending))
    }

    @Test("notice collection의 query는 collection을 그대로 쓰고 만료 오름차순 정렬을 강제한다")
    func noticeQueryForcesExpiringSoonSort() {
        let today = Date(timeIntervalSince1970: 0)
        let state = SecretListFeature.State(collection: .notice(referenceDate: today))

        let query = state.query

        // predicate가 이미 window 전체를 검사하므로 .expired와 달리 collection 변환이 필요 없다.
        #expect(query.collection == .notice(referenceDate: today))
        #expect(query.sort == SecretQuery.Sort(key: .expiry, direction: .ascending))
    }

    @Test("didSelectSecret은 selectedSecretID를 갱신하고 delegate로 알린다")
    func selectSecretNotifiesDelegate() async {
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        }

        let id = UUID()
        await store.send(.didSelectSecret(id: id)) {
            $0.selectedSecretID = id
        }
        await store.receive(.delegate(.secretSelected(id)))
    }

    /// 선택을 막으면 방향키 탐색과 컨텍스트 메뉴(영구 삭제)가 키보드로 죽는다. 조회 차단은 `MainFeature`가 상세를 만들지 않는 것으로 한다.
    @Test("Deleted 탭에서도 행 선택은 selectedSecretID를 갱신하고 delegate로 알린다")
    func selectSecretInDeletedStillSelects() async {
        let store = TestStore(initialState: SecretListFeature.State(collection: .deleted)) {
            SecretListFeature()
        }

        let id = UUID()
        await store.send(.didSelectSecret(id: id)) {
            $0.selectedSecretID = id
        }
        await store.receive(.delegate(.secretSelected(id)))
        #expect(store.state.alert == nil)
    }

    @Test("didTapDelete는 softDelete를 호출하고 성공하면 목록을 재조회한다")
    func deleteRefetchesOnSuccess() async {
        let secret = makeSecret(name: "GitHub API Key")
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in secret }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapDelete(id: secret.id))
        await store.receive(.mutationResponse(.success(secret.id)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
    }

    @Test("didTapDelete는 softDelete가 실패하면 alert를 띄우고 재조회하지 않는다")
    func deleteShowsAlertOnFailure() async {
        let secretID = UUID()
        let store = TestStore(initialState: SecretListFeature.State()) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in throw SecretUseCaseError.unexpected }
        }

        await store.send(.didTapDelete(id: secretID))
        await store.receive(.mutationResponse(.failure(.unexpected))) {
            $0.alert = AlertState {
                TextState(String.module("Couldn't complete the action."))
            } actions: {
                ButtonState(role: .cancel) { TextState(String.module("OK")) }
            } message: {
                TextState(String.module("Please try again in a moment."))
            }
        }
    }

    @Test("didTapRecover는 restore를 호출하고 성공하면 목록을 재조회한다")
    func recoverRefetchesOnSuccess() async {
        let secret = makeSecret(name: "GitHub API Key")
        let store = TestStore(initialState: SecretListFeature.State(collection: .deleted)) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.restore = { _ in secret }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapRecover(id: secret.id))
        await store.receive(.mutationResponse(.success(secret.id)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
    }

    @Test("didTapDeleteForever는 바로 지우지 않고 확인 alert를 띄운다")
    func deleteForeverShowsConfirmationAlert() async {
        let secretID = UUID()
        let store = TestStore(initialState: SecretListFeature.State(collection: .deleted)) {
            SecretListFeature()
        }

        await store.send(.didTapDeleteForever(id: secretID)) {
            $0.alert = AlertState {
                TextState(verbatim: String.module("Delete Forever?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmDeleteForever(id: secretID)) {
                    TextState(verbatim: String.module("Delete Forever"))
                }
                ButtonState(role: .cancel) {
                    TextState(verbatim: String.module("Cancel"))
                }
            } message: {
                TextState(verbatim: String.module("This action cannot be undone."))
            }
        }
    }

    @Test("alert에서 영구 삭제를 확정하면 permanentlyDelete를 호출하고 성공하면 목록을 재조회한다")
    func confirmDeleteForeverRefetchesOnSuccess() async {
        let secretID = UUID()
        let store = TestStore(initialState: SecretListFeature.State(collection: .deleted)) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.permanentlyDelete = { _ in }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapDeleteForever(id: secretID)) {
            $0.alert = AlertState {
                TextState(verbatim: String.module("Delete Forever?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmDeleteForever(id: secretID)) {
                    TextState(verbatim: String.module("Delete Forever"))
                }
                ButtonState(role: .cancel) {
                    TextState(verbatim: String.module("Cancel"))
                }
            } message: {
                TextState(verbatim: String.module("This action cannot be undone."))
            }
        }
        await store.send(.alert(.presented(.confirmDeleteForever(id: secretID)))) {
            $0.alert = nil
        }
        await store.receive(.mutationResponse(.success(secretID)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
    }

    // MARK: - Empty Collection (비우기 / 모두 삭제)

    @Test("didTapEmptyCollection은 Deleted에서 영구 삭제 확인 alert를 띄운다")
    func emptyCollectionShowsPermanentAlertForDeleted() async {
        var initial = SecretListFeature.State(collection: .deleted)
        initial.secretsState = .loaded([makeSecret(name: "A")])
        initial.collectionCount = 1
        let store = TestStore(initialState: initial) { SecretListFeature() }

        await store.send(.didTapEmptyCollection) {
            $0.alert = AlertState {
                TextState(String.module("Empty Deleted list?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmEmptyCollection) {
                    TextState(String.module("Empty"))
                }
                ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
            } message: {
                TextState(String.module("\(1) secrets will be permanently deleted. This can't be undone."))
            }
        }
    }

    @Test("didTapEmptyCollection은 목록이 비어 있으면 아무것도 하지 않는다")
    func emptyCollectionNoOpWhenEmpty() async {
        var initial = SecretListFeature.State(collection: .deleted)
        initial.secretsState = .loaded([])
        let store = TestStore(initialState: initial) { SecretListFeature() }

        await store.send(.didTapEmptyCollection)
    }

    @Test("Deleted 비우기 확정은 permanentlyDeleteAll을 호출하고 재조회 후 조회뷰를 닫는다")
    func confirmEmptyDeletedCallsPermanentlyDeleteAll() async {
        let target = makeSecret(name: "A")
        var initial = SecretListFeature.State(collection: .deleted)
        initial.secretsState = .loaded([target])
        initial.selectedSecretID = target.id
        initial.collectionCount = 1
        let calledPermanent = LockIsolated(false)

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.permanentlyDeleteAll = { _ in calledPermanent.setValue(true) }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapEmptyCollection) {
            $0.alert = AlertState {
                TextState(String.module("Empty Deleted list?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmEmptyCollection) {
                    TextState(String.module("Empty"))
                }
                ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
            } message: {
                TextState(String.module("\(1) secrets will be permanently deleted. This can't be undone."))
            }
        }
        await store.send(.alert(.presented(.confirmEmptyCollection))) {
            $0.alert = nil
        }
        await store.receive(.emptyCollectionResponse(nil)) {
            $0.collectionCount = 0
        }
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
        await store.receive(.reselectAfterMutation) {
            $0.selectedSecretID = nil
        }
        await store.receive(.delegate(.secretSelected(nil)))
        #expect(calledPermanent.value)
    }

    @Test("Expired 모두 삭제 확정은 softDeleteAll을 호출한다('삭제됨'으로 이동)")
    func confirmEmptyExpiredCallsSoftDeleteAll() async {
        let target = makeSecret(name: "A")
        var initial = SecretListFeature.State(collection: .expired(referenceDate: Date(timeIntervalSince1970: 1_700_000_000)))
        initial.secretsState = .loaded([target])
        initial.collectionCount = 1
        let calledSoft = LockIsolated(false)

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDeleteAll = { _ in calledSoft.setValue(true) }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapEmptyCollection) {
            $0.alert = AlertState {
                TextState(String.module("Delete All Expired?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmEmptyCollection) {
                    TextState(String.module("Delete All"))
                }
                ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
            } message: {
                TextState(String.module("\(1) secrets will move to Deleted. You can recover them later."))
            }
        }
        await store.send(.alert(.presented(.confirmEmptyCollection))) {
            $0.alert = nil
        }
        await store.receive(.emptyCollectionResponse(nil)) {
            $0.collectionCount = 0
        }
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
        await store.receive(.reselectAfterMutation)
        await store.receive(.delegate(.secretSelected(nil)))
        #expect(calledSoft.value)
    }

    @Test("검색 결과가 0건이어도 검색 중이면 비우기가 컬렉션 전체에 실행된다")
    func emptyCollectionRunsWhenSearchFiltersToEmpty() async {
        var initial = SecretListFeature.State(collection: .deleted)
        // 검색으로 걸러져 화면엔 0건이지만 컬렉션엔 5개가 있는 상황.
        initial.secretsState = .loaded([])
        initial.searchText = "no-match"
        initial.collectionCount = 5
        let calledPermanent = LockIsolated(false)

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.permanentlyDeleteAll = { _ in calledPermanent.setValue(true) }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        // 검색 결과가 0건이어도 확인 alert가 뜨고, 개수는 검색 무관 전체 수(5)를 보여준다.
        await store.send(.didTapEmptyCollection) {
            $0.alert = AlertState {
                TextState(String.module("Empty Deleted list?"))
            } actions: {
                ButtonState(role: .destructive, action: .confirmEmptyCollection) {
                    TextState(String.module("Empty"))
                }
                ButtonState(role: .cancel) { TextState(String.module("Cancel")) }
            } message: {
                TextState(String.module("\(5) secrets will be permanently deleted. This can't be undone."))
            }
        }
        await store.send(.alert(.presented(.confirmEmptyCollection))) {
            $0.alert = nil
        }
        await store.receive(.emptyCollectionResponse(nil)) {
            $0.collectionCount = 0
        }
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([])))
        await store.receive(.reselectAfterMutation)
        await store.receive(.delegate(.secretSelected(nil)))
        // 검색 결과(0건)가 아니라 컬렉션 전체를 대상으로 삭제가 위임됐다.
        #expect(calledPermanent.value)
    }

    @Test("삭제 대상이 지금 조회 중이던 시크릿이면, 재조회 후 남은 목록의 맨 위 항목으로 재선택한다")
    func deleteViewedSecretReselectsTopOfRemainingList() async {
        let deleted = makeSecret(name: "삭제될 시크릿")
        let remainingTop = makeSecret(name: "남은 시크릿 1")
        let remainingBottom = makeSecret(name: "남은 시크릿 2")

        var initial = SecretListFeature.State()
        initial.selectedSecretID = deleted.id

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in deleted }
            $0.secretClient.fetchByQuery = { _ in [remainingTop, remainingBottom] }
        }

        await store.send(.didTapDelete(id: deleted.id))
        await store.receive(.mutationResponse(.success(deleted.id)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([remainingTop, remainingBottom]))) {
            $0.secretsState = .loaded([remainingTop, remainingBottom])
            $0.collectionCount = 2
        }
        await store.receive(.reselectAfterMutation) {
            $0.selectedSecretID = remainingTop.id
        }
        await store.receive(.delegate(.secretSelected(remainingTop.id)))
    }

    @Test("삭제 대상이 지금 조회 중이던 시크릿이고 남은 목록이 비어 있으면 선택을 nil로 정리한다")
    func deleteViewedSecretClearsSelectionWhenListBecomesEmpty() async {
        let deleted = makeSecret(name: "삭제될 시크릿")

        var initial = SecretListFeature.State()
        initial.selectedSecretID = deleted.id

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in deleted }
            $0.secretClient.fetchByQuery = { _ in [] }
        }

        await store.send(.didTapDelete(id: deleted.id))
        await store.receive(.mutationResponse(.success(deleted.id)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([]))) {
            $0.secretsState = .loaded([])
        }
        await store.receive(.reselectAfterMutation) {
            $0.selectedSecretID = nil
        }
        await store.receive(.delegate(.secretSelected(nil)))
    }

    @Test("삭제 대상이 지금 조회 중이던 시크릿이 아니면 재선택을 하지 않는다")
    func deleteOtherSecretDoesNotReselect() async {
        let viewed = makeSecret(name: "조회 중인 시크릿")
        let deleted = makeSecret(name: "다른 곳에서 삭제된 시크릿")

        var initial = SecretListFeature.State()
        initial.selectedSecretID = viewed.id

        let store = TestStore(initialState: initial) {
            SecretListFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in deleted }
            $0.secretClient.fetchByQuery = { _ in [viewed] }
        }

        await store.send(.didTapDelete(id: deleted.id))
        await store.receive(.mutationResponse(.success(deleted.id)))
        await store.receive(.delegate(.secretsChanged))
        await store.receive(.secretsResponse(.success([viewed]))) {
            $0.secretsState = .loaded([viewed])
            $0.collectionCount = 1
        }
        // `.reselectAfterMutation`도 `.delegate(.secretSelected)`도 오지 않는다 — selectedSecretID는 그대로다.
        #expect(store.state.selectedSecretID == viewed.id)
    }

    // MARK: - Helpers

    private func makeSecret(id: UUID = UUID(), name: String) -> Secret {
        Secret(
            id: id,
            name: name,
            secretType: .apiKeyToken,
            createdAt: .now,
            updatedAt: .now,
            payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
        )
    }
}
