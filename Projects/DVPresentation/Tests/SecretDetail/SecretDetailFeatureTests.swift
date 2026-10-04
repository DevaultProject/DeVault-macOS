// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

import ComposableArchitecture
import DVDomain

@testable import DVPresentation

@Suite("SecretDetailFeature")
@MainActor
struct SecretDetailFeatureTests {

    /// reveal 인증 창 판정이 실행 시점에 흔들리지 않도록 고정한다.
    private static let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Helpers

    /// 순수 팩토리라 격리가 필요 없다. `nonisolated`인 것은 기본 인자 위치에서도 부를 수 있어야
    /// 하기 때문이다 — 기본 인자는 함수의 격리와 무관하게 nonisolated 문맥에서 평가된다.
    nonisolated private static func makeSecret(
        name: String = "Test Secret",
        secretType: SecretType = .apiKeyToken,
        liked: Bool = false
    ) -> Secret {
        Secret(
            id: UUID(),
            name: name,
            secretType: secretType,
            liked: liked,
            createdAt: Date(),
            updatedAt: Date(),
            payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
        )
    }

    // MARK: - Viewing 진입

    @Test("초기 mode는 .viewing이다")
    func initialModeIsViewing() async {
        let secret = Self.makeSecret()
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        }

        store.assert { state in
            #expect(state.mode == .viewing)
            #expect(state.editFields == nil)
        }
    }

    // `task`가 거는 것은 연결 프로젝트 조회와 lifecycle 구독 둘뿐이다. 후자는 테스트 환경에서
    // 곧바로 끝나는 스트림이라 액션을 내지 않으므로, 수신 순서를 맞출 필요가 없다.

    /// 진입이 아니라 눈 버튼이 복호화를 유발한다. 복호화는 인증을 통과해야 성공하므로
    /// 도착 자체가 인증 성공이고, 그 시각으로 재인증 창이 열린다.
    @Test("눈 버튼: 값이 없으면 복호화하고 그 필드를 연다")
    func toggleReveal_decryptsAndOpensField() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "test_token"), nil)

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in payload }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapToggleReveal(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.success(payload), then: .reveal(.value))) {
            $0.payloadState = .loaded(payload)
            $0.revealAuthorizedAt = Self.referenceDate
            $0.revealedFields = [.value]
        }
    }

    @Test("눈 버튼 복호화 실패: payloadState .failed + alert 노출")
    func toggleReveal_decryptionFailure() async {
        let secret = Self.makeSecret()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in throw SecretUseCaseError.cryptoFailure(.decryptionFailed) }
        }

        await store.send(.didTapToggleReveal(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.failure(.cryptoFailure(.decryptionFailed)), then: .reveal(.value))) {
            $0.payloadState = .failed(.cryptoFailure(.decryptionFailed))
            $0.alert = .payloadRevealFailed(.decryptionFailed)
        }
    }

    @Test("눈 버튼 인증 실패: authRequired alert 노출")
    func toggleReveal_authenticationFailure() async {
        let secret = Self.makeSecret()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in throw SecretUseCaseError.authenticationFailure(.cancelled) }
        }

        await store.send(.didTapToggleReveal(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.failure(.authenticationFailure(.cancelled)), then: .reveal(.value))) {
            $0.payloadState = .failed(.authenticationFailure(.cancelled))
            $0.alert = .payloadRevealFailed(.authRequired)
        }
    }

    @Test("task: 연결된 프로젝트 로드 성공")
    func task_linkedProjectsSuccess() async {
        let secret = Self.makeSecret()
        let linked = [
            Project(id: UUID(), name: "Backend", createdAt: Date(), updatedAt: Date()),
        ]

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.fetchLinkedProjects = { _ in linked }
        }

        // 진입은 복호화를 시작하지 않는다. `revealPayload`를 스텁하지 않았으므로
        // 진입이 복호화를 걸면 미구현 dependency 호출로 이 테스트가 실패한다.
        await store.send(.task) {
            $0.linkedProjectsState = .loading
        }
        await store.receive(.linkedProjectsResponse(.success(linked))) {
            $0.linkedProjectsState = .loaded(linked)
        }
    }

    /// 모든 실패를 알린다는 정책에 따라 이 경로도 alert를 띄운다.
    /// 진입 시 복호화를 하지 않게 되면서 복호화 실패 alert와 겹칠 일이 없어졌다.
    @Test("연결된 프로젝트 조회 실패도 alert를 띄운다")
    func task_linkedProjectsFailure_showsAlert() async {
        let secret = Self.makeSecret()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.fetchLinkedProjects = { _ in throw SecretUseCaseError.unexpected }
        }

        // 진입은 복호화를 시작하지 않는다. `revealPayload`를 스텁하지 않았으므로
        // 진입이 복호화를 걸면 미구현 dependency 호출로 이 테스트가 실패한다.
        await store.send(.task) {
            $0.linkedProjectsState = .loading
        }
        await store.receive(.linkedProjectsResponse(.failure(.unexpected))) {
            $0.linkedProjectsState = .failed(.unexpected)
            $0.alert = .linkedProjectsLoadFailed
        }
        // 값은 비어 있을 뿐 다른 정보는 영향받지 않는다.
        #expect(store.state.linkedProjects.isEmpty)
    }

    /// 못 읽은 것을 "연결 없음"으로 삼고 편집에 들어가면 저장할 때 **실제 연결이 조용히 끊긴다.**
    @Test("연결된 프로젝트를 못 읽으면 수정 진입이 막힌다")
    func didTapEdit_whenLinkedProjectsFailed_doesNothing() async {
        let secret = Self.makeSecret()
        var initial = SecretDetailFeature.State(secret: secret)
        initial.payloadState = .loaded(Self.editablePayload)
        initial.linkedProjectsState = .failed(.unexpected)

        // `revealPayload`·`fetchProjects`를 스텁하지 않았으므로 진입이 뚫리면 미구현 호출로 실패한다.
        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapEdit)
    }

    /// 사용자가 스스로 복구할 수 있는 유일한 경로다. 재조회에 성공하면 수정이 다시 열린다.
    @Test("연결된 프로젝트 조회 실패: Retry로 다시 읽는다")
    func retryLinkedProjects_reloads() async {
        let secret = Self.makeSecret()
        let linked = [
            Project(id: UUID(), name: "DrinkiG", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)
        ]
        var initial = SecretDetailFeature.State(secret: secret)
        initial.linkedProjectsState = .failed(.unexpected)
        initial.alert = .linkedProjectsLoadFailed

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.fetchLinkedProjects = { _ in linked }
        }

        await store.send(.alert(.presented(.retryLinkedProjects))) {
            $0.alert = nil
            $0.linkedProjectsState = .loading
        }
        await store.receive(.linkedProjectsResponse(.success(linked))) {
            $0.linkedProjectsState = .loaded(linked)
        }
    }

    // MARK: - payload 재시도

    /// 실패 후 재시도는 **눈 버튼이 그대로 맡는다.** `.failed`에서 다시 누르면 그 필드를
    /// continuation에 실은 채 복호화를 새로 걸므로, 성공하면 누른 필드가 실제로 열린다 —
    /// 이 테스트가 확인하는 것이 그 점이고, 전용 재시도 액션이 필요 없는 근거다.
    @Test("인증 취소 후 재시도: alert를 닫고 눈 버튼을 다시 누르면 그 필드가 열린다")
    func retryReveal_afterAuthenticationCancellation() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "test_token"), nil)
        let attemptCount = LockIsolated(0)

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.date = .constant(Self.referenceDate)
            $0.secretClient.revealPayload = { _, _ in
                let attempt = attemptCount.withValue { count -> Int in
                    count += 1
                    return count
                }
                // 첫 시도는 Touch ID 취소, 재시도는 성공.
                if attempt == 1 {
                    throw SecretUseCaseError.authenticationFailure(.cancelled)
                }
                return payload
            }
        }

        await store.send(.didTapToggleReveal(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.failure(.authenticationFailure(.cancelled)), then: .reveal(.value))) {
            $0.payloadState = .failed(.authenticationFailure(.cancelled))
            $0.alert = .payloadRevealFailed(.authRequired)
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        await store.send(.didTapToggleReveal(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.success(payload), then: .reveal(.value))) {
            $0.payloadState = .loaded(payload)
            $0.revealAuthorizedAt = Self.referenceDate
            // 전용 재시도 액션은 continuation을 잃어 값만 받아왔다 — 인증을 통과하고도
            // 모든 필드가 마스킹된 채 남아 아무 일도 안 일어난 것처럼 보였다.
            $0.revealedFields = [.value]
        }
        // 매 시도가 생체인증을 새로 타므로 호출 횟수 자체가 재시도 성립의 근거다.
        #expect(attemptCount.value == 2)
    }

    // MARK: - reveal 인증 창

    /// 창이 열려 있는 동안에는 다른 필드를 열어도 인증을 다시 요구하지 않는다.
    @Test("인증 창이 열려 있으면 다른 필드는 인증 없이 열린다")
    func toggleReveal_withinWindow_skipsAuthentication() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.oauthClient(
            OAuthClientPayload(clientId: "id", clientSecret: "secret"), nil
        )

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)
        state.revealAuthorizedAt = Self.referenceDate
        state.revealedFields = [.clientId]

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            // 인증을 부르면 미구현 dependency 호출로 실패하므로, 호출하지 않는다는 것 자체가 검증된다.
            $0.date = .constant(Self.referenceDate.addingTimeInterval(60))
        }

        await store.send(.didTapToggleReveal(.clientSecret)) {
            $0.revealedFields = [.clientId, .clientSecret]
        }
    }

    /// 창이 닫힌 뒤에는 값이 이미 있어도 인증을 다시 받는다. 복호화는 하지 않는다.
    @Test("창이 만료되면 인증만 다시 받고 복호화는 하지 않는다")
    func toggleReveal_afterExpiry_reauthenticatesOnly() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "token"), nil)
        let expired = Self.referenceDate.addingTimeInterval(-1_000)

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)
        state.revealAuthorizedAt = expired

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.authenticate = { _ in }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapToggleReveal(.value))
        await store.receive(.reauthenticateResponse(.success(true), revealing: .value)) {
            $0.revealAuthorizedAt = Self.referenceDate
            $0.revealedFields = [.value]
        }
    }

    @Test("재인증 실패: 필드가 열리지 않고 alert가 뜬다")
    func reauthenticate_failure_showsAlert() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "token"), nil)

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)
        state.revealAuthorizedAt = Self.referenceDate.addingTimeInterval(-1_000)

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.authenticate = { _ in throw SecretUseCaseError.unexpected }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapToggleReveal(.value))
        await store.receive(.reauthenticateResponse(.success(false), revealing: .value)) {
            $0.alert = .payloadRevealFailed(.authRequired)
        }
        #expect(store.state.revealedFields.isEmpty)
    }

    /// 수정 진입 복호화와 눈·복사 복호화는 취소 그룹이 달라 서로를 대체하지 않는다. 막지 않으면
    /// 인증 시트가 둘 뜨고 늦게 온 응답이 먼저 온 응답의 continuation을 덮어쓴다.
    /// `revealPayload`를 스텁하지 않아, 두 번째 복호화가 시작되면 실패한다.
    @Test("수정 진입 복호화 중에는 눈·복사가 두 번째 복호화를 시작하지 않는다")
    func reveal_whileEnteringEdit_startsNoSecondDecrypt() async {
        var state = SecretDetailFeature.State(secret: Self.makeSecret())
        state.payloadState = .loading
        state.isEnteringEdit = true

        let store = TestStore(initialState: state) { SecretDetailFeature() }

        await store.send(.didTapToggleReveal(.value))
        await store.send(.didTapCopy(.value))
        #expect(store.state.payloadState == .loading)
        #expect(store.state.revealedFields.isEmpty)
    }

    /// 막는 것은 새 복호화를 시작하는 방향뿐이다. 닫기는 노출을 줄이므로 언제나 통해야 한다.
    @Test("수정 진입 복호화 중에도 열린 필드는 닫을 수 있다")
    func closeRevealed_whileEnteringEdit_stillCloses() async {
        var state = SecretDetailFeature.State(secret: Self.makeSecret())
        state.payloadState = .loading
        state.isEnteringEdit = true
        state.revealedFields = [.value]

        let store = TestStore(initialState: state) { SecretDetailFeature() }

        await store.send(.didTapToggleReveal(.value)) {
            $0.revealedFields = []
        }
    }

    /// 닫는 방향은 노출을 줄이므로 인증을 타지 않는다.
    @Test("열린 필드를 닫을 때는 인증하지 않는다")
    func toggleReveal_closing_needsNoAuthentication() async {
        let secret = Self.makeSecret()
        var state = SecretDetailFeature.State(secret: secret)
        state.revealedFields = [.value]

        let store = TestStore(initialState: state) { SecretDetailFeature() }

        await store.send(.didTapToggleReveal(.value)) {
            $0.revealedFields = []
        }
    }

    // MARK: - 생명주기 무효화

    @Test("무효화 대상 사건이 오면 인증 창과 열린 필드가 모두 닫힌다")
    func lifecycleEvent_invalidatesRevealState() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "token"), nil)

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)
        state.revealAuthorizedAt = Self.referenceDate
        state.revealedFields = [.value]

        let store = TestStore(initialState: state) { SecretDetailFeature() }

        await store.send(.lifecycleEvent(.didEnterBackground)) {
            $0.revealAuthorizedAt = nil
            $0.revealedFields = []
        }
        // 값 자체는 남는다 — 다시 열 때 인증만 받으면 되고 재복호화는 불필요한 비용이다.
        #expect(store.state.payloadState == .loaded(payload))
    }

    @Test("정책이 무시하는 사건은 상태를 건드리지 않는다")
    func lifecycleEvent_ignoredByPolicy_keepsState() async {
        let secret = Self.makeSecret()
        var state = SecretDetailFeature.State(secret: secret)
        state.revealAuthorizedAt = Self.referenceDate
        state.revealedFields = [.value]

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            $0.revealAuthPolicy = RevealAuthPolicy(
                ttl: 180,
                invalidatesOnBackground: false
            )
        }

        await store.send(.lifecycleEvent(.didEnterBackground))
    }

    // MARK: - 복사

    @Test("값이 있으면 복호화 없이 원문을 복사한다")
    func copy_withLoadedPayload_copiesPlainValue() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "ghp_secret"), nil)
        let copied = LockIsolated<String?>(nil)

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.copySensitiveValue = { value in
                copied.withValue { $0 = value }
            }
        }

        await store.send(.didTapCopy(.value))
        await store.receive(.copyResponse(.success(true)))
        // 마스킹 여부와 무관하게 원문이 들어가야 한다.
        #expect(copied.value == "ghp_secret")
    }

    @Test("값이 없으면 복호화한 뒤 Copy 정책을 적용한다")
    func copy_withoutPayload_decryptsThenCopies() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "ghp_secret"), nil)
        let copied = LockIsolated<String?>(nil)

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.loadPayloadForCopy = { _ in payload }
            $0.secretClient.copySensitiveValue = { value in
                copied.withValue { $0 = value }
            }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapCopy(.value)) {
            $0.payloadState = .loading
        }
        await store.receive(.payloadResponse(.success(payload), then: .copy(.value))) {
            $0.payloadState = .loaded(payload)
        }
        await store.receive(.copyResponse(.success(true)))
        #expect(copied.value == "ghp_secret")
        // 복사는 마스킹을 풀지 않는다.
        #expect(store.state.revealedFields.isEmpty)
    }

    @Test("복사 실패: alert가 뜬다")
    func copy_failure_showsAlert() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.apiKey(APIKeyPayload(value: "ghp_secret"), nil)

        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)

        let store = TestStore(initialState: state) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.copySensitiveValue = { _ in throw ClipboardError.writeFailed }
        }

        await store.send(.didTapCopy(.value))
        await store.receive(.copyResponse(.success(false))) {
            $0.alert = .copyFailed
        }
    }

    /// 복사 대기는 그 복사를 유발한 복호화에만 딸린 것이다. 다른 필드를 여느라 복호화가
    /// 새로 걸리면 대기도 함께 사라져야 한다 — 눈 버튼을 눌렀는데 다른 필드가 클립보드에
    /// 들어가면 사용자가 알 방법이 없다.
    @Test("복사 대기 중 다른 필드를 열면 대기 중이던 복사는 사라진다")
    func pendingCopy_supersededByReveal_doesNotCopy() async {
        let secret = Self.makeSecret()
        let payload = CreateSecretPayload.oauthClient(
            OAuthClientPayload(clientId: "client-id", clientSecret: "client-secret"),
            nil
        )
        let copied = LockIsolated<String?>(nil)
        let clock = TestClock()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.loadPayloadForCopy = { _ in
                try await clock.sleep(for: .seconds(1))
                return payload
            }
            $0.secretClient.revealPayload = { _, _ in
                try await clock.sleep(for: .seconds(1))
                return payload
            }
            $0.secretClient.copySensitiveValue = { value in
                copied.withValue { $0 = value }
            }
            $0.date = .constant(Self.referenceDate)
        }

        // 값이 없는 상태에서 Client Secret 복사 → 복호화가 걸리고 복사는 대기한다.
        await store.send(.didTapCopy(.clientSecret)) {
            $0.payloadState = .loading
        }

        // 응답 전에 Client ID의 눈 버튼. 같은 CancelID라 앞 복호화가 취소되고 새로 시작한다.
        await store.send(.didTapToggleReveal(.clientId))

        await clock.advance(by: .seconds(1))
        await store.receive(.payloadResponse(.success(payload), then: .reveal(.clientId))) {
            $0.payloadState = .loaded(payload)
            $0.revealAuthorizedAt = Self.referenceDate
            $0.revealedFields = [.clientId]
        }

        #expect(copied.value == nil)
    }

    /// 평문 필드(Redirect URL·Public Key·Renew Command)는 payload에 없어 꺼낼 식별자가 없다.
    /// 값을 그대로 받아 복사한다.
    ///
    /// `revealPayload`와 `copySensitiveValue`를 **일부러 스텁하지 않는다** — 둘 중 하나라도 불리면
    /// 미구현 dependency 호출로 실패한다. 평문을 보는 데 인증을 요구하지 않는다는 것과,
    /// 비밀이 아닌 값에 자동 정리·반복 감지를 씌우지 않는다는 것이 이렇게 고정된다.
    @Test("평문 필드 복사: 복호화도 민감 값 정책도 타지 않는다")
    func copyPlainValue_bypassesRevealAndSensitivePolicy() async {
        let secret = Self.makeSecret()
        let copied = LockIsolated<String?>(nil)
        let redirectURL = "https://app.example/oauth/callback"

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.copyPlainValue = { value in
                copied.withValue { $0 = value }
            }
        }

        await store.send(.didTapCopyPlainValue(redirectURL))
        await store.receive(.copyResponse(.success(true)))
        #expect(copied.value == redirectURL)
        #expect(store.state.payloadState == .idle)
    }

    @Test("평문 복사 실패도 alert를 띄운다")
    func copyPlainValue_failure_showsAlert() async {
        let secret = Self.makeSecret()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.copyPlainValue = { _ in throw ClipboardError.writeFailed }
        }

        await store.send(.didTapCopyPlainValue("https://app.example/oauth/callback"))
        await store.receive(.copyResponse(.success(false))) {
            $0.alert = .copyFailed
        }
    }

    // MARK: - Close delegate

    @Test("didTapClose는 delegate(.closed)를 emit한다")
    func didTapClose_emitsClosedDelegate() async {
        let secret = Self.makeSecret()
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        }

        await store.send(.didTapClose)
        await store.receive(.delegate(.closed))
    }

    // MARK: - 즐겨찾기

    @Test("didTapToggleLike 성공: secret 교체 + secretUpdated delegate")
    func toggleLike_success() async {
        let secret = Self.makeSecret(liked: false)
        var updated = secret
        updated.liked = true

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.setLiked = { _, _ in updated }
        }

        await store.send(.didTapToggleLike)
        await store.receive(.likeResponse(.success(updated))) {
            $0.secret = updated
        }
        await store.receive(.delegate(.secretUpdated(updated)))
    }

    @Test("didTapToggleLike는 현재 liked의 반대값을 전달한다")
    func toggleLike_sendsInvertedValue() async {
        let secret = Self.makeSecret(liked: true)
        var updated = secret
        updated.liked = false

        let requestedLiked = LockIsolated<Bool?>(nil)
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.setLiked = { _, liked in
                requestedLiked.setValue(liked)
                return updated
            }
        }

        await store.send(.didTapToggleLike)
        await store.receive(.likeResponse(.success(updated))) {
            $0.secret = updated
        }
        await store.receive(.delegate(.secretUpdated(updated)))
        #expect(requestedLiked.value == false)
    }

    @Test("didTapToggleLike 실패: alert 노출 + secret 유지")
    func toggleLike_failure() async {
        let secret = Self.makeSecret(liked: false)
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.setLiked = { _, _ in throw SecretUseCaseError.unexpected }
        }

        await store.send(.didTapToggleLike)
        await store.receive(.likeResponse(.failure(.unexpected))) {
            $0.alert = .likeFailed
        }
        #expect(store.state.secret.liked == false)
    }

    // MARK: - 삭제

    @Test("didTapDelete는 즉시 삭제하지 않고 확인 alert를 띄운다")
    func didTapDelete_presentsConfirmAlert() async {
        let secret = Self.makeSecret()
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDelete
        }
    }

    @Test("confirmDelete 성공: deleted delegate emit")
    func confirmDelete_success() async {
        let secret = Self.makeSecret()
        var deleted = secret
        deleted.deletedAt = Date()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in deleted }
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDelete
        }
        await store.send(.alert(.presented(.confirmDelete))) {
            $0.alert = nil
            $0.isDeleting = true
        }
        await store.receive(.deleteResponse(.success(deleted))) {
            $0.isDeleting = false
        }
        await store.receive(.delegate(.deleted(secret.id)))
    }

    @Test("confirmDelete 실패: isDeleting 해제 + alert 노출")
    func confirmDelete_failure() async {
        let secret = Self.makeSecret()
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.softDelete = { _ in throw SecretUseCaseError.unexpected }
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDelete
        }
        await store.send(.alert(.presented(.confirmDelete))) {
            $0.alert = nil
            $0.isDeleting = true
        }
        await store.receive(.deleteResponse(.failure(.unexpected))) {
            $0.isDeleting = false
            $0.alert = .deleteFailed
        }
    }

    @Test("이미 휴지통에 있는 시크릿은 didTapDelete가 영구 삭제 확인 alert를 띄운다")
    func didTapDelete_whenAlreadyTrashed_presentsConfirmDeleteForeverAlert() async {
        var secret = Self.makeSecret()
        secret.deletedAt = Date()
        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDeleteForever
        }
    }

    @Test("confirmDeleteForever 성공: permanentlyDelete 호출 후 deleted delegate emit")
    func confirmDeleteForever_success() async {
        var secret = Self.makeSecret()
        secret.deletedAt = Date()
        let deletedID = LockIsolated<Secret.ID?>(nil)

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.permanentlyDelete = { id in deletedID.setValue(id) }
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDeleteForever
        }
        await store.send(.alert(.presented(.confirmDeleteForever))) {
            $0.alert = nil
            $0.isDeleting = true
        }
        await store.receive(.deleteForeverResponse(.success(secret.id))) {
            $0.isDeleting = false
        }
        await store.receive(.delegate(.deleted(secret.id)))
        #expect(deletedID.value == secret.id)
    }

    @Test("confirmDeleteForever 실패: isDeleting 해제 + alert 노출")
    func confirmDeleteForever_failure() async {
        var secret = Self.makeSecret()
        secret.deletedAt = Date()

        let store = TestStore(initialState: SecretDetailFeature.State(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.permanentlyDelete = { _ in throw SecretUseCaseError.unexpected }
        }

        await store.send(.didTapDelete) {
            $0.alert = .confirmDeleteForever
        }
        await store.send(.alert(.presented(.confirmDeleteForever))) {
            $0.alert = nil
            $0.isDeleting = true
        }
        await store.receive(.deleteForeverResponse(.failure(.unexpected))) {
            $0.isDeleting = false
            $0.alert = .deleteFailed
        }
    }

    // MARK: - 편집 진입

    /// 편집 폼의 type-specific 필드는 평문에서만 만들 수 있다. 값이 이미 있으면 다시 받을 이유가
    /// 없으므로 인증도 복호화도 타지 않는다 — `revealPayload`를 스텁하지 않아, 불리면 실패한다.
    @Test("수정 진입: 값이 이미 있으면 인증 없이 편집 모드로 들어간다")
    func didTapEdit_withLoadedPayload_entersEditingWithoutAuthentication() async {
        let secret = Self.makeSecret(name: "GitHub Token")
        let payload = Self.editablePayload
        let project = Project(
            id: UUID(), name: "DrinkiG",
            createdAt: Self.referenceDate, updatedAt: Self.referenceDate
        )

        let store = TestStore(
            initialState: {
                var state = SecretDetailFeature.State(secret: secret)
                state.payloadState = .loaded(payload)
                state.linkedProjectsState = .loaded([project])
                return state
            }()
        ) {
            SecretDetailFeature()
        } withDependencies: {
            // 프로젝트 목록은 이 테스트의 관심사가 아니다. 액션을 내지 않게 해 순서 의존을 없앤다.
            $0.secretClient.fetchProjects = { throw CancellationError() }
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canEditSecrets = { true }
        }

        await store.send(.didTapEdit)
        await store.receive(.canEditSecretsResponse(.success(true))) {
            $0.isLoadingProjects = true
            $0.mode = .editing
            $0.editFields = SecretMetaFields(secret: secret, payload: payload, projectIds: [project.id])
            $0.editFieldsBaseline = $0.editFields
            $0.editPayloadBaseline = payload
        }
    }

    @Test("수정 진입: 값이 없으면 복호화한 뒤 편집 모드로 들어간다")
    func didTapEdit_withoutPayload_decryptsThenEnters() async {
        let secret = Self.makeSecret()
        let payload = Self.editablePayload

        let store = TestStore(initialState: Self.readyToEditState(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in payload }
            $0.secretClient.fetchProjects = { throw CancellationError() }
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canEditSecrets = { true }
        }

        await store.send(.didTapEdit)
        await store.receive(.canEditSecretsResponse(.success(true))) {
            $0.isLoadingProjects = true
            $0.payloadState = .loading
            $0.isEnteringEdit = true
        }
        await store.receive(.payloadResponse(.success(payload), then: .edit)) {
            $0.payloadState = .loaded(payload)
            $0.revealAuthorizedAt = Self.referenceDate
            $0.isEnteringEdit = false
            $0.mode = .editing
            $0.editFields = SecretMetaFields(secret: secret, payload: payload, projectIds: [])
            $0.editFieldsBaseline = $0.editFields
            $0.editPayloadBaseline = payload
        }
    }

    /// 인증을 취소했는데 편집 화면이 열려 있으면 안 된다. TestStore가 상태 변화를 전수 검사하므로
    /// mode가 `.editing`으로 넘어갔다면 이 테스트가 실패한다.
    @Test("수정 진입: 복호화에 실패하면 조회 모드에 남는다")
    func didTapEdit_decryptionFailure_staysViewing() async {
        let secret = Self.makeSecret()

        let store = TestStore(initialState: Self.readyToEditState(secret: secret)) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in
                throw SecretUseCaseError.authenticationFailure(.cancelled)
            }
            $0.secretClient.fetchProjects = { throw CancellationError() }
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canEditSecrets = { true }
        }

        await store.send(.didTapEdit)
        await store.receive(.canEditSecretsResponse(.success(true))) {
            $0.isLoadingProjects = true
            $0.payloadState = .loading
            $0.isEnteringEdit = true
        }
        await store.receive(.payloadResponse(.failure(.authenticationFailure(.cancelled)), then: .edit)) {
            $0.payloadState = .failed(.authenticationFailure(.cancelled))
            $0.isEnteringEdit = false
            $0.alert = .payloadRevealFailed(.authRequired)
        }
    }

    // MARK: - 편집 취소

    @Test("취소: 건드린 것이 없으면 확인 없이 조회로 돌아간다")
    func didTapCancelEdit_withoutChanges_returnsImmediately() async {
        let store = TestStore(initialState: Self.editingState()) {
            SecretDetailFeature()
        }

        await store.send(.didTapCancelEdit) {
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
    }

    @Test("취소: 변경이 있으면 확인 alert를 띄우고 편집 모드에 남는다")
    func didTapCancelEdit_withChanges_presentsConfirmDiscard() async {
        var initial = Self.editingState()
        initial.editFields?.memo = "고친 메모"

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapCancelEdit) {
            $0.alert = .confirmDiscard
        }
    }

    @Test("취소 확정: 편집 전용 상태가 모두 비워진다")
    func confirmDiscard_clearsEditingState() async {
        var initial = Self.editingState()
        initial.editFields?.name = "고친 이름"

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapCancelEdit) {
            $0.alert = .confirmDiscard
        }
        await store.send(.alert(.presented(.confirmDiscard))) {
            $0.alert = nil
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
    }

    /// 드롭다운은 선택을 Set으로 다루고 `Array(Set)`으로 되돌리므로 같은 프로젝트를 껐다 켜기만 해도
    /// 배열 순서가 달라진다. 그것을 변경으로 세면 **아무것도 안 바꾼 사용자에게 확인 alert가 뜬다.**
    @Test("취소: 프로젝트 순서만 다른 것은 변경이 아니다")
    func didTapCancelEdit_projectIdsReordered_returnsImmediately() async {
        let first = UUID()
        let second = UUID()
        var initial = Self.editingState(projectIds: [first, second])
        initial.editFields?.projectIds = [second, first]

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapCancelEdit) {
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
    }

    /// 남겨두면 다음 편집 진입이 **옛 목록으로 시작**해 그 사이 지워진 프로젝트가 선택지에 뜬다.
    @Test("편집을 끝내면 프로젝트 선택 옵션과 로딩 표시도 함께 비워진다")
    func endEditing_clearsProjectOptions() async {
        var initial = Self.editingState()
        initial.availableProjects = [
            Project(id: UUID(), name: "DrinkiG", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)
        ]
        initial.isLoadingProjects = true

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapCancelEdit) {
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
            $0.availableProjects = []
            $0.isLoadingProjects = false
        }
    }

    // MARK: - 편집 폼의 프로젝트 목록

    @Test("편집 진입 시 프로젝트 선택 옵션을 읽어 온다")
    func didTapEdit_loadsAvailableProjects() async {
        let secret = Self.makeSecret()
        let payload = Self.editablePayload
        let projects = [
            Project(id: UUID(), name: "DrinkiG", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)
        ]

        let store = TestStore(
            initialState: Self.readyToEditState(secret: secret, payloadState: .loaded(payload))
        ) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.fetchProjects = { projects }
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canEditSecrets = { true }
        }

        await store.send(.didTapEdit)
        await store.receive(.canEditSecretsResponse(.success(true))) {
            $0.isLoadingProjects = true
            $0.mode = .editing
            $0.editFields = SecretMetaFields(secret: secret, payload: payload, projectIds: [])
            $0.editFieldsBaseline = $0.editFields
            $0.editPayloadBaseline = payload
        }
        await store.receive(.availableProjectsResponse(.success(projects))) {
            $0.isLoadingProjects = false
            $0.availableProjects = projects
        }
    }

    /// 프로젝트 연결만 못 바꿀 뿐 나머지 필드는 영향이 없으므로 편집을 계속할 수 있게 둔다.
    @Test("프로젝트 목록 조회 실패: alert를 띄우되 편집 모드는 유지한다")
    func availableProjectsFailure_keepsEditing() async {
        let secret = Self.makeSecret()
        let payload = Self.editablePayload

        let store = TestStore(
            initialState: Self.readyToEditState(secret: secret, payloadState: .loaded(payload))
        ) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.fetchProjects = { throw ProjectUseCaseError.unexpected }
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canEditSecrets = { true }
        }

        await store.send(.didTapEdit)
        await store.receive(.canEditSecretsResponse(.success(true))) {
            $0.isLoadingProjects = true
            $0.mode = .editing
            $0.editFields = SecretMetaFields(secret: secret, payload: payload, projectIds: [])
            $0.editFieldsBaseline = $0.editFields
            $0.editPayloadBaseline = payload
        }
        await store.receive(.availableProjectsResponse(.failure(.unexpected))) {
            $0.isLoadingProjects = false
            $0.alert = .projectsLoadFailed
        }
    }

    /// 전체 재조회를 하지 않는 것이 요지다 — 편집 중인 폼이 그대로 있어야 한다.
    @Test("프로젝트 생성 시트: 만들어진 프로젝트가 선택 옵션에 더해진다")
    func createProject_appendsToAvailableProjects() async {
        let newItem = ProjectItem(id: UUID(), name: "새 프로젝트")

        let store = TestStore(initialState: Self.editingState()) {
            SecretDetailFeature()
        } withDependencies: {
            $0.date = .constant(Self.referenceDate)
            $0.entitlementClient.canCreateProject = { true }
        }

        await store.send(.didTapCreateProject)
        await store.receive(.canCreateProjectResponse(.success(true))) {
            $0.createProject = CreateProjectFeature.State()
        }
        await store.send(.createProject(.presented(.delegate(.projectCreated(newItem))))) {
            $0.availableProjects = [
                Project(
                    id: newItem.id, name: newItem.name,
                    createdAt: Self.referenceDate, updatedAt: Self.referenceDate
                )
            ]
        }
        // 저장 여부와 무관하게 프로젝트는 이미 만들어졌다 — 사이드바가 곧바로 알아야 한다.
        await store.receive(.delegate(.projectsChanged))
    }

    // MARK: - 저장

    /// 아무것도 안 바꾸고 Save를 누르면 도메인을 부르지 않는다. 부르면 updatedAt만 갱신되어
    /// 목록의 "최근 추가" 정렬이 이유 없이 흔들린다. `updateSecret`을 스텁하지 않아, 불리면 실패한다.
    @Test("저장: 변경이 없으면 write 없이 조회로 돌아간다")
    func didTapSave_withoutChanges_skipsWrite() async {
        let store = TestStore(initialState: Self.editingState()) { SecretDetailFeature() }

        await store.send(.didTapSave) {
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
    }

    /// 순서 차이를 변경으로 세면 `updatedAt`만 바꾸는 write가 나가 목록의 "최근" 정렬이 흔들린다 —
    /// 변경 없음 판정이 막으려던 바로 그 일이다. `updateSecret`을 스텁하지 않아, 불리면 실패한다.
    @Test("저장: 프로젝트 순서만 다르면 write 없이 조회로 돌아간다")
    func didTapSave_projectIdsReordered_skipsWrite() async {
        let first = UUID()
        let second = UUID()
        var initial = Self.editingState(projectIds: [first, second])
        initial.editFields?.projectIds = [second, first]

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapSave) {
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
    }

    @Test("저장: 필수 필드가 비면 인라인 경고만 세우고 저장하지 않는다")
    func didTapSave_missingRequired_setsValidationErrors() async {
        var initial = Self.editingState()
        initial.editFields?.content = .apiKeyToken(APIKeyTokenFields(value: "", authorityScope: "repo:read"))

        let store = TestStore(initialState: initial) { SecretDetailFeature() }

        await store.send(.didTapSave) {
            $0.validationErrors = [.value: .module("Required.")]
        }
    }

    @Test("저장 성공: secret·payloadState 교체 + 열린 필드 정리 + delegate")
    func didTapSave_success() async {
        let secret = Self.makeSecret(name: "GitHub Token")
        var initial = Self.editingState(secret: secret)
        // payload 자체를 고쳐야 payloadState 교체 단언에 의미가 생긴다 —
        // 공통 필드만 바꾸면 저장된 payload가 baseline과 같아 갱신 여부를 구분할 수 없다.
        initial.editFields?.content = .apiKeyToken(
            APIKeyTokenFields(value: "ghp_new", authorityScope: "repo:read")
        )
        initial.revealedFields = [.value]
        let saved = CreateSecretPayload.apiKey(
            APIKeyPayload(value: "ghp_new"),
            APIKeyMetadata(scope: "repo:read")
        )
        let updated = Self.makeSecret(name: "GitHub Token")

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, _, _, _ in updated }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(updated), saved: saved)) {
            $0.isSaving = false
            $0.secret = updated
            $0.payloadState = .loaded(saved)
            $0.revealedFields = []
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
        await store.receive(.delegate(.secretUpdated(updated)))
    }

    /// 갱신하지 않으면 저장하며 Touch ID를 통과한 직후 눈 버튼이 **또** 인증을 요구한다.
    /// 3분 캐싱 정책이 이 경로에서만 무너진다.
    @Test("저장 직전 재인증: 인증 창을 다시 연다")
    func didTapSave_reauthenticates_refreshesAuthWindow() async {
        var initial = Self.editingState()
        // 인증 창이 닫힌 채로 저장에 들어가는 상황을 만든다.
        initial.revealAuthorizedAt = Self.referenceDate.addingTimeInterval(-1_000)
        initial.editFields?.content = .apiKeyToken(
            APIKeyTokenFields(value: "ghp_new", authorityScope: "repo:read")
        )
        let saved = CreateSecretPayload.apiKey(
            APIKeyPayload(value: "ghp_new"),
            APIKeyMetadata(scope: "repo:read")
        )
        let updated = Self.makeSecret(name: "GitHub Token")

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.authenticate = { _ in }
            $0.secretClient.updateSecret = { _, _, _, _ in updated }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveAuthenticated) {
            $0.revealAuthorizedAt = Self.referenceDate
        }
        await store.receive(.saveResponse(.success(updated), saved: saved)) {
            $0.isSaving = false
            $0.secret = updated
            $0.payloadState = .loaded(saved)
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
        await store.receive(.delegate(.secretUpdated(updated)))
    }

    /// 인증이 취소되면 쓰기는 나가지 않으므로 인증 창도 열리면 안 된다.
    /// `updateSecret`을 스텁하지 않아, 불리면 실패한다.
    @Test("저장 직전 재인증 실패: 인증 창을 열지 않고 편집에 남는다")
    func didTapSave_reauthenticationFails_keepsWindowClosed() async {
        let expired = Self.referenceDate.addingTimeInterval(-1_000)
        var initial = Self.editingState()
        initial.revealAuthorizedAt = expired
        initial.editFields?.content = .apiKeyToken(
            APIKeyTokenFields(value: "ghp_new", authorityScope: "repo:read")
        )
        let saved = CreateSecretPayload.apiKey(
            APIKeyPayload(value: "ghp_new"),
            APIKeyMetadata(scope: "repo:read")
        )

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.authenticate = { _ in
                throw SecretUseCaseError.authenticationFailure(.cancelled)
            }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(
            .saveResponse(.failure(.authenticationFailure(.cancelled)), saved: saved)
        ) {
            $0.isSaving = false
            $0.alert = .updateAuthRequired
        }
        #expect(store.state.revealAuthorizedAt == expired)
        #expect(store.state.mode == .editing)
    }

    /// 조회 화면의 Project chip은 `linkedProjects`를 읽는다. 갱신하지 않으면
    /// **이전 프로젝트가 그대로 남아** 방금 저장한 것과 화면이 어긋난다.
    @Test("저장 성공: 바뀐 프로젝트 연결이 조회용 목록에도 반영된다")
    func didTapSave_success_updatesLinkedProjects() async {
        let picked = Project(id: UUID(), name: "DrinkiG", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)
        let other = Project(id: UUID(), name: "CheerLot", createdAt: Self.referenceDate, updatedAt: Self.referenceDate)

        var initial = Self.editingState()
        initial.availableProjects = [picked, other]
        initial.editFields?.projectIds = [picked.id]
        let updated = Self.makeSecret(name: "GitHub Token")

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, _, _, _ in updated }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(updated), saved: Self.editablePayload)) {
            $0.isSaving = false
            $0.secret = updated
            $0.payloadState = .loaded(Self.editablePayload)
            $0.linkedProjectsState = .loaded([picked])
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
            $0.availableProjects = []
        }
        await store.receive(.delegate(.secretUpdated(updated)))
    }

    /// 조회로 되돌리면 사용자가 입력한 내용이 통째로 사라진다.
    @Test("저장 실패: alert를 띄우되 편집 모드와 입력을 유지한다")
    func didTapSave_failure_keepsEditing() async {
        var initial = Self.editingState()
        initial.editFields?.memo = "고친 메모"

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, _, _, _ in throw SecretUseCaseError.unexpected }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.failure(.unexpected), saved: Self.editablePayload)) {
            $0.isSaving = false
            $0.alert = .updateFailed
        }
    }

    /// 바뀐 필드만 `.set`으로 실어야 불필요한 write가 생기지 않는다.
    @Test("저장: 바뀐 공통 필드만 patch에 실린다")
    func didTapSave_patchesOnlyChangedFields() async {
        var initial = Self.editingState()
        initial.editFields?.memo = "고친 메모"

        let recorded = LockIsolated<SecretPatch?>(nil)
        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, patch, _, _ in
                recorded.setValue(patch)
                return Self.makeSecret()
            }
            $0.date = .constant(Self.referenceDate)
        }

        // 관심은 Client에 무엇이 전달됐는지 하나뿐이다. 상태 전이는 위 저장 성공 테스트가 본다.
        store.exhaustivity = .off
        await store.send(.didTapSave)
        await store.finish()

        let patch = try? #require(recorded.value)
        #expect(patch?.memo == .set("고친 메모"))
        #expect(patch?.name == .unchanged)
        #expect(patch?.service == .unchanged)
        #expect(patch?.expiresAt == .unchanged)
        // 서브타입과 즐겨찾기는 수정 화면이 건드리지 않는다.
        #expect(patch?.subType == .unchanged)
        #expect(patch?.liked == .unchanged)
    }

    /// 목록이 같으면 `.set`으로 보내지 않는다 — `.set`은 같은 목록이어도 연결을 다시 조정한다.
    @Test("저장: 프로젝트 연결이 그대로면 unchanged로 보낸다")
    func didTapSave_unchangedProjects_sendsUnchanged() async {
        let projectID = UUID()
        var initial = Self.editingState(projectIds: [projectID])
        initial.editFields?.memo = "고친 메모"

        let recorded = LockIsolated<PatchField<[Project.ID]>?>(nil)
        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, _, _, projectIds in
                recorded.setValue(projectIds)
                return Self.makeSecret()
            }
            $0.date = .constant(Self.referenceDate)
        }

        // 관심은 Client에 무엇이 전달됐는지 하나뿐이다. 상태 전이는 위 저장 성공 테스트가 본다.
        store.exhaustivity = .off
        await store.send(.didTapSave)
        await store.finish()

        #expect(recorded.value == .unchanged)
    }

    @Test("저장: 프로젝트 연결이 바뀌면 최종 목록을 set으로 보낸다")
    func didTapSave_changedProjects_sendsSet() async {
        let kept = UUID()
        let added = UUID()
        var initial = Self.editingState(projectIds: [kept])
        initial.editFields?.projectIds = [kept, added]

        let recorded = LockIsolated<PatchField<[Project.ID]>?>(nil)
        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretClient.updateSecret = { _, _, _, projectIds in
                recorded.setValue(projectIds)
                return Self.makeSecret()
            }
            $0.date = .constant(Self.referenceDate)
        }

        // 관심은 Client에 무엇이 전달됐는지 하나뿐이다. 상태 전이는 위 저장 성공 테스트가 본다.
        store.exhaustivity = .off
        await store.send(.didTapSave)
        await store.finish()

        #expect(recorded.value == .set([kept, added]))
    }
}


