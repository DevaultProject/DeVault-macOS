// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVCore
import DVDomain
import Foundation

// MARK: - CreateSecretFeature

@Reducer
public struct CreateSecretFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        /// 이전 화면에서 주입되는 SecretType. 이 화면 안에서는 변경 불가.
        let secretType: CreatableSecretType

        var selectedSubType: CreatableSecretSubType?

        var meta: SecretMetaFields

        var availableProjects: [Project] = []

        /// 도메인 매핑 실패로 누락된 필드에 대한 인라인 경고. Save 시도 시 세팅.
        var validationErrors: [SecretMetaFields.FieldID: String] = [:]

        /// "Auto-detected: <service>" 인라인 힌트. 감지 엔진이 primaryDetectionFieldID 기준으로 채움.
        var detectedServices: [SecretMetaFields.FieldID: String] = [:]

        /// 감지 엔진이 넘겨준 service chip 후보 목록. `ServicesFieldView`가 chip으로 표시.
        var serviceCandidates: [String] = []

        var isSaving = false

        /// 프로젝트 목록을 로드 중인 동안 true. Project picker spinner용.
        var isLoadingProjects = false

        /// 설정의 기본 환경을 이미 얹었는지. `.task`는 화면이 다시 만들어질 때마다 실행되므로
        /// 이 표시가 없으면 사용자가 고른 환경을 덮어쓴다.
        var didApplyDefaultEnvironment = false

        @Presents var alert: AlertState<Action.Alert>?

        /// 프로젝트 생성 시트 State. `didTapCreateProject` 시 세팅되어 sheet 노출.
        @Presents var createProject: CreateProjectFeature.State?

        public init(secretType: CreatableSecretType) {
            let initialSubType = secretType.availableSubTypes.first
            self.secretType = secretType
            self.selectedSubType = initialSubType
            self.meta = SecretMetaFields(
                content: .default(for: secretType, subType: initialSubType)
            )
        }

        /// Create 버튼의 disable/enable 판정.
        /// 필수 필드 검증은 `didTapSave`가 `handleSave`에서 수행해 `validationErrors`를 채운다 —
        /// 여기서 사전 차단하면 인라인 warning이 절대 안 뜨므로 저장 중 재클릭만 막는다.
        var isSaveEnabled: Bool {
            !isSaving
        }
    }

    // MARK: - Action

    public enum Action: BindableAction, Equatable {

        // MARK: - View

        case task
        case binding(BindingAction<State>)
        case didTapCancel
        case didTapSave
        case didTapCreateProject
        /// Project 생성 게이트 판정 결과. 폼 안에서 만드는 경로도 사이드바와 같은 규칙을 탄다.
        case canCreateProjectResponse(Result<Bool, ProjectUseCaseError>)

        // MARK: - Internal

        case projectsResponse(Result<[Project], ProjectUseCaseError>)
        case saveResponse(Result<Secret, SecretUseCaseError>)
        /// 같은 타입에 같은 이름이 이미 있어 저장을 멈췄다.
        case nameDuplicated
        /// 감지 엔진이 후보 서비스를 넘겨주면 `state.serviceCandidates`에 저장.
        case didDetectServiceCandidates([String])

        // MARK: - Child

        case alert(PresentationAction<Alert>)
        case createProject(PresentationAction<CreateProjectFeature.Action>)

        // MARK: - Delegate

        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmCancel
        }

        public enum Delegate: Equatable {
            case secretCreated(Secret.ID)
            case cancelled
            /// 폼 안에서 프로젝트를 새로 만들었다. **시크릿 저장 여부와 무관하게** 프로젝트는 이미
            /// 만들어졌으므로 사이드바가 곧바로 반영해야 한다 — 취소하고 나가도 프로젝트는 남는다.
            case projectsChanged
            /// 무료 한도에 걸려 프로젝트를 더 만들 수 없다. 페이월은 상위가 소유하므로 올려보낸다.
            case paywallRequired
        }
    }

    // MARK: - Dependencies

    @Dependency(\.secretManagementClient) var secretManagementClient
    @Dependency(\.projectClient) var projectClient
    @Dependency(\.entitlementClient) var entitlementClient
    @Dependency(\.detectionClient) var detectionClient
    @Dependency(\.generalSettingsClient) var generalSettingsClient
    @Dependency(\.date.now) var now

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            // MARK: View

            case .task:
                // 설정의 기본 환경을 폼 초기값으로 **한 번만** 얹는다. `.task`는 화면이 다시
                // 만들어질 때마다 실행되는데(설정 화면을 다녀오면 State는 살아남은 채 뷰만
                // 다시 만들어진다) 매번 얹으면 사용자가 고른 환경이 조용히 되돌아간다.
                //
                // 저장된 문자열이 폼 enum에 없으면 `.dev`로 떨어뜨린다 — 설정 화면이 읽을 때와
                // 같은 규칙이다(`GeneralSettingsFeature.task`).
                if !state.didApplyDefaultEnvironment {
                    state.didApplyDefaultEnvironment = true
                    state.meta.environment = SecretEnvironment(
                        rawValue: generalSettingsClient.defaultEnvironment()
                    ) ?? .dev
                }
                state.isLoadingProjects = true
                return .run { send in
                    do {
                        let projects = try await projectClient.fetchProjects()
                        await send(.projectsResponse(.success(projects)))
                    } catch is CancellationError {
                        // ifLet이 feature를 해제할 때 effect가 취소됨 — state 자체가 사라지므로 별도 처리 불필요
                    } catch {
                        let mapped = (error as? ProjectUseCaseError) ?? .unexpected
                        await send(.projectsResponse(.failure(mapped)))
                    }
                }

            case .binding(\.selectedSubType):
                state.meta.content = .default(
                    for: state.secretType,
                    subType: state.selectedSubType
                )
                state.validationErrors = [:]
                state.serviceCandidates = []
                state.detectedServices = [:]
                return .none

            case .binding:
                let primary = state.meta.primaryDetectionValue
                guard !primary.isEmpty else {
                    state.serviceCandidates = []
                    state.detectedServices = [:]
                    return .none
                }
                let result = detectionClient.detect(SensitiveString(primary))
                state.serviceCandidates = result.candidates.map(\.service)
                let fieldID = state.meta.primaryDetectionFieldID
                state.detectedServices[fieldID] = result.candidates.first?.service
                return .none

            case .didTapCancel:
                state.alert = .confirmCancel
                return .none

            case .didTapSave:
                return handleSave(state: &state)

            case .didTapCreateProject:
                // 시트를 열기 전에 묻는다. 열어 두고 저장에서 막으면 입력한 이름이 날아간다.
                return .run { send in
                    await send(.canCreateProjectResponse(Result {
                        try await entitlementClient.canCreateProject()
                    }.mapError(ProjectUseCaseError.map)))
                }

            case .canCreateProjectResponse(.success(true)):
                state.createProject = CreateProjectFeature.State()
                return .none

            case .canCreateProjectResponse(.success(false)):
                return .send(.delegate(.paywallRequired))

            case .canCreateProjectResponse(.failure):
                // 판정 실패는 저장소가 깨진 것이다. 페이월을 띄우면 결제해도 해결되지 않는다.
                return .none

            // MARK: Internal

            case .projectsResponse(.success(let projects)):
                state.isLoadingProjects = false
                state.availableProjects = projects
                return .none

            case .projectsResponse(.failure(let err)):
                state.isLoadingProjects = false
                state.availableProjects = []
                state.alert = .projectLoadFailed(ProjectLoadError.map(err))
                return .none

            case .nameDuplicated:
                state.isSaving = false
                state.validationErrors[.name] = .module("A secret with this name already exists.")
                return .none

            case .saveResponse(.success(let secret)):
                state.isSaving = false
                return .send(.delegate(.secretCreated(secret.id)))

            case .saveResponse(.failure(let err)):
                state.isSaving = false
                state.alert = .createSecretFailed(CreateSecretError.map(err))
                return .none

            case .didDetectServiceCandidates(let candidates):
                state.serviceCandidates = candidates
                return .none

            // MARK: Child

            case .alert(.presented(.confirmCancel)):
                return .send(.delegate(.cancelled))

            case .alert:
                return .none

            case .createProject(.presented(.delegate(.projectCreated(let projectItem)))):
                state.availableProjects.append(
                    Project(id: projectItem.id, name: projectItem.name, createdAt: now, updatedAt: now)
                )
                return .send(.delegate(.projectsChanged))

            case .createProject:
                return .none

            // MARK: Delegate

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$createProject, action: \.createProject) {
            CreateProjectFeature()
        }
    }

    // MARK: - Helpers

    private func handleSave(state: inout State) -> Effect<Action> {
        switch state.meta.toCreateSecretPayload(
            secretType: state.secretType,
            subType: state.selectedSubType
        ) {
        case .success(let payload):
            state.isSaving = true
            state.validationErrors = [:]
            let draft = state.meta.toSecretDraft(
                secretType: state.secretType,
                subType: state.selectedSubType
            )
            #if DEBUG
            // 개발 검증용 콘솔 dump — payload에 평문 시크릿이 포함되므로 반드시 Debug 빌드에서만 노출.
            Log.info(
                """
                [CreateSecret] Save 요청 준비 완료
                  secretType    = \(state.secretType)
                  subType       = \(String(describing: state.selectedSubType))
                  draft         = \(draft)
                  payload       = \(payload)
                  projectIds    = \(state.meta.projectIds)
                """,
                category: .ui
            )
            #endif
            return .run { [projectIds = state.meta.projectIds] send in
                do {
                    // 암호화보다 앞에 둔다 — 거절될 저장에 크립토 작업을 들일 이유가 없다.
                    guard try await !secretManagementClient.isNameDuplicated(
                        draft.name,
                        draft.secretType,
                        nil
                    ) else {
                        await send(.nameDuplicated)
                        return
                    }
                    let secret = try await secretManagementClient.createSecret(
                        draft: draft,
                        payload: payload,
                        projectIds: projectIds
                    )
                    await send(.saveResponse(.success(secret)))
                } catch {
                    let mapped = (error as? SecretUseCaseError) ?? .unexpected
                    await send(.saveResponse(.failure(mapped)))
                }
            }

        case .failure(.missingRequired(let fieldIDs)):
            Log.warn("[CreateSecret] 필수 필드 누락: \(fieldIDs)", category: .ui)
            // 이전 시도의 잔존 warning 제거 후 이번 검증 결과만 세팅.
            state.validationErrors = [:]
            for fieldID in fieldIDs {
                state.validationErrors[fieldID] = .module("Required.")
            }
            return .none

        case .failure(.invalidTypeCombination):
            Log.error("[CreateSecret] invalid (secretType, subType) 조합", category: .ui)
            return .none
        }
    }
}

// MARK: - AlertState presets

extension AlertState where Action == CreateSecretFeature.Action.Alert {
    static var confirmCancel: Self {
        Self {
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
