// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@Suite("CreateSecretFeature")
@MainActor
struct CreateSecretFeatureTests {

    // MARK: - task / isLoadingProjects

    @Test("task 성공: isLoadingProjects true → false, availableProjects 채워짐")
    func task_success() async {
        let projects = [
            Project(id: UUID(), name: "Backend",  createdAt: Date(), updatedAt: Date()),
            Project(id: UUID(), name: "Mobile",   createdAt: Date(), updatedAt: Date()),
        ]

        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "dev" }
            $0.projectClient.fetchProjects = { projects }
        }

        await store.send(.task) {
            $0.didApplyDefaultEnvironment = true
            $0.isLoadingProjects = true
        }
        await store.receive(.projectsResponse(.success(projects))) {
            $0.isLoadingProjects = false
            $0.availableProjects = projects
        }
    }

    @Test("task 실패: isLoadingProjects false 해제 + projectLoadFailed alert 노출")
    func task_failure() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "dev" }
            $0.projectClient.fetchProjects = {
                throw ProjectUseCaseError.repositoryFailure(.storageUnavailable)
            }
        }

        await store.send(.task) {
            $0.didApplyDefaultEnvironment = true
            $0.isLoadingProjects = true
        }
        await store.receive(.projectsResponse(.failure(.repositoryFailure(.storageUnavailable)))) {
            $0.isLoadingProjects = false
            $0.availableProjects = []
            $0.alert = .projectLoadFailed(ProjectLoadError.map(.repositoryFailure(.storageUnavailable)))
        }
    }

    @Test("task 실패(.unexpected): alert 노출")
    func task_failure_unexpected() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "dev" }
            $0.projectClient.fetchProjects = {
                throw ProjectUseCaseError.unexpected
            }
        }

        await store.send(.task) {
            $0.didApplyDefaultEnvironment = true
            $0.isLoadingProjects = true
        }
        await store.receive(.projectsResponse(.failure(.unexpected))) {
            $0.isLoadingProjects = false
            $0.alert = .projectLoadFailed(.unexpected)
        }
    }

    // MARK: - 기본 환경(설정) 반영

    /// 설정에서 고른 기본 환경이 생성 폼의 Environment 라디오에 미리 선택돼 있어야 한다.
    @Test("task: 설정의 기본 환경이 폼 초기값으로 얹힌다")
    func task_appliesDefaultEnvironmentFromSettings() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "prod" }
            $0.projectClient.fetchProjects = { [] }
        }

        await store.send(.task) {
            $0.didApplyDefaultEnvironment = true
            $0.meta.environment = .prod
            $0.isLoadingProjects = true
        }
        await store.receive(.projectsResponse(.success([]))) {
            $0.isLoadingProjects = false
        }
    }

    /// 앱이 환경 목록을 바꾼 뒤 이전 값이 설정에 남은 경우다. 설정 화면이 읽을 때와 같은 규칙으로
    /// `.dev`에 떨어져야 한다 — 폼이 빈 선택으로 열리면 안 된다.
    @Test("task: 설정에 알 수 없는 환경이 저장돼 있으면 dev로 떨어진다")
    func task_unknownDefaultEnvironment_fallsBackToDev() async {
        // `.dev`에서 출발하면 "폴백했다"와 "아무것도 안 했다"가 같은 결과라 단언이 공허해진다.
        var initial = CreateSecretFeature.State(secretType: .apiKeyToken)
        initial.meta.environment = .prod

        let store = TestStore(initialState: initial) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "canary" }
            $0.projectClient.fetchProjects = { [] }
        }

        await store.send(.task) {
            $0.didApplyDefaultEnvironment = true
            $0.meta.environment = .dev
            $0.isLoadingProjects = true
        }
        await store.receive(.projectsResponse(.success([]))) {
            $0.isLoadingProjects = false
        }
    }

    /// `.task`는 최초 진입이 아니라 뷰가 다시 만들어질 때마다 실행된다 — 설정 화면을 다녀오면
    /// State는 살아남은 채 뷰만 다시 만들어진다. 매번 얹으면 고른 환경이 조용히 되돌아간다.
    @Test("task: 다시 실행돼도 사용자가 고른 환경을 덮어쓰지 않는다")
    func task_rerun_keepsUserChosenEnvironment() async {
        var initial = CreateSecretFeature.State(secretType: .apiKeyToken)
        // 기본 환경을 이미 얹은 뒤 사용자가 직접 prod로 바꾼 상태.
        initial.didApplyDefaultEnvironment = true
        initial.meta.environment = .prod

        let store = TestStore(initialState: initial) {
            CreateSecretFeature()
        } withDependencies: {
            $0.generalSettingsClient.defaultEnvironment = { "dev" }
            $0.projectClient.fetchProjects = { [] }
        }

        await store.send(.task) {
            $0.isLoadingProjects = true
        }
        #expect(store.state.meta.environment == .prod)
        await store.receive(.projectsResponse(.success([]))) {
            $0.isLoadingProjects = false
        }
    }

    // MARK: - selectedSubType binding

    @Test("selectedSubType 변경: content 교체 + validationErrors / detection state 초기화")
    func binding_selectedSubType_swapsContentAndClearsState() async {
        var initialState = CreateSecretFeature.State(secretType: .oauth)
        initialState.validationErrors = [.name: "Required."]
        initialState.serviceCandidates = ["GitHub"]
        initialState.detectedServices = [.clientSecret: "GitHub"]
        initialState.meta.content = .oauthClient(OAuthClientFields(clientId: "prev-id"))

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.set(\.selectedSubType, .serviceAccount)) {
            $0.selectedSubType = .serviceAccount
            $0.meta.content = .default(for: .oauth, subType: .serviceAccount)
            $0.validationErrors = [:]
            $0.serviceCandidates = []
            $0.detectedServices = [:]
        }
    }

    // MARK: - binding / detection

    @Test("binding: 빈 value → 감지 결과 없음, candidates/detectedServices 초기화")
    func binding_emptyValue_clearsDetection() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.serviceCandidates = ["GitHub"]
        initialState.detectedServices = [.value: "GitHub"]

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.detectionClient.detect = { _ in .none }
        }

        await store.send(.set(\.meta.content, .apiKeyToken(APIKeyTokenFields(value: "")))) {
            $0.serviceCandidates = []
            $0.detectedServices = [:]
        }
    }

    @Test("binding: value 입력 → 감지 엔진 호출 → candidates / detectedServices 업데이트")
    func binding_value_triggersDetection() async {
        let candidate = ServiceCandidate(service: "GitHub", displayLabel: "GitHub PAT", confidence: .high)
        let result = DetectionResult(candidates: [candidate])

        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.detectionClient.detect = { _ in result }
        }

        await store.send(.set(\.meta.content, .apiKeyToken(APIKeyTokenFields(value: "ghp_1234567890")))) {
            $0.meta.content = .apiKeyToken(APIKeyTokenFields(value: "ghp_1234567890"))
            $0.serviceCandidates = ["GitHub"]
            $0.detectedServices = [.value: "GitHub"]
        }
    }

    @Test("binding: database linkString → 감지 결과가 detectedServices[.linkString]에 저장")
    func binding_database_usesLinkStringFieldID() async {
        let candidate = ServiceCandidate(service: "PostgreSQL", displayLabel: "PostgreSQL", confidence: .high)
        let result = DetectionResult(candidates: [candidate])

        let store = TestStore(initialState: .init(secretType: .database)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.detectionClient.detect = { _ in result }
        }

        await store.send(.set(\.meta.content, .database(DatabaseFields(linkString: "postgres://user:pass@host/db")))) {
            $0.meta.content = .database(DatabaseFields(linkString: "postgres://user:pass@host/db"))
            $0.serviceCandidates = ["PostgreSQL"]
            $0.detectedServices = [.linkString: "PostgreSQL"]
        }
    }

    // MARK: - didTapSave

    @Test("didTapSave 성공: isSaving true → response로 false → delegate(.secretCreated)")
    func didTapSave_success() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.meta.name = "MyKey"
        initialState.meta.content = .apiKeyToken(APIKeyTokenFields(value: "sk_test"))

        let createdId = UUID()
        let createdSecret = Secret(
            id: createdId,
            name: "MyKey",
            secretType: .apiKeyToken,
            subType: .apiKey,
            createdAt: Date(),
            updatedAt: Date(),
            payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
        )

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretManagementClient.createSecret = { _, _, _ in createdSecret }
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(createdSecret))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.secretCreated(createdId)))
    }

    @Test("didTapSave: expireDate는 그대로 SecretDraft.expiresAt에 전달된다 (23:59:59 고정은 SecretUseCaseHelper 책임)")
    func didTapSave_expireDatePassedThroughAsIs() async throws {
        let pickedDate = DateComponents(
            calendar: .current, year: 2026, month: 8, day: 14, hour: 9, minute: 0, second: 0
        ).date!

        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.meta.name = "MyKey"
        initialState.meta.content = .apiKeyToken(APIKeyTokenFields(value: "sk_test"))
        initialState.meta.expireDate = pickedDate

        let createdSecret = Secret(
            id: UUID(),
            name: "MyKey",
            secretType: .apiKeyToken,
            subType: .apiKey,
            createdAt: Date(),
            updatedAt: Date(),
            payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
        )

        let capturedDraft = LockIsolated<SecretDraft?>(nil)

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in false }
            $0.secretManagementClient.createSecret = { draft, _, _ in
                capturedDraft.setValue(draft)
                return createdSecret
            }
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(createdSecret))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.secretCreated(createdSecret.id)))

        #expect(capturedDraft.value?.expiresAt == pickedDate)
    }

    @Test("didTapSave 매핑 실패: name + value 모두 빈값 → 둘 다 warning, Effect 미발행")
    func didTapSave_missingBoth() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        }

        await store.send(.didTapSave) {
            $0.validationErrors = [.name: String.module("Required."), .value: String.module("Required.")]
        }
    }

    @Test("didTapSave 매핑 실패: name 있으나 value 누락")
    func didTapSave_missingValue() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.meta.name = "MyKey"

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.didTapSave) {
            $0.validationErrors = [.value: String.module("Required.")]
        }
    }

    @Test("didTapSave 재시도: 이전 validationErrors가 새 결과로 대체 (해결된 필드 warning 사라짐)")
    func didTapSave_retryReplacesPriorErrors() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.validationErrors = [.name: "Required.", .value: "Required."]
        initialState.meta.name = "n"

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.didTapSave) {
            $0.validationErrors = [.value: String.module("Required.")]
        }
    }

    @Test("didTapSave 다중 누락: oauth 초기 상태 → name + clientId + clientSecret 모두 warning")
    func didTapSave_oauth_multipleMissing() async {
        let store = TestStore(initialState: .init(secretType: .oauth)) {
            CreateSecretFeature()
        }

        await store.send(.didTapSave) {
            $0.validationErrors = [
                .name: String.module("Required."),
                .clientId: String.module("Required."),
                .clientSecret: String.module("Required."),
            ]
        }
    }

    // MARK: - saveResponse failure → alert

    @Test("saveResponse(.failure .unexpected): isSaving 해제 + unexpected alert 노출")
    func saveResponse_failure_unexpected() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.isSaving = true

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.saveResponse(.failure(.unexpected))) {
            $0.isSaving = false
            $0.alert = .createSecretFailed(.unexpected)
        }
    }

    @Test("saveResponse(.failure .cryptoFailure .keyUnavailable): cryptoUnavailable alert 노출")
    func saveResponse_failure_crypto() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.isSaving = true

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.saveResponse(.failure(.cryptoFailure(.keyUnavailable)))) {
            $0.isSaving = false
            $0.alert = .createSecretFailed(.cryptoUnavailable)
        }
    }

    @Test("saveResponse(.failure .authenticationFailure): authRequired alert 노출")
    func saveResponse_failure_auth() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.isSaving = true

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        }

        await store.send(.saveResponse(.failure(.authenticationFailure(.cancelled)))) {
            $0.isSaving = false
            $0.alert = .createSecretFailed(.authRequired)
        }
    }

    // MARK: - didTapCancel

    @Test("didTapCancel → confirmCancel alert → dismissed → delegate(.cancelled)")
    func didTapCancel_confirm() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        }

        await store.send(.didTapCancel) {
            $0.alert = .confirmCancel
        }
        await store.send(.alert(.presented(.confirmCancel))) {
            $0.alert = nil
        }
        await store.receive(.delegate(.cancelled))
    }

    // MARK: - didTapCreateProject

    @Test("didTapCreateProject: createProject State 세팅 → sheet 노출")
    func didTapCreateProject_opensSheet() async {
        let store = TestStore(initialState: .init(secretType: .apiKeyToken)) {
            CreateSecretFeature()
        } withDependencies: {
            $0.entitlementClient.canCreateProject = { true }
        }

        await store.send(.didTapCreateProject)
        await store.receive(.canCreateProjectResponse(.success(true))) {
            $0.createProject = CreateProjectFeature.State()
        }
    }

    @Test("createProject delegate: 생성된 ProjectItem → availableProjects에 Project로 추가")
    func createProject_delegate_appendsProject() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.createProject = CreateProjectFeature.State()

        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let newItem = ProjectItem(id: UUID(), name: "New Project")

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.date.now = fixedDate
        }

        await store.send(.createProject(.presented(.delegate(.projectCreated(newItem))))) {
            $0.availableProjects = [
                Project(id: newItem.id, name: newItem.name, createdAt: fixedDate, updatedAt: fixedDate)
            ]
        }
        await store.receive(.delegate(.projectsChanged))
    }

    // MARK: - isSaveEnabled

    @Test("isSaveEnabled: 초기 상태(빈 필드)에도 활성 — 필드 검증은 didTapSave에서")
    func isSaveEnabled_initiallyTrue() {
        let state = CreateSecretFeature.State(secretType: .apiKeyToken)
        #expect(state.isSaveEnabled == true)
    }

    @Test("isSaveEnabled: 저장 중에는 false")
    func isSaveEnabled_falseWhileSaving() {
        var state = CreateSecretFeature.State(secretType: .apiKeyToken)
        state.isSaving = true
        #expect(state.isSaveEnabled == false)
    }
    @Test("didTapSave 중복 이름: 생성하지 않고 name에 인라인 경고를 세운다")
    func didTapSave_duplicateName() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.meta.name = "MyKey"
        initialState.meta.content = .apiKeyToken(APIKeyTokenFields(value: "sk_test"))

        // createSecret은 일부러 비워 둔다 — 불리면 TestStore가 unimplemented로 실패한다.
        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { _, _, _ in true }
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.nameDuplicated) {
            $0.isSaving = false
            $0.validationErrors[.name] = .module("A secret with this name already exists.")
        }
    }

    @Test("didTapSave 중복 검사: 생성은 제외할 시크릿이 없으므로 excludingID가 nil이다")
    func didTapSave_duplicateCheckPassesNilExcludingID() async {
        var initialState = CreateSecretFeature.State(secretType: .apiKeyToken)
        initialState.meta.name = "  MyKey  "
        initialState.meta.content = .apiKeyToken(APIKeyTokenFields(value: "sk_test"))

        let created = Secret(
            id: UUID(),
            name: "MyKey",
            secretType: .apiKeyToken,
            subType: .apiKey,
            createdAt: Date(),
            updatedAt: Date(),
            payload: SecretPayload(encryptedData: Data(), keyTag: "test", schemaVersion: 1)
        )
        let passed = LockIsolated<(String, SecretType, Secret.ID?)?>(nil)

        let store = TestStore(initialState: initialState) {
            CreateSecretFeature()
        } withDependencies: {
            $0.secretManagementClient.isNameDuplicated = { name, secretType, excludingID in
                passed.setValue((name, secretType, excludingID))
                return false
            }
            $0.secretManagementClient.createSecret = { _, _, _ in created }
        }

        await store.send(.didTapSave) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.success(created))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.secretCreated(created.id)))

        #expect(passed.value?.0 == "  MyKey  ")
        #expect(passed.value?.1 == .apiKeyToken)
        #expect(passed.value?.2 == nil)
    }

}