// MARK: - 편집 Fixtures

@MainActor
extension SecretDetailFeatureTests {

    /// metadata까지 있는 조합이라야 보존·dirty 판정 경로가 함께 걸린다.
    fileprivate static var editablePayload: CreateSecretPayload {
        .apiKey(APIKeyPayload(value: "ghp_x"), APIKeyMetadata(scope: "repo:read"))
    }

    /// 수정 버튼을 누를 수 있는 조회 상태. 연결 목록을 읽어 오기 전에는 수정 진입이 막히므로,
    /// 진입 자체가 관심사가 아닌 테스트도 이 상태에서 출발해야 한다.
    fileprivate static func readyToEditState(
        secret: Secret,
        payloadState: LoadingState<CreateSecretPayload, SecretUseCaseError> = .idle,
        linkedProjects: [Project] = []
    ) -> SecretDetailFeature.State {
        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = payloadState
        state.linkedProjectsState = .loaded(linkedProjects)
        return state
    }

    /// 편집 진입을 마친 상태. `beginEditing`이 세우는 것과 같은 조합이어야 한다.
    fileprivate static func editingState(
        secret: Secret = makeSecret(name: "GitHub Token"),
        projectIds: [Project.ID] = []
    ) -> SecretDetailFeature.State {
        let payload = editablePayload
        var state = SecretDetailFeature.State(secret: secret)
        state.payloadState = .loaded(payload)
        // 실제 진입 경로를 따른다 — 편집에 들어왔다면 연결 목록을 읽었고 인증 창도 방금 열렸다.
        state.linkedProjectsState = .loaded([])
        state.revealAuthorizedAt = referenceDate
        let fields = SecretMetaFields(secret: secret, payload: payload, projectIds: projectIds)
        state.editFields = fields
        state.editFieldsBaseline = fields
        state.editPayloadBaseline = payload
        state.mode = .editing
        return state
    }

