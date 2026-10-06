// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

// MARK: - SecretDetailView

public struct SecretDetailView: View {

    // MARK: - Properties

    @Bindable public var store: StoreOf<SecretDetailFeature>

    // MARK: - Init

    public init(store: StoreOf<SecretDetailFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        // 필드 폭은 컨테이너 폭에서 파생된다. detail 컬럼은 기본적으로 가변 폭 1열(.detailFluid)이고,
        // 컬럼이 2열 임계값(816)을 넘으면 CreateSecret과 같은 .dual 배열로 전환된다.
        GeometryReader { proxy in
            let layout = DetailColumnFormLayout.layout(for: proxy.size.width)
            VStack(spacing: 0) {
                ScrollView {
                    bodyStack {
                        // 헤더는 두 모드가 사실상 같으므로 교체 대상에서 빼둔다
                        Group {
                            if store.mode == .viewing {
                                viewingSection.transition(.opacity)
                            } else {
                                editingSection.transition(.opacity)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if store.mode == .editing {
                    // 생성 화면과 마찬가지로 구분선을 두지 않는다 — footer 자체가 여백으로 분리된다.
                    footer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // `value`를 좁히지 않으면 편집 중 타이핑 한 글자마다 폼 전체가 다시 애니메이션된다.
            .dvAnimation(MotionMetrics.layout, value: store.mode)
            // header/footer는 본문과 분리된 채 각자 이 프레임을 따라간다.
            .formMaxWidth()
            .formLayout(layout)
        }
        // 진행 중임을 알리는 지점은 화면당 하나로 모은다 — `windowBusy`는 서브트리마다 값을
        // 세우는 preference라, 조상과 자손이 각각 부르면 어느 쪽이 남는지가 배치에 좌우된다.
        // 눈·복사가 유발한 복호화는 여기에 넣지 않는다 — 창을 잠그면 "나중 요청이 앞 요청을
        // 대체한다"는 규칙(``SecretDetailFeature/CancelID/reveal``)이 눌러볼 수 없게 되어 사라진다.
        .windowBusy(store.isSaving || store.isEnteringEdit)
        // `id:`가 필수다 — 다른 시크릿 선택 시 뷰가 재생성되지 않아 평범한 `.task`는 다시 돌지 않는다.
        // `finish()`를 await해야 secret이 바뀔 때 이전 secret의 lifecycle 구독·프로젝트 조회가 함께 끝난다.
        .task(id: store.secret.id) {
            await store.send(.task).finish()
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.createProject, action: \.createProject)) { store in
            CreateProjectView(store: store)
        }
    }
}

// MARK: - Subviews

extension SecretDetailView {

    // MARK: Viewing

    /// payload 필드는 값이 있든 없든 마스킹되므로 복호화 전후로 화면 구성이 달라지지 않고, 로딩·실패 전용 화면도
    /// 필요 없다(실패는 alert로 알린다). secure·copy 동작은 Environment로 내려보낸다 — 필드가 9개 섹션
    /// 안쪽에 흩어져 있어 파라미터로 넘기면 중간 섹션들이 쓰지도 않는 값을 계속 실어 나른다.
    private var viewingSection: some View {
        DetailPayloadSectionView(
            secret: store.secret,
            linkedProjects: store.linkedProjects,
            payload: displayedPayload
        )
        .environment(
            \.detailFieldActions,
            DetailFieldActions(
                revealedFields: store.revealedFields,
                onToggleReveal: { store.send(.didTapToggleReveal($0)) },
                onCopy: { store.send(.didTapCopy($0)) },
                onCopyPlainValue: { store.send(.didTapCopyPlainValue($0)) }
            )
        )
    }

    /// 민감 필드는 어차피 마스킹되어 화면이 같고, metadata는 평문이라 `Secret`에서 그대로 채워지므로 평문 필드가 처음부터 보인다.
    private var displayedPayload: CreateSecretPayload {
        if case .loaded(let payload) = store.payloadState {
            return payload
        }
        return .beforeReveal(for: store.secret)
    }

    /// 복호화 전후로 padding·정렬이 어긋나지 않게 한곳에 둔다.
    private func bodyStack<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            content()
        }
        .padding(.horizontal, FormLayoutMetrics.horizontalPadding)
        .padding(.vertical, FormLayoutMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        SecretDetailHeaderView(
            secretType: store.secret.secretType,
            subType: store.secret.subType,
            isLiked: store.secret.liked,
            isEditEnabled: isEditEnabled,
            isEditing: store.mode == .editing,
            onToggleLike: { store.send(.didTapToggleLike) },
            onEdit: { store.send(.didTapEdit) },
            onDelete: { store.send(.didTapDelete) }
        )
        .disabled(store.isDeleting)
    }

    /// 복호화는 **진행 중일 때만** 막는다 — `.idle`에서 누르면 그때 복호화가 시작되고, `.failed`에서 누르면
    /// 재시도가 된다(실패했다고 수정을 영영 막을 이유가 없다). 연결된 프로젝트는 다르다 — 빈 목록을 baseline으로
    /// 삼으면 저장할 때 실제 연결이 끊기므로 `.loaded`가 아니면 잠근다(복구는 `linkedProjectsLoadFailed` alert의 Retry가 맡는다).
    private var isEditEnabled: Bool {
        if case .loading = store.payloadState { return false }
        guard case .loaded = store.linkedProjectsState else { return false }
        return true
    }

    // MARK: Editing

    /// 생성 화면과 **같은 SectionView**를 쓴다(`SecretFormSectionsView`) — 마스킹·여러 줄 입력 같은
    /// 배선이 그쪽에 이미 있으므로 편집 모드용으로 다시 만들 것이 없다. `editFields`가 `nil`인 채로
    /// `mode == .editing`인 조합은 reducer가 만들지 않지만, `if let`이 그 조합을 아예 렌더 불가능하게 만든다.
    @ViewBuilder
    private var editingSection: some View {
        // `Binding($store.editFields)`를 쓰면 안 된다. 그 이니셜라이저는 **생성 시점에만** nil을
        // 걸러내고, 만들어진 바인딩은 읽을 때마다 강제 언래핑한다. 취소·저장이 `editFields`를
        // 비우는 순간 전환 애니메이션 때문에 사라지는 쪽 뷰가 아직 살아 있어 한 번 더 읽히고,
        // 그때 크래시한다. 마지막 값으로 대신 읽게 해 둔다 — 그 프레임은 어차피 페이드 아웃 중이다.
        if let snapshot = store.editFields {
            let fields = Binding(
                get: { $store.editFields.wrappedValue ?? snapshot },
                set: { $store.editFields.wrappedValue = $0 }
            )
            SecretFormSectionsView(
                secretType: store.secret.secretType.creatableType,
                subType: store.secret.secretType.creatableType
                    .resolvedSubType(store.secret.subType),
                meta: fields,
                availableProjects: store.availableProjects,
                // 감지 힌트는 생성 화면 전용이다. 이미 저장된 값을 고치는 중에 서비스 제안 필요 없음.
                serviceCandidates: [],
                validationErrors: store.validationErrors,
                detectedServices: [:],
                onCreateProject: { store.send(.didTapCreateProject) }
            )
            // 진행 표시는 창 루트가 그린다 (`.omc/GUIDELINES.md`). 알리는 것은 `body`가
            // 한곳에서 하고, 여기서는 입력만 잠근다 — 잠금은 진행 표시와 별개다.
            .disabled(store.isSaving)
            .environment(\.isProjectLoading, store.isLoadingProjects)
        }
    }

    /// 생성 화면과 같은 컴포넌트를 쓰고 라벨만 다르다.
    private var footer: some View {
        FooterActionsView(
            saveTitle: .module("Save"),
            // 필수 필드 검증은 `didTapSave`가 수행해 인라인 경고를 세운다 — 여기서 미리 막으면
            // 경고가 영영 뜨지 않는다. 생성 화면과 같은 규칙.
            isSaveEnabled: !store.isSaving,
            onCancel: { store.send(.didTapCancelEdit) },
            onSave: { store.send(.didTapSave) }
        )
        .padding(.horizontal, FormLayoutMetrics.horizontalPadding)
        .padding(.vertical, 16)
    }
}

// MARK: - Preview

#if DEBUG

/// 화면 프리뷰는 payload **상태**를 확인하는 자리다 — 타입별 섹션 조합은
/// `DetailPayloadSectionView`의 sweep 프리뷰가 담당하므로 여기서 조합을 늘리지 않는다.
private let _previewSecret = [Secret].previewSubTypeMatrix[0]

/// 진입만으로는 이 상태에 도달하지 않으므로 State를 직접 세팅한다 —
/// 마스킹이 풀린 필드와 그대로 가려진 필드가 한 화면에 같이 보이는 것이 확인 대상이다.
#Preview("SecretDetail · reveal 후") {
    SecretDetailView(
        store: Store(
            initialState: {
                var state = SecretDetailFeature.State(secret: _previewSecret)
                state.payloadState = .loaded(
                    .apiKey(APIKeyPayload(value: "ghp_preview_token"), APIKeyMetadata(scope: "repo:read"))
                )
                state.revealedFields = [.value]
                return state
            }()
        ) {
            SecretDetailFeature()
        }
    )
    .frame(width: 420, height: 700)
}

/// 복호화하지 않으므로 payload 필드가 전부 마스킹된 채로 그려진다.
/// 평문 필드(Services·Environment 등)는 `Secret`에서 오므로 값이 그대로 보여야 한다.
#Preview("SecretDetail · 복호화 전") {
    SecretDetailView(
        store: Store(
            initialState: SecretDetailFeature.State(secret: _previewSecret)
        ) {
            SecretDetailFeature()
        }
    )
    .frame(width: 420, height: 700)
}

/// 실패는 alert로만 알리고 필드는 마스킹된 채 남는다 —
/// 화면 전체를 덮는 실패 뷰가 없다는 것이 이 프리뷰가 확인하려는 지점이다.
#Preview("SecretDetail · 인증 취소") {
    SecretDetailView(
        store: Store(
            initialState: {
                var state = SecretDetailFeature.State(secret: _previewSecret)
                state.payloadState = .failed(.authenticationFailure(.cancelled))
                return state
            }()
        ) {
            SecretDetailFeature()
        } withDependencies: {
            $0.secretClient.revealPayload = { _, _ in
                throw SecretUseCaseError.authenticationFailure(.cancelled)
            }
        }
    )
    .frame(width: 420, height: 700)
}

// MARK: 편집 모드

/// `mode`만 바꾸면 `editFields`가 비어 폼이 그려지지 않는다. reducer의 `beginEditing`이 세우는
/// 조합을 그대로 만들어 준다 — 프리뷰가 실제 진입과 다른 상태를 보여주면 확인의 의미가 없다.
private func _editingPreviewState(
    isSaving: Bool = false,
    validationErrors: [SecretFieldID: String] = [:]
) -> SecretDetailFeature.State {
    let payload = CreateSecretPayload.apiKey(
        APIKeyPayload(value: "ghp_preview_token"),
        APIKeyMetadata(scope: "repo:read")
    )
    let projects = [Project].preview
    var state = SecretDetailFeature.State(secret: _previewSecret)
    state.payloadState = .loaded(payload)
    state.linkedProjectsState = .loaded(Array(projects.prefix(1)))
    state.availableProjects = projects
    let fields = SecretMetaFields(
        secret: _previewSecret,
        payload: payload,
        projectIds: state.linkedProjects.map(\.id)
    )
    state.editFields = fields
    state.editFieldsBaseline = fields
    state.editPayloadBaseline = payload
    state.isSaving = isSaving
    state.validationErrors = validationErrors
    state.mode = .editing
    return state
}

/// 확인 대상은 세 가지다 — 헤더에서 공유·수정·삭제가 사라지고 즐겨찾기만 회색으로 남는지,
/// 폼이 생성 화면과 같은 SectionView로 그려지는지, footer 라벨이 Save인지.
#Preview("SecretDetail · 편집") {
    SecretDetailView(
        store: Store(initialState: _editingPreviewState()) { SecretDetailFeature() }
    )
    .frame(width: 420, height: 700)
}

/// 컬럼이 2열 임계값을 넘으면 생성 화면과 같은 dual 배열이 되어야 한다.
#Preview("SecretDetail · 편집 (dual)") {
    SecretDetailView(
        store: Store(initialState: _editingPreviewState()) { SecretDetailFeature() }
    )
    .frame(width: 900, height: 700)
}

#Preview("SecretDetail · 편집 저장 중") {
    SecretDetailView(
        store: Store(initialState: _editingPreviewState(isSaving: true)) { SecretDetailFeature() }
    )
    .frame(width: 420, height: 700)
}

#Preview("SecretDetail · 편집 검증 실패") {
    SecretDetailView(
        store: Store(
            initialState: {
                var state = _editingPreviewState(validationErrors: [.value: .module("Required.")])
                state.editFields?.content = .apiKeyToken(APIKeyTokenFields(value: ""))
                return state
            }()
        ) {
            SecretDetailFeature()
        }
    )
    .frame(width: 420, height: 700)
}

#endif