// MARK: - Error mapping unit tests

@Suite("CreateSecretError")
struct CreateSecretErrorMappingTests {

    @Test("cryptoFailure.keyUnavailable → .cryptoUnavailable")
    func map_keyUnavailable() {
        #expect(CreateSecretError.map(.cryptoFailure(.keyUnavailable)) == .cryptoUnavailable)
    }

    @Test("cryptoFailure.keychainFailure → .cryptoUnavailable")
    func map_keychainFailure() {
        #expect(CreateSecretError.map(.cryptoFailure(.keychainFailure(status: -25300))) == .cryptoUnavailable)
    }

    @Test("cryptoFailure.encryptionFailed → .cryptoUnavailable")
    func map_encryptionFailed() {
        #expect(CreateSecretError.map(.cryptoFailure(.encryptionFailed)) == .cryptoUnavailable)
    }

    @Test("authenticationFailure → .authRequired")
    func map_auth() {
        #expect(CreateSecretError.map(.authenticationFailure(.cancelled)) == .authRequired)
        #expect(CreateSecretError.map(.authenticationFailure(.failed)) == .authRequired)
    }

    @Test("repositoryFailure → .repositoryFailure")
    func map_repository() {
        #expect(CreateSecretError.map(.repositoryFailure(.storageUnavailable)) == .repositoryFailure)
        #expect(CreateSecretError.map(.repositoryFailure(.persistenceFailed)) == .repositoryFailure)
    }