    /// 동기화나 이전 데이터로 같은 이름이 이미 둘 있으면, 이름을 건드리지 않은 저장까지 막혀
    /// 그 시크릿의 메모조차 고칠 수 없게 된다.
    @Test("저장: 이름을 바꾸지 않았으면 중복 검사를 하지 않는다")
    func didTapSave_unchangedName_skipsDuplicateCheck() async {
        var initial = Self.editingState()
        initial.editFields?.memo = "고친 메모"

        // isNameDuplicated는 일부러 비워 둔다 — 불리면 TestStore가 unimplemented로 실패한다.
        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.updateSecret = { _, _, _, _ in Self.makeSecret() }
            $0.date = .constant(Self.referenceDate)
        }

        store.exhaustivity = .off
        await store.send(.didTapSave)
        await store.finish()
    }

    @Test("저장 중복 이름: 수정하지 않고 name에 인라인 경고를 세운다")
    func didTapSave_duplicateName() async {
        var initial = Self.editingState()
        initial.editFields?.name = "다른 토큰"

        // updateSecret은 일부러 비워 둔다 — 불리면 TestStore가 unimplemented로 실패한다.
        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in true }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.nameDuplicated) {
            $0.isSaving = false
            $0.validationErrors[.name] = .module("A secret with this name already exists.")
        }
    }

    @Test("저장 중복 검사: 수정은 자기 자신을 excludingID로 뺀다")
    func didTapSave_duplicateCheckExcludesSelf() async {
        let secret = Self.makeSecret(name: "GitHub Token")
        var initial = Self.editingState(secret: secret)
        initial.editFields?.name = "바꾼 이름"
        let updated = secret
        let passed = LockIsolated<(String, SecretType, Secret.ID?)?>(nil)

        let store = TestStore(initialState: initial) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { name, secretType, excludingID in
                passed.setValue((name, secretType, excludingID))
                return false
            }
            $0.secretClient.updateSecret = { _, _, _, _ in updated }
            $0.date = .constant(Self.referenceDate)
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(updated), saved: Self.editablePayload)) {
            $0.isSaving = false
            $0.mode = .viewing
            $0.editFields = nil
            $0.editFieldsBaseline = nil
            $0.editPayloadBaseline = nil
        }
        await store.receive(.delegate(.secretUpdated(updated)))

        #expect(passed.value?.0 == "바꾼 이름")
        #expect(passed.value?.1 == secret.secretType)
        #expect(passed.value?.2 == secret.id)
    }

}