    @Test("unexpected → .unexpected")
    func map_unexpected() {
        #expect(CreateSecretError.map(.unexpected) == .unexpected)
    }
}

@Suite("ProjectLoadError")
struct ProjectLoadErrorMappingTests {

    @Test("repositoryFailure → .repositoryFailure")
    func map_repository() {
        #expect(ProjectLoadError.map(.repositoryFailure(.storageUnavailable)) == .repositoryFailure)
        #expect(ProjectLoadError.map(.repositoryFailure(.persistenceFailed)) == .repositoryFailure)
    }

    @Test("unexpected → .unexpected")
    func map_unexpected() {
        #expect(ProjectLoadError.map(.unexpected) == .unexpected)
    }
}

// MARK: - Detection helpers unit tests

@Suite("SecretMetaFields detection helpers")
struct SecretMetaFieldsDetectionTests {

    @Test("apiKeyToken: primaryDetectionValue = value, fieldID = .value")
    func apiKeyToken() {
        var fields = SecretMetaFields(content: .apiKeyToken(APIKeyTokenFields(value: "sk-abc")))
        #expect(fields.primaryDetectionValue == "sk-abc")
        #expect(fields.primaryDetectionFieldID == .value)
    }

    @Test("database: primaryDetectionValue = linkString, fieldID = .linkString")
    func database() {
        let fields = SecretMetaFields(content: .database(DatabaseFields(linkString: "postgres://host/db")))
        #expect(fields.primaryDetectionValue == "postgres://host/db")
        #expect(fields.primaryDetectionFieldID == .linkString)
    }

    @Test("serviceAccount: primaryDetectionValue = credentialJSON, fieldID = .credentialJSON")
    func serviceAccount() {
        let fields = SecretMetaFields(content: .serviceAccount(ServiceAccountFields(credentialJSON: "{}")))
        #expect(fields.primaryDetectionValue == "{}")
        #expect(fields.primaryDetectionFieldID == .credentialJSON)
    }

    @Test("sshKey: primaryDetectionValue = privateKey, fieldID = .privateKey")
    func sshKey() {
        let fields = SecretMetaFields(content: .sshKey(SSHKeyFields(privateKey: "-----BEGIN")))
        #expect(fields.primaryDetectionValue == "-----BEGIN")
        #expect(fields.primaryDetectionFieldID == .privateKey)
    }

    @Test("envSet: primaryDetectionValue = envContent, fieldID = .envContent")
    func envSet() {
        let fields = SecretMetaFields(content: .envSet(EnvSetFields(envContent: "K=V")))
        #expect(fields.primaryDetectionValue == "K=V")
        #expect(fields.primaryDetectionFieldID == .envContent)
    }
}
